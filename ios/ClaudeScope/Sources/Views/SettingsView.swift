import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var usageService: UsageService
    @EnvironmentObject var notificationService: NotificationService
    @State private var language = AppLanguage.stored
    @State private var selectedPolling: Int = UsageService.defaultPollingMinutes
    @State private var showLanguagePicker = false
    @State private var selectedWidgetSize: WidgetSize = .large

    private var isEN: Bool { language.isEnglish }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                accountSection
                languageSection
                notificationsSection
                refreshRhythmSection
                signOutSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 120)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .onAppear {
            selectedPolling = usageService.pollingMinutes
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Theme.sectionTitle(isEN ? "CLAUDE SETTINGS" : "CLAUDE 设置")
            Text(isEN ? "Tune the app around\nyour habits." : "按照你的使用习惯调整应\n用。")
                .font(.title)
                .fontWeight(.bold)
                .foregroundStyle(Theme.bodyText)
            Text(isEN
                 ? "Control language, refresh rhythm, widgets, and notifications from one calm place."
                 : "把语言、刷新节奏、小组件和通知集中放在一个安静的设置页面。")
                .font(.subheadline)
                .foregroundStyle(Theme.subtitleText)
            LanguageToggle(language: $language)
        }
    }

    // MARK: - Account & Sync

    private var accountSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text(isEN ? "ACCOUNT & SYNC" : "账号与同步")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                if usageService.isAuthenticated {
                    Text(isEN ? "Signed in to Claude" : "已登录 Claude")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let email = usageService.accountEmail {
                        Text(email)
                            .font(.caption)
                            .foregroundStyle(Theme.subtitleText)
                    }

                    if let lastUpdated = usageService.lastUpdated {
                        Text(isEN ? "Last refreshed " : "上次刷新 ")
                            .font(.caption)
                            .foregroundStyle(Theme.subtitleText)
                        + Text(lastUpdated, style: .relative)
                            .font(.caption)
                            .foregroundStyle(Theme.subtitleText)
                        + Text(isEN ? " ago" : "前")
                            .font(.caption)
                            .foregroundStyle(Theme.subtitleText)
                    }

                    Button {
                        Task { await usageService.fetchUsage() }
                    } label: {
                        Text(isEN ? "SYNC NOW" : "立即同步")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .tracking(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Theme.teal)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                } else {
                    Text(isEN ? "Not signed in" : "未登录")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(isEN ? "Sign in to sync your real-time usage data." : "登录后同步你的实时用量数据。")
                        .font(.caption)
                        .foregroundStyle(Theme.subtitleText)

                    Button {
                        usageService.startOAuthFlow()
                    } label: {
                        Text(isEN ? "SIGN IN WITH CLAUDE" : "登录 CLAUDE")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .tracking(1)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Theme.teal)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Language & Widgets

    private var languageSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text(isEN ? "LANGUAGE & WIDGETS" : "语言与组件")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                // Display language - tap to cycle
                Button {
                    cycleLanguage()
                } label: {
                    HStack {
                        Text(isEN ? "Display language" : "显示语言")
                            .font(.subheadline)
                            .foregroundStyle(Theme.bodyText)
                        Spacer()
                        Text(language.displayName)
                            .font(.subheadline)
                            .foregroundStyle(Theme.teal)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Theme.subtitleText)
                    }
                }

                Divider()

                // Widget size - tap to cycle
                Button {
                    cycleWidgetSize()
                } label: {
                    HStack {
                        Text(isEN ? "Home screen widget" : "主屏幕小组件")
                            .font(.subheadline)
                            .foregroundStyle(Theme.bodyText)
                        Spacer()
                        Text(selectedWidgetSize.localizedName)
                            .font(.subheadline)
                            .foregroundStyle(Theme.teal)
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(Theme.subtitleText)
                    }
                }
            }
        }
    }

    private func cycleLanguage() {
        switch language {
        case .english:
            language = .simplifiedChinese
        case .simplifiedChinese:
            language = .system
        case .system:
            language = .english
        }
        UserDefaults.standard.set(language.rawValue, forKey: AppLanguage.storageKey)
        AnalyticsService.shared.trackLanguageChanged(language.rawValue)
    }

    private func cycleWidgetSize() {
        switch selectedWidgetSize {
        case .small: selectedWidgetSize = .medium
        case .medium: selectedWidgetSize = .large
        case .large: selectedWidgetSize = .small
        }
        AnalyticsService.shared.trackWidgetConfigured(size: selectedWidgetSize.rawValue)
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text(isEN ? "NOTIFICATIONS" : "通知")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                Toggle(isOn: Binding(
                    get: { notificationService.alertsEnabled },
                    set: {
                        notificationService.alertsEnabled = $0
                        if $0 { notificationService.requestPermission() }
                    }
                )) {
                    Text(isEN ? "Usage threshold alerts" : "用量阈值提醒")
                        .font(.subheadline)
                }
                .tint(Theme.teal)

                HStack {
                    Text(isEN ? "Warn me at" : "提醒阈值")
                        .font(.subheadline)
                    Spacer()
                    Text("\(notificationService.warnThreshold)%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Theme.terracotta)
                }

                Slider(value: Binding(
                    get: { Double(notificationService.warnThreshold) },
                    set: { notificationService.warnThreshold = Int($0) }
                ), in: 50...100, step: 5)
                .tint(Theme.terracotta)
            }
        }
    }

    // MARK: - Refresh Rhythm

    private var refreshRhythmSection: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Text(isEN ? "REFRESH RHYTHM" : "刷新频率")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .tracking(1.5)
                    .foregroundStyle(Theme.sectionHeader)

                Text(isEN
                     ? "Choose how often ClaudeScope checks your usage in the background."
                     : "选择 ClaudeScope 在后台检查用量的频率。")
                    .font(.caption)
                    .foregroundStyle(Theme.subtitleText)

                HStack(spacing: 0) {
                    ForEach([5, 15, 30, 60], id: \.self) { minutes in
                        Button {
                            selectedPolling = minutes
                            usageService.updatePollingInterval(minutes)
                            AnalyticsService.shared.trackPollingIntervalChanged(minutes)
                        } label: {
                            Text(pollingLabel(minutes))
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedPolling == minutes ? Theme.teal : Color.clear)
                                .foregroundStyle(selectedPolling == minutes ? .white : Theme.bodyText)
                        }
                    }
                }
                .background(Color.gray.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    private func pollingLabel(_ minutes: Int) -> String {
        if minutes >= 60 {
            return isEN ? "1h" : "1小时"
        }
        return isEN ? "\(minutes)m" : "\(minutes)分"
    }

    // MARK: - Sign Out

    @ViewBuilder
    private var signOutSection: some View {
        if usageService.isAuthenticated {
            Button {
                usageService.signOut()
            } label: {
                Text(isEN ? "Sign Out" : "退出登录")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardCornerRadius))
        }
    }
}
