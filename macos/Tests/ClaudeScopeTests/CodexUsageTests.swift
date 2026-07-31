import XCTest
@testable import ClaudeScope

final class CodexUsageTests: XCTestCase {
    // Shape captured from a live wham/usage response.
    private let apiJSON = """
    {
      "email": "user@example.com",
      "plan_type": "prolite",
      "rate_limit": {
        "allowed": true,
        "limit_reached": false,
        "primary_window": {
          "used_percent": 70,
          "limit_window_seconds": 604800,
          "reset_after_seconds": 434835,
          "reset_at": 1785917731
        },
        "secondary_window": null
      },
      "additional_rate_limits": [
        {
          "limit_name": "GPT-5.3-Codex-Spark",
          "metered_feature": "codex_bengalfox",
          "rate_limit": {
            "primary_window": {
              "used_percent": 12,
              "limit_window_seconds": 604800,
              "reset_at": 1786087697
            }
          }
        }
      ],
      "credits": { "has_credits": true, "unlimited": false, "balance": "42.5" }
    }
    """

    func testParsesAPIResponse() throws {
        let usage = try XCTUnwrap(CodexUsageParser.usage(fromAPIResponse: Data(apiJSON.utf8)))

        XCTAssertEqual(usage.displayPlan, "Pro Lite")
        XCTAssertEqual(usage.email, "user@example.com")
        XCTAssertEqual(usage.primary?.usedPercent, 70)
        XCTAssertEqual(usage.primary?.windowSeconds, 604_800)
        XCTAssertEqual(usage.primary?.resetAt, Date(timeIntervalSince1970: 1_785_917_731))
        XCTAssertNil(usage.secondary)
        XCTAssertEqual(usage.scoped.count, 1)
        XCTAssertEqual(usage.scoped.first?.name, "GPT-5.3-Codex-Spark")
        XCTAssertEqual(usage.scoped.first?.window.usedPercent, 12)
        XCTAssertTrue(usage.hasCredits)
        XCTAssertEqual(usage.creditsBalance, "42.5")
    }

    func testWindowDurationLabels() {
        XCTAssertEqual(CodexUsage.Window(usedPercent: 0, windowSeconds: 604_800, resetAt: nil).durationLabel, "7d")
        XCTAssertEqual(CodexUsage.Window(usedPercent: 0, windowSeconds: 5 * 3600, resetAt: nil).durationLabel, "5h")
        XCTAssertEqual(CodexUsage.Window(usedPercent: 0, windowSeconds: 86_400, resetAt: nil).durationLabel, "24h")
    }

    func testWindowsListSkipsMissingLanes() throws {
        let usage = try XCTUnwrap(CodexUsageParser.usage(fromAPIResponse: Data(apiJSON.utf8)))
        XCTAssertEqual(usage.windows.map(\.label), ["7d"])
    }

    // Shape captured from a token_count event in ~/.codex/sessions.
    func testParsesSessionFallbackSnapshot() throws {
        let rateLimits: [String: Any] = [
            "limit_id": "codex",
            "primary": [
                "used_percent": 62.0,
                "window_minutes": 10080,
                "resets_at": 1_785_917_731,
            ],
            "secondary": NSNull(),
            "credits": ["has_credits": false, "balance": "0"],
        ]

        let usage = try XCTUnwrap(CodexUsageParser.usage(fromSessionRateLimits: rateLimits))

        XCTAssertEqual(usage.primary?.usedPercent, 62)
        XCTAssertEqual(usage.primary?.windowSeconds, 10_080 * 60)
        XCTAssertEqual(usage.primary?.resetAt, Date(timeIntervalSince1970: 1_785_917_731))
        XCTAssertNil(usage.planType)
        XCTAssertFalse(usage.hasCredits)
    }

    // MARK: - Session scanner

    private func transcript(_ events: [String]) -> String {
        events.joined(separator: "\n")
    }

    private func metaLine(cwd: String) -> String {
        #"{"timestamp":"2026-07-30T10:00:00Z","type":"session_meta","payload":{"type":"session_meta","cwd":"\#(cwd)"}}"#
    }

    private func turnContextLine(model: String) -> String {
        #"{"timestamp":"2026-07-30T10:00:01Z","type":"turn_context","payload":{"type":"turn_context","model":"\#(model)"}}"#
    }

    private func tokenLine(total: Int, timestamp: String = "2026-07-30T10:00:02Z") -> String {
        #"{"timestamp":"\#(timestamp)","type":"event_msg","payload":{"type":"token_count","info":{"last_token_usage":{"total_tokens":\#(total)}}}}"#
    }

    func testScannerAttributesTokensToCurrentModelAndProject() {
        let content = transcript([
            metaLine(cwd: "/Users/me/monitor"),
            turnContextLine(model: "gpt-5.6-sol"),
            tokenLine(total: 1000),
            turnContextLine(model: "codex-auto-review"),
            tokenLine(total: 200),
        ])
        let cutoff = Date(timeIntervalSince1970: 0)

        let turns = CodexSessionScanner.turnTokens(inTranscript: content, cutoff: cutoff)

        XCTAssertEqual(turns.count, 2)
        XCTAssertEqual(turns[0].model, "gpt-5.6-sol")
        XCTAssertEqual(turns[0].project, "monitor")
        XCTAssertEqual(turns[0].tokens, 1000)
        XCTAssertEqual(turns[1].model, "codex-auto-review")
        XCTAssertEqual(turns[1].tokens, 200)
    }

    func testScannerSkipsEventsBeforeCutoff() {
        let content = transcript([
            metaLine(cwd: "/p/x"),
            turnContextLine(model: "m"),
            tokenLine(total: 500, timestamp: "2026-07-01T00:00:00Z"),
            tokenLine(total: 700, timestamp: "2026-07-30T00:00:00Z"),
        ])
        let cutoff = ISO8601DateFormatter().date(from: "2026-07-25T00:00:00Z")!

        let turns = CodexSessionScanner.turnTokens(inTranscript: content, cutoff: cutoff)

        XCTAssertEqual(turns.map(\.tokens), [700])
    }

    func testStatsRankModelsAndProjectsByTokens() {
        let stats = CodexSessionScanner.stats(
            fromTurnTokens: [
                (model: "gpt-5.6-sol", project: "monitor", tokens: 900),
                (model: "gpt-5.6-sol", project: "admin", tokens: 50),
                (model: "codex-auto-review", project: "monitor", tokens: 50),
            ],
            windowDays: 7
        )

        XCTAssertEqual(stats.totalTokens, 1000)
        XCTAssertEqual(stats.models.first?.key, "gpt-5.6-sol")
        XCTAssertEqual(stats.models.first?.share ?? 0, 0.95, accuracy: 0.001)
        XCTAssertEqual(stats.projects.first?.key, "monitor")
        XCTAssertEqual(stats.projects.first?.share ?? 0, 0.95, accuracy: 0.001)
        XCTAssertFalse(stats.isEmpty)
    }

    func testEmptyTurnsProduceEmptyStats() {
        let stats = CodexSessionScanner.stats(fromTurnTokens: [], windowDays: 7)
        XCTAssertTrue(stats.isEmpty)
    }

    func testRejectsGarbage() {
        XCTAssertNil(CodexUsageParser.usage(fromAPIResponse: Data("nope".utf8)))
        XCTAssertNil(CodexUsageParser.usage(fromSessionRateLimits: [:]))
    }
}
