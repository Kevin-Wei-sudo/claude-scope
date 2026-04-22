package io.sandwichlab.claudescope.service.usage

import io.sandwichlab.claudescope.data.model.UsageResponse
import io.sandwichlab.claudescope.data.remote.UsageApi
import io.sandwichlab.claudescope.service.analytics.AnalyticsService
import io.sandwichlab.claudescope.service.history.UsageHistoryService
import io.sandwichlab.claudescope.service.notifications.NotificationService
import io.sandwichlab.claudescope.service.oauth.AuthState
import io.sandwichlab.claudescope.service.oauth.OAuthManager
import io.sandwichlab.claudescope.widget.WidgetUpdater
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class UsageService(
    private val usageApi: UsageApi,
    oauthManager: OAuthManager,
    private val historyService: UsageHistoryService,
    private val widgetUpdater: WidgetUpdater,
    private val notificationService: NotificationService,
    private val scope: CoroutineScope,
) {
    private val _usage = MutableStateFlow<UsageResponse?>(null)
    val usage: StateFlow<UsageResponse?> = _usage.asStateFlow()

    private val _lastUpdatedEpochMs = MutableStateFlow<Long?>(null)
    val lastUpdatedEpochMs: StateFlow<Long?> = _lastUpdatedEpochMs.asStateFlow()

    private val _isFetching = MutableStateFlow(false)
    val isFetching: StateFlow<Boolean> = _isFetching.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    private val fetchMutex = Mutex()

    init {
        scope.launch {
            oauthManager.authState.collect { state ->
                when (state) {
                    is AuthState.SignedIn -> refresh()
                    AuthState.SignedOut -> clear()
                    AuthState.Unknown -> Unit
                }
            }
        }
    }

    fun refresh() {
        scope.launch { fetch() }
    }

    private suspend fun fetch() = fetchMutex.withLock {
        _isFetching.value = true
        try {
            usageApi.fetchUsage().fold(
                onSuccess = { response ->
                    _usage.value = response
                    _lastUpdatedEpochMs.value = System.currentTimeMillis()
                    _lastError.value = null
                    historyService.recordDataPoint(pct5h = response.pct5h, pct7d = response.pct7d)
                    widgetUpdater.publish(response)
                    notificationService.onUsageFetched(response.pct5h, response.pct7d)
                    AnalyticsService.trackUsageFetched(response.pct5h, response.pct7d)
                },
                onFailure = { error ->
                    _lastError.value = error.message ?: error.javaClass.simpleName
                },
            )
        } finally {
            _isFetching.value = false
        }
    }

    private fun clear() {
        _usage.value = null
        _lastUpdatedEpochMs.value = null
        _lastError.value = null
        notificationService.onClear()
    }
}
