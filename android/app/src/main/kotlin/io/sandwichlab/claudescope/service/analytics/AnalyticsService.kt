package io.sandwichlab.claudescope.service.analytics

import android.app.Application
import android.util.Log
import com.appsflyer.AFInAppEventParameterName
import com.appsflyer.AFInAppEventType
import com.appsflyer.AppsFlyerLib
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import io.sandwichlab.claudescope.BuildConfig
import kotlin.math.roundToInt

/**
 * Centralised analytics tracking for AppsFlyer + Facebook SDK events.
 *
 * Event surface is a direct port of iOS [AnalyticsService.swift] — same names,
 * same param keys, same value formats — so the two platforms roll up into the
 * same AppsFlyer project without munging.
 *
 * Usage:
 * ```
 *   // Once, from Application.onCreate:
 *   AnalyticsService.configure(this)
 *   AnalyticsService.start(this)
 *
 *   // Anywhere:
 *   AnalyticsService.trackTabSelected("home")
 * ```
 */
object AnalyticsService {

    private const val TAG = "AnalyticsService"
    private const val DEV_KEY = BuildConfig.APPSFLYER_DEV_KEY

    @Volatile private var configured = false

    /** Initialise SDKs. Safe to call multiple times — subsequent calls no-op. */
    fun configure(application: Application) {
        if (configured) return
        configured = true

        runCatching {
            AppsFlyerLib.getInstance().apply {
                setDebugLog(BuildConfig.DEBUG)
                init(DEV_KEY, null, application)
            }
        }.onFailure { Log.w(TAG, "AppsFlyer init failed", it) }

        runCatching {
            FacebookSdk.sdkInitialize(application)
            AppEventsLogger.activateApp(application)
        }.onFailure { Log.w(TAG, "Facebook SDK init failed", it) }
    }

    /** Start AppsFlyer session. Call when the app becomes interactive. */
    fun start(application: Application) {
        runCatching {
            AppsFlyerLib.getInstance().start(application)
        }.onFailure { Log.w(TAG, "AppsFlyer start failed", it) }
    }

    // MARK: - Auth events

    fun trackLogin(method: String = "oauth") = logEvent(
        AFInAppEventType.LOGIN,
        mapOf(AFInAppEventParameterName.REGISTRATION_METHOD to method),
    )

    fun trackSignOut() = logEvent("sign_out", emptyMap())

    // MARK: - Usage events

    fun trackUsageFetched(pct5h: Double, pct7d: Double) = logEvent(
        "usage_fetched",
        mapOf(
            "pct_5h" to (pct5h * 100).roundToInt(),
            "pct_7d" to (pct7d * 100).roundToInt(),
        ),
    )

    fun trackThresholdAlert(window: String, pct: Int) = logEvent(
        "threshold_alert",
        mapOf("window" to window, "pct" to pct),
    )

    // MARK: - Navigation events

    fun trackTabSelected(tab: String) = logEvent("tab_selected", mapOf("tab" to tab))

    fun trackLanguageChanged(language: String) =
        logEvent("language_changed", mapOf("language" to language))

    fun trackPollingIntervalChanged(minutes: Int) =
        logEvent("polling_interval_changed", mapOf("minutes" to minutes))

    // MARK: - Widget events

    fun trackWidgetConfigured(size: String) =
        logEvent("widget_configured", mapOf("size" to size))

    // MARK: - Internal

    private fun logEvent(event: String, params: Map<String, Any>) {
        if (!configured) return
        runCatching {
            AppsFlyerLib.getInstance().logEvent(null, event, params)
        }.onFailure { Log.w(TAG, "AppsFlyer logEvent '$event' failed", it) }
    }
}
