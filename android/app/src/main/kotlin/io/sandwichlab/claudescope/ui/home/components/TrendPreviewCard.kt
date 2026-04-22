package io.sandwichlab.claudescope.ui.home.components

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.theme.SubtitleText

@Composable
fun TrendPreviewCard(
    trend: List<Double>,
    modifier: Modifier = Modifier,
) {
    Column(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.home_trend_preview))
        Spacer(Modifier.size(4.dp))
        Text(
            text = stringResource(R.string.home_trend_subtitle),
            color = SubtitleText,
            style = MaterialTheme.typography.bodyMedium,
        )
        Spacer(Modifier.size(8.dp))
        if (trend.size >= 2) {
            MiniBarChart(
                points = trend,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(60.dp),
            )
        } else {
            Text(
                text = stringResource(R.string.home_trend_empty),
                color = SubtitleText,
                style = MaterialTheme.typography.bodySmall,
                modifier = Modifier.height(60.dp),
            )
        }
    }
}
