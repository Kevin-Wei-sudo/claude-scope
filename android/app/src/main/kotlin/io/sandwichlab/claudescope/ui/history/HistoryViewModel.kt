package io.sandwichlab.claudescope.ui.history

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import io.sandwichlab.claudescope.ClaudeScopeApp
import io.sandwichlab.claudescope.data.model.TimeRange
import io.sandwichlab.claudescope.data.model.UsageDataPoint
import io.sandwichlab.claudescope.data.model.UsageResponse
import io.sandwichlab.claudescope.service.history.Downsampler
import io.sandwichlab.claudescope.service.history.UsageHistoryService
import io.sandwichlab.claudescope.service.oauth.AuthState
import io.sandwichlab.claudescope.service.oauth.OAuthManager
import io.sandwichlab.claudescope.service.usage.UsageService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn

data class HistoryUiState(
    val isLive: Boolean,
    val selectedRange: TimeRange,
    val trendPoints: List<UsageDataPoint>,
    val sonnetPct: Double,
    val opusPct: Double,
    val recentSnapshots: List<UsageDataPoint>,
)

class HistoryViewModel(
    application: Application,
    oauthManager: OAuthManager,
    usageService: UsageService,
    private val historyService: UsageHistoryService,
) : AndroidViewModel(application) {

    private val _selectedRange = MutableStateFlow(TimeRange.Day7)
    val selectedRange: StateFlow<TimeRange> = _selectedRange

    val uiState: StateFlow<HistoryUiState> = combine(
        oauthManager.authState,
        usageService.usage,
        historyService.history,
        _selectedRange,
    ) { authState, usage, points, range ->
        val signedIn = authState is AuthState.SignedIn
        if (signedIn) buildLiveState(usage, points, range)
        else buildDemoState(range)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = buildDemoState(TimeRange.Day7),
    )

    fun selectRange(range: TimeRange) {
        _selectedRange.value = range
    }

    private fun buildLiveState(
        usage: UsageResponse?,
        history: List<UsageDataPoint>,
        range: TimeRange,
    ): HistoryUiState {
        val downsampled = Downsampler.downsample(history, range)
        return HistoryUiState(
            isLive = true,
            selectedRange = range,
            trendPoints = downsampled,
            sonnetPct = usage?.sonnetPct ?: 0.0,
            opusPct = usage?.opusPct ?: 0.0,
            recentSnapshots = history.takeLast(5).reversed(),
        )
    }

    private fun buildDemoState(range: TimeRange): HistoryUiState = HistoryUiState(
        isLive = false,
        selectedRange = range,
        trendPoints = HistoryDemoData.trendPoints(),
        sonnetPct = HistoryDemoData.SONNET_PCT,
        opusPct = HistoryDemoData.OPUS_PCT,
        recentSnapshots = HistoryDemoData.snapshots(),
    )

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = this[APPLICATION_KEY] as ClaudeScopeApp
                HistoryViewModel(
                    app,
                    app.oauthManager,
                    app.usageService,
                    app.historyService,
                )
            }
        }
    }
}
