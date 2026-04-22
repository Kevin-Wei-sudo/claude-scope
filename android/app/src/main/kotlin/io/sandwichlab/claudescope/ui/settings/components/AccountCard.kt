package io.sandwichlab.claudescope.ui.settings.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.service.oauth.AuthState
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.home.rememberRelativeTime
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Teal
import java.time.Instant

@Composable
fun AccountCard(
    authState: AuthState,
    lastUpdatedEpochMs: Long?,
    isSyncing: Boolean,
    onSyncClick: () -> Unit,
    onSignInClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    CardView(modifier = modifier.fillMaxWidth()) {
        when (authState) {
            is AuthState.SignedIn -> {
                Text(
                    text = stringResource(R.string.settings_account_signed_in),
                    color = BodyText,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                )
                if (!authState.email.isNullOrBlank()) {
                    Spacer(Modifier.size(2.dp))
                    Text(
                        text = authState.email,
                        color = SubtitleText,
                        style = MaterialTheme.typography.bodySmall,
                    )
                }
                Spacer(Modifier.size(6.dp))
                val lastLabel = when {
                    lastUpdatedEpochMs == null -> stringResource(R.string.settings_account_never_refreshed)
                    else -> stringResource(
                        R.string.settings_account_last_refreshed,
                        rememberRelativeTime(Instant.ofEpochMilli(lastUpdatedEpochMs)),
                    )
                }
                Text(
                    text = lastLabel,
                    color = SubtitleText,
                    style = MaterialTheme.typography.bodySmall,
                )
                Spacer(Modifier.size(12.dp))
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Button(
                        onClick = onSyncClick,
                        enabled = !isSyncing,
                        shape = RoundedCornerShape(50),
                        colors = ButtonDefaults.buttonColors(
                            containerColor = Teal,
                            contentColor = Color.White,
                        ),
                    ) {
                        if (isSyncing) {
                            CircularProgressIndicator(
                                modifier = Modifier.size(14.dp),
                                color = Color.White,
                                strokeWidth = 2.dp,
                            )
                            Spacer(Modifier.size(8.dp))
                        }
                        Text(stringResource(R.string.settings_sync_now))
                    }
                }
            }

            AuthState.SignedOut, AuthState.Unknown -> {
                Text(
                    text = stringResource(R.string.settings_account_not_signed_in),
                    color = BodyText,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                )
                Spacer(Modifier.size(4.dp))
                Text(
                    text = stringResource(R.string.settings_account_sign_in_hint),
                    color = SubtitleText,
                    style = MaterialTheme.typography.bodySmall,
                )
                Spacer(Modifier.size(12.dp))
                Button(
                    onClick = onSignInClick,
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(50),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Teal,
                        contentColor = Color.White,
                    ),
                ) {
                    Text(stringResource(R.string.settings_sign_in_cta))
                }
            }
        }
    }
}
