package io.sandwichlab.claudescope.data.remote

import io.sandwichlab.claudescope.data.remote.dto.TokenResponse
import io.sandwichlab.claudescope.data.remote.dto.UserInfoResponse
import io.sandwichlab.claudescope.service.oauth.OAuthConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody

class OAuthApi(
    private val httpClient: OkHttpClient,
    private val json: Json = DEFAULT_JSON,
) {

    suspend fun exchangeCode(
        code: String,
        state: String,
        codeVerifier: String,
    ): Result<TokenResponse> = runCatching {
        val body = buildJsonObject {
            put("grant_type", "authorization_code")
            put("code", code)
            put("state", state)
            put("client_id", OAuthConfig.CLIENT_ID)
            put("redirect_uri", OAuthConfig.REDIRECT_URI)
            put("code_verifier", codeVerifier)
        }
        postJson(OAuthConfig.TOKEN_URL, body)
    }

    suspend fun refreshToken(
        refreshToken: String,
        scopes: List<String>,
    ): Result<TokenResponse> = runCatching {
        val body = buildJsonObject {
            put("grant_type", "refresh_token")
            put("refresh_token", refreshToken)
            put("client_id", OAuthConfig.CLIENT_ID)
            if (scopes.isNotEmpty()) {
                put("scope", scopes.joinToString(" "))
            }
        }
        postJson(OAuthConfig.TOKEN_URL, body)
    }

    suspend fun fetchUserInfo(accessToken: String): Result<UserInfoResponse> = runCatching {
        withContext(Dispatchers.IO) {
            val request = Request.Builder()
                .url(OAuthConfig.USERINFO_URL)
                .get()
                .addHeader("Authorization", "Bearer $accessToken")
                .addHeader("anthropic-beta", OAuthConfig.ANTHROPIC_BETA_HEADER)
                .build()
            httpClient.newCall(request).execute().use { response ->
                val bodyText = response.body?.string().orEmpty()
                if (!response.isSuccessful) {
                    throw OAuthHttpException(response.code, bodyText.ifEmpty { response.message })
                }
                json.decodeFromString(UserInfoResponse.serializer(), bodyText)
            }
        }
    }

    private suspend fun postJson(url: String, body: JsonObject): TokenResponse = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(url)
            .post(body.toString().toRequestBody(JSON_MEDIA))
            .addHeader("Content-Type", "application/json")
            .build()
        httpClient.newCall(request).execute().use { response ->
            val bodyText = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw OAuthHttpException(response.code, bodyText.ifEmpty { response.message })
            }
            json.decodeFromString(TokenResponse.serializer(), bodyText)
        }
    }

    companion object {
        private val JSON_MEDIA = "application/json; charset=utf-8".toMediaType()

        val DEFAULT_JSON = Json {
            ignoreUnknownKeys = true
            isLenient = true
        }
    }
}

class OAuthHttpException(val statusCode: Int, message: String) : RuntimeException(message)
