package io.sandwichlab.claudescope.ui.widget

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import io.sandwichlab.claudescope.ClaudeScopeApp
import io.sandwichlab.claudescope.service.oauth.AuthState
import io.sandwichlab.claudescope.service.oauth.OAuthManager
import io.sandwichlab.claudescope.service.settings.AppSettings
import io.sandwichlab.claudescope.service.settings.AppSettingsService
import io.sandwichlab.claudescope.service.settings.WidgetSizePreset
import io.sandwichlab.claudescope.service.usage.UsageService
import io.sandwichlab.claudescope.ui.home.DemoHomeContent
import io.sandwichlab.claudescope.ui.home.HomeContent
import androidx.glance.appwidget.updateAll
import io.sandwichlab.claudescope.widget.ClaudeUsageWidget
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class WidgetSettingsUiState(
    val preview: HomeContent,
    val settings: AppSettings,
)

class WidgetSettingsViewModel(
    application: Application,
    oauthManager: OAuthManager,
    usageService: UsageService,
    private val settingsService: AppSettingsService,
) : AndroidViewModel(application) {

    val uiState: StateFlow<WidgetSettingsUiState> = combine(
        oauthManager.authState,
        usageService.usage,
        settingsService.settings,
    ) { authState, usage, settings ->
        val signedIn = authState is AuthState.SignedIn
        val preview = if (signedIn && usage != null) {
            HomeContent(
                isLive = true,
                pct5h = usage.pct5h,
                pct7d = usage.pct7d,
                sonnetPct = usage.sonnetPct,
                reset5h = usage.fiveHour?.resetsAtInstant,
                reset7d = usage.sevenDay?.resetsAtInstant,
                trend = DemoHomeContent.TREND,
            )
        } else {
            DemoHomeContent.snapshot()
        }
        WidgetSettingsUiState(preview = preview, settings = settings)
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = WidgetSettingsUiState(
            preview = DemoHomeContent.snapshot(),
            settings = AppSettings(),
        ),
    )

    fun setShow5h(value: Boolean) { settingsService.setWidgetShow5h(value); bumpWidget() }
    fun setShow7d(value: Boolean) { settingsService.setWidgetShow7d(value); bumpWidget() }
    fun setShowReset(value: Boolean) { settingsService.setWidgetShowReset(value); bumpWidget() }
    fun setPreferredSize(size: WidgetSizePreset) { settingsService.setWidgetPreferredSize(size); bumpWidget() }

    private fun bumpWidget() {
        val ctx: Application = getApplication()
        viewModelScope.launch {
            try {
                ClaudeUsageWidget().updateAll(ctx)
            } catch (_: Exception) {
                // Widget update is best-effort; failures are harmless.
            }
        }
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = this[APPLICATION_KEY] as ClaudeScopeApp
                WidgetSettingsViewModel(app, app.oauthManager, app.usageService, app.settingsService)
            }
        }
    }
}
