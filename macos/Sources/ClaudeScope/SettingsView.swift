import SwiftUI
import ServiceManagement

struct SettingsWindowContent: View {
    @ObservedObject var service: UsageService
    @ObservedObject var notificationService: NotificationService
    @ObservedObject var intelligenceService: UsageIntelligenceService
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    var body: some View {
        Form {
            Section(localizedString("settings.general", fallback: "General", language: appLanguage)) {
                LaunchAtLoginToggle()

                Picker(localizedString("settings.language", fallback: "Language", language: appLanguage), selection: $appLanguageRaw) {
                    Text(localizedString("language.follow_system", fallback: "Follow System", language: appLanguage)).tag(AppLanguage.system.rawValue)
                    Text(localizedString("language.english", fallback: "English", language: appLanguage)).tag(AppLanguage.english.rawValue)
                    Text(localizedString("language.simplified_chinese", fallback: "Simplified Chinese", language: appLanguage)).tag(AppLanguage.simplifiedChinese.rawValue)
                }

                Picker(localizedString("settings.polling_interval", fallback: "Polling Interval", language: appLanguage), selection: Binding(
                    get: { service.pollingMinutes },
                    set: { service.updatePollingInterval($0) }
                )) {
                    ForEach(UsageService.pollingOptions, id: \.self) { mins in
                        Text(pollingOptionLabel(for: mins, locale: appLanguage.locale))
                            .tag(mins)
                    }
                }
            }

            Section(localizedString("settings.notifications", fallback: "Notifications", language: appLanguage)) {
                Toggle(
                    localizedString("settings.reset_reminders", fallback: "Reset reminders", language: appLanguage),
                    isOn: Binding(
                        get: { notificationService.resetRemindersEnabled },
                        set: { notificationService.setResetRemindersEnabled($0) }
                    )
                )

                ThresholdSlider(
                    label: localizedString("window.5hour", fallback: "5-hour window", language: appLanguage),
                    value: notificationService.threshold5h,
                    onChange: { notificationService.setThreshold5h($0) }
                )
                ThresholdSlider(
                    label: localizedString("window.7day", fallback: "7-day window", language: appLanguage),
                    value: notificationService.threshold7d,
                    onChange: { notificationService.setThreshold7d($0) }
                )
                ThresholdSlider(
                    label: localizedString("window.extra", fallback: "Extra usage", language: appLanguage),
                    value: notificationService.thresholdExtra,
                    onChange: { notificationService.setThresholdExtra($0) }
                )
            }

            Section(localizedString("settings.usage_intelligence", fallback: "Usage Intelligence", language: appLanguage)) {
                Toggle(
                    localizedString("settings.predictions", fallback: "Predictions", language: appLanguage),
                    isOn: $intelligenceService.predictionEnabled
                )
                Toggle(
                    localizedString("settings.usage_intelligence_enabled", fallback: "Usage intelligence", language: appLanguage),
                    isOn: $intelligenceService.intelligenceEnabled
                )
            }

            if service.isAuthenticated {
                Section(localizedString("settings.account", fallback: "Account", language: appLanguage)) {
                    if let email = service.accountEmail {
                        Text(email)
                    }
                    Button(localizedString("settings.sign_out", fallback: "Sign Out", language: appLanguage)) {
                        service.signOut()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            focusSettingsWindow()
        }
    }
}

@MainActor
private func focusSettingsWindow() {
    DispatchQueue.main.async {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.last(where: { $0.isVisible && $0.canBecomeKey }) {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
    }
}

struct LaunchAtLoginToggle: View {
    @StateObject private var model: LaunchAtLoginModel
    private let controlSize: ControlSize
    private let useSwitchStyle: Bool
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    init(
        controlSize: ControlSize = .regular,
        useSwitchStyle: Bool = false,
        bundleURL: URL = Bundle.main.bundleURL
    ) {
        _model = StateObject(
            wrappedValue: LaunchAtLoginModel(bundleURL: bundleURL)
        )
        self.controlSize = controlSize
        self.useSwitchStyle = useSwitchStyle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            toggle

            if let message = model.message {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var toggle: some View {
        let baseToggle = Toggle(localizedString("launch_at_login", fallback: "Launch at Login", language: appLanguage), isOn: Binding(
            get: { model.isEnabled },
            set: { model.setEnabled($0) }
        ))
        .disabled(!model.isSupported)
        .controlSize(controlSize)

        if useSwitchStyle {
            baseToggle.toggleStyle(.switch)
        } else {
            baseToggle
        }
    }
}

@MainActor
final class LaunchAtLoginModel: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var isSupported: Bool
    @Published private(set) var message: String?

    init(bundleURL: URL = Bundle.main.bundleURL) {
        isSupported = supportsLaunchAtLoginManagement(appURL: bundleURL)

        guard isSupported else {
            message = localizedString(
                "launch_at_login.install_required",
                fallback: "Install the app in Applications to manage launch at login."
            )
            return
        }

        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        guard isSupported else { return }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = enabled
            message = nil
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
            message = localizedString(
                "launch_at_login.update_failed",
                fallback: "Could not update launch at login."
            )
        }
    }
}

func supportsLaunchAtLoginManagement(
    appURL: URL = Bundle.main.bundleURL,
    installDirectories: [URL] = launchAtLoginInstallDirectories()
) -> Bool {
    let normalizedAppURL = appURL.resolvingSymlinksInPath().standardizedFileURL

    return installDirectories.contains { directory in
        let normalizedDirectory = directory.resolvingSymlinksInPath().standardizedFileURL
        let directoryPath = normalizedDirectory.path
        let appPath = normalizedAppURL.path

        return appPath == directoryPath || appPath.hasPrefix(directoryPath + "/")
    }
}

func launchAtLoginInstallDirectories(fileManager: FileManager = .default) -> [URL] {
    [
        URL(fileURLWithPath: "/Applications", isDirectory: true),
        fileManager.homeDirectoryForCurrentUser.appending(path: "Applications", directoryHint: .isDirectory)
    ]
}

private struct ThresholdSlider: View {
    let label: String
    let value: Int
    let onChange: (Int) -> Void
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    var body: some View {
        LabeledContent {
            Slider(
                value: Binding(
                    get: { Double(value) },
                    set: { onChange(Int($0)) }
                ),
                in: 0...100,
                step: 5
            )
        } label: {
            Text(label)
            Text(value > 0 ? "\(value)%" : localizedString("value.off", fallback: "Off", language: appLanguage))
                .foregroundStyle(.secondary)
        }
        .alignmentGuide(.firstTextBaseline) { d in
            d[VerticalAlignment.center]
        }
    }
}
