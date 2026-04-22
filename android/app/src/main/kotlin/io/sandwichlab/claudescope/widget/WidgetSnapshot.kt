package io.sandwichlab.claudescope.widget

import kotlinx.serialization.Serializable

@Serializable
data class WidgetSnapshot(
    val pct5h: Double,
    val pct7d: Double,
    val resetEpochMs: Long?,
    val lastUpdatedEpochMs: Long,
) {
    companion object {
        val Placeholder = WidgetSnapshot(
            pct5h = 0.18,
            pct7d = 0.42,
            resetEpochMs = null,
            lastUpdatedEpochMs = 0L,
        )
    }
}
