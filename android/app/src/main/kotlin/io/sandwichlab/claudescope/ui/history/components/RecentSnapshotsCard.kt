package io.sandwichlab.claudescope.ui.history.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.data.model.UsageDataPoint
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Teal
import io.sandwichlab.claudescope.ui.theme.Terracotta
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.roundToInt

@Composable
fun RecentSnapshotsCard(
    points: List<UsageDataPoint>,
    modifier: Modifier = Modifier,
) {
    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.history_recent_snapshots))
        Spacer(Modifier.size(12.dp))

        if (points.isEmpty()) {
            Text(
                text = stringResource(R.string.history_no_snapshots),
                color = SubtitleText,
                style = MaterialTheme.typography.bodySmall,
            )
            return@CardView
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            points.forEach { point ->
                SnapshotRow(point)
            }
        }
    }
}

@Composable
private fun SnapshotRow(point: UsageDataPoint) {
    val pct = (point.pct7d * 100).roundToInt().coerceIn(0, 999)
    val color = if (point.pct7d > 0.6) Terracotta else Teal

    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            text = snapshotLabel(point.timestampEpochMs),
            color = BodyText,
            style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
        )
        Spacer(Modifier.weight(1f))
        Text(
            text = stringResource(R.string.history_pct_used, pct),
            color = color,
            style = MaterialTheme.typography.bodyMedium,
        )
    }
}

private val TIME_FMT = DateTimeFormatter.ofPattern("HH:mm", Locale.getDefault())
private val DATE_FMT = DateTimeFormatter.ofPattern("MMM d HH:mm", Locale.getDefault())

@Composable
private fun snapshotLabel(epochMs: Long): String {
    val zone = ZoneId.systemDefault()
    val zoned = Instant.ofEpochMilli(epochMs).atZone(zone)
    val today = LocalDate.now(zone)
    val pointDay = zoned.toLocalDate()
    val hhmm = TIME_FMT.format(zoned)
    return when (pointDay) {
        today -> stringResource(R.string.history_snapshot_today, hhmm)
        today.minusDays(1) -> stringResource(R.string.history_snapshot_yesterday, hhmm)
        else -> DATE_FMT.format(zoned)
    }
}
