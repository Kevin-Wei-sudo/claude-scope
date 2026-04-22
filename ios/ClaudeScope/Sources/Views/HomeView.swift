import SwiftUI

// MARK: - Demo data for unauthenticated state

private enum DemoData {
    static let pct5h: Double = 0.18
    static let pct7d: Double = 0.42
    static let sonnetPct: Double = 0.34
    static let opusPct: Double = 0.24
    static let resetDate: Date = {
        var comps = DateComponents()
        comps.hour = 0
        comps.minute = 0
        comps.weekday = 3
        return Calendar.current.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime)
            ?? Date().addingTimeInterval(3 * 86400)
    }()

    static let trendPoints: [UsageDataPoint] = {
        let now = Date()
        return (0..<7).map { i in
            let values: [Double] = [0.25, 0.32, 0.38, 0.45, 0.52, 0.68, 0.42]
            return UsageDataPoint(
                timestamp: now.addingTimeInterval(Double(i - 6) * 86400),
                pct5h: values[i] * 0.6,
                pct7d: values[i]
            )
        }
    }()
}

struct HomeView: View {
    @EnvironmentObject var usageService: UsageService
    @EnvironmentObject var historyService: UsageHistoryService
    @State private var language = AppLanguage.stored

    private var isEN: Bool { language.isEnglish }
    private var isLive: Bool { usageService.isAuthenticated }

    private var pct5h: Double { isLive ? usageService.pct5h : DemoData.pct5h }
    private var pct7d: Double { isLive ? usageService.pct7d : DemoData.pct7d }
    private var sonnetPct: Double {
        isLive ? (usageService.usage?.sevenDaySonnet?.utilization ?? 0) / 100.0 : DemoData.sonnetPct
    }
    private var reset5h: Date? { isLive ? usageService.reset5h : DemoData.resetDate.addingTimeInterval(-2 * 86400) }
    private var reset7d: Date? { isLive ? usageService.reset7d : DemoData.resetDate }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                if !isLive { signInBanner }
                todaySnapshot
                windowCards
                modelFocus
                trendPreview
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
        }
        .background(Theme.background)
        .scrollDismissesKeyboard(.interactively)
        .onAppear {
            // Ask ATT on first home-view appearance, then start AppsFlyer.
            // Safe to call on every onAppear — helper checks status and no-ops
            // if the user already decided.
            TrackingAuthorization.requestIfNeededAndStart()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Theme.sectionTitle(isEN ? "CLAUDE USAGE" : "CLAUDE 用量")
            Text(isEN ? "Your limit, without the\nguessing." : "不用猜，还能用多少一眼就\n知道。")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Theme.bodyText)
            Text(isEN
                 ? "A compact iPhone view for 5-hour, 7-day, and model-level usage."
                 : "一个紧凑的 iPhone 视图，覆盖 5 小时、7 天和模型级用量。")
                .font(.subheadline)
                .foregroundStyle(Theme.subtitleText)
            LanguageToggle(language: $language)
        }
    }

    // MARK: - Sign In Banner

    private var signInBanner: some View {
        SignInBannerView(language: $language)
    }

    // MARK: - Today's Snapshot

    private var todaySnapshot: some View {
        let pct = Int(round(pct7d * 100))
        let summary: String = {
            if !isLive {
                return isEN
                    ? "Comfortable headroom. Sonnet is still your main model this week."
                    : "当前额度比较充足，本周仍以 Sonnet 为主。"
            }
            if pct < 40 {
                return isEN ? "Comfortable headroom. Sonnet is still your main model this week." : "当前额度比较充足，本周仍以 Sonnet 为主。"
            } else if pct < 70 {
                return isEN ? "Moderate usage. Keep an eye on it." : "用量适中，留意一下。"
            }
            return isEN ? "Usage is getting high. Consider pacing." : "用量偏高，建议控制节奏。"
        }()

        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(isEN ? "TODAY'S SNAPSHOT" : "今日概览")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                Text("\(pct)%")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.teal)

                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(Theme.subtitleText)

                if let resetDate = reset7d {
                    HStack {
                        Text(isEN ? "Next reset" : "下次重置")
                            .font(.caption)
                            .foregroundStyle(Theme.subtitleText)
                        Spacer()
                        Text(resetDate, style: .relative)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.bodyText)
                    }
                }
            }
        }
        .opacity(isLive ? 1.0 : 0.75)
    }

    // MARK: - Window Cards

    private var windowCards: some View {
        HStack(spacing: 12) {
            windowCard(
                title: isEN ? "5 HOUR" : "5 小时",
                pct: pct5h,
                resetDate: reset5h,
                tint: Theme.terracotta
            )
            windowCard(
                title: isEN ? "7 DAY" : "7 天",
                pct: pct7d,
                resetDate: reset7d,
                tint: Theme.teal
            )
        }
        .opacity(isLive ? 1.0 : 0.75)
    }

    private func windowCard(title: String, pct: Double, resetDate: Date?, tint: Color) -> some View {
        CardView {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                Text("\(Int(round(pct * 100)))%")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.bodyText)

                UsageProgressBar(value: pct, tint: tint)

                if let resetDate {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isEN ? "Resets" : "重置")
                            .font(.caption2)
                            .foregroundStyle(Theme.subtitleText)
                        Text(resetDate, style: .relative)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(Theme.bodyText)
                    }
                }
            }
        }
    }

    // MARK: - Model Focus

    private var modelFocus: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text(isEN ? "MODEL FOCUS" : "模型统计")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                HStack {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(Theme.terracotta)
                    Text("Sonnet model")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text(isEN ? "已用 " : "已用 ")
                        .font(.caption)
                        .foregroundStyle(Theme.subtitleText)
                    Text("\(Int(round(sonnetPct * 100)))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(Theme.bodyText)
                }

                UsageProgressBar(value: sonnetPct, tint: Theme.terracotta)

                if let resetDate = reset7d {
                    Text(isEN ? "Resets " : "重置 ")
                        .font(.caption2)
                        .foregroundStyle(Theme.subtitleText)
                    + Text(resetDate, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(Theme.subtitleText)
                }
            }
        }
        .opacity(isLive ? 1.0 : 0.75)
    }

    // MARK: - Trend Preview

    private var trendPreview: some View {
        let points = isLive ? historyService.downsampledPoints(for: .day7) : DemoData.trendPoints

        return VStack(alignment: .leading, spacing: 8) {
            Text(isEN ? "TREND PREVIEW" : "趋势预览")
                .font(.caption)
                .fontWeight(.semibold)
                .tracking(1.5)
                .foregroundStyle(Theme.sectionHeader)
            Text(isEN ? "Usage drift this week" : "本周用量变化")
                .font(.subheadline)
                .foregroundStyle(Theme.subtitleText)

            if points.count >= 2 {
                MiniBarChart(points: points)
                    .frame(height: 60)
            } else {
                Text(isEN ? "Not enough data yet" : "数据不足")
                    .font(.caption)
                    .foregroundStyle(Theme.subtitleText)
                    .frame(height: 60)
            }
        }
        .opacity(isLive ? 1.0 : 0.75)
    }
}

