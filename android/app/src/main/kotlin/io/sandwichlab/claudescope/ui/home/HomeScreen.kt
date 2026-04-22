package io.sandwichlab.claudescope.ui.home

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
import io.sandwichlab.claudescope.ui.home.components.ModelFocusCard
import io.sandwichlab.claudescope.ui.home.components.TodaySnapshotCard
import io.sandwichlab.claudescope.ui.home.components.TrendPreviewCard
import io.sandwichlab.claudescope.ui.home.components.WindowCardsRow
import io.sandwichlab.claudescope.ui.signin.AuthUiState
import io.sandwichlab.claudescope.ui.signin.AuthViewModel
import io.sandwichlab.claudescope.ui.signin.SignInCard
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText

@Composable
fun HomeScreen(
    modifier: Modifier = Modifier,
    authViewModel: AuthViewModel = viewModel(factory = AuthViewModel.Factory),
    homeViewModel: HomeViewModel = viewModel(factory = HomeViewModel.Factory),
) {
    val authState by authViewModel.uiState.collectAsState()
    val content by homeViewModel.content.collectAsState()

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 12.dp)
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        SectionTitle(stringResource(R.string.home_section_title))
        Text(
            text = stringResource(R.string.home_headline),
            color = BodyText,
            style = MaterialTheme.typography.titleLarge,
        )
        Text(
            text = stringResource(R.string.home_subheading),
            color = SubtitleText,
            style = MaterialTheme.typography.bodyMedium,
        )

        if (authState is AuthUiState.SignedOut || authState is AuthUiState.AwaitingCode) {
            SignInCard(
                state = authState,
                onSignInClick = authViewModel::onSignInClick,
                onSubmitCode = authViewModel::onSubmitCode,
                onCancel = authViewModel::onCancelCodeEntry,
            )
        }

        TodaySnapshotCard(
            pct7d = content.pct7d,
            reset7d = content.reset7d,
            isLive = content.isLive,
        )

        WindowCardsRow(
            pct5h = content.pct5h,
            pct7d = content.pct7d,
            reset5h = content.reset5h,
            reset7d = content.reset7d,
        )

        ModelFocusCard(
            sonnetPct = content.sonnetPct,
            reset7d = content.reset7d,
        )

        TrendPreviewCard(trend = content.trend)
    }
}
