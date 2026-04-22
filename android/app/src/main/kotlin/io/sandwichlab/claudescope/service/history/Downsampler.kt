package io.sandwichlab.claudescope.service.history

import io.sandwichlab.claudescope.data.model.TimeRange
import io.sandwichlab.claudescope.data.model.UsageDataPoint

/**
 * Bucket-averages points into `range.targetPointCount` slots over `range.intervalMs`.
 * Port of iOS `UsageHistoryService.downsampledPoints(for:)`.
 *
 * - Returns input unchanged when there are fewer points than the target.
 * - Drops empty buckets (iOS behavior via `compactMap`).
 * - Per bucket, averages pct5h, pct7d, and timestamp.
 */
object Downsampler {

    fun downsample(
        allPoints: List<UsageDataPoint>,
        range: TimeRange,
        nowEpochMs: Long = System.currentTimeMillis(),
    ): List<UsageDataPoint> {
        if (allPoints.size <= range.targetPointCount) return allPoints

        val rangeStart = nowEpochMs - range.intervalMs
        val bucketCount = range.targetPointCount
        val bucketDuration = range.intervalMs.toDouble() / bucketCount

        val buckets = Array(bucketCount) { mutableListOf<UsageDataPoint>() }
        for (point in allPoints) {
            val offset = (point.timestampEpochMs - rangeStart).toDouble()
            val rawIndex = (offset / bucketDuration).toInt()
            val index = rawIndex.coerceIn(0, bucketCount - 1)
            buckets[index].add(point)
        }

        return buckets.mapNotNull { bucket ->
            if (bucket.isEmpty()) return@mapNotNull null
            val avgPct5h = bucket.sumOf { it.pct5h } / bucket.size
            val avgPct7d = bucket.sumOf { it.pct7d } / bucket.size
            val avgTs = bucket.sumOf { it.timestampEpochMs } / bucket.size
            UsageDataPoint(
                timestampEpochMs = avgTs,
                pct5h = avgPct5h,
                pct7d = avgPct7d,
            )
        }
    }
}
