package io.sandwichlab.claudescope.ui.settings

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.lifecycle.viewmodel.compose.viewModel
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.service.oauth.AuthState
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.settings.components.AccountCard
import io.sandwichlab.claudescope.ui.settings.components.LanguageCard
import io.sandwichlab.claudescope.ui.settings.components.NotificationsCard
import io.sandwichlab.claudescope.ui.settings.components.RefreshRhythmCard
import io.sandwichlab.claudescope.ui.settings.components.SignOutButton
import io.sandwichlab.claudescope.ui.signin.AuthViewModel
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText

@Composable
fun SettingsScreen(
    modifier: Modifier = Modifier,
    viewModel: SettingsViewModel = viewModel(factory = SettingsViewModel.Factory),
    authViewModel: AuthViewModel = viewModel(factory = AuthViewModel.Factory),
) {
    val state by viewModel.uiState.collectAsState()
    val isSignedIn = state.authState is AuthState.SignedIn
    val context = LocalContext.current

    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted ->
        if (!granted) {
            // User denied → keep the preference off so UI matches reality.
            viewModel.setNotificationsEnabled(false)
        }
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp, vertical = 12.dp)
            .padding(bottom = 24.dp),
        verticalArrangement = Arrangement.spacedBy(20.dp),
    ) {
        SectionTitle(stringResource(R.string.settings_section_title))
        Text(
            text = stringResource(R.string.settings_headline),
            color = BodyText,
            style = MaterialTheme.typography.titleLarge,
        )
        Text(
            text = stringResource(R.string.settings_subheading),
            color = SubtitleText,
            style = MaterialTheme.typography.bodyMedium,
        )

        AccountCard(
            authState = state.authState,
            lastUpdatedEpochMs = state.lastUpdatedEpochMs,
            isSyncing = state.isSyncing,
            onSyncClick = viewModel::sync,
            onSignInClick = authViewModel::onSignInClick,
        )

        LanguageCard(
            language = state.settings.language,
            onSelect = viewModel::setLanguage,
        )

        NotificationsCard(
            enabled = state.settings.notificationsEnabled,
            threshold = state.settings.notificationThreshold,
            onToggleEnabled = { enabled ->
                if (enabled && Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    val granted = ContextCompat.checkSelfPermission(
                        context,
                        Manifest.permission.POST_NOTIFICATIONS,
                    ) == PackageManager.PERMISSION_GRANTED
                    if (!granted) {
                        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                        viewModel.setNotificationsEnabled(true)
                        return@NotificationsCard
                    }
                }
                viewModel.setNotificationsEnabled(enabled)
            },
            onThresholdChange = viewModel::setThreshold,
        )

        RefreshRhythmCard(
            pollingMinutes = state.settings.pollingMinutes,
            onSelect = viewModel::setPollingMinutes,
        )

        if (isSignedIn) {
            SignOutButton(onClick = viewModel::signOut)
        }
    }
}
