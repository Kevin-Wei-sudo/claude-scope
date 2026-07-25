import XCTest
@testable import ClaudeScope

@MainActor
final class UsageHistoryServiceTests: XCTestCase {
    private var directory: URL!
    private var legacyFile: URL!

    private let accountA = "11111111-1111-1111-1111-111111111111"
    private let accountB = "22222222-2222-2222-2222-222222222222"

    override func setUpWithError() throws {
        directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("history-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        legacyFile = directory.appendingPathComponent("legacy-history.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeService() -> UsageHistoryService {
        UsageHistoryService(directoryURL: directory, legacyHistoryFileURL: legacyFile)
    }

    /// The reported bug: two accounts must never share one series.
    func testSwitchingAccountsKeepsSeriesSeparateAndRestoresThemOnReturn() throws {
        let service = makeService()

        service.activate(accountKey: accountA)
        service.recordDataPoint(pct5h: 0.7, pct7d: 0.6)
        service.recordDataPoint(pct5h: 0.8, pct7d: 0.6)

        service.activate(accountKey: accountB)
        XCTAssertTrue(service.history.dataPoints.isEmpty, "account B must not see account A's points")
        service.recordDataPoint(pct5h: 0.1, pct7d: 0.2)
        XCTAssertEqual(service.history.dataPoints.count, 1)

        service.activate(accountKey: accountA)
        XCTAssertEqual(service.history.dataPoints.count, 2, "account A's own points come back")
        XCTAssertEqual(service.history.dataPoints.map(\.pct5h), [0.7, 0.8])
    }

    func testRecordingIsPausedWhileAccountIsUnknown() {
        let service = makeService()

        service.activate(accountKey: nil)
        service.recordDataPoint(pct5h: 0.5, pct7d: 0.5)

        XCTAssertTrue(service.history.dataPoints.isEmpty)
    }

    func testDetachingKeepsTheAccountFileForNextSignIn() throws {
        let service = makeService()
        service.activate(accountKey: accountA)
        service.recordDataPoint(pct5h: 0.4, pct7d: 0.4)

        service.activate(accountKey: nil)   // sign-out

        XCTAssertTrue(service.history.dataPoints.isEmpty, "signed-out app shows no chart")
        service.activate(accountKey: accountA)
        XCTAssertEqual(service.history.dataPoints.count, 1, "data survives sign-out")
    }

    func testAdoptsPreScopingHistoryOnlyAtLaunch() throws {
        let unscoped = directory.appendingPathComponent("history.json")
        try Data(historyJSON(pct5h: 0.9).utf8).write(to: unscoped)

        let launch = makeService()
        launch.activate(accountKey: accountA, adoptUnscopedHistory: true)
        XCTAssertEqual(launch.history.dataPoints.count, 1, "existing users keep their chart")
        XCTAssertFalse(FileManager.default.fileExists(atPath: unscoped.path), "file is migrated, not copied")

        // A fresh sign-in must not inherit whatever was lying around unscoped.
        let other = directory.appendingPathComponent("history.json")
        try Data(historyJSON(pct5h: 0.3).utf8).write(to: other)
        let signIn = makeService()
        signIn.activate(accountKey: accountB, adoptUnscopedHistory: false)
        XCTAssertTrue(signIn.history.dataPoints.isEmpty)
    }

    func testAdoptsLegacyDirectoryHistoryAtLaunch() throws {
        try Data(historyJSON(pct5h: 0.6).utf8).write(to: legacyFile)

        let service = makeService()
        service.activate(accountKey: accountA, adoptUnscopedHistory: true)

        XCTAssertEqual(service.history.dataPoints.count, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: legacyFile.path))
    }

    func testFlushWritesToTheActiveAccountFile() throws {
        let service = makeService()
        service.activate(accountKey: accountA)
        service.recordDataPoint(pct5h: 0.2, pct7d: 0.2)

        service.flushToDisk()

        let file = directory.appendingPathComponent("history-\(accountA).json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    private func historyJSON(pct5h: Double) -> String {
        """
        {"dataPoints":[{"id":"\(UUID().uuidString)","timestamp":"\(ISO8601DateFormatter().string(from: Date()))","pct5h":\(pct5h),"pct7d":0.5}]}
        """
    }
}
