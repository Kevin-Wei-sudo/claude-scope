import XCTest
@testable import ClaudeScope

@MainActor
final class UsageHistoryServiceTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("history-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeService() -> UsageHistoryService {
        UsageHistoryService(
            historyFileURL: directory.appendingPathComponent("history.json"),
            legacyHistoryFileURL: directory.appendingPathComponent("legacy-history.json")
        )
    }

    func testClearHistoryEmptiesPointsAndDeletesFile() throws {
        let service = makeService()
        service.recordDataPoint(pct5h: 0.4, pct7d: 0.5)
        service.flushToDisk()
        let file = directory.appendingPathComponent("history.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))

        service.clearHistory()

        XCTAssertTrue(service.history.dataPoints.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testClearedHistoryDoesNotComeBackFromLegacyFileOnReload() throws {
        // The previous account's data could live in the pre-rename location;
        // loadHistory falls back to it, so clearing must remove it as well.
        let legacy = directory.appendingPathComponent("legacy-history.json")
        let json = """
        {"dataPoints":[{"id":"\(UUID().uuidString)","timestamp":"2026-07-01T00:00:00Z","pct5h":0.9,"pct7d":0.9}]}
        """
        try Data(json.utf8).write(to: legacy)

        let service = makeService()
        service.loadHistory()
        XCTAssertFalse(service.history.dataPoints.isEmpty, "precondition: legacy data is loaded")

        service.clearHistory()
        service.loadHistory()

        XCTAssertTrue(service.history.dataPoints.isEmpty)
    }

    func testFlushAfterClearDoesNotRewriteOldPoints() throws {
        let service = makeService()
        service.recordDataPoint(pct5h: 0.4, pct7d: 0.5)

        service.clearHistory()
        service.flushToDisk()

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: directory.appendingPathComponent("history.json").path)
        )
    }
}
