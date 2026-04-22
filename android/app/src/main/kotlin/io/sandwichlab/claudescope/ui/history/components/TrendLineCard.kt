package io.sandwichlab.claudescope.ui.history.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import io.sandwichlab.claudescope.data.model.TimeRange
import io.sandwichlab.claudescope.data.model.UsageDataPoint
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import kotlin.math.roundToInt

@Composable
fun TrendLineCard(
    range: TimeRange,
    points: List<UsageDataPoint>,
    modifier: Modifier = Modifier,
) {
    val peakPct = (points.maxOfOrNull { it.pct7d } ?: 0.0).let { (it * 100).roundToInt() }

    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.history_trend_line))
        Spacer(Modifier.size(8.dp))
        Text(
            text = stringResource(R.string.history_peak_label, range.label, peakPct),
            color = BodyText,
            style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
        )
        Spacer(Modifier.size(12.dp))
        if (points.size >= 2) {
            TrendBarChart(points = points)
        } else {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(140.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = stringResource(R.string.history_trend_empty),
                    color = SubtitleText,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
        Spacer(Modifier.size(8.dp))
        Text(
            text = stringResource(R.string.history_trend_legend),
            color = SubtitleText,
            style = MaterialTheme.typography.bodySmall,
        )
    }
}
