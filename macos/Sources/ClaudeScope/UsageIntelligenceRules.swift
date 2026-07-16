import Foundation

private let intelligenceHighRiskThreshold = 80.0
private let sevenDayElevatedThreshold = 65.0
private let peakWindowLookback: TimeInterval = 14 * 24 * 60 * 60

/// Even pace that would consume exactly 100% of the 5-hour window: 20 pct-points/hour.
let fiveHourEvenPacePctPerHour = 20.0
private let burnRateLookback: TimeInterval = 60 * 60
private let burnRateMinimumSpan: TimeInterval = 5 * 60
private let burnRateResetDropThreshold = 0.01

struct BurnRateSnapshot: Equatable {
    /// Measured 5-hour-window growth in percentage points per hour.
    let pctPerHour: Double
    /// Measured pace relative to the even-consumption baseline (1.0 = would exactly exhaust the window).
    let multiplier: Double
}

// MARK: - US daytime (ET peak) comparison

/// Anthropic's former peak-throttling window: weekdays 8 AM–2 PM US Eastern.
/// The throttle itself was removed in May 2026; we only use the window to compare
/// the user's own measured burn rate inside vs outside it.
private let usPeakLookback: TimeInterval = 30 * 24 * 60 * 60
private let usPeakMaxSampleGap: TimeInterval = 20 * 60
private let usPeakActiveDeltaPctPoints = 0.05
private let usPeakMinimumActiveHours = 3.0
let usPeakMinimumInsightRatio = 1.15

private let easternCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "America/New_York") ?? .current
    return calendar
}()

struct PeakPeriodComparison: Equatable {
    /// Measured active burn rate (pct-points/hour) during US weekday daytime.
    let peakRatePctPerHour: Double
    /// Measured active burn rate (pct-points/hour) at all other times.
    let offPeakRatePctPerHour: Double
    let peakActiveHours: Double
    let offPeakActiveHours: Double

    /// How much faster the user burns during US daytime; guarded > 0 at construction.
    var ratio: Double {
        peakRatePctPerHour / offPeakRatePctPerHour
    }
}

func isInUSDaytimePeak(_ date: Date) -> Bool {
    let weekday = easternCalendar.component(.weekday, from: date)
    guard weekday >= 2, weekday <= 6 else { return false }
    let hour = easternCalendar.component(.hour, from: date)
    return hour >= 8 && hour < 14
}

func usPeakPeriodComparison(points: [UsageDataPoint], now: Date) -> PeakPeriodComparison? {
    let cutoff = now.addingTimeInterval(-usPeakLookback)
    let recent = points
        .filter { $0.timestamp >= cutoff && $0.timestamp <= now }
        .sorted { $0.timestamp < $1.timestamp }
    guard recent.count >= 2 else { return nil }

    var peakBurn = 0.0, peakHours = 0.0
    var offBurn = 0.0, offHours = 0.0

    for (a, b) in zip(recent, recent.dropFirst()) {
        let gap = b.timestamp.timeIntervalSince(a.timestamp)
        guard gap > 0, gap <= usPeakMaxSampleGap else { continue }

        let deltaPctPoints = (b.pct5h - a.pct5h) * 100
        // Skip resets, idle stretches, and sampling jitter — compare active burn only.
        guard deltaPctPoints > usPeakActiveDeltaPctPoints else { continue }

        let hours = gap / 3600
        if isInUSDaytimePeak(a.timestamp.addingTimeInterval(gap / 2)) {
            peakBurn += deltaPctPoints
            peakHours += hours
        } else {
            offBurn += deltaPctPoints
            offHours += hours
        }
    }

    guard peakHours >= usPeakMinimumActiveHours, offHours >= usPeakMinimumActiveHours else { return nil }
    let offPeakRate = offBurn / offHours
    guard offPeakRate > 0 else { return nil }

    return PeakPeriodComparison(
        peakRatePctPerHour: peakBurn / peakHours,
        offPeakRatePctPerHour: offPeakRate,
        peakActiveHours: peakHours,
        offPeakActiveHours: offHours
    )
}

func currentBurnRate(points: [UsageDataPoint], now: Date) -> BurnRateSnapshot? {
    let cutoff = now.addingTimeInterval(-burnRateLookback)
    var recent = points
        .filter { $0.timestamp >= cutoff && $0.timestamp <= now }
        .sorted { $0.timestamp < $1.timestamp }
    guard recent.count >= 2 else { return nil }

    // Measure only after the latest reset so the drop does not skew the slope.
    var startIndex = 0
    for i in 1..<recent.count where recent[i].pct5h < recent[i - 1].pct5h - burnRateResetDropThreshold {
        startIndex = i
    }
    recent = Array(recent[startIndex...])

    guard let first = recent.first, let last = recent.last else { return nil }
    let span = last.timestamp.timeIntervalSince(first.timestamp)
    guard span >= burnRateMinimumSpan else { return nil }

    let pctPerHour = max(0, (last.pct5h - first.pct5h) * 100 / span * 3600)
    return BurnRateSnapshot(
        pctPerHour: pctPerHour,
        multiplier: pctPerHour / fiveHourEvenPacePctPerHour
    )
}

