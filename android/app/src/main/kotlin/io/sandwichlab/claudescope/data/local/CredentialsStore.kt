package io.sandwichlab.claudescope.data.local

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import io.sandwichlab.claudescope.data.model.StoredCredentials
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

class CredentialsStore(context: Context) {

    private val prefs: SharedPreferences by lazy {
        val masterKey = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
        )
    }

    suspend fun save(credentials: StoredCredentials) = withContext(Dispatchers.IO) {
        prefs.edit().apply {
            putString(KEY_ACCESS_TOKEN, credentials.accessToken)
            if (credentials.refreshToken != null) {
                putString(KEY_REFRESH_TOKEN, credentials.refreshToken)
            } else {
                remove(KEY_REFRESH_TOKEN)
            }
            if (credentials.expiresAtEpochMs != null) {
                putLong(KEY_EXPIRES_AT, credentials.expiresAtEpochMs)
            } else {
                remove(KEY_EXPIRES_AT)
            }
            putString(KEY_SCOPES, credentials.scopes.joinToString(SCOPE_SEPARATOR))
        }.apply()
    }

    suspend fun load(): StoredCredentials? = withContext(Dispatchers.IO) {
        val accessToken = prefs.getString(KEY_ACCESS_TOKEN, null) ?: return@withContext null
        val refreshToken = prefs.getString(KEY_REFRESH_TOKEN, null)
        val expiresAt = if (prefs.contains(KEY_EXPIRES_AT)) prefs.getLong(KEY_EXPIRES_AT, 0L) else null
        val scopes = prefs.getString(KEY_SCOPES, null)
            ?.split(SCOPE_SEPARATOR)
            ?.filter { it.isNotBlank() }
            .orEmpty()
        StoredCredentials(accessToken, refreshToken, expiresAt, scopes)
    }

    suspend fun delete() = withContext(Dispatchers.IO) {
        prefs.edit().clear().apply()
    }

    companion object {
        private const val PREFS_NAME = "claudescope_auth"
        private const val KEY_ACCESS_TOKEN = "access_token"
        private const val KEY_REFRESH_TOKEN = "refresh_token"
        private const val KEY_EXPIRES_AT = "expires_at"
        private const val KEY_SCOPES = "scopes"
        private const val SCOPE_SEPARATOR = " "
    }
}
