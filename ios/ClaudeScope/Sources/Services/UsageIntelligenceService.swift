import Foundation

@MainActor
final class UsageIntelligenceService: ObservableObject {
    @Published private(set) var snapshot: UsageIntelligenceSnapshot?
    @Published var intelligenceEnabled: Bool {
        didSet { UserDefaults.standard.set(intelligenceEnabled, forKey: Self.intelligenceEnabledKey) }
    }
    @Published var predictionEnabled: Bool {
        didSet { UserDefaults.standard.set(predictionEnabled, forKey: Self.predictionEnabledKey) }
    }

    private static let intelligenceEnabledKey = "intelligenceEnabled"
    private static let predictionEnabledKey = "predictionEnabled"

    init() {
        intelligenceEnabled = UserDefaults.standard.object(forKey: Self.intelligenceEnabledKey) as? Bool ?? true
        predictionEnabled = UserDefaults.standard.object(forKey: Self.predictionEnabledKey) as? Bool ?? true
    }

    func refresh(usage: UsageResponse?, history: UsageHistory, now: Date = Date()) {
        guard intelligenceEnabled, predictionEnabled, let usage else { snapshot = nil; return }

        let fiveHourProjection = projectLimitRisk(
            currentPct: usage.fiveHour?.utilization ?? 0,
            history: history.dataPoints, keyPath: \.pct5h,
            resetDate: usage.fiveHour?.resetsAtDate, now: now
        ).map { LimitProjection(windowKey: "5-hour", confidence: $0.confidence, secondsUntilHighRisk: $0.secondsUntilHighRisk, safeAdditionalPct: $0.safeAdditionalPct) }

        let sevenDayProjection = projectLimitRisk(
            currentPct: usage.sevenDay?.utilization ?? 0,
            history: history.dataPoints, keyPath: \.pct7d,
            resetDate: usage.sevenDay?.resetsAtDate, now: now
        ).map { LimitProjection(windowKey: "7-day", confidence: $0.confidence, secondsUntilHighRisk: $0.secondsUntilHighRisk, safeAdditionalPct: $0.safeAdditionalPct) }

        let summary = buildIntelligenceSummary(
            fiveHour: fiveHourProjection, sevenDay: sevenDayProjection,
            fiveHourCurrentPct: usage.fiveHour?.utilization ?? 0,
            sevenDayCurrentPct: usage.sevenDay?.utilization ?? 0
        )

        let insights = buildInsightItems(
            fiveHour: fiveHourProjection, sevenDay: sevenDayProjection,
            fiveHourCurrentPct: usage.fiveHour?.utilization ?? 0,
            sevenDayCurrentPct: usage.sevenDay?.utilization ?? 0,
            reset5h: usage.fiveHour?.resetsAtDate,
            history: history.dataPoints, now: now
        )

        snapshot = UsageIntelligenceSnapshot(
            generatedAt: now,
            fiveHourCurrentPct: usage.fiveHour?.utilization ?? 0,
            sevenDayCurrentPct: usage.sevenDay?.utilization ?? 0,
            fiveHourProjection: fiveHourProjection,
            sevenDayProjection: sevenDayProjection,
            summary: summary, insights: insights
        )
    }

    func reset() { snapshot = nil }
}
