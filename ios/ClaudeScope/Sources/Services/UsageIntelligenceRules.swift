import Foundation

private let intelligenceHighRiskThreshold = 80.0
private let sevenDayElevatedThreshold = 65.0
private let peakWindowLookback: TimeInterval = 14 * 24 * 60 * 60

func projectedSlope(
    points: [UsageDataPoint], keyPath: KeyPath<UsageDataPoint, Double>,
    over interval: TimeInterval, now: Date
) -> Double? {
    let cutoff = now.addingTimeInterval(-interval)
    let filtered = points.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp < $1.timestamp }
    guard let first = filtered.first, let last = filtered.last, first.timestamp < last.timestamp else { return nil }
    let deltaValue = (last[keyPath: keyPath] - first[keyPath: keyPath]) * 100
    let deltaTime = last.timestamp.timeIntervalSince(first.timestamp)
    guard deltaTime > 0 else { return nil }
    return deltaValue / deltaTime
}

func confidenceScore(shortTermSlope: Double?, longTermSlope: Double?) -> Double {
    switch (shortTermSlope, longTermSlope) {
    case let (short?, long?): return max(0.2, min(1.0, 1.0 - abs(short - long) * 60 * 30))
    case (.some, .none), (.none, .some): return 0.55
    case (.none, .none): return 0.0
    }
}

func projectLimitRisk(
    currentPct: Double, history: [UsageDataPoint],
    keyPath: KeyPath<UsageDataPoint, Double>, resetDate: Date?, now: Date
) -> LimitProjection? {
    let shortSlope = projectedSlope(points: history, keyPath: keyPath, over: 30 * 60, now: now)
    let longSlope = projectedSlope(points: history, keyPath: keyPath, over: 24 * 60 * 60, now: now)
    let slope = shortSlope ?? longSlope
    let confidence = confidenceScore(shortTermSlope: shortSlope, longTermSlope: longSlope)

    var secondsUntilHighRisk: TimeInterval?
    if currentPct >= intelligenceHighRiskThreshold { secondsUntilHighRisk = 0 }
    else if let slope, slope > 0 { secondsUntilHighRisk = (intelligenceHighRiskThreshold - currentPct) / slope }

    var safeAdditionalPct: Double?
    if let resetDate, resetDate > now, let slope, slope > 0 {
        let projectedGain = slope * resetDate.timeIntervalSince(now)
        safeAdditionalPct = max(0, intelligenceHighRiskThreshold - currentPct - projectedGain)
    } else if let resetDate, resetDate > now {
        safeAdditionalPct = max(0, intelligenceHighRiskThreshold - currentPct)
    }

    return LimitProjection(windowKey: "", confidence: confidence, secondsUntilHighRisk: secondsUntilHighRisk, safeAdditionalPct: safeAdditionalPct)
}

func buildIntelligenceSummary(
    fiveHour: LimitProjection?, sevenDay: LimitProjection?,
    fiveHourCurrentPct: Double, sevenDayCurrentPct: Double
) -> IntelligenceSummary {
    if sevenDay?.isHighRiskSoon == true || sevenDayCurrentPct >= intelligenceHighRiskThreshold {
        return IntelligenceSummary(kind: .risk, titleKey: "intelligence.summary.seven_day_risk.title", titleFallback: "7-day window is getting tight", bodyKey: "intelligence.summary.seven_day_risk.body", bodyFallback: "7-day is at %d%% while 5-hour is at %d%%. Keep larger tasks for after the weekly reset.", bodyArguments: [Int(round(sevenDayCurrentPct)), Int(round(fiveHourCurrentPct))], emphasizedFragments: [])
    }
    if let projection = fiveHour, projection.isHighRiskSoon {
        let hours = max(1, Int(ceil((projection.secondsUntilHighRisk ?? 0) / 3600)))
        return IntelligenceSummary(kind: .risk, titleKey: "intelligence.summary.risk.title", titleFallback: "5-hour window is heating up", bodyKey: "intelligence.summary.risk.body", bodyFallback: "At your current pace, you may enter the high-risk zone in about %d hour(s).", bodyArguments: [Int(round(fiveHourCurrentPct)), Int(round(sevenDayCurrentPct)), hours], emphasizedFragments: [])
    }
    if sevenDayCurrentPct >= sevenDayElevatedThreshold {
        return IntelligenceSummary(kind: .action, titleKey: "intelligence.summary.seven_day_action.title", titleFallback: "7-day window needs pacing", bodyKey: "intelligence.summary.seven_day_action.body", bodyFallback: "Short tasks are fine, but pace bigger work.", bodyArguments: [Int(round(sevenDayCurrentPct)), Int(round(fiveHourCurrentPct))], emphasizedFragments: [])
    }
    if fiveHourCurrentPct < 35, sevenDayCurrentPct < 45 {
        return IntelligenceSummary(kind: .opportunity, titleKey: "intelligence.summary.opportunity.title", titleFallback: "Windows look healthy", bodyKey: "intelligence.summary.opportunity.body", bodyFallback: "Both windows are still running at a low level.", bodyArguments: [Int(round(fiveHourCurrentPct)), Int(round(sevenDayCurrentPct))], emphasizedFragments: [])
    }
    return IntelligenceSummary(kind: .action, titleKey: "intelligence.summary.action.title", titleFallback: "Usage is stable for now", bodyKey: "intelligence.summary.action.body", bodyFallback: "Things still look stable, but this window is worth pacing.", bodyArguments: [Int(round(fiveHourCurrentPct)), Int(round(sevenDayCurrentPct))], emphasizedFragments: [])
}

