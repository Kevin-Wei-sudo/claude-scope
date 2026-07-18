import XCTest
@testable import ClaudeScope

final class WindowElapsedFractionTests: XCTestCase {
    func testHalfwayThroughFiveHourWindow() {
        let now = Date(timeIntervalSince1970: 100_000)
        let fraction = windowElapsedFraction(
            resetDate: now.addingTimeInterval(2.5 * 3600),
            windowDuration: 5 * 3600,
            now: now
        )
        XCTAssertEqual(fraction ?? -1, 0.5, accuracy: 0.0001)
    }

    func testClampsWhenResetDateIsStale() {
        let now = Date(timeIntervalSince1970: 100_000)
        // Reset already passed (stale data) -> fully elapsed.
        XCTAssertEqual(
            windowElapsedFraction(resetDate: now.addingTimeInterval(-60), windowDuration: 5 * 3600, now: now),
            1
        )
        // Reset further away than the window length -> clamp to just started.
        XCTAssertEqual(
            windowElapsedFraction(resetDate: now.addingTimeInterval(6 * 3600), windowDuration: 5 * 3600, now: now),
            0
        )
    }

    func testNilWithoutResetDate() {
        XCTAssertNil(windowElapsedFraction(resetDate: nil, windowDuration: 5 * 3600, now: Date(timeIntervalSince1970: 0)))
    }
}

final class UsageModelTests: XCTestCase {
    func testResetDateParsesTimestampWithoutTimezoneAsUTC() throws {
        let bucket = UsageBucket(
            utilization: 25.0,
            resetsAt: "2026-03-05T18:00:00"
        )

        XCTAssertEqual(bucket.resetsAtDate, date("2026-03-05T18:00:00Z"))
    }

    func testReconcileKeepsPreviousResetWhenServerTemporarilyDropsIt() throws {
        let previousReset = date("2026-03-05T18:00:00Z")
        let previous = usageResponse(
            fiveHour: UsageBucket(utilization: 88.0, resetsAt: iso(previousReset))
        )
        let current = usageResponse(
            fiveHour: UsageBucket(utilization: 89.0, resetsAt: nil)
        )

        let reconciled = current.reconciled(
            with: previous,
            now: date("2026-03-05T17:30:00Z")
        )

        XCTAssertEqual(reconciled.fiveHour?.resetsAtDate, previousReset)
    }

    func testReconcileAdvancesResetAfterRolloverWhenServerDropsIt() throws {
        let previousReset = date("2026-03-05T18:00:00Z")
        let previous = usageResponse(
            fiveHour: UsageBucket(utilization: 100.0, resetsAt: iso(previousReset))
        )
        let current = usageResponse(
            fiveHour: UsageBucket(utilization: 2.0, resetsAt: "not-a-date")
        )

        let reconciled = current.reconciled(
            with: previous,
            now: date("2026-03-05T18:05:00Z")
        )

        XCTAssertEqual(reconciled.fiveHour?.resetsAtDate, date("2026-03-05T23:00:00Z"))
    }

    func testReconcilePreservesValidServerReset() throws {
        let previous = usageResponse(
            fiveHour: UsageBucket(utilization: 100.0, resetsAt: "2026-03-05T18:00:00Z")
        )
        let current = usageResponse(
            fiveHour: UsageBucket(utilization: 2.0, resetsAt: "2026-03-05T22:00:00Z")
        )

        let reconciled = current.reconciled(
            with: previous,
            now: date("2026-03-05T18:05:00Z")
        )

        XCTAssertEqual(reconciled.fiveHour?.resetsAtDate, date("2026-03-05T22:00:00Z"))
    }

    func testDecodesUnknownBucketsIntoAdditionalBuckets() throws {
        let json = """
        {
          "five_hour": {"utilization": 48.0, "resets_at": "2026-07-18T13:10:00Z"},
          "seven_day": {"utilization": 55.0, "resets_at": "2026-07-19T11:00:00Z"},
          "seven_day_opus": null,
          "seven_day_fable": {"utilization": 82.0, "resets_at": "2026-07-19T11:00:00Z"},
          "tangelo": {"utilization": 12.0, "resets_at": "2026-07-19T11:00:00Z"},
          "nimbus_quill": null,
          "spend": {"percent": 84, "severity": "warning"},
          "limits": [],
          "extra_usage": {"is_enabled": false, "utilization": 83.5}
        }
        """
        let response = try JSONDecoder().decode(UsageResponse.self, from: Data(json.utf8))

        XCTAssertEqual(Set(response.additionalBuckets.keys), ["seven_day_fable", "tangelo"])
        XCTAssertEqual(response.additionalBuckets["seven_day_fable"]?.utilization, 82.0)
        XCTAssertEqual(response.fiveHour?.utilization, 48.0)
        XCTAssertEqual(response.extraUsage?.utilization, 83.5)
    }

    func testAdditionalBucketsSurviveReconciliation() throws {
        let fable = UsageBucket(utilization: 82.0, resetsAt: "2026-07-19T11:00:00Z")
        let response = UsageResponse(
            fiveHour: nil, sevenDay: nil, sevenDayOpus: nil, sevenDaySonnet: nil,
            extraUsage: nil, additionalBuckets: ["seven_day_fable": fable]
        )

        let reconciled = response.reconciled(with: nil, now: date("2026-07-18T00:00:00Z"))

        XCTAssertEqual(reconciled.additionalBuckets["seven_day_fable"]?.utilization, 82.0)
    }

    func testBucketKeyDisplayNames() {
        XCTAssertEqual(displayName(forBucketKey: "seven_day_fable"), "Fable 5")
        XCTAssertEqual(displayName(forBucketKey: "seven_day_omelette"), "Claude Design")
        XCTAssertEqual(displayName(forBucketKey: "seven_day_iguana_necktie"), "Iguana Necktie")
        XCTAssertEqual(displayName(forBucketKey: "cinder_cove"), "Cinder Cove")
    }

    private func usageResponse(fiveHour: UsageBucket? = nil) -> UsageResponse {
        UsageResponse(
            fiveHour: fiveHour,
            sevenDay: nil,
            sevenDayOpus: nil,
            sevenDaySonnet: nil,
            extraUsage: nil
        )
    }

    private func date(_ value: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)!
    }

    private func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }
}
