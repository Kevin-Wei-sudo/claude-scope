import SwiftUI

// Widget data model for sharing between app and widget
struct WidgetData: Codable {
    let pct5h: Double
    let pct7d: Double
    let resetDate: Date?
    let lastUpdated: Date

    static let placeholder = WidgetData(pct5h: 0.18, pct7d: 0.42, resetDate: nil, lastUpdated: Date())

    static var appGroupID: String { "group.io.sandwichlab.claudescope" }

    static func save(_ data: WidgetData) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        defaults.set(try? JSONEncoder().encode(data), forKey: "widgetData")
    }

    static func load() -> WidgetData? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: "widgetData") else { return nil }
        return try? JSONDecoder().decode(WidgetData.self, from: data)
    }
}

// MARK: - Widget Entry View (can be used in both app preview and actual widget)

struct WidgetEntryView: View {
    let data: WidgetData
    let size: WidgetSize

    var body: some View {
        switch size {
        case .small:
            smallWidget
        case .medium:
            mediumWidget
        case .large:
            largeWidget
        }
    }

    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ClaudeScope")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(Int(round(data.pct7d * 100)))%")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.teal)
            Text("7-day")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    private var mediumWidget: some View {
        VStack(spacing: 8) {
            HStack {
                Text("ClaudeScope")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(round(data.pct7d * 100)))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.teal)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("5h").font(.caption2).foregroundStyle(.secondary)
                    UsageProgressBar(value: data.pct5h, tint: Theme.terracotta, height: 4)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("7d").font(.caption2).foregroundStyle(.secondary)
                    UsageProgressBar(value: data.pct7d, tint: Theme.teal, height: 4)
                }
            }

            if let resetDate = data.resetDate {
                HStack {
                    Text("Resets").font(.caption2).foregroundStyle(.secondary)
                    Text(resetDate, style: .relative).font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
        .padding(12)
    }

    private var largeWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("ClaudeScope")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(Int(round(data.pct7d * 100)))%")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.teal)
            }

            Divider()

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("5-Hour").font(.caption).fontWeight(.medium)
                    Text("\(Int(round(data.pct5h * 100)))%")
                        .font(.title3).fontWeight(.bold)
                    UsageProgressBar(value: data.pct5h, tint: Theme.terracotta, height: 5)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("7-Day").font(.caption).fontWeight(.medium)
                    Text("\(Int(round(data.pct7d * 100)))%")
                        .font(.title3).fontWeight(.bold)
                    UsageProgressBar(value: data.pct7d, tint: Theme.teal, height: 5)
                }
            }

            Spacer()

            if let resetDate = data.resetDate {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("Resets ").font(.caption2).foregroundStyle(.secondary)
                    + Text(resetDate, style: .relative).font(.caption2).foregroundStyle(.secondary)
                }
            }

            Text("Updated ").font(.caption2).foregroundStyle(.tertiary)
            + Text(data.lastUpdated, style: .relative).font(.caption2).foregroundStyle(.tertiary)
            + Text(" ago").font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(14)
    }
}
