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

    func testRejectsGarbage() {
        XCTAssertNil(CodexUsageParser.usage(fromAPIResponse: Data("nope".utf8)))
        XCTAssertNil(CodexUsageParser.usage(fromSessionRateLimits: [:]))
    }
}
