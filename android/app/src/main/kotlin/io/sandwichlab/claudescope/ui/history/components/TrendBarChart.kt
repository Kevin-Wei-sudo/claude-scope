package io.sandwichlab.claudescope.ui.history.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.sandwichlab.claudescope.data.model.UsageDataPoint
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Teal
import io.sandwichlab.claudescope.ui.theme.Terracotta
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import kotlin.math.max

/**
 * Larger variant of the Home MiniBarChart: 140dp tall, with 3-letter weekday
 * labels under each bar. Matches iOS `HistoryView.trendBarChart`.
 *
 * Reserves the bottom ~15% for day labels so bars never overlap text.
 */
@Composable
fun TrendBarChart(
    points: List<UsageDataPoint>,
    modifier: Modifier = Modifier,
) {
    if (points.size < 2) return

    val maxValue = max(points.maxOf { it.pct7d }, 0.01)
    val lastIndex = points.size - 1

    Column(modifier = modifier
        .fillMaxWidth()
        .height(140.dp)) {

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .weight(0.82f),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.Bottom,
        ) {
            points.forEachIndexed { index, point ->
                val heightFraction = max(0.05f, (point.pct7d / maxValue).toFloat()).coerceAtMost(1f)
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(heightFraction)
                        .clip(RoundedCornerShape(4.dp))
                        .background(if (index == lastIndex) Teal else Terracotta),
                )
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .weight(0.18f),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            points.forEach { point ->
                Text(
                    text = dayLabel(point.timestampEpochMs),
                    color = SubtitleText,
                    fontSize = 9.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

private val DAY_FORMATTER: DateTimeFormatter =
    DateTimeFormatter.ofPattern("EEE", Locale.getDefault())

private fun dayLabel(epochMs: Long): String {
    val zoned = Instant.ofEpochMilli(epochMs).atZone(ZoneId.systemDefault())
    return DAY_FORMATTER.format(zoned).take(3)
}
