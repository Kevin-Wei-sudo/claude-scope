import Foundation

/// Usage snapshot for OpenAI Codex, fetched with the token Codex CLI already
/// maintains in ~/.codex/auth.json. Shapes mirror the wham/usage response.
struct CodexUsage: Equatable {
    struct Window: Equatable {
        let usedPercent: Double
        let windowSeconds: TimeInterval
        let resetAt: Date?

        /// "5h" / "7d" style label derived from the window length — plans
        /// differ in which windows they have, so names are never hard-coded.
        var durationLabel: String {
            let hours = windowSeconds / 3600
            if hours >= 48 {
                return "\(Int((hours / 24).rounded()))d"
            }
            return "\(Int(hours.rounded()))h"
        }
    }

    struct ScopedLimit: Equatable {
        let name: String
        let window: Window
    }

    let planType: String?
    let email: String?
    let primary: Window?
    let secondary: Window?
    let scoped: [ScopedLimit]
    let creditsBalance: String?
    let hasCredits: Bool

    var displayPlan: String? {
        switch planType?.lowercased() {
        case "plus": return "Plus"
        case "pro": return "Pro"
        case "prolite": return "Pro Lite"
        case "business": return "Business"
        case "team": return "Team"
        case "free": return "Free"
        case let other?: return other.capitalized
        case nil: return nil
        }
    }

    var windows: [(label: String, window: Window)] {
        var result = [(String, Window)]()
        if let primary { result.append((primary.durationLabel, primary)) }
        if let secondary { result.append((secondary.durationLabel, secondary)) }
        return result
    }
}

enum CodexUsageParser {
    struct AuthTokens: Equatable {
        let accessToken: String
        let accountID: String?
    }

    /// ChatGPT-login tokens from ~/.codex/auth.json; nil in API-key mode,
    /// where there are no plan windows to poll.
    static func authTokens(fromAuthJSON data: Data) -> AuthTokens? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tokens = object["tokens"] as? [String: Any],
              let accessToken = tokens["access_token"] as? String,
              !accessToken.isEmpty else {
            return nil
        }
        return AuthTokens(accessToken: accessToken, accountID: tokens["account_id"] as? String)
    }

    /// Active model provider from ~/.codex/config.toml (e.g. "deepseek"),
    /// so the API-key caption can say which key is billing.
    static func providerName(fromConfigTOML content: String) -> String? {
        for line in content.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("model_provider") else { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let value = parts[1].trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return value.isEmpty ? nil : value
        }
        return nil
    }

    /// True when Codex CLI is signed in with an API key (pay-per-token, no
    /// subscription rate windows).
    static func isAPIKeyMode(authJSON data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        if let mode = object["auth_mode"] as? String, mode.lowercased() == "apikey" { return true }
        if authTokens(fromAuthJSON: data) == nil,
           let key = object["OPENAI_API_KEY"] as? String, !key.isEmpty {
            return true
        }
        return false
    }

    /// Parses the wham/usage response body.
    static func usage(fromAPIResponse data: Data) -> CodexUsage? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let rateLimit = object["rate_limit"] as? [String: Any]
        let credits = object["credits"] as? [String: Any]

        let scoped = (object["additional_rate_limits"] as? [[String: Any]] ?? []).compactMap { entry -> CodexUsage.ScopedLimit? in
            guard let name = entry["limit_name"] as? String,
                  let limit = entry["rate_limit"] as? [String: Any],
                  let window = window(from: limit["primary_window"]) else {
                return nil
            }
            return CodexUsage.ScopedLimit(name: name, window: window)
        }

        return CodexUsage(
            planType: object["plan_type"] as? String,
            email: object["email"] as? String,
            primary: window(from: rateLimit?["primary_window"]),
            secondary: window(from: rateLimit?["secondary_window"]),
            scoped: scoped,
            creditsBalance: credits?["balance"] as? String,
            hasCredits: credits?["has_credits"] as? Bool ?? false
        )
    }

    /// Parses the `rate_limits` payload of a `token_count` event from a local
    /// session file — the offline fallback when the API is unreachable.
    static func usage(fromSessionRateLimits object: [String: Any]) -> CodexUsage? {
        let primary = sessionWindow(from: object["primary"])
        let secondary = sessionWindow(from: object["secondary"])
        guard primary != nil || secondary != nil else { return nil }

        let credits = object["credits"] as? [String: Any]
        return CodexUsage(
            planType: nil,
            email: nil,
            primary: primary,
            secondary: secondary,
            scoped: [],
            creditsBalance: credits?["balance"] as? String,
            hasCredits: credits?["has_credits"] as? Bool ?? false
        )
    }

    private static func window(from value: Any?) -> CodexUsage.Window? {
        guard let object = value as? [String: Any],
              let used = double(object["used_percent"]),
              let seconds = double(object["limit_window_seconds"]) else {
            return nil
        }
        return CodexUsage.Window(
            usedPercent: used,
            windowSeconds: seconds,
            resetAt: double(object["reset_at"]).map { Date(timeIntervalSince1970: $0) }
        )
    }

    private static func sessionWindow(from value: Any?) -> CodexUsage.Window? {
        guard let object = value as? [String: Any],
              let used = double(object["used_percent"]),
              let minutes = double(object["window_minutes"]) else {
            return nil
        }
        return CodexUsage.Window(
            usedPercent: used,
            windowSeconds: minutes * 60,
            resetAt: double(object["resets_at"]).map { Date(timeIntervalSince1970: $0) }
        )
    }

    private static func double(_ value: Any?) -> Double? {
        switch value {
        case let number as NSNumber: return number.doubleValue
        case let string as String: return Double(string)
        default: return nil
        }
    }
}

