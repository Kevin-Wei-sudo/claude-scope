package io.sandwichlab.claudescope

import android.app.Application
import io.sandwichlab.claudescope.data.local.CredentialsStore
import io.sandwichlab.claudescope.data.local.UsageHistoryStore
import io.sandwichlab.claudescope.data.preferences.AppPreferencesStore
import io.sandwichlab.claudescope.data.remote.HttpClientProvider
import io.sandwichlab.claudescope.data.remote.OAuthApi
import io.sandwichlab.claudescope.data.remote.UsageApi
import io.sandwichlab.claudescope.service.analytics.AnalyticsService
import io.sandwichlab.claudescope.service.history.UsageHistoryService
import io.sandwichlab.claudescope.service.notifications.NotificationChannels
import io.sandwichlab.claudescope.service.notifications.NotificationService
import io.sandwichlab.claudescope.service.oauth.OAuthManager
import io.sandwichlab.claudescope.service.polling.PollingScheduler
import io.sandwichlab.claudescope.service.settings.AppSettingsService
import io.sandwichlab.claudescope.service.usage.UsageService
import io.sandwichlab.claudescope.widget.WidgetDataStore
import io.sandwichlab.claudescope.widget.WidgetUpdater
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

class ClaudeScopeApp : Application() {

    private val appScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    val httpClient by lazy { HttpClientProvider.create() }
    val credentialsStore by lazy { CredentialsStore(applicationContext) }
    val oauthApi by lazy { OAuthApi(httpClient) }
    val oauthManager by lazy { OAuthManager(credentialsStore, oauthApi) }
    val usageApi by lazy { UsageApi(httpClient, oauthManager) }
    val historyStore by lazy { UsageHistoryStore(applicationContext) }
    val historyService by lazy { UsageHistoryService(historyStore, appScope) }
    val preferencesStore by lazy { AppPreferencesStore(applicationContext) }
    val settingsService by lazy { AppSettingsService(preferencesStore, appScope) }
    val widgetDataStore by lazy { WidgetDataStore(applicationContext) }
    val widgetUpdater by lazy { WidgetUpdater(applicationContext, widgetDataStore) }
    val notificationService by lazy { NotificationService(applicationContext, settingsService) }
    val usageService by lazy {
        UsageService(
            usageApi = usageApi,
            oauthManager = oauthManager,
            historyService = historyService,
            widgetUpdater = widgetUpdater,
            notificationService = notificationService,
            scope = appScope,
        )
    }
    val pollingScheduler by lazy {
        PollingScheduler(applicationContext, oauthManager, settingsService, appScope)
    }

    override fun onCreate() {
        super.onCreate()
        AnalyticsService.configure(this)
        AnalyticsService.start(this)
        NotificationChannels.ensureCreated(this)
        appScope.launch {
            historyService.bootstrap()
            oauthManager.bootstrap()
        }
        usageService
        settingsService
        pollingScheduler
    }
}
