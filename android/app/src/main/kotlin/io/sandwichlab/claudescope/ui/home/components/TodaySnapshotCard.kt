package io.sandwichlab.claudescope.ui.home.components

import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.home.rememberRelativeTime
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Teal
import java.time.Instant
import kotlin.math.roundToInt

@Composable
fun TodaySnapshotCard(
    pct7d: Double,
    reset7d: Instant?,
    isLive: Boolean,
    modifier: Modifier = Modifier,
) {
    val pct = (pct7d * 100).roundToInt().coerceIn(0, 999)
    val summaryRes = when {
        !isLive || pct < 40 -> R.string.home_summary_healthy
        pct < 70 -> R.string.home_summary_moderate
        else -> R.string.home_summary_high
    }
    val relative = rememberRelativeTime(reset7d)

    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.home_today_snapshot))
        Spacer(Modifier.size(8.dp))
        Text(
            text = "$pct%",
            color = Teal,
            fontSize = 48.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Default,
        )
        Spacer(Modifier.size(4.dp))
        Text(
            text = stringResource(summaryRes),
            color = SubtitleText,
            style = MaterialTheme.typography.bodyMedium,
        )
        if (reset7d != null) {
            Spacer(Modifier.size(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = stringResource(R.string.home_next_reset),
                    color = SubtitleText,
                    style = MaterialTheme.typography.bodySmall,
                )
                Text(
                    text = relative,
                    color = BodyText,
                    style = MaterialTheme.typography.bodySmall.copy(fontWeight = FontWeight.Medium),
                )
            }
        }
    }
}
