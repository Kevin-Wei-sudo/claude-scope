import SwiftUI

struct PopoverView: View {
    @ObservedObject var service: UsageService
    @ObservedObject var historyService: UsageHistoryService
    @ObservedObject var notificationService: NotificationService
    @ObservedObject var intelligenceService: UsageIntelligenceService
    @ObservedObject var announcementService: AnnouncementService
    @ObservedObject var attributionService: AttributionService
    @ObservedObject var codexService: CodexUsageService
    @ObservedObject var appUpdater: AppUpdater
    @AppStorage("setupComplete") private var setupComplete = false
    @AppStorage("popoverProviderTab") private var providerTabRaw = "claude"
    @Environment(\.openWindow) private var openWindow
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !setupComplete && !service.isAuthenticated {
                SetupView(
                    service: service,
                    notificationService: notificationService,
                    onComplete: { setupComplete = true }
                )
            } else {
                Text(localizedString("popover.title", fallback: "ClaudeScope", language: appLanguage))
                    .font(.headline)
                if !service.isAuthenticated {
                    signInView
                } else {
                    usageView
                }
            }
        }
        .padding()
        .frame(width: 340)
    }

    @ViewBuilder
    private var signInView: some View {
        if service.isAwaitingCode {
            CodeEntryView(service: service)
        } else {
            Text(localizedString("signin.prompt", fallback: "Sign in to view your usage.", language: appLanguage))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button(localizedString("signin.button", fallback: "Sign in with Claude", language: appLanguage)) {
                service.startOAuthFlow()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }

        if let error = service.lastError {
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.caption)
        }

        Divider()
        HStack {
            settingsButton
            Spacer()
            Button(localizedString("button.quit", fallback: "Quit", language: appLanguage)) {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var usageView: some View {
        if codexService.usage != nil {
            Picker("", selection: $providerTabRaw) {
                Text("Claude").tag("claude")
                Text("Codex").tag("codex")
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }

        if providerTabRaw == "codex", let codex = codexService.usage {
            CodexSection(
                usage: codex,
                localStats: codexService.localStats,
                isStale: codexService.isStale,
                language: appLanguage
            )
        } else {
            claudeUsageView
        }

        sharedFooterView
    }

    @ViewBuilder
    private var claudeUsageView: some View {
        if let announcement = announcementService.banner {
            AnnouncementBanner(
                announcement: announcement,
                language: appLanguage,
                onDismiss: { announcementService.dismiss(announcement) }
            )
            Divider()
        }

        if let snapshot = intelligenceService.snapshot {
            IntelligenceSection(snapshot: snapshot, language: appLanguage)
            Divider()
        }

        UsageBucketRow(
            label: localizedString("usage.five_hour_window", fallback: "5-Hour Window", language: appLanguage),
            bucket: service.usage?.fiveHour,
            windowDuration: 5 * 60 * 60
        )

        if let burnRate = currentBurnRate(points: historyService.history.dataPoints, now: Date()) {
            BurnRateRow(burnRate: burnRate)
        }

        UsageBucketRow(
            label: localizedString("usage.seven_day_window", fallback: "7-Day Window", language: appLanguage),
            bucket: service.usage?.sevenDay,
            windowDuration: 7 * 24 * 60 * 60
        )

        let opus = service.usage?.sevenDayOpus
        let sonnet = service.usage?.sevenDaySonnet
        let scopedBuckets = service.usage?.scopedWeeklyBuckets ?? []
        let additionalBuckets = (service.usage?.additionalBuckets ?? [:]).sorted { $0.key < $1.key }
        if (opus?.utilization != nil) || (sonnet?.utilization != nil) || !additionalBuckets.isEmpty || !scopedBuckets.isEmpty {
            Divider()
            Text(localizedString("usage.per_model", fallback: "Per-Model (7 day)", language: appLanguage))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            ForEach(scopedBuckets, id: \.label) { entry in
                UsageBucketRow(
                    label: entry.label,
                    bucket: entry.bucket,
                    windowDuration: 7 * 24 * 60 * 60
                )
            }
            if let opus, opus.utilization != nil {
                UsageBucketRow(
                    label: localizedString("usage.model.opus_only", fallback: "Opus only", language: appLanguage),
                    bucket: opus
                )
            }
            if let sonnet, sonnet.utilization != nil {
                UsageBucketRow(
                    label: localizedString("usage.model.sonnet_only", fallback: "Sonnet only", language: appLanguage),
                    bucket: sonnet
                )
            }
            ForEach(additionalBuckets, id: \.key) { entry in
                UsageBucketRow(
                    label: displayName(forBucketKey: entry.key),
                    bucket: entry.value
                )
            }
        }

        if let extra = service.usage?.extraUsage, extra.isEnabled {
            Divider()
            ExtraUsageRow(extra: extra)
        }

        Divider()
        UsageChartView(historyService: historyService)
        HStack {
            Spacer()
            attributionButton
        }
    }

    @ViewBuilder
    private var sharedFooterView: some View {
        if let error = service.lastError {
            Divider()
            Label(error, systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
                .font(.caption)
        }

        if let updaterError = appUpdater.lastError {
            Divider()
            Label(updaterError, systemImage: "arrow.triangle.2.circlepath.circle")
                .foregroundStyle(.red)
                .font(.caption)
        }

        Divider()

        HStack(spacing: 12) {
            if let updated = service.lastUpdated {
                Text(
                    localizedFormat(
                        "usage.updated_ago",
                        fallback: "Updated %@ ago",
                        language: appLanguage,
                        updated.formatted(
                            .relative(presentation: .named)
                                .locale(appLanguage.locale)
                        )
                    )
                )
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }

        HStack(spacing: 12) {
            settingsButton
            Spacer()
            Button(localizedString("button.refresh", fallback: "Refresh", language: appLanguage)) {
                Task { await service.fetchUsage() }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            if appUpdater.isConfigured {
                Button(localizedString("button.check_updates", fallback: "Check for Updates…", language: appLanguage)) {
                    appUpdater.checkForUpdates()
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .disabled(!appUpdater.canCheckForUpdates)
            }
            Button(localizedString("button.quit", fallback: "Quit", language: appLanguage)) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var attributionButton: some View {
        Button(localizedString("button.attribution", fallback: "Where it went…", language: appLanguage)) {
            attributionService.refreshIfStale()
            openWindow(id: AttributionWindow.id)
            NSApp.activate(ignoringOtherApps: true)
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }

    private var settingsButton: some View {
        SettingsLink {
            Text(localizedString("button.settings", fallback: "Settings…", language: appLanguage))
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }
}

private struct AnnouncementBanner: View {
    let announcement: Announcement
    let language: AppLanguage
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "megaphone.fill")
                .font(.caption)
                .foregroundStyle(.purple)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 3) {
                Text(announcement.localizedTitle(for: language))
                    .font(.caption.weight(.semibold))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text(announcement.localizedBody(for: language))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                if let urlString = announcement.url, let url = URL(string: urlString) {
                    Link(
                        localizedString("announcement.details", fallback: "Details", language: language),
                        destination: url
                    )
                    .font(.caption2)
                }
            }

            Spacer(minLength: 0)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.purple.opacity(0.18), lineWidth: 1)
        )
    }
}

private struct IntelligenceSection: View {
    let snapshot: UsageIntelligenceSnapshot
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("intelligence.section_title", fallback: "Usage Intelligence", language: language))
                .font(.caption)
                .foregroundStyle(.secondary)

            IntelligenceSummaryCard(snapshot: snapshot, language: language)

            if !snapshot.insights.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(snapshot.insights) { insight in
                        UsageInsightRow(insight: insight, language: language)
                    }
                }
            }
        }
    }
}

private struct IntelligenceSummaryCard: View {
    let snapshot: UsageIntelligenceSnapshot
    let language: AppLanguage

    private var tint: Color {
        switch snapshot.summary.kind {
        case .risk:
            return .orange
        case .action:
            return .blue
        case .opportunity:
            return .green
        case .neutral:
            return .secondary
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(localizedString(
                    snapshot.summary.titleKey,
                    fallback: snapshot.summary.titleFallback,
                    language: language
                ))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)

                Text.highlightedInsightBody(
                    summaryBody,
                    emphasizedFragments: snapshot.summary.emphasizedFragments,
                    accent: tint,
                    baseFont: .caption
                )
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }

    private var summaryBody: String {
        let format = localizedString(
            snapshot.summary.bodyKey,
            fallback: snapshot.summary.bodyFallback,
            language: language
        )
        return String(format: format, locale: language.locale, arguments: snapshot.summary.bodyArguments)
    }
}

private struct UsageInsightRow: View {
    let insight: UsageInsightItem
    let language: AppLanguage

    private var tint: Color {
        switch insight.kind {
        case .risk:
            return .orange
        case .action:
            return .blue
        case .opportunity:
            return .green
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(tint)
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 3) {
                Text(localizedString(insight.titleKey, fallback: insight.titleFallback, language: language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text.highlightedInsightBody(
                    bodyText,
                    emphasizedFragments: insight.emphasizedFragments,
                    accent: tint,
                    baseFont: .caption2
                )
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(tint.opacity(0.16), lineWidth: 1)
        )
    }

    private var bodyText: String {
        let format = localizedString(insight.bodyKey, fallback: insight.bodyFallback, language: language)
        return String(format: format, locale: language.locale, arguments: insight.bodyArguments)
    }
}

private extension Text {
    static func highlightedInsightBody(
        _ text: String,
        emphasizedFragments: [String],
        accent: Color,
        baseFont: Font
    ) -> Text {
        let fragments = emphasizedFragments
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && text.localizedCaseInsensitiveContains($0) }

        guard !fragments.isEmpty else {
            return Text(text).font(baseFont).foregroundStyle(.secondary)
        }

        let nsText = text as NSString
        let escaped = fragments.map { fragment in
            let escapedFragment = NSRegularExpression.escapedPattern(for: fragment)
            if fragment.range(of: #"^\d+(?:\.\d+)?%?$"#, options: .regularExpression) != nil {
                return #"(?<!\d)"# + escapedFragment + #"(?!\d)"#
            }
            return escapedFragment
        }
        guard let regex = try? NSRegularExpression(
            pattern: escaped.joined(separator: "|"),
            options: [.caseInsensitive]
        ) else {
            return Text(text).font(baseFont).foregroundStyle(.secondary)
        }

        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            .sorted { $0.range.location < $1.range.location }
        guard !matches.isEmpty else {
            return Text(text).font(baseFont).foregroundStyle(.secondary)
        }

        var result = Text("")
        var cursor = 0

        for match in matches {
            let range = match.range
            if range.location < cursor { continue }

            if range.location > cursor {
                let prefix = nsText.substring(with: NSRange(location: cursor, length: range.location - cursor))
                result = result + Text(prefix).font(baseFont).foregroundStyle(.secondary)
            }

            let value = nsText.substring(with: range)
            result = result + Text(value).font(baseFont.weight(.semibold)).foregroundStyle(accent)
            cursor = range.location + range.length
        }

        if cursor < nsText.length {
            let suffix = nsText.substring(from: cursor)
            result = result + Text(suffix).font(baseFont).foregroundStyle(.secondary)
        }

        return result
    }
}

// MARK: - Setup (first launch)

private struct SetupView: View {
    @ObservedObject var service: UsageService
    @ObservedObject var notificationService: NotificationService
    var onComplete: () -> Void
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    var body: some View {
        Text(localizedString("setup.welcome", fallback: "Welcome", language: appLanguage))
            .font(.headline)
        Text(localizedString("setup.configure", fallback: "Configure your preferences to get started.", language: appLanguage))
            .font(.subheadline)
            .foregroundStyle(.secondary)

        Divider()

        LaunchAtLoginToggle(controlSize: .small, useSwitchStyle: true)

        Divider()

        VStack(alignment: .leading, spacing: 8) {
            Text(localizedString("setup.notifications", fallback: "Notifications", language: appLanguage))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SetupThresholdSlider(
                label: localizedString("window.5hour", fallback: "5-hour window", language: appLanguage),
                value: notificationService.threshold5h,
                onChange: { notificationService.setThreshold5h($0) }
            )
            SetupThresholdSlider(
                label: localizedString("window.7day", fallback: "7-day window", language: appLanguage),
                value: notificationService.threshold7d,
                onChange: { notificationService.setThreshold7d($0) }
            )
            SetupThresholdSlider(
                label: localizedString("window.extra", fallback: "Extra usage", language: appLanguage),
                value: notificationService.thresholdExtra,
                onChange: { notificationService.setThresholdExtra($0) }
            )
        }

        Divider()

        VStack(alignment: .leading, spacing: 6) {
            Text(localizedString("setup.polling_interval", fallback: "Polling Interval", language: appLanguage))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("", selection: Binding(
                get: { service.pollingMinutes },
                set: { service.updatePollingInterval($0) }
            )) {
                ForEach(UsageService.pollingOptions, id: \.self) { mins in
                    Text(localizedPollingInterval(for: mins, locale: appLanguage.locale))
                        .tag(mins)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            if isDiscouragedPollingOption(service.pollingMinutes) {
                Text(localizedString("setup.frequent_polling_warning", fallback: "Frequent polling may cause rate limiting", language: appLanguage))
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }

        Divider()

        Button(localizedString("button.get_started", fallback: "Get Started", language: appLanguage)) {
            onComplete()
        }
        .buttonStyle(.borderedProminent)
        .frame(maxWidth: .infinity)

        HStack {
            Spacer()
            Button(localizedString("button.quit", fallback: "Quit", language: appLanguage)) { NSApplication.shared.terminate(nil) }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Subviews

private struct CodeEntryView: View {
    @ObservedObject var service: UsageService
    @State private var code = ""
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    var body: some View {
        Text(localizedString("code_entry.prompt", fallback: "Paste the code from your browser:", language: appLanguage))
            .font(.subheadline)
            .foregroundStyle(.secondary)

        HStack(spacing: 4) {
            TextField(localizedString("code_entry.placeholder", fallback: "code#state", language: appLanguage), text: $code)
                .textFieldStyle(.roundedBorder)
                .font(.system(.body, design: .monospaced))
                .onSubmit { submit() }
            Button {
                if let str = NSPasteboard.general.string(forType: .string) {
                    code = str.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            } label: {
                Image(systemName: "doc.on.clipboard")
            }
            .buttonStyle(.borderless)
        }

        HStack {
            Button(localizedString("button.cancel", fallback: "Cancel", language: appLanguage)) {
                service.isAwaitingCode = false
            }
            .buttonStyle(.borderless)
            Spacer()
            Button(localizedString("button.submit", fallback: "Submit", language: appLanguage)) { submit() }
                .buttonStyle(.borderedProminent)
                .disabled(code.isEmpty)
        }
    }

    private func submit() {
        let value = code
        Task { await service.submitOAuthCode(value) }
    }
}

private struct UsageBucketRow: View {
    let label: String
    let bucket: UsageBucket?
    var windowDuration: TimeInterval? = nil
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    private var timeElapsedFraction: Double? {
        guard let windowDuration else { return nil }
        return windowElapsedFraction(resetDate: bucket?.resetsAtDate, windowDuration: windowDuration)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(percentageText)
                    .font(.subheadline)
                    .monospacedDigit()
            }
            ProgressView(value: (bucket?.utilization ?? 0) / 100.0, total: 1.0)
                .tint(colorForPct((bucket?.utilization ?? 0) / 100.0))
                .padding(.top, timeElapsedFraction == nil ? 0 : 8)
                .overlay {
                    if let fraction = timeElapsedFraction {
                        GeometryReader { geo in
                            VStack(spacing: 0) {
                                Image(systemName: "arrowtriangle.down.fill")
                                    .font(.system(size: 7, weight: .bold))
                                RoundedRectangle(cornerRadius: 1)
                                    .frame(width: 2, height: 9)
                            }
                            .foregroundStyle(Color.primary.opacity(0.8))
                            .position(
                                x: min(max(geo.size.width * fraction, 4), geo.size.width - 4),
                                // marker is 16pt tall; anchor its bottom to the bar's bottom edge
                                y: geo.size.height - 8
                            )
                        }
                        .help(
                            localizedFormat(
                                "usage.window_elapsed",
                                fallback: "Time elapsed in this window: %d%%",
                                language: appLanguage,
                                Int(round(fraction * 100))
                            )
                        )
                    }
                }
            if let resetDate = bucket?.resetsAtDate {
                Text(
                    localizedFormat(
                        "usage.resets",
                        fallback: "Resets %@",
                        language: appLanguage,
                        resetDate.formatted(
                            .relative(presentation: .named)
                                .locale(appLanguage.locale)
                        )
                    )
                )
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var percentageText: String {
        guard let pct = bucket?.utilization else { return "—" }
        return "\(Int(round(pct)))%"
    }
}

private struct BurnRateRow: View {
    let burnRate: BurnRateSnapshot
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    private var tint: Color {
        switch burnRate.multiplier {
        case ..<1.0: return .green
        case 1.0..<2.0: return .yellow
        default: return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(localizedString("usage.burn_rate", fallback: "Burn rate", language: appLanguage))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(
                    localizedFormat(
                        "usage.burn_rate.value",
                        fallback: "%.1f× (%d%%/hr)",
                        language: appLanguage,
                        burnRate.multiplier,
                        Int(round(burnRate.pctPerHour))
                    )
                )
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(tint)
            }
            Text(localizedString(
                "usage.burn_rate.baseline",
                fallback: "1× = even pace for the 5-hour window (20%/hr)",
                language: appLanguage
            ))
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

private struct CodexSection: View {
    let usage: CodexUsage
    let localStats: CodexLocalStats?
    let isStale: Bool
    let language: AppLanguage

    private static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private func bucket(for window: CodexUsage.Window) -> UsageBucket {
        UsageBucket(
            utilization: window.usedPercent,
            resetsAt: window.resetAt.map { Self.isoFormatter.string(from: $0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("Codex")
                    .font(.subheadline)
                if let plan = usage.displayPlan {
                    Text(plan)
                        .font(.caption2)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
                Spacer()
                if isStale {
                    Text(localizedString("codex.stale", fallback: "Offline snapshot", language: language))
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }

            ForEach(usage.windows, id: \.label) { entry in
                UsageBucketRow(
                    label: localizedFormat(
                        "codex.window",
                        fallback: "%@ window",
                        language: language,
                        entry.label
                    ),
                    bucket: bucket(for: entry.window),
                    windowDuration: entry.window.windowSeconds
                )
            }

            ForEach(usage.scoped, id: \.name) { scoped in
                UsageBucketRow(
                    label: scoped.name,
                    bucket: bucket(for: scoped.window),
                    windowDuration: scoped.window.windowSeconds
                )
            }

            if usage.hasCredits, let balance = usage.creditsBalance {
                Text(localizedFormat(
                    "codex.credits",
                    fallback: "Credits balance: %@",
                    language: language,
                    balance
                ))
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if let stats = localStats {
                Divider()
                Text(localizedFormat(
                    "codex.local_stats",
                    fallback: "Last %d days on this Mac · %@ tokens",
                    language: language,
                    stats.windowDays,
                    formatTokenCount(stats.totalTokens)
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)

                CodexStatGroup(
                    title: localizedString("attribution.by_model", fallback: "By model", language: language),
                    entries: stats.models
                )
                CodexStatGroup(
                    title: localizedString("attribution.by_project", fallback: "By project", language: language),
                    entries: stats.projects
                )
                if !stats.efforts.isEmpty {
                    CodexStatGroup(
                        title: localizedString("codex.by_effort", fallback: "By reasoning effort", language: language),
                        entries: stats.efforts
                    )
                }
                if stats.daily.contains(where: { $0.tokens > 0 }) {
                    CodexDailyTrend(entries: stats.daily, language: language)
                }
            }
        }
    }
}

private struct CodexDailyTrend: View {
    let entries: [CodexDailyEntry]
    let language: AppLanguage

    private var peak: Int { max(entries.map(\.tokens).max() ?? 1, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localizedString("codex.daily_trend", fallback: "Daily trend", language: language))
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(alignment: .bottom, spacing: 4) {
                ForEach(entries) { entry in
                    VStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(entry.tokens == peak ? Color.teal : Color.teal.opacity(0.45))
                            .frame(height: max(3, 36 * CGFloat(entry.tokens) / CGFloat(peak)))
                        Text(entry.day, format: Date.FormatStyle().weekday(.narrow).locale(language.locale))
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .help("\(entry.day.formatted(date: .abbreviated, time: .omitted)) · \(formatTokenCount(entry.tokens))")
                }
            }
            .frame(height: 48, alignment: .bottom)
        }
    }
}

private struct CodexStatGroup: View {
    let title: String
    let entries: [CodexStatEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(entries) { entry in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(entry.key)
                            .font(.caption)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text("\(Int(round(entry.share * 100)))% · \(formatTokenCount(entry.tokens))")
                            .font(.caption2)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: entry.share, total: 1.0)
                        .tint(.teal)
                }
            }
        }
    }
}

private struct ExtraUsageRow: View {
    let extra: ExtraUsage
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(localizedString("usage.extra", fallback: "Extra Usage", language: appLanguage))
                .font(.subheadline)
            if let used = extra.usedCreditsAmount, let limit = extra.monthlyLimitAmount {
                HStack {
                    Text("\(ExtraUsage.formatUSD(used)) / \(ExtraUsage.formatUSD(limit))")
                        .font(.caption)
                        .monospacedDigit()
                    Spacer()
                    if let pct = extra.utilization {
                        Text("\(Int(round(pct)))%")
                            .font(.caption)
                            .monospacedDigit()
                    }
                }
                ProgressView(value: (extra.utilization ?? 0) / 100.0, total: 1.0)
                    .tint(.blue)
            }
        }
    }
}

private struct SetupThresholdSlider: View {
    let label: String
    let value: Int
    let onChange: (Int) -> Void
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.callout)
                Spacer()
                Text(value > 0 ? "\(value)%" : localizedString("value.off", fallback: "Off", language: appLanguage))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { onChange(Int($0)) }
                ),
                in: 0...100,
                step: 5
            )
            .controlSize(.small)
        }
    }
}

private func colorForPct(_ pct: Double) -> Color {
    switch pct {
    case ..<0.60: return .green
    case 0.60..<0.80: return .yellow
    default: return .red
    }
}
