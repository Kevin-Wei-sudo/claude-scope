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