func projectedSlope(
    points: [UsageDataPoint],
    keyPath: KeyPath<UsageDataPoint, Double>,
    over interval: TimeInterval,
    now: Date
) -> Double? {
    let cutoff = now.addingTimeInterval(-interval)
    let filtered = points.filter { $0.timestamp >= cutoff }.sorted { $0.timestamp < $1.timestamp }
    guard let first = filtered.first, let last = filtered.last, first.timestamp < last.timestamp else {
        return nil
    }

    let deltaValue = (last[keyPath: keyPath] - first[keyPath: keyPath]) * 100
    let deltaTime = last.timestamp.timeIntervalSince(first.timestamp)
    guard deltaTime > 0 else { return nil }
    return deltaValue / deltaTime
}

func confidenceScore(shortTermSlope: Double?, longTermSlope: Double?) -> Double {
    switch (shortTermSlope, longTermSlope) {
    case let (short?, long?):
        let drift = abs(short - long)
        return max(0.2, min(1.0, 1.0 - drift * 60 * 30))
    case (.some, .none), (.none, .some):
        return 0.55
    case (.none, .none):
        return 0.0
    }
}

func projectLimitRisk(
    currentPct: Double,
    history: [UsageDataPoint],
    keyPath: KeyPath<UsageDataPoint, Double>,
    resetDate: Date?,
    now: Date
) -> LimitProjection? {
    let shortSlope = projectedSlope(points: history, keyPath: keyPath, over: 30 * 60, now: now)
    let longSlope = projectedSlope(points: history, keyPath: keyPath, over: 24 * 60 * 60, now: now)
    let slope = shortSlope ?? longSlope
    let confidence = confidenceScore(shortTermSlope: shortSlope, longTermSlope: longSlope)

    var secondsUntilHighRisk: TimeInterval?
    if currentPct >= intelligenceHighRiskThreshold {
        secondsUntilHighRisk = 0
    } else if let slope, slope > 0 {
        secondsUntilHighRisk = (intelligenceHighRiskThreshold - currentPct) / slope
    }

    var safeAdditionalPct: Double?
    if let resetDate, resetDate > now, let slope, slope > 0 {
        let projectedGain = slope * resetDate.timeIntervalSince(now)
        safeAdditionalPct = max(0, intelligenceHighRiskThreshold - currentPct - projectedGain)
    } else if let resetDate, resetDate > now {
        safeAdditionalPct = max(0, intelligenceHighRiskThreshold - currentPct)
    }

    return LimitProjection(
        windowKey: "",
        confidence: confidence,
        secondsUntilHighRisk: secondsUntilHighRisk,
        safeAdditionalPct: safeAdditionalPct
    )
}

