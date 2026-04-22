package io.sandwichlab.claudescope.ui.widget.components

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.service.settings.WidgetSizePreset
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.PillSelector
import io.sandwichlab.claudescope.ui.components.SectionTitle

@Composable
fun WidgetSizeCard(
    selected: WidgetSizePreset,
    onSelect: (WidgetSizePreset) -> Unit,
    modifier: Modifier = Modifier,
) {
    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.widget_size_title))
        Spacer(Modifier.size(12.dp))
        val options = listOf(
            WidgetSizePreset.Small,
            WidgetSizePreset.Medium,
            WidgetSizePreset.Large,
        )
        PillSelector(
            options = options,
            selected = selected,
            onSelect = onSelect,
            label = { stringResource(it.labelRes()) },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

private fun WidgetSizePreset.labelRes(): Int = when (this) {
    WidgetSizePreset.Small -> R.string.widget_size_small
    WidgetSizePreset.Medium -> R.string.widget_size_medium
    WidgetSizePreset.Large -> R.string.widget_size_large
}
