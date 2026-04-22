package io.sandwichlab.claudescope.service.notifications

/**
 * Pure-function port of iOS NotificationService.checkAndNotify logic.
 * Returns the list of windows that crossed the threshold upward on this tick.
 */
object ThresholdChecker {

    data class Crossing(val window: UsageWindow, val pctInt: Int)

    enum class UsageWindow { FiveHour, SevenDay }

    fun check(
        thresholdPct: Int,
        previousPct5h: Double?,
        currentPct5h: Double,
        previousPct7d: Double?,
        currentPct7d: Double,
    ): List<Crossing> {
        val results = mutableListOf<Crossing>()
        if (crossed(thresholdPct, previousPct5h, currentPct5h)) {
            results += Crossing(UsageWindow.FiveHour, (currentPct5h * 100).toInt())
        }
        if (crossed(thresholdPct, previousPct7d, currentPct7d)) {
            results += Crossing(UsageWindow.SevenDay, (currentPct7d * 100).toInt())
        }
        return results
    }

    private fun crossed(thresholdPct: Int, previous: Double?, current: Double): Boolean {
        val threshold = thresholdPct / 100.0
        val before = previous ?: 0.0
        return before < threshold && current >= threshold
    }
}
