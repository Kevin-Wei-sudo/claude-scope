package io.sandwichlab.claudescope.ui.settings.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.Teal
import io.sandwichlab.claudescope.ui.theme.Terracotta

@Composable
fun NotificationsCard(
    enabled: Boolean,
    threshold: Int,
    onToggleEnabled: (Boolean) -> Unit,
    onThresholdChange: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.settings_notifications_title))
        Spacer(Modifier.size(10.dp))
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(
                text = stringResource(R.string.settings_threshold_alerts),
                color = BodyText,
                style = MaterialTheme.typography.bodyMedium,
            )
            Switch(
                checked = enabled,
                onCheckedChange = onToggleEnabled,
                colors = SwitchDefaults.colors(
                    checkedThumbColor = Color.White,
                    checkedTrackColor = Teal,
                    uncheckedThumbColor = Color.White,
                ),
            )
        }
        if (enabled) {
            Spacer(Modifier.size(8.dp))
            Text(
                text = stringResource(R.string.settings_threshold_warn_at, threshold),
                color = Teal,
                style = MaterialTheme.typography.bodyMedium,
            )
            Slider(
                value = threshold.toFloat(),
                onValueChange = { onThresholdChange(it.toInt()) },
                valueRange = 50f..100f,
                steps = 9,
                colors = SliderDefaults.colors(
                    thumbColor = Terracotta,
                    activeTrackColor = Terracotta,
                ),
            )
        }
    }
}
