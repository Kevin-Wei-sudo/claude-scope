import SwiftUI

@main
struct ClaudeScopeApp: App {
    // Must run before @StateObject autoclosures are evaluated so services read
    // migrated values instead of empty defaults.
    init() {
        UserDefaultsMigration.runIfNeeded()
    }

    @StateObject private var service = UsageService()
    @StateObject private var historyService = UsageHistoryService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var intelligenceService = UsageIntelligenceService()
    @StateObject private var appUpdater = AppUpdater()
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage {
        AppLanguage.from(appLanguageRaw)
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView(
                service: service,
                historyService: historyService,
                notificationService: notificationService,
                intelligenceService: intelligenceService,
                appUpdater: appUpdater
            )
            .environment(\.locale, appLanguage.locale)
        } label: {
            Image(nsImage: service.isAuthenticated
                ? renderIcon(pct5h: service.pct5h, pct7d: service.pct7d)
                : renderUnauthenticatedIcon()
            )
                .task {
                    // Auto-mark existing users as setup-complete
                    if service.isAuthenticated && !UserDefaults.standard.bool(forKey: "setupComplete") {
                        UserDefaults.standard.set(true, forKey: "setupComplete")
                    }
                    historyService.loadHistory()
                    service.historyService = historyService
                    service.notificationService = notificationService
                    service.intelligenceService = intelligenceService
                    intelligenceService.refresh(usage: service.usage, history: historyService.history)
                    service.startPolling()
                }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsWindowContent(
                service: service,
                notificationService: notificationService,
                intelligenceService: intelligenceService
            )
            .environment(\.locale, appLanguage.locale)
        }
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
    }
}
