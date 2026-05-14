import UIKit
#if canImport(AppsFlyerLib)
import AppsFlyerLib
#endif
#if canImport(FBSDKCoreKit)
import FBSDKCoreKit
#endif

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // AppsFlyer
        AnalyticsService.shared.configure()

        // Facebook SDK
        #if canImport(FBSDKCoreKit)
        // Must come BEFORE ApplicationDelegate.shared.application(...) so the
        // SDK reads these values during its own initialization.
        Settings.shared.appID = "2435202536976265"
        Settings.shared.clientToken = "0d79d61ad91ec640cf3222d4752e9f68"
        // Enabled by default; `ATTrackingManager` still gates the IDFA, so this
        // flag only affects non-IDFA advertiser signals that Meta can still use.
        Settings.shared.isAdvertiserTrackingEnabled = true

        ApplicationDelegate.shared.application(
            application,
            didFinishLaunchingWithOptions: launchOptions
        )
        #endif

        return true
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // AppsFlyer start() is deferred to TrackingAuthorization flow (fired
        // from HomeView.onAppear) so the ATT prompt happens before first
        // attribution event — avoids IDFA loss on day-0.
        // For subsequent foregrounds we still safely re-invoke start().
        TrackingAuthorization.requestIfNeededAndStart()
    }

    func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        #if canImport(FBSDKCoreKit)
        ApplicationDelegate.shared.application(
            app,
            open: url,
            sourceApplication: options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String,
            annotation: options[UIApplication.OpenURLOptionsKey.annotation]
        )
        #endif
        return true
    }
}
