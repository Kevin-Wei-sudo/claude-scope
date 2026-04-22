package io.sandwichlab.claudescope.data.model

import kotlinx.serialization.Serializable
import java.util.UUID

@Serializable
data class UsageDataPoint(
    val id: String = UUID.randomUUID().toString(),
    val timestampEpochMs: Long,
    val pct5h: Double,
    val pct7d: Double,
)

@Serializable
data class UsageHistorySnapshot(
    val version: Int = 1,
    val dataPoints: List<UsageDataPoint> = emptyList(),
)
