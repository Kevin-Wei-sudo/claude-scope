package io.sandwichlab.claudescope.widget

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.json.Json
import java.io.File

/**
 * Shared file for UsageService → Glance widget data flow. Lives in filesDir
 * because Glance's `provideGlance` runs in the app process, so there's no IPC
 * concern — we just need on-disk persistence that survives widget restarts.
 */
class WidgetDataStore(context: Context) {

    private val file = File(context.filesDir, "widget_snapshot.json")
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    suspend fun read(): WidgetSnapshot = withContext(Dispatchers.IO) {
        if (!file.exists()) return@withContext WidgetSnapshot.Placeholder
        runCatching {
            json.decodeFromString(WidgetSnapshot.serializer(), file.readText())
        }.getOrDefault(WidgetSnapshot.Placeholder)
    }

    suspend fun write(snapshot: WidgetSnapshot) = withContext(Dispatchers.IO) {
        val tmp = File(file.parentFile, "widget_snapshot.json.tmp")
        tmp.writeText(json.encodeToString(WidgetSnapshot.serializer(), snapshot))
        tmp.renameTo(file)
        Unit
    }
}
