package io.sandwichlab.claudescope.data.model

enum class TimeRange(val label: String, val intervalMs: Long, val targetPointCount: Int) {
    Day7("7D", 7L * 86_400_000L, 7),
    Day30("30D", 30L * 86_400_000L, 30),
    Day90("90D", 90L * 86_400_000L, 90),
}
