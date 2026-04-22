package io.sandwichlab.claudescope.ui.home

import android.text.format.DateUtils
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay
import java.time.Instant

/**
 * Produces a relative time label ("in 5 hours" / "5 分钟后") that updates roughly
 * once a minute. Mirrors SwiftUI's `Text(date, style: .relative)` behavior.
 *
 * Follows the system locale via DateUtils. Once we add an in-app language
 * toggle (P4), this will need to switch to manual formatting with the
 * user-selected locale — same gap iOS had before the recent fix.
 */
@Composable
fun rememberRelativeTime(instant: Instant?): String {
    if (instant == null) return ""
    var tick by remember { mutableStateOf(System.currentTimeMillis()) }
    LaunchedEffect(instant) {
        while (true) {
            delay(60_000)
            tick = System.currentTimeMillis()
        }
    }
    return remember(instant, tick) { formatRelative(instant, tick) }
}

private fun formatRelative(instant: Instant, now: Long): String {
    return DateUtils.getRelativeTimeSpanString(
        instant.toEpochMilli(),
        now,
        DateUtils.MINUTE_IN_MILLIS,
        DateUtils.FORMAT_ABBREV_RELATIVE,
    ).toString()
}