// MARK: - Local session stats

struct CodexStatEntry: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let tokens: Int
    let share: Double
}

struct CodexDailyEntry: Identifiable, Equatable {
    var id: Date { day }
    let day: Date
    let tokens: Int
}

/// Token totals from ~/.codex/sessions over a window — the per-model,
/// per-project, per-effort and per-day breakdown the usage API does not offer.
struct CodexLocalStats: Equatable {
    let windowDays: Int
    let totalTokens: Int
    let models: [CodexStatEntry]
    let projects: [CodexStatEntry]
    let efforts: [CodexStatEntry]
    /// One entry per calendar day, oldest first, zero-filled — chart-ready.
    let daily: [CodexDailyEntry]

    var isEmpty: Bool { totalTokens == 0 }
}

/// One assistant turn from a Codex session transcript.
struct CodexTurn: Equatable {
    let model: String
    let project: String
    let effort: String
    let timestamp: Date
    let tokens: Int
    /// Set when the cwd was inside a Claude session scratchpad; carries the
    /// munged host-project segment for later re-attribution.
    var scratchpadHost: String? = nil
}

enum CodexSessionScanner {
    /// One session transcript: `turn_context` lines carry the model, cwd and
    /// effort in effect, `token_count` lines carry that turn's usage.
    static func turnTokens(inTranscript content: String, cutoff: Date) -> [CodexTurn] {
        var model = "?"
        var project = "?"
        var effort = "?"
        var scratchpadHost: String?
        var result = [CodexTurn]()

        for line in content.split(separator: "\n") {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any] else {
                continue
            }
            let payload = object["payload"] as? [String: Any] ?? [:]
            let type = payload["type"] as? String ?? object["type"] as? String

            switch type {
            case "session_meta":
                if let cwd = payload["cwd"] as? String {
                    project = URL(fileURLWithPath: cwd).lastPathComponent
                    scratchpadHost = ProjectNameResolver.scratchpadHostSegment(inPath: cwd)
                }
            case "turn_context":
                if let m = payload["model"] as? String { model = m }
                if let e = payload["effort"] as? String { effort = e }
                if let cwd = payload["cwd"] as? String {
                    project = URL(fileURLWithPath: cwd).lastPathComponent
                    scratchpadHost = ProjectNameResolver.scratchpadHostSegment(inPath: cwd)
                }
            case "token_count":
                guard let timestampString = object["timestamp"] as? String,
                      let timestamp = isoDate(from: timestampString),
                      timestamp >= cutoff,
                      let info = payload["info"] as? [String: Any],
                      let last = info["last_token_usage"] as? [String: Any],
                      let total = last["total_tokens"] as? Int, total > 0 else {
                    break
                }
                result.append(CodexTurn(
                    model: model, project: project, effort: effort,
                    timestamp: timestamp, tokens: total,
                    scratchpadHost: scratchpadHost
                ))
            default:
                break
            }
        }
        return result
    }

    static func stats(
        fromTurns turns: [CodexTurn],
        windowDays: Int,
        now: Date,
        calendar: Calendar = .current,
        topCount: Int = 4
    ) -> CodexLocalStats {
        let total = turns.reduce(0) { $0 + $1.tokens }

        // Fold scratchpad-worktree turns back into the project that spawned
        // them; unresolvable ones keep the worktree name rather than vanish.
        let knownProjects = Set(turns.filter { $0.scratchpadHost == nil }.map(\.project))
        func effectiveProject(_ turn: CodexTurn) -> String {
            guard let segment = turn.scratchpadHost,
                  let host = ProjectNameResolver.hostProject(forMungedSegment: segment, knownProjects: knownProjects) else {
                return turn.project
            }
            return host
        }

        func rank(_ key: (CodexTurn) -> String) -> [CodexStatEntry] {
            let grouped = Dictionary(grouping: turns, by: key)
            let entries: [CodexStatEntry] = grouped.map { pair in
                let tokens = pair.value.reduce(0) { $0 + $1.tokens }
                let share = total > 0 ? Double(tokens) / Double(total) : 0
                return CodexStatEntry(key: pair.key, tokens: tokens, share: share)
            }
            return entries
                .sorted { $0.tokens > $1.tokens }
                .filter { $0.share >= 0.005 }
                .prefix(topCount)
                .map { $0 }
        }

        var tokensByDay = [Date: Int]()
        for turn in turns {
            tokensByDay[calendar.startOfDay(for: turn.timestamp), default: 0] += turn.tokens
        }
        let today = calendar.startOfDay(for: now)
        let daily: [CodexDailyEntry] = (0..<windowDays).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return CodexDailyEntry(day: day, tokens: tokensByDay[day] ?? 0)
        }

        return CodexLocalStats(
            windowDays: windowDays,
            totalTokens: total,
            models: rank { $0.model },
            projects: rank { effectiveProject($0) },
            // Turns before the effort field existed report "?" — not a lane.
            efforts: rank { $0.effort }.filter { $0.key != "?" },
            daily: daily
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
