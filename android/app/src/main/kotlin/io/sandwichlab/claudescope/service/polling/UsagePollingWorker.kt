package io.sandwichlab.claudescope.service.polling

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import io.sandwichlab.claudescope.ClaudeScopeApp
import io.sandwichlab.claudescope.service.oauth.AuthState
import kotlinx.coroutines.flow.first

/**
 * One-shot worker that UsageService.refresh()s the API and returns. Scheduled
 * as a PeriodicWorkRequest by PollingScheduler, minimum interval 15 minutes.
 */
class UsagePollingWorker(
    context: Context,
    params: WorkerParameters,
) : CoroutineWorker(context, params) {

    override suspend fun doWork(): Result {
        val app = applicationContext as ClaudeScopeApp
        val auth = app.oauthManager.authState.first()
        if (auth !is AuthState.SignedIn) return Result.success()

        // UsageService.refresh() is fire-and-forget via its own coroutine
        // scope; we also invoke fetch synchronously here to ensure the
        // notification + widget update run before the worker completes.
        return try {
            app.usageApi.fetchUsage().fold(
                onSuccess = { usage ->
                    app.historyService.recordDataPoint(usage.pct5h, usage.pct7d)
                    app.widgetUpdater.publish(usage)
                    app.notificationService.onUsageFetched(usage.pct5h, usage.pct7d)
                    Result.success()
                },
                onFailure = { Result.retry() },
            )
        } catch (t: Throwable) {
            Result.retry()
        }
    }
}
