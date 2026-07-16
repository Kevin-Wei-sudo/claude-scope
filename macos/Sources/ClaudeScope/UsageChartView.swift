import SwiftUI
import Charts

struct UsageChartView: View {
    @ObservedObject var historyService: UsageHistoryService
    @State private var selectedRange: TimeRange = .day1
    @State private var hoverDate: Date?
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("", selection: $selectedRange) {
                ForEach(TimeRange.allCases) { range in
                    Text(range.rawValue).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            let points = historyService.downsampledPoints(for: selectedRange)

            if points.isEmpty {
                Text(localizedString("chart.no_history", fallback: "No history data yet.", language: appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
            } else {
                chartView(points: points)
            }
        }
    }

    @ViewBuilder
    private func chartView(points: [UsageDataPoint]) -> some View {
        let interpolated = hoverDate.flatMap {
            UsageChartInterpolation.interpolateValues(at: $0, in: points)
        }
        let series5h = UsageChartInterpolation.stepSeries(from: points, keyPath: \.pct5h)
        let series7d = UsageChartInterpolation.stepSeries(from: points, keyPath: \.pct7d)

        Chart {
            ForEach(series5h) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Usage", point.value * 100)
                )
                .foregroundStyle(by: .value("Window", "5h"))
            }

            ForEach(series7d) { point in
                LineMark(
                    x: .value("Time", point.timestamp),
                    y: .value("Usage", point.value * 100)
                )
                .foregroundStyle(by: .value("Window", "7d"))
            }

            if let iv = interpolated {
                RuleMark(x: .value("Selected", iv.date))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1))

                PointMark(
                    x: .value("Time", iv.date),
                    y: .value("Usage", iv.pct5h * 100)
                )
                .foregroundStyle(.blue)
                .symbolSize(24)

                PointMark(
                    x: .value("Time", iv.date),
                    y: .value("Usage", iv.pct7d * 100)
                )
                .foregroundStyle(.orange)
                .symbolSize(24)
            }
        }
        .chartXScale(domain: Date.now.addingTimeInterval(-selectedRange.interval)...Date.now)
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)%")
                            .font(.caption2)
                    }
                }
                AxisGridLine()
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel(format: xAxisFormat)
                    .font(.caption2)
                AxisGridLine()
            }
        }
        .chartForegroundStyleScale([
            "5h": Color.blue,
            "7d": Color.orange
        ])
        .chartLegend(.visible)
        .chartPlotStyle { plot in
            plot.clipped()
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            let plotOrigin = geo[proxy.plotFrame!].origin
                            let x = location.x - plotOrigin.x
                            if let date: Date = proxy.value(atX: x) {
                                hoverDate = date
                            }
                        case .ended:
                            hoverDate = nil
                        }
                    }
            }
        }
        .overlay(alignment: .top) {
            if let iv = interpolated {
                tooltipView(date: iv.date, pct5h: iv.pct5h, pct7d: iv.pct7d)
            }
        }
        .frame(height: 120)
        .padding(.top, 4)
    }

    @ViewBuilder
    private func tooltipView(date: Date, pct5h: Double, pct7d: Double) -> some View {
        VStack(spacing: 2) {
            Text(date, format: tooltipDateFormat.locale(appLanguage.locale))
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                Label("\(Int(round(pct5h * 100)))%", systemImage: "circle.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.blue)
                Label("\(Int(round(pct7d * 100)))%", systemImage: "circle.fill")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 4))
    }

    // MARK: - Formatting

    private var xAxisFormat: Date.FormatStyle {
        switch selectedRange {
        case .hour1:
            return .dateTime.hour().minute().locale(appLanguage.locale)
        case .hour6, .day1:
            return .dateTime.hour().locale(appLanguage.locale)
        case .day7:
            return .dateTime.weekday(.abbreviated).locale(appLanguage.locale)
        case .day30:
            return .dateTime.day().month(.abbreviated).locale(appLanguage.locale)
        }
    }

    private var tooltipDateFormat: Date.FormatStyle {
        switch selectedRange {
        case .hour1, .hour6, .day1:
            return .dateTime.hour().minute().locale(appLanguage.locale)
        case .day7:
            return .dateTime.weekday(.abbreviated).hour().minute().locale(appLanguage.locale)
        case .day30:
            return .dateTime.month(.abbreviated).day().hour().locale(appLanguage.locale)
        }
    }
}

struct UsageChartInterpolatedValues {
    let date: Date
    let pct5h: Double
    let pct7d: Double
}

struct UsageSeriesPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

enum UsageChartInterpolation {
    /// Any drop larger than this between consecutive samples is treated as a window reset.
    static let resetDropThreshold = 0.01

    /// Builds a per-series polyline where window resets fall vertically: when a sample
    /// drops below the previous one, the previous level is held until the drop timestamp.
    static func stepSeries(
        from points: [UsageDataPoint],
        keyPath: KeyPath<UsageDataPoint, Double>
    ) -> [UsageSeriesPoint] {
        let sorted = points.sorted { $0.timestamp < $1.timestamp }
        var series = [UsageSeriesPoint]()
        for point in sorted {
            let value = point[keyPath: keyPath]
            if let last = series.last, value < last.value - resetDropThreshold {
                series.append(UsageSeriesPoint(timestamp: point.timestamp, value: last.value))
            }
            series.append(UsageSeriesPoint(timestamp: point.timestamp, value: value))
        }
        return series
    }

    static func linearValue(at date: Date, in series: [UsageSeriesPoint]) -> Double? {
        guard series.count >= 2, let first = series.first, let last = series.last else { return nil }
        guard date >= first.timestamp, date <= last.timestamp else { return nil }

        for i in 0..<(series.count - 1) {
            let a = series[i]
            let b = series[i + 1]
            guard date >= a.timestamp, date <= b.timestamp else { continue }
            let span = b.timestamp.timeIntervalSince(a.timestamp)
            guard span > 0 else { return clampToUnitInterval(b.value) }
            let t = date.timeIntervalSince(a.timestamp) / span
            return clampToUnitInterval(a.value + (b.value - a.value) * t)
        }

        return nil
    }

    static func interpolateValues(at date: Date, in points: [UsageDataPoint]) -> UsageChartInterpolatedValues? {
        guard points.count >= 2 else { return nil }

        let series5h = stepSeries(from: points, keyPath: \.pct5h)
        let series7d = stepSeries(from: points, keyPath: \.pct7d)

        guard let pct5h = linearValue(at: date, in: series5h),
              let pct7d = linearValue(at: date, in: series7d) else {
            return UsageChartInterpolatedValues(date: date, pct5h: 0, pct7d: 0)
        }

        return UsageChartInterpolatedValues(date: date, pct5h: pct5h, pct7d: pct7d)
    }

    private static func clampToUnitInterval(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}
