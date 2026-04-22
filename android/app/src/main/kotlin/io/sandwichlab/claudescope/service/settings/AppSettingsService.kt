package io.sandwichlab.claudescope.service.settings

import io.sandwichlab.claudescope.data.preferences.AppPreferenceKeys
import io.sandwichlab.claudescope.data.preferences.AppPreferencesStore
import io.sandwichlab.claudescope.data.preferences.PollingDefaults
import io.sandwichlab.claudescope.service.analytics.AnalyticsService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch

enum class WidgetSizePreset(val tag: String) {
    Small("small"),
    Medium("medium"),
    Large("large");

    companion object {
        fun fromTag(tag: String?): WidgetSizePreset = entries.firstOrNull { it.tag == tag } ?: Medium
    }
}

data class AppSettings(
    val language: AppLanguage = AppLanguage.System,
    val pollingMinutes: Int = PollingDefaults.DEFAULT_MINUTES,
    val notificationsEnabled: Boolean = false,
    val notificationThreshold: Int = PollingDefaults.DEFAULT_NOTIFICATION_THRESHOLD,
    val resetRemindersEnabled: Boolean = true,
    val widgetShow5h: Boolean = true,
    val widgetShow7d: Boolean = true,
    val widgetShowReset: Boolean = true,
    val widgetPreferredSize: WidgetSizePreset = WidgetSizePreset.Medium,
)

class AppSettingsService(
    private val store: AppPreferencesStore,
    private val scope: CoroutineScope,
) {

    val settings: StateFlow<AppSettings> = store.preferences
        .map { prefs ->
            AppSettings(
                language = AppLanguage.fromTag(prefs[AppPreferenceKeys.LANGUAGE_TAG]),
                pollingMinutes = prefs[AppPreferenceKeys.POLLING_MINUTES] ?: PollingDefaults.DEFAULT_MINUTES,
                notificationsEnabled = prefs[AppPreferenceKeys.NOTIFICATIONS_ENABLED] ?: false,
                notificationThreshold = prefs[AppPreferenceKeys.NOTIFICATION_THRESHOLD]
                    ?: PollingDefaults.DEFAULT_NOTIFICATION_THRESHOLD,
                resetRemindersEnabled = prefs[AppPreferenceKeys.RESET_REMINDERS_ENABLED] ?: true,
                widgetShow5h = prefs[AppPreferenceKeys.WIDGET_SHOW_5H] ?: true,
                widgetShow7d = prefs[AppPreferenceKeys.WIDGET_SHOW_7D] ?: true,
                widgetShowReset = prefs[AppPreferenceKeys.WIDGET_SHOW_RESET] ?: true,
                widgetPreferredSize = WidgetSizePreset.fromTag(prefs[AppPreferenceKeys.WIDGET_PREFERRED_SIZE]),
            )
        }
        .stateIn(scope, SharingStarted.Eagerly, AppSettings())

    fun setLanguage(language: AppLanguage) {
        AnalyticsService.trackLanguageChanged(language.tag.ifEmpty { "system" })
        launch { it[AppPreferenceKeys.LANGUAGE_TAG] = language.tag }
    }

    fun setPollingMinutes(minutes: Int) {
        AnalyticsService.trackPollingIntervalChanged(minutes)
        launch { it[AppPreferenceKeys.POLLING_MINUTES] = minutes }
    }

    fun setNotificationsEnabled(enabled: Boolean) = launch {
        it[AppPreferenceKeys.NOTIFICATIONS_ENABLED] = enabled
    }

    fun setNotificationThreshold(value: Int) = launch {
        it[AppPreferenceKeys.NOTIFICATION_THRESHOLD] = value.coerceIn(50, 100)
    }

    fun setResetRemindersEnabled(enabled: Boolean) = launch {
        it[AppPreferenceKeys.RESET_REMINDERS_ENABLED] = enabled
    }

    fun setWidgetShow5h(enabled: Boolean) = launch {
        it[AppPreferenceKeys.WIDGET_SHOW_5H] = enabled
    }

    fun setWidgetShow7d(enabled: Boolean) = launch {
        it[AppPreferenceKeys.WIDGET_SHOW_7D] = enabled
    }

    fun setWidgetShowReset(enabled: Boolean) = launch {
        it[AppPreferenceKeys.WIDGET_SHOW_RESET] = enabled
    }

    fun setWidgetPreferredSize(size: WidgetSizePreset) {
        AnalyticsService.trackWidgetConfigured(size.tag)
        launch { it[AppPreferenceKeys.WIDGET_PREFERRED_SIZE] = size.tag }
    }

    private inline fun launch(
        crossinline block: (androidx.datastore.preferences.core.MutablePreferences) -> Unit,
    ) {
        scope.launch { store.update { block(it) } }
    }
}
