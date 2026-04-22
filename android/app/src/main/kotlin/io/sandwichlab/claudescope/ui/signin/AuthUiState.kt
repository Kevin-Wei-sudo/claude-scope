package io.sandwichlab.claudescope.ui.signin

sealed interface AuthUiState {
    data object Loading : AuthUiState
    data class SignedOut(val errorMessage: String? = null) : AuthUiState
    data class AwaitingCode(
        val isSubmitting: Boolean = false,
        val errorMessage: String? = null,
    ) : AuthUiState
    data class SignedIn(val email: String?) : AuthUiState
}

sealed interface AuthEvent {
    data class OpenAuthorizationUrl(val url: String) : AuthEvent
}
