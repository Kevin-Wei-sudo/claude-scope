package io.sandwichlab.claudescope.ui.history.components

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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Teal
import io.sandwichlab.claudescope.ui.theme.Terracotta
import kotlin.math.roundToInt

@Composable
fun ModelSplitCard(
    sonnetPct: Double,
    opusPct: Double,
    modifier: Modifier = Modifier,
) {
    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.history_model_split))
        Spacer(Modifier.size(14.dp))
        ModelRow(
            name = stringResource(R.string.history_model_sonnet),
            pct = sonnetPct,
            color = Terracotta,
        )
        Spacer(Modifier.size(10.dp))
        ModelRow(
            name = stringResource(R.string.history_model_opus),
            pct = opusPct,
            color = Teal,
        )
        Spacer(Modifier.size(14.dp))
        Text(
            text = stringResource(R.string.history_model_split_body),
            color = SubtitleText,
            style = MaterialTheme.typography.bodySmall,
        )
    }
}

@Composable
private fun ModelRow(name: String, pct: Double, color: Color) {
    val value = (pct * 100).roundToInt().coerceIn(0, 999)
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(color),
        )
        Spacer(Modifier.size(8.dp))
        Text(
            text = name,
            color = BodyText,
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Medium),
        )
        Spacer(Modifier.weight(1f))
        Text(
            text = "$value%",
            color = color,
            style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
        )
    }
}
