package io.sandwichlab.claudescope.ui.history

import io.sandwichlab.claudescope.data.model.UsageDataPoint

/**
 * Matches iOS `HistoryDemoData` in HistoryView.swift so the signed-out UI
 * looks identical across platforms.
 */
object HistoryDemoData {

    const val SONNET_PCT: Double = 0.61
    const val OPUS_PCT: Double = 0.24

    private val TREND_VALUES = listOf(0.25, 0.32, 0.45, 0.38, 0.52, 0.68, 0.42)

    fun trendPoints(nowEpochMs: Long = System.currentTimeMillis()): List<UsageDataPoint> =
        TREND_VALUES.mapIndexed { index, v ->
            UsageDataPoint(
                timestampEpochMs = nowEpochMs + (index - 6) * 86_400_000L,
                pct5h = v * 0.5,
                pct7d = v,
            )
        }

    fun snapshots(nowEpochMs: Long = System.currentTimeMillis()): List<UsageDataPoint> =
        listOf(
            UsageDataPoint(timestampEpochMs = nowEpochMs - 30L * 60 * 1000, pct5h = 0.18, pct7d = 0.42),
            UsageDataPoint(timestampEpochMs = nowEpochMs - 14L * 60 * 60 * 1000, pct5h = 0.25, pct7d = 0.37),
            UsageDataPoint(timestampEpochMs = nowEpochMs - 26L * 60 * 60 * 1000, pct5h = 0.12, pct7d = 0.31),
        )
}
