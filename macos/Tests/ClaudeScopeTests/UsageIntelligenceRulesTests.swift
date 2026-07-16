import XCTest
@testable import ClaudeScope

final class UsageIntelligenceRulesTests: XCTestCase {
    func testSummaryPrioritizesElevatedSevenDayWindowEvenWhenFiveHourIsLow() {
        let summary = buildIntelligenceSummary(
            fiveHour: nil,
            sevenDay: nil,
            fiveHourCurrentPct: 12,
            sevenDayCurrentPct: 72
        )

        XCTAssertEqual(summary.kind, .action)
        XCTAssertEqual(summary.titleKey, "intelligence.summary.seven_day_action.title")
    }

    func testSummaryPrioritizesSevenDayRiskEvenWhenFiveHourIsLow() {
        let summary = buildIntelligenceSummary(
            fiveHour: nil,
            sevenDay: nil,
            fiveHourCurrentPct: 12,
            sevenDayCurrentPct: 84
        )

        XCTAssertEqual(summary.kind, .risk)
        XCTAssertEqual(summary.titleKey, "intelligence.summary.seven_day_risk.title")
    }

    func testInsightsIncludeSevenDayPacingWhenFiveHourHasRoom() {
        let insights = buildInsightItems(
            fiveHour: nil,
            sevenDay: nil,
            fiveHourCurrentPct: 12,
            sevenDayCurrentPct: 72,
            reset5h: nil,
            history: [],
            now: Date()
        )

        XCTAssertEqual(insights.first?.kind, .action)
        XCTAssertEqual(insights.first?.titleKey, "intelligence.insight.seven_day_pacing.title")
    }

    func testBurnRateMeasuresPaceAgainstEvenBaseline() {
        let now = Date(timeIntervalSince1970: 100_000)
        let points = [
            UsageDataPoint(timestamp: now.addingTimeInterval(-3600), pct5h: 0.10, pct7d: 0.2),
            UsageDataPoint(timestamp: now.addingTimeInterval(-1800), pct5h: 0.30, pct7d: 0.2),
            UsageDataPoint(timestamp: now, pct5h: 0.50, pct7d: 0.2),
        ]

        let rate = currentBurnRate(points: points, now: now)

        // 40 pct-points over one hour = 2x the even 20%/hr pace.
        XCTAssertEqual(rate?.pctPerHour ?? -1, 40, accuracy: 0.001)
        XCTAssertEqual(rate?.multiplier ?? -1, 2, accuracy: 0.001)
    }

    func testBurnRateIgnoresSamplesBeforeReset() {
        let now = Date(timeIntervalSince1970: 100_000)
        let points = [
            UsageDataPoint(timestamp: now.addingTimeInterval(-3600), pct5h: 0.70, pct7d: 0.2),
            UsageDataPoint(timestamp: now.addingTimeInterval(-1800), pct5h: 0.00, pct7d: 0.2),
            UsageDataPoint(timestamp: now, pct5h: 0.10, pct7d: 0.2),
        ]

        let rate = currentBurnRate(points: points, now: now)

        // Only the post-reset climb (0% -> 10% in 30 min = 20%/hr) counts.
        XCTAssertEqual(rate?.pctPerHour ?? -1, 20, accuracy: 0.001)
        XCTAssertEqual(rate?.multiplier ?? -1, 1, accuracy: 0.001)
    }

    func testBurnRateReturnsNilWithInsufficientData() {
        let now = Date(timeIntervalSince1970: 100_000)

        XCTAssertNil(currentBurnRate(points: [], now: now))
        XCTAssertNil(currentBurnRate(
            points: [UsageDataPoint(timestamp: now, pct5h: 0.5, pct7d: 0.5)],
            now: now
        ))
        // Two samples only one minute apart are too noisy to extrapolate.
        XCTAssertNil(currentBurnRate(
            points: [
                UsageDataPoint(timestamp: now.addingTimeInterval(-60), pct5h: 0.4, pct7d: 0.5),
                UsageDataPoint(timestamp: now, pct5h: 0.5, pct7d: 0.5),
            ],
            now: now
        ))
    }

    // MARK: - US daytime peak comparison

