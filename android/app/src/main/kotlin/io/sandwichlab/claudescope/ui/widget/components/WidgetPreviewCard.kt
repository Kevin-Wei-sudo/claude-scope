package io.sandwichlab.claudescope.ui.widget.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
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
import io.sandwichlab.claudescope.ui.theme.PillInactiveBg
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Teal
import io.sandwichlab.claudescope.ui.theme.Terracotta
import java.time.Instant
import kotlin.math.roundToInt

/**
 * In-app preview of what the home-screen widget will look like with the current
 * show-5h / show-7d / show-reset toggles applied. Mirrors iOS
 * WidgetSettingsView's "live preview" card.
 */
@Composable
fun WidgetPreviewCard(
    pct5h: Double,
    pct7d: Double,
    resetAt: Instant?,
    show5h: Boolean,
    show7d: Boolean,
    showReset: Boolean,
    modifier: Modifier = Modifier,
) {
    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.widget_preview_title))
        Spacer(Modifier.size(12.dp))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(12.dp))
                .background(PillInactiveBg)
                .border(1.dp, SubtitleText.copy(alpha = 0.3f), RoundedCornerShape(12.dp))
                .padding(14.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "ClaudeScope",
                    color = SubtitleText,
                    style = MaterialTheme.typography.bodySmall,
                )
                Spacer(Modifier.weight(1f))
                Text(
                    text = "${(pct7d * 100).roundToInt()}%",
                    color = Teal,
                    fontWeight = FontWeight.Bold,
                    fontFamily = FontFamily.Default,
                    fontSize = 22.sp,
                )
            }
            if (show5h) {
                Spacer(Modifier.height(10.dp))
                PreviewRow(label = "5h", pct = pct5h, tint = Terracotta)
            }
            if (show7d) {
                Spacer(Modifier.height(8.dp))
                PreviewRow(label = "7d", pct = pct7d, tint = Teal)
            }
            if (showReset && resetAt != null) {
                Spacer(Modifier.height(10.dp))
                Text(
                    text = stringResource(R.string.widget_preview_resets, rememberRelativeTime(resetAt)),
                    color = SubtitleText,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
            if (!show5h && !show7d && !showReset) {
                Spacer(Modifier.height(10.dp))
                Box(
                    modifier = Modifier.fillMaxWidth().height(24.dp),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = "—",
                        color = SubtitleText,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }
        }
    }
}

@Composable
private fun PreviewRow(label: String, pct: Double, tint: androidx.compose.ui.graphics.Color) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, color = SubtitleText, style = MaterialTheme.typography.bodySmall)
        Spacer(Modifier.size(8.dp))
        UsageProgressBar(
            value = pct.toFloat(),
            tint = tint,
            modifier = Modifier.weight(1f),
        )
        Spacer(Modifier.size(8.dp))
        Text(
            text = "${(pct * 100).roundToInt()}%",
            color = BodyText,
            fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.bodySmall,
        )
    }
}
