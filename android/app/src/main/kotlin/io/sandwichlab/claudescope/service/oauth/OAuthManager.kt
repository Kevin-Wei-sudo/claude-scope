package io.sandwichlab.claudescope.service.oauth

import android.net.Uri
import io.sandwichlab.claudescope.data.local.CredentialsStore
import io.sandwichlab.claudescope.data.model.StoredCredentials
import io.sandwichlab.claudescope.data.remote.OAuthApi
import io.sandwichlab.claudescope.data.remote.OAuthHttpException
import io.sandwichlab.claudescope.data.remote.dto.TokenResponse
import io.sandwichlab.claudescope.service.analytics.AnalyticsService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * Orchestrates the OAuth PKCE flow (mirrors [ios/.../UsageService.swift]):
 *  1. [beginAuthorization] — generate verifier/challenge/state, return URL for Custom Tabs
 *  2. user authorizes in browser, copies `code#state` back
 *  3. [exchangeCode] — swap code for tokens, persist via [CredentialsStore]
 *  4. [refreshIfNeeded] — auto-refresh when <5 min to expiry and a refresh_token exists
 */
class OAuthManager(
    private val credentialsStore: CredentialsStore,
    private val oauthApi: OAuthApi,
) {

    private val _authState = MutableStateFlow<AuthState>(AuthState.Unknown)
    val authState: StateFlow<AuthState> = _authState.asStateFlow()

    private val refreshMutex = Mutex()

    @Volatile private var pendingVerifier: String? = null
    @Volatile private var pendingState: String? = null

    suspend fun bootstrap() {
        val stored = credentialsStore.load()
        _authState.value = if (stored != null) AuthState.SignedIn(email = null) else AuthState.SignedOut
    }

    fun beginAuthorization(): AuthorizationRequest {
        val verifier = PkceGenerator.generateVerifier()
        val state = PkceGenerator.generateState()
        val challenge = PkceGenerator.challengeFor(verifier)
        pendingVerifier = verifier
        pendingState = state

        val url = Uri.parse(OAuthConfig.AUTHORIZE_URL).buildUpon()
            .appendQueryParameter("code", "true")
            .appendQueryParameter("client_id", OAuthConfig.CLIENT_ID)
            .appendQueryParameter("response_type", "code")
            .appendQueryParameter("redirect_uri", OAuthConfig.REDIRECT_URI)
            .appendQueryParameter("scope", OAuthConfig.DEFAULT_SCOPES.joinToString(" "))
            .appendQueryParameter("code_challenge", challenge)
            .appendQueryParameter("code_challenge_method", "S256")
            .appendQueryParameter("state", state)
            .build()
            .toString()

        return AuthorizationRequest(url = url, state = state)
    }

    fun cancelPendingFlow() {
        pendingVerifier = null
        pendingState = null
    }

    suspend fun exchangeCode(rawInput: String): Result<StoredCredentials> {
        val trimmed = rawInput.trim()
        val (code, returnedState) = splitCodeAndState(trimmed)
        val verifier = pendingVerifier ?: return Result.failure(OAuthError.NoPendingFlow)
        val expectedState = pendingState

        if (returnedState != null && expectedState != null && returnedState != expectedState) {
            cancelPendingFlow()
            return Result.failure(OAuthError.StateMismatch)
        }

        val stateForRequest = expectedState ?: returnedState.orEmpty()

        val response = oauthApi.exchangeCode(
            code = code,
            state = stateForRequest,
            codeVerifier = verifier,
        ).getOrElse { return Result.failure(it.toOAuthError()) }

        val credentials = response.toCredentials(fallbackScopes = OAuthConfig.DEFAULT_SCOPES)
            ?: return Result.failure(OAuthError.InvalidTokenResponse)

        credentialsStore.save(credentials)
        cancelPendingFlow()

        val email = runCatching { oauthApi.fetchUserInfo(credentials.accessToken).getOrNull()?.email }.getOrNull()
        _authState.value = AuthState.SignedIn(email = email)
        AnalyticsService.trackLogin(method = "oauth")
        return Result.success(credentials)
    }

    suspend fun currentCredentials(): StoredCredentials? = credentialsStore.load()

    suspend fun refreshIfNeeded(): Result<StoredCredentials?> = refreshMutex.withLock {
        val current = credentialsStore.load() ?: return Result.success(null)
        if (!current.needsRefresh()) return Result.success(current)
        val refreshToken = current.refreshToken ?: return Result.success(current)

        val response = oauthApi.refreshToken(refreshToken, current.scopes)
            .getOrElse { return Result.failure(it.toOAuthError()) }

        val updated = response.toCredentials(
            fallbackRefreshToken = current.refreshToken,
            fallbackScopes = current.scopes.ifEmpty { OAuthConfig.DEFAULT_SCOPES },
        ) ?: return Result.failure(OAuthError.InvalidTokenResponse)

        credentialsStore.save(updated)
        _authState.value = (_authState.value as? AuthState.SignedIn) ?: AuthState.SignedIn(email = null)
        return Result.success(updated)
    }

    suspend fun signOut() {
        credentialsStore.delete()
        cancelPendingFlow()
        _authState.value = AuthState.SignedOut
        AnalyticsService.trackSignOut()
    }

    private fun splitCodeAndState(raw: String): Pair<String, String?> {
        val hashIndex = raw.indexOf('#')
        return if (hashIndex >= 0) raw.substring(0, hashIndex) to raw.substring(hashIndex + 1)
        else raw to null
    }

    private fun TokenResponse.toCredentials(
        fallbackRefreshToken: String? = null,
        fallbackScopes: List<String> = emptyList(),
    ): StoredCredentials? {
        if (accessToken.isEmpty()) return null
        val scopeList = scope?.split(' ', '\t', '\n')?.filter { it.isNotBlank() }
            ?: fallbackScopes
        val expiresAt = expiresInSeconds?.let { System.currentTimeMillis() + it * 1000L }
        return StoredCredentials(
            accessToken = accessToken,
            refreshToken = refreshToken ?: fallbackRefreshToken,
            expiresAtEpochMs = expiresAt,
            scopes = scopeList,
        )
    }

    private fun Throwable.toOAuthError(): OAuthError = when (this) {
        is OAuthError -> this
        is OAuthHttpException -> OAuthError.Http(statusCode, message ?: "")
        else -> OAuthError.Http(-1, message ?: javaClass.simpleName)
    }
}
