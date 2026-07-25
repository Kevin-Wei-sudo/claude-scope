import Foundation
import Combine

@MainActor
final class AttributionService: ObservableObject {
    @Published private(set) var snapshot: AttributionSnapshot?
    @Published private(set) var isScanning = false
    @Published private(set) var unavailableReason: UnavailableReason?

    enum UnavailableReason: Equatable {
        /// The sandboxed App Store build cannot read files outside its container.
        case sandboxed
        /// Claude Code has never run on this Mac, or writes elsewhere.
        case noTranscripts
    }

    /// Rescans are expensive (hundreds of MB), so reuse a recent scan.
    private static let minimumRescanInterval: TimeInterval = 10 * 60
    private var lastScan: Date?
    private let transcriptsDirectory: URL

    init(transcriptsDirectory: URL = AttributionService.defaultTranscriptsDirectory()) {
        self.transcriptsDirectory = transcriptsDirectory
    }

    nonisolated static func defaultTranscriptsDirectory() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude/projects", isDirectory: true)
    }

    func refreshIfStale(windowDays: Int = 7) {
        if let lastScan, Date().timeIntervalSince(lastScan) < Self.minimumRescanInterval, snapshot != nil {
            return
        }
        refresh(windowDays: windowDays)
    }

    func refresh(windowDays: Int = 7) {
        guard !isScanning else { return }

        if AppEnvironment.isAppStoreBuild {
            unavailableReason = .sandboxed
            return
        }
        guard FileManager.default.fileExists(atPath: transcriptsDirectory.path) else {
            unavailableReason = .noTranscripts
            return
        }

        isScanning = true
        let directory = transcriptsDirectory
        let now = Date()

        Task {
            let turns = await Self.scan(directory: directory, windowDays: windowDays, now: now)
            let result = AttributionAggregator.snapshot(turns: turns, windowDays: windowDays, now: now)
            self.snapshot = result
            self.unavailableReason = result.isEmpty ? .noTranscripts : nil
            self.lastScan = Date()
            self.isScanning = false
        }
    }

    /// Streams transcripts line by line off the main actor. Only files touched
    /// inside the window are opened — a month of history is gigabytes.
    private nonisolated static func scan(
        directory: URL,
        windowDays: Int,
        now: Date
    ) async -> [AttributionTurn] {
        await Task.detached(priority: .utility) { () -> [AttributionTurn] in
            let cutoff = now.addingTimeInterval(-Double(windowDays) * 86400)

            // Only transcripts touched inside the window are worth opening;
            // the full archive runs to gigabytes.
            func recentTranscripts() -> [URL] {
                guard let walker = FileManager.default.enumerator(
                    at: directory,
                    includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey]
                ) else {
                    return []
                }
                var urls = [URL]()
                for case let url as URL in walker where url.pathExtension == "jsonl" {
                    let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
                    guard values?.isRegularFile == true,
                          let modified = values?.contentModificationDate,
                          modified >= cutoff else {
                        continue
                    }
                    urls.append(url)
                }
                return urls
            }

            var turns = [AttributionTurn]()
            for url in recentTranscripts() {
                turns.append(contentsOf: parseTranscript(at: url, cutoff: cutoff))
            }
            return turns
        }.value
    }

    private nonisolated static func parseTranscript(at url: URL, cutoff: Date) -> [AttributionTurn] {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? handle.close() }

        var turns = [AttributionTurn]()
        var buffer = Data()
        let newline = UInt8(ascii: "\n")

        while let chunk = try? handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            buffer.append(chunk)
            while let index = buffer.firstIndex(of: newline) {
                let line = buffer[buffer.startIndex..<index]
                buffer = buffer[buffer.index(after: index)...]
                if !line.isEmpty,
                   let turn = AttributionAggregator.turn(fromTranscriptLine: Data(line), cutoff: cutoff) {
                    turns.append(turn)
                }
            }
        }
        if !buffer.isEmpty,
           let turn = AttributionAggregator.turn(fromTranscriptLine: Data(buffer), cutoff: cutoff) {
            turns.append(turn)
        }

        return turns
    }
}
