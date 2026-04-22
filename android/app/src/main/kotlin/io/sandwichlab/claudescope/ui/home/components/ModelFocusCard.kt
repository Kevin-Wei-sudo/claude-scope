package io.sandwichlab.claudescope.ui.home.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.components.UsageProgressBar
import io.sandwichlab.claudescope.ui.home.rememberRelativeTime
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Terracotta
import java.time.Instant
import kotlin.math.roundToInt

@Composable
fun ModelFocusCard(
    sonnetPct: Double,
    reset7d: Instant?,
    modifier: Modifier = Modifier,
) {
    val pct = (sonnetPct * 100).roundToInt().coerceIn(0, 999)
    val relative = rememberRelativeTime(reset7d)

    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.home_model_focus))
        Spacer(Modifier.size(10.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(Terracotta),
            )
            Spacer(Modifier.size(8.dp))
            Text(
                text = stringResource(R.string.home_model_sonnet_row),
                color = BodyText,
                style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
            )
        }
        Spacer(Modifier.size(8.dp))
        Row(verticalAlignment = Alignment.Bottom) {
            Text(
                text = stringResource(R.string.home_model_used_prefix),
                color = SubtitleText,
                style = MaterialTheme.typography.bodySmall,
            )
            Text(
                text = "$pct%",
                color = BodyText,
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
            )
        }
        Spacer(Modifier.size(8.dp))
        UsageProgressBar(value = sonnetPct.toFloat(), tint = Terracotta)
        if (reset7d != null) {
            Spacer(Modifier.size(8.dp))
            Row {
                Text(
                    text = stringResource(R.string.home_resets_label) + " ",
                    color = SubtitleText,
                    style = MaterialTheme.typography.bodySmall,
                )
                Text(
                    text = relative,
                    color = SubtitleText,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
    }
}
