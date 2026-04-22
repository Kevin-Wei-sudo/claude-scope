package io.sandwichlab.claudescope.ui.history

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
import io.sandwichlab.claudescope.ui.history.components.ModelSplitCard
import io.sandwichlab.claudescope.ui.history.components.RecentSnapshotsCard
import io.sandwichlab.claudescope.ui.history.components.TimeRangeSelector
import io.sandwichlab.claudescope.ui.history.components.TrendLineCard
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText

@Composable
fun HistoryScreen(
    modifier: Modifier = Modifier,
    viewModel: HistoryViewModel = viewModel(factory = HistoryViewModel.Factory),
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
        SectionTitle(stringResource(R.string.history_section_title))
        Text(
            text = stringResource(R.string.history_headline),
            color = BodyText,
            style = MaterialTheme.typography.titleLarge,
        )
        Text(
            text = stringResource(R.string.history_subheading),
            color = SubtitleText,
            style = MaterialTheme.typography.bodyMedium,
        )

        TrendLineCard(
            range = state.selectedRange,
            points = state.trendPoints,
        )

        TimeRangeSelector(
            selected = state.selectedRange,
            onSelect = viewModel::selectRange,
        )

        ModelSplitCard(
            sonnetPct = state.sonnetPct,
            opusPct = state.opusPct,
        )

        RecentSnapshotsCard(points = state.recentSnapshots)
    }
}
