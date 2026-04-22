package io.sandwichlab.claudescope.ui.signin

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelProvider.AndroidViewModelFactory.Companion.APPLICATION_KEY
import androidx.lifecycle.viewModelScope
import androidx.lifecycle.viewmodel.initializer
import androidx.lifecycle.viewmodel.viewModelFactory
import io.sandwichlab.claudescope.ClaudeScopeApp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.service.oauth.AuthState
import io.sandwichlab.claudescope.service.oauth.OAuthError
import io.sandwichlab.claudescope.service.oauth.OAuthManager
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch

class AuthViewModel(
    application: Application,
    private val oauthManager: OAuthManager,
) : AndroidViewModel(application) {

    private val _uiState = MutableStateFlow<AuthUiState>(AuthUiState.Loading)
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    private val _events = Channel<AuthEvent>(
        capacity = Channel.BUFFERED,
        onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val events = _events.receiveAsFlow()

    init {
        viewModelScope.launch {
            oauthManager.authState.collect { authState ->
                _uiState.value = when (authState) {
                    AuthState.Unknown -> AuthUiState.Loading
                    AuthState.SignedOut -> AuthUiState.SignedOut()
                    is AuthState.SignedIn -> AuthUiState.SignedIn(authState.email)
                }
            }
        }
    }

    fun onSignInClick() {
        if (_uiState.value is AuthUiState.SignedIn) return
        val request = oauthManager.beginAuthorization()
        _uiState.value = AuthUiState.AwaitingCode()
        viewModelScope.launch { _events.send(AuthEvent.OpenAuthorizationUrl(request.url)) }
    }

    fun onSubmitCode(raw: String) {
        if (raw.isBlank()) return
        _uiState.value = AuthUiState.AwaitingCode(isSubmitting = true)
        viewModelScope.launch {
            val result = oauthManager.exchangeCode(raw)
            if (result.isFailure) {
                _uiState.value = AuthUiState.AwaitingCode(
                    isSubmitting = false,
                    errorMessage = resolveError(result.exceptionOrNull()),
                )
            }
            // Success path flips state via OAuthManager.authState observer above.
        }
    }

    fun onCancelCodeEntry() {
        oauthManager.cancelPendingFlow()
        _uiState.value = AuthUiState.SignedOut()
    }

    fun onSignOut() {
        viewModelScope.launch { oauthManager.signOut() }
    }

    private fun resolveError(error: Throwable?): String {
        val res = getApplication<Application>().resources
        return when (error) {
            OAuthError.StateMismatch -> res.getString(R.string.error_oauth_state_mismatch)
            OAuthError.NoPendingFlow -> res.getString(R.string.error_no_pending_oauth_flow)
            OAuthError.InvalidTokenResponse -> res.getString(R.string.error_invalid_token_response)
            is OAuthError.Http -> res.getString(R.string.error_http_status, error.statusCode)
            null -> res.getString(R.string.error_token_exchange_failed)
            else -> error.message ?: res.getString(R.string.error_token_exchange_failed)
        }
    }

    companion object {
        val Factory: ViewModelProvider.Factory = viewModelFactory {
            initializer {
                val app = this[APPLICATION_KEY] as ClaudeScopeApp
                AuthViewModel(app, app.oauthManager)
            }
        }
    }
}
