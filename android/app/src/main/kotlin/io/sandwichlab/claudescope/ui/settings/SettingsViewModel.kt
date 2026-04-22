package io.sandwichlab.claudescope.ui.settings

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
import io.sandwichlab.claudescope.service.settings.AppLanguage
import io.sandwichlab.claudescope.service.settings.AppSettings
import io.sandwichlab.claudescope.service.settings.AppSettingsService
import io.sandwichlab.claudescope.service.usage.UsageService
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

data class SettingsUiState(
    val authState: AuthState = AuthState.Unknown,
    val lastUpdatedEpochMs: Long? = null,
    val isSyncing: Boolean = false,
    val settings: AppSettings = AppSettings(),
)

class SettingsViewModel(
    application: Application,
    private val oauthManager: OAuthManager,
    private val usageService: UsageService,
    private val settingsService: AppSettingsService,
) : AndroidViewModel(application) {

    val uiState: StateFlow<SettingsUiState> = combine(
        oauthManager.authState,
        usageService.lastUpdatedEpochMs,
        usageService.isFetching,
        settingsService.settings,
    ) { authState, lastUpdated, isFetching, settings ->
        SettingsUiState(
            authState = authState,
            lastUpdatedEpochMs = lastUpdated,
            isSyncing = isFetching,
            settings = settings,
        )
    }.stateIn(
        scope = viewModelScope,
        started = SharingStarted.WhileSubscribed(5_000),
        initialValue = SettingsUiState(),
    )

    fun sync() = usageService.refresh()
    fun setLanguage(language: AppLanguage) = settingsService.setLanguage(language)
    fun setNotificationsEnabled(enabled: Boolean) = settingsService.setNotificationsEnabled(enabled)
    fun setThreshold(value: Int) = settingsService.setNotificationThreshold(value)
    fun setPollingMinutes(minutes: Int) = settingsService.setPollingMinutes(minutes)
    fun signOut() = viewModelScope.launch { oauthManager.signOut() }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = this[APPLICATION_KEY] as ClaudeScopeApp
                SettingsViewModel(app, app.oauthManager, app.usageService, app.settingsService)
            }
        }
    }
}
