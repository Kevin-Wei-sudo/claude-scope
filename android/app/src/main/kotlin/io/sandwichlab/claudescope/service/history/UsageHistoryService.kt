package io.sandwichlab.claudescope.service.history

import io.sandwichlab.claudescope.data.local.UsageHistoryStore
import io.sandwichlab.claudescope.data.model.TimeRange
import io.sandwichlab.claudescope.data.model.UsageDataPoint
import io.sandwichlab.claudescope.data.model.UsageHistorySnapshot
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class UsageHistoryService(
    private val store: UsageHistoryStore,
    private val scope: CoroutineScope,
) {
    private val _history = MutableStateFlow<List<UsageDataPoint>>(emptyList())
    val history: StateFlow<List<UsageDataPoint>> = _history.asStateFlow()

    private val mutex = Mutex()

    /** Load persisted points into memory. Safe to call multiple times. */
    suspend fun bootstrap() = mutex.withLock {
        val loaded = store.load().dataPoints
        _history.value = prune(loaded)
    }

    /**
     * Append a new data point. Persists asynchronously via [scope] so callers
     * (UsageService on API fetch) aren't blocked on disk I/O.
     */
    fun recordDataPoint(pct5h: Double, pct7d: Double) {
        val point = UsageDataPoint(
            timestampEpochMs = System.currentTimeMillis(),
            pct5h = pct5h,
            pct7d = pct7d,
        )
        scope.launch {
            mutex.withLock {
                val updated = prune(_history.value + point)
                _history.value = updated
                store.save(UsageHistorySnapshot(dataPoints = updated))
            }
        }
    }

    fun downsampled(range: TimeRange, nowEpochMs: Long = System.currentTimeMillis()): List<UsageDataPoint> =
        Downsampler.downsample(_history.value, range, nowEpochMs)

    fun recent(count: Int = 5): List<UsageDataPoint> =
        _history.value.takeLast(count).reversed()

    private fun prune(points: List<UsageDataPoint>, nowEpochMs: Long = System.currentTimeMillis()): List<UsageDataPoint> {
        val cutoff = nowEpochMs - RETENTION_MS
        return points.filter { it.timestampEpochMs >= cutoff }
    }

    companion object {
        private const val RETENTION_MS: Long = 90L * 86_400_000L
    }
}