func buildIntelligenceSummary(
    fiveHour: LimitProjection?,
    sevenDay: LimitProjection?,
    fiveHourCurrentPct: Double,
    sevenDayCurrentPct: Double
) -> IntelligenceSummary {
    if sevenDay?.isHighRiskSoon == true || sevenDayCurrentPct >= intelligenceHighRiskThreshold {
        return IntelligenceSummary(
            kind: .risk,
            titleKey: "intelligence.summary.seven_day_risk.title",
            titleFallback: "7-day window is getting tight",
            bodyKey: "intelligence.summary.seven_day_risk.body",
            bodyFallback: "7-day is at %d%% while 5-hour is at %d%%. Keep larger tasks for after the weekly reset.",
            bodyArguments: [Int(round(sevenDayCurrentPct)), Int(round(fiveHourCurrentPct))],
            emphasizedFragments: ["7-day", "weekly reset", "7 天", "周重置", "\(Int(round(sevenDayCurrentPct)))%"]
        )
    }

    if let projection = fiveHour, projection.isHighRiskSoon {
        let hours = max(1, Int(ceil((projection.secondsUntilHighRisk ?? 0) / 3600)))
        return IntelligenceSummary(
            kind: .risk,
            titleKey: "intelligence.summary.risk.title",
            titleFallback: "5-hour window is heating up",
            bodyKey: "intelligence.summary.risk.body",
            bodyFallback: "5-hour is at %d%% and 7-day is at %d%%. At your current pace, you may enter the high-risk zone in about %d hour(s).",
            bodyArguments: [Int(round(fiveHourCurrentPct)), Int(round(sevenDayCurrentPct)), hours],
            emphasizedFragments: ["high-risk zone", "高风险区", "\(hours)"]
        )
    }

    if sevenDayCurrentPct >= sevenDayElevatedThreshold {
        return IntelligenceSummary(
            kind: .action,
            titleKey: "intelligence.summary.seven_day_action.title",
            titleFallback: "7-day window needs pacing",
            bodyKey: "intelligence.summary.seven_day_action.body",
            bodyFallback: "7-day is at %d%% while 5-hour is at %d%%. Short tasks are fine, but pace bigger work.",
            bodyArguments: [Int(round(sevenDayCurrentPct)), Int(round(fiveHourCurrentPct))],
            emphasizedFragments: ["7-day", "pace bigger work", "7 天", "控制大任务", "\(Int(round(sevenDayCurrentPct)))%"]
        )
    }

    if fiveHourCurrentPct < 35, sevenDayCurrentPct < 45 {
        return IntelligenceSummary(
            kind: .opportunity,
            titleKey: "intelligence.summary.opportunity.title",
            titleFallback: "Windows look healthy",
            bodyKey: "intelligence.summary.opportunity.body",
            bodyFallback: "5-hour is at %d%% and 7-day is at %d%%. Both windows are still running at a low level.",
            bodyArguments: [Int(round(fiveHourCurrentPct)), Int(round(sevenDayCurrentPct))],
            emphasizedFragments: ["low level", "低位", "低占用"]
        )
    }

    return IntelligenceSummary(
        kind: .action,
        titleKey: "intelligence.summary.action.title",
        titleFallback: "Usage is stable for now",
        bodyKey: "intelligence.summary.action.body",
        bodyFallback: "5-hour is at %d%% and 7-day is at %d%%. Things still look stable, but this window is worth pacing.",
        bodyArguments: [Int(round(fiveHourCurrentPct)), Int(round(sevenDayCurrentPct))],
        emphasizedFragments: ["stable", "稳定", "pacing", "控制一下节奏"]
    )
}

func detectedPeakHour(points: [UsageDataPoint], now: Date) -> Int? {
    let cutoff = now.addingTimeInterval(-peakWindowLookback)
    let calendar = Calendar.autoupdatingCurrent
    let filtered = points.filter { $0.timestamp >= cutoff }
    guard !filtered.isEmpty else { return nil }

    var totals = Array(repeating: (sum: 0.0, count: 0), count: 24)
    for point in filtered {
        let hour = calendar.component(.hour, from: point.timestamp)
        totals[hour].sum += point.pct5h
        totals[hour].count += 1
    }

    return totals.enumerated()
        .filter { $0.element.count > 0 }
        .max { lhs, rhs in
            (lhs.element.sum / Double(lhs.element.count)) < (rhs.element.sum / Double(rhs.element.count))
        }?
        .offset
}

func anomalyMultiplier(points: [UsageDataPoint], now: Date) -> Double? {
    let short = projectedSlope(points: points, keyPath: \.pct5h, over: 2 * 60 * 60, now: now)
    let baseline = projectedSlope(points: points, keyPath: \.pct5h, over: 7 * 24 * 60 * 60, now: now)
    guard let short, let baseline, baseline > 0 else { return nil }
    return short / baseline
}

