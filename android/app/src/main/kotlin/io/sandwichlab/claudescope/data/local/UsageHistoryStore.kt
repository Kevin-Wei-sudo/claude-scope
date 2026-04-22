package io.sandwichlab.claudescope.data.local

import android.content.Context
import io.sandwichlab.claudescope.data.model.UsageHistorySnapshot
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.File

/**
 * JSON file persistence for usage history, mirroring iOS's history.json under
 * Application Support/ClaudeScope. On Android we use the app's internal files
 * directory — same lifecycle (per-install, survives upgrades) minus the macOS
 * Application Support semantics which don't apply.
 */
class UsageHistoryStore(context: Context) {

    private val file: File = File(context.filesDir, "history.json")
    private val json = Json {
        ignoreUnknownKeys = true
        prettyPrint = false
        encodeDefaults = true
    }

    suspend fun load(): UsageHistorySnapshot = withContext(Dispatchers.IO) {
        if (!file.exists()) return@withContext UsageHistorySnapshot()
        runCatching {
            json.decodeFromString(UsageHistorySnapshot.serializer(), file.readText())
        }.getOrElse {
            // Backup corrupt file so the next run starts fresh rather than looping on parse errors.
            runCatching { file.copyTo(File(file.parentFile, "history.bak.json"), overwrite = true) }
            runCatching { file.delete() }
            UsageHistorySnapshot()
        }
    }

    suspend fun save(snapshot: UsageHistorySnapshot) = withContext(Dispatchers.IO) {
        val tmp = File(file.parentFile, "history.json.tmp")
        tmp.writeText(json.encodeToString(UsageHistorySnapshot.serializer(), snapshot))
        tmp.renameTo(file)
        Unit
    }
}
