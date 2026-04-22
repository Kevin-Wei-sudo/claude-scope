package io.sandwichlab.claudescope.ui.widget.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.material3.MaterialTheme
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

@Composable
fun VisibleSignalsCard(
    show5h: Boolean,
    show7d: Boolean,
    showReset: Boolean,
    onShow5hChange: (Boolean) -> Unit,
    onShow7dChange: (Boolean) -> Unit,
    onShowResetChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.widget_signals_title))
        Spacer(Modifier.size(8.dp))
        SignalRow(
            labelRes = R.string.widget_signals_show_5h,
            checked = show5h,
            onChange = onShow5hChange,
        )
        SignalRow(
            labelRes = R.string.widget_signals_show_7d,
            checked = show7d,
            onChange = onShow7dChange,
        )
        SignalRow(
            labelRes = R.string.widget_signals_show_reset,
            checked = showReset,
            onChange = onShowResetChange,
        )
    }
}

@Composable
private fun SignalRow(
    labelRes: Int,
    checked: Boolean,
    onChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            text = stringResource(labelRes),
            color = BodyText,
            style = MaterialTheme.typography.bodyMedium,
        )
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.White,
                checkedTrackColor = Teal,
                uncheckedThumbColor = Color.White,
            ),
        )
    }
}
