import Foundation

enum IntelligenceSummaryKind {
    case risk
    case action
    case opportunity
    case neutral
}

enum UsageInsightKind {
    case risk
    case action
    case opportunity
}

struct LimitProjection: Equatable {
    let windowKey: String
    let confidence: Double
    let secondsUntilHighRisk: TimeInterval?
    let safeAdditionalPct: Double?

    var isHighRiskSoon: Bool {
        guard let secondsUntilHighRisk else { return false }
        return secondsUntilHighRisk <= 2 * 60 * 60
    }
}

struct IntelligenceSummary {
    let kind: IntelligenceSummaryKind
    let titleKey: String
    let titleFallback: String
    let bodyKey: String
    let bodyFallback: String
    let bodyArguments: [CVarArg]
    let emphasizedFragments: [String]
}

struct UsageInsightItem: Identifiable {
    let id = UUID()
    let kind: UsageInsightKind
    let titleKey: String
    let titleFallback: String
    let bodyKey: String
    let bodyFallback: String
    let bodyArguments: [CVarArg]
    let emphasizedFragments: [String]
}

struct UsageIntelligenceSnapshot {
    let generatedAt: Date
    let fiveHourCurrentPct: Double
    let sevenDayCurrentPct: Double
    let fiveHourProjection: LimitProjection?
    let sevenDayProjection: LimitProjection?
    let summary: IntelligenceSummary
    let insights: [UsageInsightItem]
}
