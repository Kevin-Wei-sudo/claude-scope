import SwiftUI

enum WidgetSize: String, CaseIterable, CustomStringConvertible {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"

    var description: String { rawValue }

    var localizedName: String {
        switch self {
        case .small: return AppLanguage.stored.isEnglish ? "Small" : "小号"
        case .medium: return AppLanguage.stored.isEnglish ? "Medium" : "中号"
        case .large: return AppLanguage.stored.isEnglish ? "Large" : "大号"
        }
    }
}

struct WidgetSettingsView: View {
    @EnvironmentObject var usageService: UsageService
    @State private var language = AppLanguage.stored
    @State private var selectedSize: WidgetSize = .medium
    @State private var show5h = true
    @State private var show7d = true
    @State private var showNextReset = true

    private var isEN: Bool { language.isEnglish }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                livePreviewCard
                widgetSizeSection
                visibleSignalsSection
                installTipSection
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
            Theme.sectionTitle(isEN ? "CLAUDE WIDGET" : "CLAUDE 组件")
            Text(isEN ? "Pin your usage on the\nhome screen." : "把用量固定到主屏幕。")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Theme.bodyText)
            Text(isEN
                 ? "Choose a widget size, preview the layout, and decide which signals stay visible."
                 : "选择组件尺寸，预览布局，并决定要显示哪些信号。")
                .font(.subheadline)
                .foregroundStyle(Theme.subtitleText)
            LanguageToggle(language: $language)
        }
    }

    // MARK: - Live Preview

    // Demo data when not logged in
    private var previewPct5h: Double { usageService.isAuthenticated ? usageService.pct5h : 0.18 }
    private var previewPct7d: Double { usageService.isAuthenticated ? usageService.pct7d : 0.42 }
    private var previewResetDate: Date? {
        if usageService.isAuthenticated { return usageService.reset7d }
        var comps = DateComponents()
        comps.hour = 0; comps.minute = 0; comps.weekday = 3
        return Calendar.current.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime)
    }

    private var livePreviewCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(isEN ? "LIVE PREVIEW" : "实时预览")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                VStack(spacing: 10) {
                    // Title + percentage
                    HStack {
                        Text("ClaudeScope")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(Int(round(previewPct7d * 100)))%")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Theme.teal)
                    }

                    // Progress bars with percentages
                    if show5h || show7d {
                        HStack(spacing: 16) {
                            if show5h {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("5h")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Theme.subtitleText)
                                        Spacer()
                                        Text("\(Int(round(previewPct5h * 100)))%")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Theme.terracotta)
                                    }
                                    UsageProgressBar(value: previewPct5h, tint: Theme.terracotta, height: 6)
                                }
                            }
                            if show7d {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("7d")
                                            .font(.caption2)
                                            .fontWeight(.medium)
                                            .foregroundStyle(Theme.subtitleText)
                                        Spacer()
                                        Text("\(Int(round(previewPct7d * 100)))%")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(Theme.teal)
                                    }
                                    UsageProgressBar(value: previewPct7d, tint: Theme.teal, height: 6)
                                }
                            }
                        }
                    }

                    // Reset time
                    if let resetDate = previewResetDate {
                        HStack {
                            Text(isEN ? "Resets " : "重置 ")
                                .font(.caption2)
                                .foregroundStyle(Theme.subtitleText)
                            + Text(resetDate, style: .date)
                                .font(.caption2)
                                .foregroundStyle(Theme.subtitleText)
                            + Text(" ")
                                .font(.caption2)
                            + Text(resetDate, style: .time)
                                .font(.caption2)
                                .foregroundStyle(Theme.subtitleText)
                            Spacer()
                        }
                    }
                }
                .padding(14)
                .background(Color.gray.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Widget Size

    private var widgetSizeSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(isEN ? "WIDGET SIZE" : "组件尺寸")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                HStack(spacing: 0) {
                    ForEach(WidgetSize.allCases, id: \.self) { size in
                        Button {
                            selectedSize = size
                        } label: {
                            Text(size.localizedName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(selectedSize == size ? Theme.teal : Color.clear)
                                .foregroundStyle(selectedSize == size ? .white : Theme.bodyText)
                        }
                    }
                }
                .background(Color.gray.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    // MARK: - Visible Signals

    private var visibleSignalsSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text(isEN ? "VISIBLE SIGNALS" : "显示项")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                Toggle(isEN ? "Show 5-hour usage" : "显示 5 小时用量", isOn: $show5h)
                    .font(.subheadline)
                    .tint(Theme.teal)

                Toggle(isEN ? "Show 7-day usage" : "显示 7 天用量", isOn: $show7d)
                    .font(.subheadline)
                    .tint(Theme.teal)

                Toggle(isEN ? "Show next reset" : "显示下次重置", isOn: $showNextReset)
                    .font(.subheadline)
                    .tint(Theme.teal)
            }
        }
    }

    // MARK: - Install Tip

    @State private var showInstallAlert = false

    private var installTipSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text(isEN ? "INSTALL TIP" : "安装提示")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                Text(isEN
                     ? "Long-press the home screen, tap edit, then add the ClaudeScope widget in your preferred size."
                     : "长按主屏幕，点击编辑，然后添加 ClaudeScope 组件并选择你想要的尺寸。")
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtitleText)

                Button {
                    showInstallAlert = true
                } label: {
                    Text(isEN ? "ADD TO HOME SCREEN" : "添加到主屏幕")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .tracking(1)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Theme.teal)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
                .alert(
                    isEN ? "Add Widget" : "添加组件",
                    isPresented: $showInstallAlert
                ) {
                    Button(isEN ? "OK" : "好的", role: .cancel) {}
                } message: {
                    Text(isEN
                         ? "1. Go to your Home Screen\n2. Long-press on an empty area\n3. Tap the + button at the top\n4. Search for \"ClaudeScope\"\n5. Choose your preferred size and tap \"Add Widget\""
                         : "1. 返回主屏幕\n2. 长按空白区域\n3. 点击左上角 + 按钮\n4. 搜索「ClaudeScope」\n5. 选择尺寸并点击「添加小组件」")
                }
            }
        }
    }
}