func buildInsightItems(
    fiveHour: LimitProjection?,
    sevenDay: LimitProjection?,
    fiveHourCurrentPct: Double,
    sevenDayCurrentPct: Double,
    reset5h: Date?,
    history: [UsageDataPoint],
    now: Date
) -> [UsageInsightItem] {
    var items = [UsageInsightItem]()

    if let projection = fiveHour,
       projection.isHighRiskSoon,
       let reset5h,
       reset5h.timeIntervalSince(now) <= 90 * 60 {
        items.append(
            UsageInsightItem(
                kind: .action,
                titleKey: "intelligence.insight.save_for_reset.title",
                titleFallback: "Save heavy work for reset",
                bodyKey: "intelligence.insight.save_for_reset.body",
                bodyFallback: "You are close to the 5-hour risk zone and the next reset is fairly soon.",
                bodyArguments: [],
                emphasizedFragments: ["reset", "重置", "5-hour risk zone", "5 小时高风险区"]
            )
        )
    }

    if sevenDay?.isHighRiskSoon == true || sevenDayCurrentPct >= intelligenceHighRiskThreshold {
        items.append(
            UsageInsightItem(
                kind: .risk,
                titleKey: "intelligence.insight.seven_day_tight.title",
                titleFallback: "Protect the 7-day budget",
                bodyKey: "intelligence.insight.seven_day_tight.body",
                bodyFallback: "Your weekly window is the limiting factor now. Keep heavy tasks for after the weekly reset.",
                bodyArguments: [],
                emphasizedFragments: ["weekly window", "weekly reset", "7 天窗口", "周重置"]
            )
        )
    } else if sevenDayCurrentPct >= sevenDayElevatedThreshold {
        items.append(
            UsageInsightItem(
                kind: .action,
                titleKey: "intelligence.insight.seven_day_pacing.title",
                titleFallback: "Pace larger work",
                bodyKey: "intelligence.insight.seven_day_pacing.body",
                bodyFallback: "Your 5-hour window has room, but the 7-day window is already elevated.",
                bodyArguments: [],
                emphasizedFragments: ["5-hour", "7-day window", "5 小时", "7 天窗口"]
            )
        )
    }

    if let multiplier = anomalyMultiplier(points: history, now: now), multiplier >= 1.75 {
        items.append(
            UsageInsightItem(
                kind: .risk,
                titleKey: "intelligence.insight.anomaly.title",
                titleFallback: "Usage is running hot",
                bodyKey: "intelligence.insight.anomaly.body",
                bodyFallback: "Your recent usage pace is about %.1fx above your 7-day baseline.",
                bodyArguments: [multiplier],
                emphasizedFragments: ["above your 7-day baseline", "7 天基线", String(format: "%.1f", multiplier)]
            )
        )
    }

    if let comparison = usPeakPeriodComparison(points: history, now: now),
       comparison.ratio >= usPeakMinimumInsightRatio {
        let ratioText = String(format: "%.1f", comparison.ratio)
        if isInUSDaytimePeak(now) {
            items.append(
                UsageInsightItem(
                    kind: .action,
                    titleKey: "intelligence.insight.us_peak_now.title",
                    titleFallback: "You're in your US-daytime hot zone",
                    bodyKey: "intelligence.insight.us_peak_now.body",
                    bodyFallback: "Over the last 30 days, your measured burn rate during US weekday daytime (8 AM\u{2013}2 PM ET) was about %.1fx your rate at other times.",
                    bodyArguments: [comparison.ratio],
                    emphasizedFragments: ["\(ratioText)x", ratioText, "US weekday daytime", "美东工作日白天"]
                )
            )
        } else {
            items.append(
                UsageInsightItem(
                    kind: .opportunity,
                    titleKey: "intelligence.insight.us_offpeak_now.title",
                    titleFallback: "Cheaper hours right now",
                    bodyKey: "intelligence.insight.us_offpeak_now.body",
                    bodyFallback: "US weekday daytime (8 AM\u{2013}2 PM ET) is your hot zone at about %.1fx. You're outside it now \u{2014} historically a better time for heavy work.",
                    bodyArguments: [comparison.ratio],
                    emphasizedFragments: ["\(ratioText)x", ratioText, "outside it now", "低消耗时段"]
                )
            )
        }
    }

    if let peakHour = detectedPeakHour(points: history, now: now) {
        let currentHour = Calendar.autoupdatingCurrent.component(.hour, from: now)
        if abs(currentHour - peakHour) <= 1, fiveHourCurrentPct >= 55 {
            items.append(
                UsageInsightItem(
                    kind: .action,
                    titleKey: "intelligence.insight.peak_window.title",
                    titleFallback: "This is one of your peak hours",
                    bodyKey: "intelligence.insight.peak_window.body",
                    bodyFallback: "You usually burn usage faster around %@:00. Consider batching prompts right now.",
                    bodyArguments: [peakHour],
                    emphasizedFragments: ["batching prompts", "合并问题", "\(peakHour):00"]
                )
            )
        }
    }

    if items.isEmpty, fiveHourCurrentPct < 35, sevenDayCurrentPct < 45 {
        items.append(
            UsageInsightItem(
                kind: .opportunity,
                titleKey: "intelligence.insight.good_window.title",
                titleFallback: "Good time for bigger tasks",
                bodyKey: "intelligence.insight.good_window.body",
                bodyFallback: "You still have room in both windows, so this is a strong time for summaries, reviews, or larger runs.",
                bodyArguments: [],
                emphasizedFragments: ["summaries, reviews, or larger runs", "总结、复盘或长任务", "还有空间"]
            )
        )
    }

    if items.isEmpty, let safePct = fiveHour?.safeAdditionalPct {
        items.append(
            UsageInsightItem(
                kind: .action,
                titleKey: "intelligence.insight.safe_budget.title",
                titleFallback: "Keep this window lean",
                bodyKey: "intelligence.insight.safe_budget.body",
                bodyFallback: "To stay comfortable before reset, try to keep another %d%% or less in this 5-hour window.",
                bodyArguments: [Int(round(safePct))],
                emphasizedFragments: ["before reset", "重置前", "5-hour window", "5 小时窗口"]
            )
        )
    }

    return Array(items.prefix(2))
}
