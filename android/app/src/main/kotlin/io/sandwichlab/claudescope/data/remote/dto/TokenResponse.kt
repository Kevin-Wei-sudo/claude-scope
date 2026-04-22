package io.sandwichlab.claudescope.data.remote.dto

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

@Serializable
data class TokenResponse(
    @SerialName("access_token") val accessToken: String,
    @SerialName("refresh_token") val refreshToken: String? = null,
    @SerialName("expires_in") val expiresInSeconds: Long? = null,
    @SerialName("scope") val scope: String? = null,
    @SerialName("token_type") val tokenType: String? = null,
)

@Serializable
data class UserInfoResponse(
    @SerialName("email") val email: String? = null,
    @SerialName("name") val name: String? = null,
)
