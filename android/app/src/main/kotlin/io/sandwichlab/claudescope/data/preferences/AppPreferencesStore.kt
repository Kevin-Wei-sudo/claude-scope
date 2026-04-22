package io.sandwichlab.claudescope.data.preferences

import android.content.Context
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import kotlinx.coroutines.flow.Flow

private val Context.dataStore by preferencesDataStore(name = "claudescope_prefs")

object AppPreferenceKeys {
    val LANGUAGE_TAG = stringPreferencesKey("language_tag")
    val POLLING_MINUTES = intPreferencesKey("polling_minutes")
    val NOTIFICATIONS_ENABLED = booleanPreferencesKey("notifications_enabled")
    val NOTIFICATION_THRESHOLD = intPreferencesKey("notification_threshold")
    val RESET_REMINDERS_ENABLED = booleanPreferencesKey("reset_reminders_enabled")
    val WIDGET_SHOW_5H = booleanPreferencesKey("widget_show_5h")
    val WIDGET_SHOW_7D = booleanPreferencesKey("widget_show_7d")
    val WIDGET_SHOW_RESET = booleanPreferencesKey("widget_show_reset")
    val WIDGET_PREFERRED_SIZE = stringPreferencesKey("widget_preferred_size")
}

object PollingDefaults {
    const val DEFAULT_MINUTES = 30
    val OPTIONS = listOf(15, 30, 60, 180)
    const val DEFAULT_NOTIFICATION_THRESHOLD = 80
}

class AppPreferencesStore(private val context: Context) {

    val preferences: Flow<Preferences> = context.dataStore.data

    suspend fun update(block: suspend (androidx.datastore.preferences.core.MutablePreferences) -> Unit) {
        context.dataStore.edit { block(it) }
    }
}
