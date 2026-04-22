import Foundation
#if canImport(AppTrackingTransparency)
import AppTrackingTransparency
#endif

/// Asks the user for ATT permission, then starts AppsFlyer. Should fire from
/// the first interactive surface (HomeView.onAppear) — Apple requires the
/// request to come from an already-visible UI context.
///
/// AppsFlyer's `waitForATTUserAuthorization(timeoutInterval:)` (set in
/// `AnalyticsService.configure`) holds the install event until this resolves,
/// so the IDFA is included on day-0 attribution.
@MainActor
enum TrackingAuthorization {

    /// Idempotent — safe to call from every `onAppear`.
    static func requestIfNeededAndStart() {
        #if canImport(AppTrackingTransparency)
        if #available(iOS 14.5, *) {
            let status = ATTrackingManager.trackingAuthorizationStatus
            if status != .notDetermined {
                AnalyticsService.shared.start()
                return
            }
            ATTrackingManager.requestTrackingAuthorization { _ in
                Task { @MainActor in
                    AnalyticsService.shared.start()
                }
            }
            return
        }
        #endif
        // iOS < 14.5: no ATT, start immediately.
        AnalyticsService.shared.start()
    }
}