    private func easternDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar.date(from: DateComponents(
            year: year, month: month, day: day, hour: hour, minute: minute
        ))!
    }

    /// One-hour active session starting at the given ET time, climbing `ratePctPerHour`,
    /// sampled every 15 minutes.
    private func session(startingET start: Date, ratePctPerHour: Double) -> [UsageDataPoint] {
        (0...4).map { step in
            UsageDataPoint(
                timestamp: start.addingTimeInterval(Double(step) * 15 * 60),
                pct5h: ratePctPerHour / 100 / 4 * Double(step),
                pct7d: 0.2
            )
        }
    }

    /// Mon–Thu Jul 13–16, 2026: peak sessions at 9 AM ET burning 40%/h,
    /// off-peak sessions at 8 PM ET burning 20%/h.
    private func peakVsOffPeakHistory() -> [UsageDataPoint] {
        (13...16).flatMap { day in
            session(startingET: easternDate(2026, 7, day, 9), ratePctPerHour: 40)
                + session(startingET: easternDate(2026, 7, day, 20), ratePctPerHour: 20)
        }
    }

    func testIsInUSDaytimePeak() {
        XCTAssertTrue(isInUSDaytimePeak(easternDate(2026, 7, 13, 9)))    // Monday 9 AM ET
        XCTAssertTrue(isInUSDaytimePeak(easternDate(2026, 7, 13, 13, 59)))
        XCTAssertFalse(isInUSDaytimePeak(easternDate(2026, 7, 13, 7, 59)))
        XCTAssertFalse(isInUSDaytimePeak(easternDate(2026, 7, 13, 14)))  // boundary
        XCTAssertFalse(isInUSDaytimePeak(easternDate(2026, 7, 13, 3)))
        XCTAssertFalse(isInUSDaytimePeak(easternDate(2026, 7, 11, 9)))   // Saturday 9 AM ET
    }

    func testUSPeakComparisonMeasuresRateRatio() {
        let now = easternDate(2026, 7, 17, 9)
        let comparison = usPeakPeriodComparison(points: peakVsOffPeakHistory(), now: now)

        XCTAssertEqual(comparison?.peakRatePctPerHour ?? -1, 40, accuracy: 0.001)
        XCTAssertEqual(comparison?.offPeakRatePctPerHour ?? -1, 20, accuracy: 0.001)
        XCTAssertEqual(comparison?.ratio ?? -1, 2, accuracy: 0.001)
        XCTAssertEqual(comparison?.peakActiveHours ?? -1, 4, accuracy: 0.001)
        XCTAssertEqual(comparison?.offPeakActiveHours ?? -1, 4, accuracy: 0.001)
    }

    func testUSPeakComparisonNeedsActiveHoursInBothBuckets() {
        let now = easternDate(2026, 7, 17, 9)
        let peakOnly = (13...16).flatMap { day in
            session(startingET: easternDate(2026, 7, day, 9), ratePctPerHour: 40)
        }

        XCTAssertNil(usPeakPeriodComparison(points: peakOnly, now: now))
        XCTAssertNil(usPeakPeriodComparison(points: [], now: now))
    }

    func testInsightsFlagUSPeakWhenCurrentlyInsideWindow() {
        let insights = buildInsightItems(
            fiveHour: nil,
            sevenDay: nil,
            fiveHourCurrentPct: 10,
            sevenDayCurrentPct: 20,
            reset5h: nil,
            history: peakVsOffPeakHistory(),
            now: easternDate(2026, 7, 17, 9)   // Friday 9 AM ET — inside peak
        )

        XCTAssertEqual(insights.first?.titleKey, "intelligence.insight.us_peak_now.title")
        XCTAssertEqual(insights.first?.kind, .action)
    }

    func testInsightsFlagCheaperHoursWhenOutsidePeakWindow() {
        let insights = buildInsightItems(
            fiveHour: nil,
            sevenDay: nil,
            fiveHourCurrentPct: 10,
            sevenDayCurrentPct: 20,
            reset5h: nil,
            history: peakVsOffPeakHistory(),
            now: easternDate(2026, 7, 18, 9)   // Saturday 9 AM ET — outside peak
        )

        XCTAssertEqual(insights.first?.titleKey, "intelligence.insight.us_offpeak_now.title")
        XCTAssertEqual(insights.first?.kind, .opportunity)
    }
}
