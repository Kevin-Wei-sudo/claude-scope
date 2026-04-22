package io.sandwichlab.claudescope.service.polling

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.sandwichlab.claudescope.service.oauth.AuthState
import io.sandwichlab.claudescope.service.oauth.OAuthManager
import io.sandwichlab.claudescope.service.settings.AppSettingsService
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.distinctUntilChanged
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.onEach
import java.util.concurrent.TimeUnit

/**
 * Reconciles the WorkManager schedule with the user's current polling preference
 * and auth state:
 * - Not signed in → cancel any scheduled work.
 * - Signed in → (re)schedule a PeriodicWorkRequest with interval = prefs minutes
 *   (clamped to WorkManager's 15 min minimum).
 */
class PollingScheduler(
    private val context: Context,
    oauthManager: OAuthManager,
    settingsService: AppSettingsService,
    scope: CoroutineScope,
) {

    init {
        combine(oauthManager.authState, settingsService.settings) { authState, settings ->
            Desired(authState is AuthState.SignedIn, settings.pollingMinutes)
        }
            .distinctUntilChanged()
            .onEach { apply(it) }
            .launchIn(scope)
    }

    private fun apply(desired: Desired) {
        val wm = WorkManager.getInstance(context)
        if (!desired.signedIn) {
            wm.cancelUniqueWork(WORK_NAME)
            return
        }
        val intervalMinutes = desired.minutes.coerceAtLeast(MIN_INTERVAL_MINUTES).toLong()
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(NetworkType.CONNECTED)
            .build()
        val request = PeriodicWorkRequestBuilder<UsagePollingWorker>(
            intervalMinutes, TimeUnit.MINUTES,
        )
            .setConstraints(constraints)
            .build()
        wm.enqueueUniquePeriodicWork(
            WORK_NAME,
            ExistingPeriodicWorkPolicy.UPDATE,
            request,
        )
    }

    private data class Desired(val signedIn: Boolean, val minutes: Int)

    companion object {
        const val WORK_NAME = "claude_usage_polling"
        const val MIN_INTERVAL_MINUTES = 15
    }
}
