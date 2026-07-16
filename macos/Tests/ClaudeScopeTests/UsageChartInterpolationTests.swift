import XCTest
@testable import ClaudeScope

final class UsageChartInterpolationTests: XCTestCase {
    func testStepSeriesInsertsVerticalDropAtReset() {
        let base = Date(timeIntervalSince1970: 0)
        let points = [
            UsageDataPoint(timestamp: base, pct5h: 0.3, pct7d: 0.3),
            UsageDataPoint(timestamp: base.addingTimeInterval(60), pct5h: 0.7, pct7d: 0.7),
            UsageDataPoint(timestamp: base.addingTimeInterval(120), pct5h: 0.0, pct7d: 0.7),
        ]

        let series = UsageChartInterpolation.stepSeries(from: points, keyPath: \.pct5h)

        // The reset inserts one extra point holding the previous level at the drop timestamp.
        XCTAssertEqual(series.count, 4)
        XCTAssertEqual(series[2].timestamp, base.addingTimeInterval(120))
        XCTAssertEqual(series[2].value, 0.7)
        XCTAssertEqual(series[3].timestamp, base.addingTimeInterval(120))
        XCTAssertEqual(series[3].value, 0.0)
    }

    func testStepSeriesDoesNotInsertPointForRisingValues() {
        let base = Date(timeIntervalSince1970: 0)
        let points = [
            UsageDataPoint(timestamp: base, pct5h: 0.1, pct7d: 0.1),
            UsageDataPoint(timestamp: base.addingTimeInterval(60), pct5h: 0.4, pct7d: 0.4),
            UsageDataPoint(timestamp: base.addingTimeInterval(120), pct5h: 0.6, pct7d: 0.6),
        ]

        let series = UsageChartInterpolation.stepSeries(from: points, keyPath: \.pct5h)

        XCTAssertEqual(series.count, 3)
    }

    func testInterpolateValuesIsLinearBetweenRisingPoints() {
        let base = Date(timeIntervalSince1970: 0)
        let points = [
            UsageDataPoint(timestamp: base, pct5h: 0.2, pct7d: 0.4),
            UsageDataPoint(timestamp: base.addingTimeInterval(100), pct5h: 0.6, pct7d: 0.8),
        ]

        let interpolated = UsageChartInterpolation.interpolateValues(
            at: base.addingTimeInterval(50),
            in: points
        )

        XCTAssertEqual(interpolated?.pct5h ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(interpolated?.pct7d ?? -1, 0.6, accuracy: 0.0001)
    }

    func testInterpolateValuesHoldsPreviousLevelUntilReset() {
        let base = Date(timeIntervalSince1970: 0)
        let points = [
            UsageDataPoint(timestamp: base, pct5h: 0.3, pct7d: 0.3),
            UsageDataPoint(timestamp: base.addingTimeInterval(100), pct5h: 0.7, pct7d: 0.5),
            UsageDataPoint(timestamp: base.addingTimeInterval(200), pct5h: 0.0, pct7d: 0.6),
        ]

        // Halfway into the reset segment, the 5h value stays at the pre-reset level
        // instead of sliding down a diagonal; 7d keeps interpolating linearly.
        let interpolated = UsageChartInterpolation.interpolateValues(
            at: base.addingTimeInterval(150),
            in: points
        )

        XCTAssertEqual(interpolated?.pct5h ?? -1, 0.7, accuracy: 0.0001)
        XCTAssertEqual(interpolated?.pct7d ?? -1, 0.55, accuracy: 0.0001)
    }

    func testInterpolateValuesOutsideRangeReturnsZeros() {
        let base = Date(timeIntervalSince1970: 0)
        let points = [
            UsageDataPoint(timestamp: base, pct5h: 0.3, pct7d: 0.3),
            UsageDataPoint(timestamp: base.addingTimeInterval(100), pct5h: 0.7, pct7d: 0.7),
        ]

        let interpolated = UsageChartInterpolation.interpolateValues(
            at: base.addingTimeInterval(500),
            in: points
        )

        XCTAssertEqual(interpolated?.pct5h, 0)
        XCTAssertEqual(interpolated?.pct7d, 0)
    }
}
