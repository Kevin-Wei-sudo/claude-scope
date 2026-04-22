package io.sandwichlab.claudescope.ui.home.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.components.UsageProgressBar
import io.sandwichlab.claudescope.ui.home.rememberRelativeTime
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Teal
import io.sandwichlab.claudescope.ui.theme.Terracotta
import java.time.Instant
import kotlin.math.roundToInt

@Composable
fun WindowCardsRow(
    pct5h: Double,
    pct7d: Double,
    reset5h: Instant?,
    reset7d: Instant?,
    modifier: Modifier = Modifier,
) {
    Row(modifier = modifier.fillMaxWidth()) {
        WindowCard(
            titleRes = R.string.home_window_5h,
            pct = pct5h,
            resetAt = reset5h,
            tint = Terracotta,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.width(12.dp))
        WindowCard(
            titleRes = R.string.home_window_7d,
            pct = pct7d,
            resetAt = reset7d,
            tint = Teal,
            modifier = Modifier.weight(1f),
        )
    }
}

@Composable
private fun WindowCard(
    titleRes: Int,
    pct: Double,
    resetAt: Instant?,
    tint: Color,
    modifier: Modifier = Modifier,
) {
    val pctValue = (pct * 100).roundToInt().coerceIn(0, 999)
    val relative = rememberRelativeTime(resetAt)
    CardView(modifier = modifier) {
        SectionTitle(stringResource(titleRes))
        Spacer(Modifier.size(6.dp))
        Text(
            text = "$pctValue%",
            color = BodyText,
            fontSize = 28.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = FontFamily.Default,
        )
        Spacer(Modifier.size(8.dp))
        UsageProgressBar(value = pct.toFloat(), tint = tint)
        if (resetAt != null) {
            Spacer(Modifier.size(8.dp))
            Text(
                text = stringResource(R.string.home_resets_label),
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
