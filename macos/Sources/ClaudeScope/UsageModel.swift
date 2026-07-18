import Foundation

struct UsageResponse: Codable {
    let fiveHour: UsageBucket?
    let sevenDay: UsageBucket?
    let sevenDayOpus: UsageBucket?
    let sevenDaySonnet: UsageBucket?
    let extraUsage: ExtraUsage?
    /// Model/feature buckets the API serves under keys we don't hard-code
    /// (e.g. a Fable 5 weekly window). Keyed by the raw API field name; only
    /// populated entries that look like usage buckets are kept, so new
    /// buckets appear in the UI without an app update.
    var additionalBuckets: [String: UsageBucket] = [:]

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
        case sevenDayOpus = "seven_day_opus"
        case sevenDaySonnet = "seven_day_sonnet"
        case extraUsage = "extra_usage"
    }

    private static let handledKeys: Set<String> = [
        "five_hour", "seven_day", "seven_day_opus", "seven_day_sonnet", "extra_usage",
    ]

    private struct DynamicKey: CodingKey {
        let stringValue: String
        let intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { nil }
    }

    init(
        fiveHour: UsageBucket?,
        sevenDay: UsageBucket?,
        sevenDayOpus: UsageBucket?,
        sevenDaySonnet: UsageBucket?,
        extraUsage: ExtraUsage?,
        additionalBuckets: [String: UsageBucket] = [:]
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.sevenDayOpus = sevenDayOpus
        self.sevenDaySonnet = sevenDaySonnet
        self.extraUsage = extraUsage
        self.additionalBuckets = additionalBuckets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        fiveHour = try container.decodeIfPresent(UsageBucket.self, forKey: .fiveHour)
        sevenDay = try container.decodeIfPresent(UsageBucket.self, forKey: .sevenDay)
        sevenDayOpus = try container.decodeIfPresent(UsageBucket.self, forKey: .sevenDayOpus)
        sevenDaySonnet = try container.decodeIfPresent(UsageBucket.self, forKey: .sevenDaySonnet)
        extraUsage = try container.decodeIfPresent(ExtraUsage.self, forKey: .extraUsage)

        var extras = [String: UsageBucket]()
        let dynamic = try decoder.container(keyedBy: DynamicKey.self)
        for key in dynamic.allKeys where !Self.handledKeys.contains(key.stringValue) {
            guard let bucket = try? dynamic.decode(UsageBucket.self, forKey: key),
                  bucket.utilization != nil,
                  bucket.resetsAtDate != nil else {
                continue
            }
            extras[key.stringValue] = bucket
        }
        additionalBuckets = extras
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(fiveHour, forKey: .fiveHour)
        try container.encodeIfPresent(sevenDay, forKey: .sevenDay)
        try container.encodeIfPresent(sevenDayOpus, forKey: .sevenDayOpus)
        try container.encodeIfPresent(sevenDaySonnet, forKey: .sevenDaySonnet)
        try container.encodeIfPresent(extraUsage, forKey: .extraUsage)
        var dynamic = encoder.container(keyedBy: DynamicKey.self)
        for (key, bucket) in additionalBuckets {
            try dynamic.encode(bucket, forKey: DynamicKey(stringValue: key)!)
        }
    }

    func reconciled(with previous: UsageResponse?, now: Date = Date()) -> UsageResponse {
        UsageResponse(
            fiveHour: fiveHour?.reconciled(
                with: previous?.fiveHour,
                resetInterval: 5 * 60 * 60,
                now: now
            ),
            sevenDay: sevenDay?.reconciled(
                with: previous?.sevenDay,
                resetInterval: 7 * 24 * 60 * 60,
                now: now
            ),
            sevenDayOpus: sevenDayOpus?.reconciled(
                with: previous?.sevenDayOpus,
                resetInterval: 7 * 24 * 60 * 60,
                now: now
            ),
            sevenDaySonnet: sevenDaySonnet?.reconciled(
                with: previous?.sevenDaySonnet,
                resetInterval: 7 * 24 * 60 * 60,
                now: now
            ),
            extraUsage: extraUsage,
            additionalBuckets: additionalBuckets
        )
    }
}