func detectedPeakHour(points: [UsageDataPoint], now: Date) -> Int? {
    let cutoff = now.addingTimeInterval(-peakWindowLookback)
    let filtered = points.filter { $0.timestamp >= cutoff }
    guard !filtered.isEmpty else { return nil }
    var totals = Array(repeating: (sum: 0.0, count: 0), count: 24)
    for point in filtered {
        let hour = Calendar.autoupdatingCurrent.component(.hour, from: point.timestamp)
        totals[hour].sum += point.pct5h; totals[hour].count += 1
    }
    return totals.enumerated().filter { $0.element.count > 0 }
        .max { ($0.element.sum / Double($0.element.count)) < ($1.element.sum / Double($1.element.count)) }?.offset
}

func anomalyMultiplier(points: [UsageDataPoint], now: Date) -> Double? {
    let short = projectedSlope(points: points, keyPath: \.pct5h, over: 2 * 60 * 60, now: now)
    let baseline = projectedSlope(points: points, keyPath: \.pct5h, over: 7 * 24 * 60 * 60, now: now)
    guard let short, let baseline, baseline > 0 else { return nil }
    return short / baseline
}

func buildInsightItems(
    fiveHour: LimitProjection?, sevenDay: LimitProjection?,
    fiveHourCurrentPct: Double, sevenDayCurrentPct: Double,
    reset5h: Date?, history: [UsageDataPoint], now: Date
) -> [UsageInsightItem] {
    var items = [UsageInsightItem]()
    if let projection = fiveHour, projection.isHighRiskSoon, let reset5h, reset5h.timeIntervalSince(now) <= 90 * 60 {
        items.append(UsageInsightItem(kind: .action, titleKey: "intelligence.insight.save_for_reset.title", titleFallback: "Save heavy work for reset", bodyKey: "intelligence.insight.save_for_reset.body", bodyFallback: "You are close to the 5-hour risk zone and the next reset is fairly soon.", bodyArguments: [], emphasizedFragments: []))
    }
    if sevenDay?.isHighRiskSoon == true || sevenDayCurrentPct >= intelligenceHighRiskThreshold {
        items.append(UsageInsightItem(kind: .risk, titleKey: "intelligence.insight.seven_day_tight.title", titleFallback: "Protect the 7-day budget", bodyKey: "intelligence.insight.seven_day_tight.body", bodyFallback: "Keep heavy tasks for after the weekly reset.", bodyArguments: [], emphasizedFragments: []))
    }
    if let multiplier = anomalyMultiplier(points: history, now: now), multiplier >= 1.75 {
        items.append(UsageInsightItem(kind: .risk, titleKey: "intelligence.insight.anomaly.title", titleFallback: "Usage is running hot", bodyKey: "intelligence.insight.anomaly.body", bodyFallback: "Your recent usage pace is about %.1fx above your 7-day baseline.", bodyArguments: [multiplier], emphasizedFragments: []))
    }
    if items.isEmpty, fiveHourCurrentPct < 35, sevenDayCurrentPct < 45 {
        items.append(UsageInsightItem(kind: .opportunity, titleKey: "intelligence.insight.good_window.title", titleFallback: "Good time for bigger tasks", bodyKey: "intelligence.insight.good_window.body", bodyFallback: "You still have room in both windows.", bodyArguments: [], emphasizedFragments: []))
    }
    return Array(items.prefix(2))
}
