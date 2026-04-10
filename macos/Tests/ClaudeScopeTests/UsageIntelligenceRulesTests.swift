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
}