/// Human-readable label for a dynamically discovered usage bucket key.
/// Known internal codenames are mapped; anything else is prettified from the
/// raw key so future buckets are still presentable.
func displayName(forBucketKey key: String) -> String {
    switch key {
    case "seven_day_fable", "fable": return "Fable 5"
    case "seven_day_omelette", "omelette_promotional": return "Claude Design"
    case "seven_day_cowork": return "Cowork"
    case "seven_day_routines": return "Routines"
    case "seven_day_oauth_apps": return "OAuth apps"
    default:
        let trimmed = key.hasPrefix("seven_day_") ? String(key.dropFirst("seven_day_".count)) : key
        return trimmed
            .split(separator: "_")
            .map { $0.prefix(1).uppercased() + $0.dropFirst() }
            .joined(separator: " ")
    }
}

struct UsageBucket: Codable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }

    var resetsAtDate: Date? {
        Self.parseResetDate(from: resetsAt)
    }

    func reconciled(with previous: UsageBucket?, resetInterval: TimeInterval, now: Date) -> UsageBucket {
        guard resetsAtDate == nil else { return self }
        guard let previousDate = previous?.resetsAtDate else { return self }

        let resolvedDate = Self.nextResetDate(
            from: previousDate,
            resetInterval: resetInterval,
            now: now
        )

        return UsageBucket(
            utilization: utilization,
            resetsAt: Self.resetString(from: resolvedDate)
        )
    }

    private static func parseResetDate(from value: String?) -> Date? {
        guard let value, !value.isEmpty else { return nil }

        let isoFormatters: [ISO8601DateFormatter.Options] = [
            [.withInternetDateTime, .withFractionalSeconds],
            [.withInternetDateTime]
        ]

        for options in isoFormatters {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = options
            if let date = formatter.date(from: value) {
                return date
            }
        }

        let fallbackPatterns = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss"
        ]

        for pattern in fallbackPatterns {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = pattern
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    private static func nextResetDate(from previous: Date, resetInterval: TimeInterval, now: Date) -> Date {
        guard resetInterval > 0 else { return previous }
        guard previous <= now else { return previous }

        let elapsed = now.timeIntervalSince(previous)
        let stepCount = floor(elapsed / resetInterval) + 1
        return previous.addingTimeInterval(stepCount * resetInterval)
    }

    private static func resetString(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}

/// Fraction of a usage window already elapsed (0...1), derived from its reset date.
/// Returns nil when there is no reset date or the window length is unknown.
func windowElapsedFraction(resetDate: Date?, windowDuration: TimeInterval, now: Date = Date()) -> Double? {
    guard let resetDate, windowDuration > 0 else { return nil }
    let remaining = resetDate.timeIntervalSince(now)
    return min(max(1 - remaining / windowDuration, 0), 1)
}

struct ExtraUsage: Codable {
    let isEnabled: Bool
    let utilization: Double?
    let usedCredits: Double?
    let monthlyLimit: Double?

    enum CodingKeys: String, CodingKey {
        case isEnabled = "is_enabled"
        case utilization
        case usedCredits = "used_credits"
        case monthlyLimit = "monthly_limit"
    }

    /// API returns credits in minor units (cents); convert to dollars.
    var usedCreditsAmount: Double? {
        usedCredits.map { $0 / 100.0 }
    }

    var monthlyLimitAmount: Double? {
        monthlyLimit.map { $0 / 100.0 }
    }

    static let currencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 2
        return f
    }()

    static func formatUSD(_ amount: Double) -> String {
        currencyFormatter.string(from: NSNumber(value: amount))
            ?? String(format: "$%.2f", amount)
    }
}
