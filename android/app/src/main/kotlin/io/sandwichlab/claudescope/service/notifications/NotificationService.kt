package io.sandwichlab.claudescope.service.notifications

import android.Manifest
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.sandwichlab.claudescope.MainActivity
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.service.analytics.AnalyticsService
import io.sandwichlab.claudescope.service.settings.AppSettingsService
import kotlinx.coroutines.flow.first

/**
 * Fires local notifications for usage threshold crossings. Mirrors iOS
 * NotificationService but without the 30-min-before-reset reminder yet.
 */
class NotificationService(
    private val context: Context,
    private val settingsService: AppSettingsService,
) {
    @Volatile private var previousPct5h: Double? = null
    @Volatile private var previousPct7d: Double? = null

    fun onClear() {
        previousPct5h = null
        previousPct7d = null
    }

    suspend fun onUsageFetched(pct5h: Double, pct7d: Double) {
        val settings = settingsService.settings.first()
        if (!settings.notificationsEnabled) {
            previousPct5h = pct5h
            previousPct7d = pct7d
            return
        }
        if (!hasPostNotificationsPermission()) {
            previousPct5h = pct5h
            previousPct7d = pct7d
            return
        }

        NotificationChannels.ensureCreated(context)

        val crossings = ThresholdChecker.check(
            thresholdPct = settings.notificationThreshold,
            previousPct5h = previousPct5h,
            currentPct5h = pct5h,
            previousPct7d = previousPct7d,
            currentPct7d = pct7d,
        )
        crossings.forEach { fireCrossing(it) }

        previousPct5h = pct5h
        previousPct7d = pct7d
    }

    private fun fireCrossing(crossing: ThresholdChecker.Crossing) {
        val windowLabel = when (crossing.window) {
            ThresholdChecker.UsageWindow.FiveHour -> context.getString(R.string.window_5hour)
            ThresholdChecker.UsageWindow.SevenDay -> context.getString(R.string.window_7day)
        }
        val title = context.getString(R.string.notification_title)
        val body = context.getString(R.string.notification_body, windowLabel, crossing.pctInt)

        val launchIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            context,
            crossing.hashCode(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(context, NotificationChannels.USAGE_ALERTS_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pending)
            .build()

        NotificationManagerCompat.from(context)
            .notify(NOTIFICATION_ID_BASE + crossing.window.ordinal, notification)

        val windowTag = when (crossing.window) {
            ThresholdChecker.UsageWindow.FiveHour -> "5h"
            ThresholdChecker.UsageWindow.SevenDay -> "7d"
        }
        AnalyticsService.trackThresholdAlert(window = windowTag, pct = crossing.pctInt)
    }

    private fun hasPostNotificationsPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS,
        ) == PackageManager.PERMISSION_GRANTED
    }

    companion object {
        private const val NOTIFICATION_ID_BASE = 2000
    }
}
