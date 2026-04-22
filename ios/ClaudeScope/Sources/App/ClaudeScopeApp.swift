import SwiftUI

@main
struct ClaudeScopeApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #endif

    @StateObject private var usageService = UsageService()
    @StateObject private var historyService = UsageHistoryService()
    @StateObject private var notificationService = NotificationService()
    @StateObject private var intelligenceService = UsageIntelligenceService()
    @AppStorage(AppLanguage.storageKey) private var appLanguageRaw = AppLanguage.system.rawValue

    private var appLanguage: AppLanguage { AppLanguage.from(appLanguageRaw) }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(usageService)
                .environmentObject(historyService)
                .environmentObject(notificationService)
                .environmentObject(intelligenceService)
                // Propagate the in-app language toggle to SwiftUI's locale so
                // Text(date, style: .relative / .date / .time) localizes correctly.
                // Without this, those formatters fall back to the device locale
                // and disagree with the rest of the UI (e.g. Chinese labels +
                // English reset times).
                .environment(\.locale, appLanguage.locale)
                .onAppear {
                    historyService.loadHistory()
                    usageService.historyService = historyService
                    usageService.notificationService = notificationService
                    usageService.intelligenceService = intelligenceService
                    usageService.startPolling()
                }
        }
    }
}
