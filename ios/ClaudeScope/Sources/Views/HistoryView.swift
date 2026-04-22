import SwiftUI
import Charts

private enum HistoryDemoData {
    static let trendPoints: [UsageDataPoint] = {
        let now = Date()
        let values: [Double] = [0.25, 0.32, 0.45, 0.38, 0.52, 0.68, 0.42]
        return values.enumerated().map { i, v in
            UsageDataPoint(timestamp: now.addingTimeInterval(Double(i - 6) * 86400), pct5h: v * 0.5, pct7d: v)
        }
    }()
    static let sonnetPct: Double = 0.61
    static let opusPct: Double = 0.24
    static let snapshots: [UsageDataPoint] = {
        let now = Date()
        return [
            UsageDataPoint(timestamp: now.addingTimeInterval(-0.5 * 3600), pct5h: 0.18, pct7d: 0.42),
            UsageDataPoint(timestamp: now.addingTimeInterval(-14 * 3600), pct5h: 0.25, pct7d: 0.37),
            UsageDataPoint(timestamp: now.addingTimeInterval(-26 * 3600), pct5h: 0.12, pct7d: 0.31),
        ]
    }()
}

struct HistoryView: View {
    @EnvironmentObject var usageService: UsageService
    @EnvironmentObject var historyService: UsageHistoryService
    @State private var language = AppLanguage.stored
    @State private var selectedRange: TimeRange = .day7

    private var isEN: Bool { language.isEnglish }
    private var isLive: Bool { usageService.isAuthenticated }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                trendLineCard
                timeRangeSelector
                modelSplitSection
                recentSnapshotsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Theme.sectionTitle(isEN ? "CLAUDE HISTORY" : "CLAUDE 历史")
            Text(isEN ? "See the shape of your\nusage." : "看清你的用量走势。")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Theme.bodyText)
            Text(isEN
                 ? "Track longer arcs, compare models, and spot spikes before they become surprises."
                 : "查看更长周期的变化，对比模型分布，排查用量突增。")
                .font(.subheadline)
                .foregroundStyle(Theme.subtitleText)
            LanguageToggle(language: $language)
        }
    }

    // MARK: - Trend Line Card

    private var trendLineCard: some View {
        let points = isLive ? historyService.downsampledPoints(for: selectedRange) : HistoryDemoData.trendPoints
        let peakPct = Int(round((points.map(\.pct7d).max() ?? 0) * 100))

        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(isEN ? "TREND LINE" : "趋势曲线")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                Text(isEN
                     ? "\(selectedRange.rawValue) peak: \(peakPct)%"
                     : "\(selectedRange.rawValue) 峰值：\(peakPct)%")
                    .font(.title3)
                    .fontWeight(.bold)

                if points.count >= 2 {
                    trendBarChart(points: points)
                        .frame(height: 140)
                } else {
                    Text(isEN ? "Not enough data yet" : "数据不足")
                        .font(.caption)
                        .foregroundStyle(Theme.subtitleText)
                        .frame(height: 140)
                        .frame(maxWidth: .infinity)
                }

                Text(isEN
                     ? "Mon to Sun, latest sync highlighted in teal."
                     : "按每一到周日展示，最新同步用青色高亮。")
                    .font(.caption2)
                    .foregroundStyle(Theme.subtitleText)
            }
        }
    }

    private func trendBarChart(points: [UsageDataPoint]) -> some View {
        let maxVal = max(points.map(\.pct7d).max() ?? 1, 0.01)

        return GeometryReader { geo in
            let spacing: CGFloat = 6
            let barWidth = max(8, (geo.size.width - CGFloat(points.count - 1) * spacing) / CGFloat(points.count))

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    let isLatest = index == points.count - 1
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isLatest ? Theme.teal : Theme.terracotta)
                            .frame(width: barWidth, height: max(6, geo.size.height * 0.85 * point.pct7d / maxVal))

                        Text(dayLabel(for: point.timestamp))
                            .font(.system(size: 8))
                            .foregroundStyle(Theme.subtitleText)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func dayLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.dateFormat = isEN ? "EEE" : "E"
        return String(formatter.string(from: date).prefix(3))
    }

    // MARK: - Time Range Selector

    private var timeRangeSelector: some View {
        HStack(spacing: 0) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    selectedRange = range
                } label: {
                    Text(range.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(selectedRange == range ? Theme.teal : Color.clear)
                        .foregroundStyle(selectedRange == range ? .white : Theme.bodyText)
                }
            }
        }
        .background(Color.gray.opacity(0.1))
        .clipShape(Capsule())
        .frame(maxWidth: .infinity)
    }

    // MARK: - Model Split

    private var modelSplitSection: some View {
        let sonnetPct = isLive ? (usageService.usage?.sevenDaySonnet?.utilization ?? 0) / 100.0 : HistoryDemoData.sonnetPct
        let opusPct = isLive ? (usageService.usage?.sevenDayOpus?.utilization ?? 0) / 100.0 : HistoryDemoData.opusPct

        return CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text(isEN ? "MODEL SPLIT" : "模型占比")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                modelRow(name: "Sonnet", pct: sonnetPct, color: Theme.terracotta)
                modelRow(name: "Opus", pct: opusPct, color: Theme.teal)

                Text(isEN
                     ? "Sonnet carries most of the weekly load, with Opus appearing in shorter bursts."
                     : "Sonnet 承担了本周大部分负载，Opus 主要出现在较短的突发使用中。")
                    .font(.caption)
                    .foregroundStyle(Theme.subtitleText)
            }
        }
    }

    private func modelRow(name: String, pct: Double, color: Color) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
            }
            Spacer()
            Text("\(Int(round(pct * 100)))%")
                .font(.body)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }

    // MARK: - Recent Snapshots

    private var recentSnapshotsSection: some View {
        let recent = isLive ? Array(historyService.history.dataPoints.suffix(5).reversed()) : HistoryDemoData.snapshots

        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(isEN ? "RECENT SNAPSHOTS" : "最近快照")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                if recent.isEmpty {
                    Text(isEN ? "No snapshots yet" : "暂无快照")
                        .font(.caption)
                        .foregroundStyle(Theme.subtitleText)
                } else {
                    ForEach(recent) { point in
                        HStack {
                            Text(snapshotDateLabel(point.timestamp))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            Text("\(Int(round(point.pct7d * 100)))% used")
                                .font(.subheadline)
                                .foregroundStyle(point.pct7d > 0.6 ? Theme.terracotta : Theme.teal)
                        }
                    }
                }
            }
        }
    }

    private func snapshotDateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.locale = language.locale
        if calendar.isDateInToday(date) {
            formatter.dateFormat = isEN ? "'Today' HH:mm" : "'今天' HH:mm"
        } else if calendar.isDateInYesterday(date) {
            formatter.dateFormat = isEN ? "'Yesterday' HH:mm" : "'昨天' HH:mm"
        } else {
            formatter.dateFormat = isEN ? "MMM d HH:mm" : "M月d日 HH:mm"
        }
        return formatter.string(from: date)
    }
}
