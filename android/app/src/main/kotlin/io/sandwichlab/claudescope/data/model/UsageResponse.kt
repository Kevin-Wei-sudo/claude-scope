package io.sandwichlab.claudescope.data.model

import java.time.Instant
import java.time.OffsetDateTime
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException

data class UsageResponse(
    val fiveHour: UsageBucket?,
    val sevenDay: UsageBucket?,
    val sevenDayOpus: UsageBucket?,
    val sevenDaySonnet: UsageBucket?,
    val extraUsage: ExtraUsage?,
) {
    val pct5h: Double get() = (fiveHour?.utilization ?: 0.0) / 100.0
    val pct7d: Double get() = (sevenDay?.utilization ?: 0.0) / 100.0
    val sonnetPct: Double get() = (sevenDaySonnet?.utilization ?: 0.0) / 100.0
    val opusPct: Double get() = (sevenDayOpus?.utilization ?: 0.0) / 100.0
}

data class UsageBucket(
    val utilization: Double?,
    val resetsAt: String?,
) {
    val resetsAtInstant: Instant? get() = parseResetDate(resetsAt)

    companion object {
        private val FALLBACK_PATTERNS = listOf(
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
        ).map { DateTimeFormatter.ofPattern(it) }

        fun parseResetDate(raw: String?): Instant? {
            if (raw.isNullOrEmpty()) return null
            runCatching { return OffsetDateTime.parse(raw).toInstant() }
            runCatching { return Instant.parse(raw) }
            for (formatter in FALLBACK_PATTERNS) {
                try {
                    return java.time.LocalDateTime.parse(raw, formatter)
                        .toInstant(java.time.ZoneOffset.UTC)
                } catch (_: DateTimeParseException) {
                    // try next
                }
            }
            return null
        }
    }
}

data class ExtraUsage(
    val isEnabled: Boolean,
    val utilization: Double?,
    val usedCredits: Double?,
    val monthlyLimit: Double?,
) {
    val usedCreditsAmount: Double? get() = usedCredits?.let { it / 100.0 }
    val monthlyLimitAmount: Double? get() = monthlyLimit?.let { it / 100.0 }
}
