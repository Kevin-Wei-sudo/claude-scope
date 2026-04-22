package io.sandwichlab.claudescope.ui.widget

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.widget.components.InstallTipCard
import io.sandwichlab.claudescope.ui.widget.components.VisibleSignalsCard
import io.sandwichlab.claudescope.ui.widget.components.WidgetPreviewCard
import io.sandwichlab.claudescope.ui.widget.components.WidgetSizeCard

@Composable
fun WidgetSettingsScreen(
    modifier: Modifier = Modifier,
    viewModel: WidgetSettingsViewModel = viewModel(factory = WidgetSettingsViewModel.Factory),
) {
    val state by viewModel.uiState.collectAsState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 12.dp)
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        SectionTitle(stringResource(R.string.widget_section_title))
        Text(
            text = stringResource(R.string.widget_headline),
            color = BodyText,
            style = MaterialTheme.typography.titleLarge,
        )
        Text(
            text = stringResource(R.string.widget_subheading),
            color = SubtitleText,
            style = MaterialTheme.typography.bodyMedium,
        )

        WidgetPreviewCard(
            pct5h = state.preview.pct5h,
            pct7d = state.preview.pct7d,
            resetAt = state.preview.reset7d,
            show5h = state.settings.widgetShow5h,
            show7d = state.settings.widgetShow7d,
            showReset = state.settings.widgetShowReset,
        )

        WidgetSizeCard(
            selected = state.settings.widgetPreferredSize,
            onSelect = viewModel::setPreferredSize,
        )

        VisibleSignalsCard(
            show5h = state.settings.widgetShow5h,
            show7d = state.settings.widgetShow7d,
            showReset = state.settings.widgetShowReset,
            onShow5hChange = viewModel::setShow5h,
            onShow7dChange = viewModel::setShow7d,
            onShowResetChange = viewModel::setShowReset,
        )

        InstallTipCard()
    }
}
