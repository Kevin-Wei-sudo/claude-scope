package io.sandwichlab.claudescope.service.oauth

sealed interface AuthState {
    data object Unknown : AuthState
    data object SignedOut : AuthState
    data class SignedIn(val email: String?) : AuthState
}

data class AuthorizationRequest(
    val url: String,
    val state: String,
)

sealed class OAuthError(message: String) : RuntimeException(message) {
    data object StateMismatch : OAuthError("OAuth state mismatch")
    data object NoPendingFlow : OAuthError("No pending OAuth flow")
    data object InvalidTokenResponse : OAuthError("Invalid token response")
    class Http(val statusCode: Int, detail: String) : OAuthError("HTTP $statusCode: $detail")
}
