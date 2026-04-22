import Foundation
#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif

/// Centralized analytics tracking for AppsFlyer events.
@MainActor
final class AnalyticsService {
    static let shared = AnalyticsService()

    // MARK: - Configuration

    /// Call once at app launch to initialize AppsFlyer SDK.
    func configure() {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().appsFlyerDevKey = "F8FrZFW2PUgiJG3bXT9Y2E"
        AppsFlyerLib.shared().appleAppID = "6761888911"
        // Wait up to 60s for ATT prompt resolution before firing the install event.
        // iOS 14.5+ hides IDFA until the user answers ATT; without this delay the
        // install attribution would miss IDFA on first launch.
        AppsFlyerLib.shared().waitForATTUserAuthorization(timeoutInterval: 60)
        #if DEBUG
        AppsFlyerLib.shared().isDebug = true
        #else
        AppsFlyerLib.shared().isDebug = false
        #endif
        #endif
    }

    /// Call when app becomes active (triggers AppsFlyer session).
    func start() {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().start()
        #endif
    }

    // MARK: - Auth Events

    func trackLogin(method: String = "oauth") {
        #if canImport(AppsFlyerLib)
        // Fire both events: AFEventLogin marks the interactive sign-in action;
        // AFEventCompleteRegistration marks the first successful auth handshake
        // (Meta and AppsFlyer use CompleteRegistration for ad attribution ROAS).
        AppsFlyerLib.shared().logEvent(AFEventLogin, withValues: [
            AFEventParamRegistrationMethod: method,
        ])
        AppsFlyerLib.shared().logEvent(AFEventCompleteRegistration, withValues: [
            AFEventParamRegistrationMethod: "claude_oauth",
        ])
        #endif
    }

    func trackSignOut() {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().logEvent("sign_out", withValues: [:])
        #endif
    }

    // MARK: - Usage Events

    func trackUsageFetched(pct5h: Double, pct7d: Double) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().logEvent("usage_fetched", withValues: [
            "pct_5h": Int(round(pct5h * 100)),
            "pct_7d": Int(round(pct7d * 100))
        ])
        #endif
    }

    func trackThresholdAlert(window: String, pct: Int) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().logEvent("threshold_alert", withValues: [
            "window": window,
            "pct": pct
        ])
        #endif
    }

    // MARK: - Navigation Events

    func trackTabSelected(_ tab: String) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().logEvent("tab_selected", withValues: [
            "tab": tab
        ])
        #endif
    }

    func trackLanguageChanged(_ language: String) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().logEvent("language_changed", withValues: [
            "language": language
        ])
        #endif
    }

    func trackPollingIntervalChanged(_ minutes: Int) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().logEvent("polling_interval_changed", withValues: [
            "minutes": minutes
        ])
        #endif
    }

    // MARK: - Widget Events

    func trackWidgetConfigured(size: String) {
        #if canImport(AppsFlyerLib)
        AppsFlyerLib.shared().logEvent("widget_configured", withValues: [
            "size": size
        ])
        #endif
    }
}
