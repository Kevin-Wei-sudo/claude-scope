package io.sandwichlab.claudescope.data.remote

import io.sandwichlab.claudescope.data.model.UsageResponse
import io.sandwichlab.claudescope.data.remote.dto.UsageResponseDto
import io.sandwichlab.claudescope.service.oauth.OAuthConfig
import io.sandwichlab.claudescope.service.oauth.OAuthManager
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request

/**
 * GET `/api/oauth/usage` with Bearer auth. On 401 we transparently refresh the
 * access token once via [OAuthManager.refreshIfNeeded] and retry the request.
 */
class UsageApi(
    private val httpClient: OkHttpClient,
    private val oauthManager: OAuthManager,
    private val json: Json = OAuthApi.DEFAULT_JSON,
) {

    suspend fun fetchUsage(): Result<UsageResponse> = runCatching {
        withContext(Dispatchers.IO) {
            val initial = oauthManager.currentCredentials()
                ?: throw NotSignedInException

            // Proactive refresh if <5 min to expiry so we don't spend a 401 round-trip.
            if (initial.needsRefresh()) {
                oauthManager.refreshIfNeeded().getOrThrow()
            }

            val token = oauthManager.currentCredentials()?.accessToken
                ?: throw NotSignedInException
            val firstAttempt = execute(token)
            if (firstAttempt.code != 401) return@withContext firstAttempt.parseOrThrow()

            // 401 → force refresh and retry once.
            val refreshed = oauthManager.refreshIfNeeded().getOrNull()
                ?: throw UsageAuthExpiredException
            val retryToken = refreshed?.accessToken ?: throw UsageAuthExpiredException
            val retry = execute(retryToken)
            if (retry.code == 401) throw UsageAuthExpiredException
            retry.parseOrThrow()
        }
    }

    private fun execute(token: String): CallResult {
        val request = Request.Builder()
            .url(OAuthConfig.USAGE_URL)
            .get()
            .addHeader("Authorization", "Bearer $token")
            .addHeader("anthropic-beta", OAuthConfig.ANTHROPIC_BETA_HEADER)
            .build()
        httpClient.newCall(request).execute().use { response ->
            return CallResult(response.code, response.body?.string().orEmpty(), response.message)
        }
    }

    private fun CallResult.parseOrThrow(): UsageResponse {
        if (code !in 200..299) throw OAuthHttpException(code, body.ifEmpty { message })
        val dto = json.decodeFromString(UsageResponseDto.serializer(), body)
        return dto.toModel()
    }

    private data class CallResult(val code: Int, val body: String, val message: String)
}

object NotSignedInException : RuntimeException("Not signed in")
object UsageAuthExpiredException : RuntimeException("Session expired")
