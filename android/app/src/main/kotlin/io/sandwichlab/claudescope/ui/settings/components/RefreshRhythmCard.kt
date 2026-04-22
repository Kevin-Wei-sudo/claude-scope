package io.sandwichlab.claudescope.ui.settings.components

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.data.preferences.PollingDefaults
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.PillSelector
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.theme.SubtitleText

@Composable
fun RefreshRhythmCard(
    pollingMinutes: Int,
    onSelect: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.settings_refresh_title))
        Spacer(Modifier.size(4.dp))
        Text(
            text = stringResource(R.string.settings_refresh_description),
            color = SubtitleText,
            style = MaterialTheme.typography.bodySmall,
        )
        Spacer(Modifier.size(12.dp))
        PillSelector(
            options = PollingDefaults.OPTIONS,
            selected = pollingMinutes,
            onSelect = onSelect,
            label = { minutes -> minuteLabel(minutes) },
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.size(8.dp))
        Text(
            text = stringResource(R.string.settings_refresh_hint),
            color = SubtitleText,
            style = MaterialTheme.typography.bodySmall,
        )
    }
}

@Composable
private fun minuteLabel(minutes: Int): String = when (minutes) {
    15 -> stringResource(R.string.settings_refresh_15m)
    30 -> stringResource(R.string.settings_refresh_30m)
    60 -> stringResource(R.string.settings_refresh_1h)
    180 -> stringResource(R.string.settings_refresh_3h)
    else -> "${minutes}m"
}
