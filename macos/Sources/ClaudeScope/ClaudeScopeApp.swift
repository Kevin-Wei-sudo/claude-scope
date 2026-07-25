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
    @StateObject private var announcementService = AnnouncementService()
    @StateObject private var attributionService = AttributionService()
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
                announcementService: announcementService,
                attributionService: attributionService,
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
                    service.historyService = historyService
                    service.restoreAccountScope()
                    service.notificationService = notificationService
                    service.intelligenceService = intelligenceService
                    intelligenceService.refresh(usage: service.usage, history: historyService.history)
                    service.startPolling()
                    announcementService.start()
                }
        }
        .menuBarExtraStyle(.window)

        Window(
            localizedString("attribution.title", fallback: "Usage Attribution", language: appLanguage),
            id: AttributionWindow.id
        ) {
            AttributionView(service: attributionService)
                .environment(\.locale, appLanguage.locale)
        }
        .windowResizability(.contentSize)

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
