import Foundation
import Combine
import AppKit

@MainActor
class UsageHistoryService: ObservableObject {
    @Published var history = UsageHistory()

    /// Account whose history is currently loaded. `nil` means the signed-in
    /// account is not identified yet — recording is paused rather than risking
    /// points landing in another account's file.
    private(set) var accountKey: String?

    private var flushTimer: AnyCancellable?
    private var isDirty = false
    private var terminationObserver: Any?

    private static let retentionInterval: TimeInterval = 30 * 86400 // 30 days
    private static let flushInterval: TimeInterval = 300 // 5 minutes

    private let directoryURL: URL
    private let legacyHistoryFileURL: URL

    nonisolated static func defaultDirectoryURL() -> URL {
        let dir = AppPaths.credentialsDirectoryURL
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    nonisolated static func defaultLegacyHistoryFileURL() -> URL {
        AppPaths.legacyCredentialsDirectoryURL.appendingPathComponent("history.json")
    }

    init(
        directoryURL: URL = UsageHistoryService.defaultDirectoryURL(),
        legacyHistoryFileURL: URL = UsageHistoryService.defaultLegacyHistoryFileURL()
    ) {
        self.directoryURL = directoryURL
        self.legacyHistoryFileURL = legacyHistoryFileURL
        terminationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated {
                self.flushToDisk()
            }
        }
    }

    deinit {
        if let observer = terminationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Account scoping

    /// Per-account file. Keys come from the API's account uuid, so one account's
    /// chart can never continue into another's.
    private func fileURL(for key: String) -> URL {
        let safe = key.replacingOccurrences(of: "/", with: "-")
        return directoryURL.appendingPathComponent("history-\(safe).json")
    }

    /// File written before per-account scoping existed.
    private var unscopedFileURL: URL {
        directoryURL.appendingPathComponent("history.json")
    }

    /// Point the service at an account's history, persisting whatever the
    /// previous account had. Pass `nil` while the account is unknown.
    ///
    /// `adoptUnscopedHistory` migrates the pre-scoping file to this account and
    /// must only be set at launch, when the signed-in account is by definition
    /// the one that recorded it — never right after a sign-in, which may well
    /// be a different account.
    func activate(accountKey key: String?, adoptUnscopedHistory: Bool = false) {
        guard key != accountKey else { return }

        flushToDisk()
        accountKey = key
        history = UsageHistory()
        isDirty = false

        guard let key else { return }

        if adoptUnscopedHistory {
            migrateUnscopedHistory(to: key)
        }
        loadHistory()
    }

    private func migrateUnscopedHistory(to key: String) {
        let destination = fileURL(for: key)
        let manager = FileManager.default
        guard !manager.fileExists(atPath: destination.path) else { return }

        for source in [unscopedFileURL, legacyHistoryFileURL] where manager.fileExists(atPath: source.path) {
            try? manager.moveItem(at: source, to: destination)
            return
        }
    }

    // MARK: - Load

    func loadHistory() {
        guard let accountKey else { return }
        let url = fileURL(for: accountKey)
        guard FileManager.default.fileExists(atPath: url.path) else {
            history = UsageHistory()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            var loaded = try JSONDecoder.historyDecoder.decode(UsageHistory.self, from: data)
            loaded.dataPoints = pruned(loaded.dataPoints)
            history = loaded
        } catch {
            // Corrupt file — rename to .bak and start fresh
            let backup = url.deletingPathExtension().appendingPathExtension("bak.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: url, to: backup)
            history = UsageHistory()
        }
    }

    // MARK: - Record

    func recordDataPoint(pct5h: Double, pct7d: Double) {
        // Without a known account there is no correct file to append to.
        guard accountKey != nil else { return }
        let point = UsageDataPoint(pct5h: pct5h, pct7d: pct7d)
        history.dataPoints.append(point)
        isDirty = true
        startFlushTimerIfNeeded()
    }

    // MARK: - Flush

    func flushToDisk() {
        guard isDirty, let accountKey else { return }
        history.dataPoints = pruned(history.dataPoints)

        guard let data = try? JSONEncoder.historyEncoder.encode(history) else { return }
        try? data.write(to: fileURL(for: accountKey), options: .atomic)

        isDirty = false
        flushTimer?.cancel()
        flushTimer = nil
    }

    private func startFlushTimerIfNeeded() {
        guard flushTimer == nil else { return }
        flushTimer = Timer.publish(every: Self.flushInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.flushToDisk()
            }
    }

    // MARK: - Downsampling

    func downsampledPoints(for range: TimeRange) -> [UsageDataPoint] {
        let allPoints = history.dataPoints

        guard allPoints.count > range.targetPointCount else { return allPoints }

        let now = Date()
        let rangeStart = now.addingTimeInterval(-range.interval)
        let bucketCount = range.targetPointCount
        let bucketDuration = range.interval / Double(bucketCount)

        var buckets = [[UsageDataPoint]](repeating: [], count: bucketCount)

        for point in allPoints {
            let offset = point.timestamp.timeIntervalSince(rangeStart)
            var index = Int(offset / bucketDuration)
            if index < 0 { index = 0 }
            if index >= bucketCount { index = bucketCount - 1 }
            buckets[index].append(point)
        }

        return buckets.compactMap { bucket -> UsageDataPoint? in
            guard !bucket.isEmpty else { return nil }
            let avgPct5h = bucket.map(\.pct5h).reduce(0, +) / Double(bucket.count)
            let avgPct7d = bucket.map(\.pct7d).reduce(0, +) / Double(bucket.count)
            let avgTimestamp = bucket.map { $0.timestamp.timeIntervalSince1970 }.reduce(0, +) / Double(bucket.count)
            return UsageDataPoint(
                timestamp: Date(timeIntervalSince1970: avgTimestamp),
                pct5h: avgPct5h,
                pct7d: avgPct7d
            )
        }
    }

    // MARK: - Pruning

    private func pruned(_ points: [UsageDataPoint]) -> [UsageDataPoint] {
        let cutoff = Date().addingTimeInterval(-Self.retentionInterval)
        return points.filter { $0.timestamp >= cutoff }
    }
}

// MARK: - JSON Coding Helpers

private extension JSONDecoder {
    static let historyDecoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

private extension JSONEncoder {
    static let historyEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()
}
