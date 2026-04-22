package io.sandwichlab.claudescope.service.notifications

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.content.getSystemService

object NotificationChannels {
    const val USAGE_ALERTS_ID = "usage_alerts"
    const val RESET_REMINDERS_ID = "reset_reminders"

    fun ensureCreated(context: Context) {
        val nm = context.getSystemService<NotificationManager>() ?: return
        nm.createNotificationChannel(
            NotificationChannel(
                USAGE_ALERTS_ID,
                "Usage threshold alerts",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Fires when 5-hour or 7-day usage crosses your threshold."
            },
        )
        nm.createNotificationChannel(
            NotificationChannel(
                RESET_REMINDERS_ID,
                "Reset reminders",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Heads-up when a usage window is about to reset."
            },
        )
    }
}
