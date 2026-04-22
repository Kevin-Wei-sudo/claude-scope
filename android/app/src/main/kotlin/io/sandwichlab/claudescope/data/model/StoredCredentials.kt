package io.sandwichlab.claudescope.data.model

data class StoredCredentials(
    val accessToken: String,
    val refreshToken: String?,
    val expiresAtEpochMs: Long?,
    val scopes: List<String>,
) {
    val hasRefreshToken: Boolean
        get() = !refreshToken.isNullOrEmpty()

    fun isExpired(now: Long = System.currentTimeMillis()): Boolean =
        expiresAtEpochMs != null && expiresAtEpochMs <= now

    fun needsRefresh(
        now: Long = System.currentTimeMillis(),
        leewayMs: Long = REFRESH_LEEWAY_MS,
    ): Boolean {
        if (!hasRefreshToken) return false
        val expires = expiresAtEpochMs ?: return false
        return expires <= now + leewayMs
    }

    companion object {
        const val REFRESH_LEEWAY_MS: Long = 5 * 60 * 1000L
    }
}
