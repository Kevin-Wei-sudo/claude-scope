package io.sandwichlab.claudescope.widget

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import io.sandwichlab.claudescope.data.model.UsageResponse

/**
 * Thin bridge UsageService calls whenever a fetch succeeds. Writes a fresh
 * [WidgetSnapshot] and triggers redraw of any active home-screen widgets.
 */
class WidgetUpdater(
    private val context: Context,
    private val store: WidgetDataStore,
) {

    suspend fun publish(usage: UsageResponse) {
        val snapshot = WidgetSnapshot(
            pct5h = usage.pct5h,
            pct7d = usage.pct7d,
            resetEpochMs = usage.sevenDay?.resetsAtInstant?.toEpochMilli(),
            lastUpdatedEpochMs = System.currentTimeMillis(),
        )
        store.write(snapshot)

        val glanceIds = GlanceAppWidgetManager(context).getGlanceIds(ClaudeUsageWidget::class.java)
        if (glanceIds.isNotEmpty()) {
            ClaudeUsageWidget().updateAll(context)
        }
    }
}
