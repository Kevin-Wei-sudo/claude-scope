package io.sandwichlab.claudescope.ui.home

import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.temporal.TemporalAdjusters

/**
 * Aggregated data that HomeScreen needs in a single struct so it's easy to
 * swap between [demo] and [live] variants without prop-drilling every card.
 */
data class HomeContent(
    val isLive: Boolean,
    val pct5h: Double,
    val pct7d: Double,
    val sonnetPct: Double,
    val reset5h: Instant?,
    val reset7d: Instant?,
    val trend: List<Double>,
)

/**
 * Demo values mirroring iOS `DemoData` in HomeView.swift. Shown to signed-out
 * users so the visual design matches the real UI.
 */
object DemoHomeContent {
    const val PCT_5H: Double = 0.18
    const val PCT_7D: Double = 0.42
    const val SONNET_PCT: Double = 0.34
    val TREND: List<Double> = listOf(0.25, 0.32, 0.38, 0.45, 0.52, 0.68, 0.42)

    fun snapshot(zone: ZoneId = ZoneId.systemDefault()): HomeContent {
        val resetDate = nextTuesdayMidnight(zone)
        val reset5h = resetDate.minusSeconds(2 * 86400L)
        return HomeContent(
            isLive = false,
            pct5h = PCT_5H,
            pct7d = PCT_7D,
            sonnetPct = SONNET_PCT,
            reset5h = reset5h,
            reset7d = resetDate,
            trend = TREND,
        )
    }

    private fun nextTuesdayMidnight(zone: ZoneId): Instant {
        val today = LocalDate.now(zone)
        val nextTuesday = today.with(TemporalAdjusters.next(DayOfWeek.TUESDAY))
        return LocalDateTime.of(nextTuesday, LocalTime.MIDNIGHT).atZone(zone).toInstant()
    }
}