// MARK: - Mini Bar Chart

struct MiniBarChart: View {
    let points: [UsageDataPoint]

    var body: some View {
        GeometryReader { geo in
            let maxVal = max(points.map(\.pct7d).max() ?? 1, 0.01)
            let barWidth = max(4, (geo.size.width - CGFloat(points.count - 1) * 3) / CGFloat(points.count))
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(points.enumerated()), id: \.offset) { index, point in
                    let isLatest = index == points.count - 1
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isLatest ? Theme.teal : Theme.terracotta)
                        .frame(width: barWidth, height: max(4, geo.size.height * point.pct7d / maxVal))
                }
            }
        }
    }
}

// MARK: - Sign-In Banner

struct SignInBannerView: View {
    @EnvironmentObject var usageService: UsageService
    @Binding var language: AppLanguage
    @State private var codeInput = ""

    private var isEN: Bool { language.isEnglish }

    var body: some View {
        CardView {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.title2)
                        .foregroundStyle(Theme.teal)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isEN ? "Connect your account" : "连接你的账号")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(isEN ? "Sign in to see your real-time usage data." : "登录后查看你的实时用量数据。")
                            .font(.caption)
                            .foregroundStyle(Theme.subtitleText)
                    }
                    Spacer()
                }

                if usageService.isAwaitingCode {
                    VStack(spacing: 10) {
                        Text(isEN ? "Paste the code from your browser:" : "请粘贴浏览器中的代码：")
                            .font(.caption)
                            .foregroundStyle(Theme.subtitleText)
                        TextField("code#state", text: $codeInput)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                            #if os(iOS)
                            .textInputAutocapitalization(.never)
                            #endif
                            .font(.caption)

                        HStack(spacing: 12) {
                            Button(isEN ? "Cancel" : "取消") {
                                usageService.isAwaitingCode = false
                                codeInput = ""
                            }
                            .font(.caption)
                            .foregroundStyle(Theme.subtitleText)

                            Button(isEN ? "Submit" : "提交") {
                                Task { await usageService.submitOAuthCode(codeInput) }
                            }
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Theme.teal)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                            .disabled(codeInput.isEmpty)
                        }
                    }
                } else {
                    Button {
                        usageService.startOAuthFlow()
                    } label: {
                        Text(isEN ? "Sign in with Claude" : "登录 Claude")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.teal)
                }

                if let error = usageService.lastError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { usageService.oauthURL != nil },
            set: { if !$0 { usageService.oauthURL = nil } }
        )) {
            if let url = usageService.oauthURL {
                SafariView(url: url)
                    .ignoresSafeArea()
            }
        }
    }
}
