import XCTest
@testable import ClaudeScope

final class AttributionTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func transcriptLine(
        type: String = "assistant",
        project: String = "/Users/me/monitor",
        session: String = "session-a",
        model: String = "claude-opus-4-8",
        sidechain: Bool = false,
        input: Int = 100,
        cacheWrite: Int = 0,
        cacheRead: Int = 0,
        output: Int = 10,
        offsetSeconds: Double = -60
    ) -> Data {
        let timestamp = ISO8601DateFormatter().string(from: now.addingTimeInterval(offsetSeconds))
        let json: [String: Any] = [
            "type": type,
            "timestamp": timestamp,
            "cwd": project,
            "sessionId": session,
            "isSidechain": sidechain,
            "message": [
                "model": model,
                "usage": [
                    "input_tokens": input,
                    "cache_creation_input_tokens": cacheWrite,
                    "cache_read_input_tokens": cacheRead,
                    "output_tokens": output,
                ],
            ],
        ]
        return try! JSONSerialization.data(withJSONObject: json)
    }

    // MARK: - Line parsing

    func testParsesAssistantTurnWithUsage() throws {
        let turn = AttributionAggregator.turn(
            fromTranscriptLine: transcriptLine(cacheRead: 500_000),
            cutoff: now.addingTimeInterval(-3600)
        )

        XCTAssertEqual(turn?.project, "monitor", "cwd is reduced to a project name")
        XCTAssertEqual(turn?.sessionID, "session-a")
        XCTAssertEqual(turn?.model, "claude-opus-4-8")
        XCTAssertEqual(turn?.usage.cacheReadTokens, 500_000)
        XCTAssertEqual(turn?.usage.contextTokens, 500_100)
    }

    func testIgnoresNonAssistantLinesAndLinesOutsideWindow() {
        let cutoff = now.addingTimeInterval(-3600)

        XCTAssertNil(AttributionAggregator.turn(
            fromTranscriptLine: transcriptLine(type: "user"), cutoff: cutoff))
        XCTAssertNil(AttributionAggregator.turn(
            fromTranscriptLine: transcriptLine(offsetSeconds: -7200), cutoff: cutoff))
        XCTAssertNil(AttributionAggregator.turn(
            fromTranscriptLine: Data("not json".utf8), cutoff: cutoff))
    }

    func testIgnoresAssistantLineWithoutUsage() {
        let json: [String: Any] = [
            "type": "assistant",
            "timestamp": ISO8601DateFormatter().string(from: now),
            "message": ["model": "m"],
        ]
        let data = try! JSONSerialization.data(withJSONObject: json)

        XCTAssertNil(AttributionAggregator.turn(fromTranscriptLine: data, cutoff: now.addingTimeInterval(-60)))
    }

    // MARK: - Aggregation

    private func turn(
        project: String, session: String, model: String = "m",
        sidechain: Bool = false, output: Int = 0, cacheRead: Int = 0
    ) -> AttributionTurn {
        AttributionTurn(
            timestamp: now, project: project, sessionID: session, model: model,
            isSidechain: sidechain,
            usage: TurnUsage(inputTokens: 0, cacheWriteTokens: 0,
                             cacheReadTokens: cacheRead, outputTokens: output)
        )
    }

    func testRanksProjectsSessionsAndModelsByWeight() {
        let snapshot = AttributionAggregator.snapshot(
            turns: [
                turn(project: "monitor", session: "s1", output: 1000),
                turn(project: "monitor", session: "s1", output: 1000),
                turn(project: "small", session: "s2", output: 200),
            ],
            windowDays: 7,
            now: now
        )

        XCTAssertEqual(snapshot.turns, 3)
        XCTAssertEqual(snapshot.projects.first?.key, "monitor")
        XCTAssertEqual(snapshot.projects.first?.share ?? 0, 2000.0 / 2200.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.projects.first?.turns, 2)
        XCTAssertEqual(snapshot.sessions.first?.key, "s1")
        XCTAssertTrue(snapshot.sessions.first?.label.hasPrefix("monitor · s1") ?? false)
    }

    func testCompositionExposesContextAsTheDominantCost() {
        // 1M cache reads (weight 100k) against 10k output (weight 50k):
        // the story users cannot see anywhere else.
        let snapshot = AttributionAggregator.snapshot(
            turns: [turn(project: "p", session: "s", output: 10_000, cacheRead: 1_000_000)],
            windowDays: 7,
            now: now
        )

        let composition = Dictionary(uniqueKeysWithValues: snapshot.composition.map { ($0.key, $0.share) })
        XCTAssertEqual(composition["cache_read"] ?? 0, 100_000.0 / 150_000.0, accuracy: 0.001)
        XCTAssertEqual(composition["output"] ?? 0, 50_000.0 / 150_000.0, accuracy: 0.001)
        XCTAssertEqual(snapshot.composition.first?.key, "cache_read", "sorted by share")
        XCTAssertEqual(snapshot.averageContextTokens, 1_000_000)
    }

    func testDropsEntriesThatWouldRenderAsZeroPercent() {
        let snapshot = AttributionAggregator.snapshot(
            turns: [
                turn(project: "real", session: "s1", output: 100_000),
                turn(project: "<synthetic>", session: "s2", output: 1),
            ],
            windowDays: 7,
            now: now
        )

        XCTAssertEqual(snapshot.projects.map(\.key), ["real"])
    }

    func testSubagentShareIsReported() {
        let snapshot = AttributionAggregator.snapshot(
            turns: [
                turn(project: "p", session: "s", output: 100),
                turn(project: "p", session: "s", sidechain: true, output: 300),
            ],
            windowDays: 7,
            now: now
        )

        XCTAssertEqual(snapshot.subagentShare, 0.75, accuracy: 0.001)
    }

    func testEmptyInputProducesEmptySnapshot() {
        let snapshot = AttributionAggregator.snapshot(turns: [], windowDays: 7, now: now)

        XCTAssertTrue(snapshot.isEmpty)
        XCTAssertTrue(snapshot.composition.isEmpty)
        XCTAssertEqual(snapshot.averageContextTokens, 0)
    }

    func testTokenFormatting() {
        XCTAssertEqual(formatTokenCount(523_379), "523K")
        XCTAssertEqual(formatTokenCount(1_500_000), "1.5M")
        XCTAssertEqual(formatTokenCount(42), "42")
    }
}
