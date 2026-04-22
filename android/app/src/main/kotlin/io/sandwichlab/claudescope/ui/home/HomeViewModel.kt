package io.sandwichlab.claudescope.ui.home

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
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn

class HomeViewModel(
    application: Application,
    private val oauthManager: OAuthManager,
    private val usageService: UsageService,
    private val historyService: UsageHistoryService,
) : AndroidViewModel(application) {

    val content: StateFlow<HomeContent> = combine(
        oauthManager.authState,
        usageService.usage,
        historyService.history,
    ) { authState, usage, history ->
        val signedIn = authState is AuthState.SignedIn
        if (signedIn && usage != null) buildLive(usage, history)
        else DemoHomeContent.snapshot()
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = DemoHomeContent.snapshot(),
    )

    fun refresh() = usageService.refresh()

    private fun buildLive(usage: UsageResponse, history: List<UsageDataPoint>): HomeContent {
        val trend = trendFor7Days(history)
        return HomeContent(
            isLive = true,
            pct5h = usage.pct5h,
            pct7d = usage.pct7d,
            sonnetPct = usage.sonnetPct,
            reset5h = usage.fiveHour?.resetsAtInstant,
            reset7d = usage.sevenDay?.resetsAtInstant,
            trend = trend,
        )
    }

    /** 7-day pct7d series, falling back to demo values until enough history accumulates. */
    private fun trendFor7Days(history: List<UsageDataPoint>): List<Double> {
        if (history.size < 2) return DemoHomeContent.TREND
        val downsampled = Downsampler.downsample(history, TimeRange.Day7)
        return downsampled.map { it.pct7d }.ifEmpty { DemoHomeContent.TREND }
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = this[APPLICATION_KEY] as ClaudeScopeApp
                HomeViewModel(app, app.oauthManager, app.usageService, app.historyService)
            }
        }
    }
}
