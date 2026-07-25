import Foundation

/// Token counts for one assistant turn, as recorded in a Claude Code transcript.
struct TurnUsage: Equatable {
    var inputTokens = 0
    var cacheWriteTokens = 0
    var cacheReadTokens = 0
    var outputTokens = 0

    /// Relative cost weight. Output dominates per token, cache reads are cheap
    /// per token but arrive in enormous quantities, so both must be counted to
    /// explain where a limit actually went.
    var weight: Double {
        Double(inputTokens)
            + Double(cacheWriteTokens) * 1.25
            + Double(cacheReadTokens) * 0.1
            + Double(outputTokens) * 5
    }

    /// Context carried into the request — the number users never see.
    var contextTokens: Int {
        inputTokens + cacheWriteTokens + cacheReadTokens
    }

    static func + (lhs: TurnUsage, rhs: TurnUsage) -> TurnUsage {
        TurnUsage(
            inputTokens: lhs.inputTokens + rhs.inputTokens,
            cacheWriteTokens: lhs.cacheWriteTokens + rhs.cacheWriteTokens,
            cacheReadTokens: lhs.cacheReadTokens + rhs.cacheReadTokens,
            outputTokens: lhs.outputTokens + rhs.outputTokens
        )
    }
}

/// One assistant turn parsed out of a transcript line.
struct AttributionTurn: Equatable {
    let timestamp: Date
    let project: String
    let sessionID: String
    let model: String
    let isSidechain: Bool
    let usage: TurnUsage
}

struct AttributionEntry: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let label: String
    let weight: Double
    let share: Double
    let turns: Int
    /// Average context carried per request; only meaningful for sessions/projects.
    let averageContextTokens: Int
}

struct AttributionSnapshot: Equatable {
    let generatedAt: Date
    let windowDays: Int
    let turns: Int
    let total: TurnUsage
    let projects: [AttributionEntry]
    let sessions: [AttributionEntry]
    let models: [AttributionEntry]
    let subagentShare: Double

    var isEmpty: Bool { turns == 0 }

    /// Cost split by token category — the answer to "what actually burned it".
    var composition: [(key: String, share: Double)] {
        let weights: [(String, Double)] = [
            ("cache_read", Double(total.cacheReadTokens) * 0.1),
            ("cache_write", Double(total.cacheWriteTokens) * 1.25),
            ("output", Double(total.outputTokens) * 5),
            ("input", Double(total.inputTokens)),
        ]
        let sum = weights.reduce(0) { $0 + $1.1 }
        guard sum > 0 else { return [] }
        return weights.map { ($0.0, $0.1 / sum) }.sorted { $0.1 > $1.1 }
    }

    /// Average context per request across the window.
    var averageContextTokens: Int {
        turns > 0 ? total.contextTokens / turns : 0
    }
}

enum AttributionAggregator {
    static func snapshot(
        turns: [AttributionTurn],
        windowDays: Int,
        now: Date,
        topCount: Int = 5
    ) -> AttributionSnapshot {
        let total = turns.reduce(TurnUsage()) { $0 + $1.usage }
        let totalWeight = turns.reduce(0.0) { $0 + $1.usage.weight }

        func rank(
            by keyPath: (AttributionTurn) -> String,
            label: @escaping (String, [AttributionTurn]) -> String
        ) -> [AttributionEntry] {
            Dictionary(grouping: turns, by: keyPath)
                .map { key, group -> AttributionEntry in
                    let weight = group.reduce(0.0) { $0 + $1.usage.weight }
                    let context = group.reduce(0) { $0 + $1.usage.contextTokens }
                    return AttributionEntry(
                        key: key,
                        label: label(key, group),
                        weight: weight,
                        share: totalWeight > 0 ? weight / totalWeight : 0,
                        turns: group.count,
                        averageContextTokens: group.isEmpty ? 0 : context / group.count
                    )
                }
                .sorted { $0.weight > $1.weight }
                // Rounding makes anything below half a percent read as "0%".
                .filter { $0.share >= 0.005 }
                .prefix(topCount)
                .map { $0 }
        }

        let subagentWeight = turns.filter(\.isSidechain).reduce(0.0) { $0 + $1.usage.weight }

        return AttributionSnapshot(
            generatedAt: now,
            windowDays: windowDays,
            turns: turns.count,
            total: total,
            projects: rank(by: { $0.project }, label: { key, _ in key }),
            sessions: rank(by: { $0.sessionID }, label: { key, group in
                let project = group.first?.project ?? ""
                return "\(project) · \(key.prefix(8))"
            }),
            models: rank(by: { $0.model }, label: { key, _ in key }),
            subagentShare: totalWeight > 0 ? subagentWeight / totalWeight : 0
        )
    }

    /// Parses one transcript line. Returns nil for anything that is not an
    /// assistant turn with usage (user messages, snapshots, tool results…).
    static func turn(fromTranscriptLine line: Data, cutoff: Date) -> AttributionTurn? {
        guard let object = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
              object["type"] as? String == "assistant",
              let timestampString = object["timestamp"] as? String,
              let timestamp = isoDate(from: timestampString),
              timestamp >= cutoff,
              let message = object["message"] as? [String: Any],
              let usage = message["usage"] as? [String: Any] else {
            return nil
        }

        let turnUsage = TurnUsage(
            inputTokens: usage["input_tokens"] as? Int ?? 0,
            cacheWriteTokens: usage["cache_creation_input_tokens"] as? Int ?? 0,
            cacheReadTokens: usage["cache_read_input_tokens"] as? Int ?? 0,
            outputTokens: usage["output_tokens"] as? Int ?? 0
        )

        let cwd = object["cwd"] as? String
        return AttributionTurn(
            timestamp: timestamp,
            project: cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "—",
            sessionID: object["sessionId"] as? String ?? "—",
            model: message["model"] as? String ?? "—",
            isSidechain: object["isSidechain"] as? Bool ?? false,
            usage: turnUsage
        )
    }

    private static func isoDate(from value: String) -> Date? {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFraction.date(from: value) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        return plain.date(from: value)
    }
}

func formatTokenCount(_ tokens: Int) -> String {
    switch tokens {
    case 1_000_000...:
        return String(format: "%.1fM", Double(tokens) / 1_000_000)
    case 1_000...:
        return String(format: "%.0fK", Double(tokens) / 1_000)
    default:
        return "\(tokens)"
    }
}
