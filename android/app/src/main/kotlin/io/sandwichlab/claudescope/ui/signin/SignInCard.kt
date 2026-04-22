package io.sandwichlab.claudescope.ui.signin

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.PersonAddAlt1
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Teal
import io.sandwichlab.claudescope.ui.theme.TealLight

@Composable
fun SignInCard(
    state: AuthUiState,
    onSignInClick: () -> Unit,
    onSubmitCode: (String) -> Unit,
    onCancel: () -> Unit,
    modifier: Modifier = Modifier,
) {
    CardView(modifier = modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(TealLight),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Filled.PersonAddAlt1,
                    contentDescription = null,
                    tint = Teal,
                )
            }
            Spacer(Modifier.size(12.dp))
            Column {
                Text(
                    text = stringResource(R.string.signin_banner_title),
                    color = BodyText,
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                )
                Text(
                    text = stringResource(R.string.signin_banner_body),
                    color = SubtitleText,
                    style = MaterialTheme.typography.bodyMedium,
                )
            }
        }

        Spacer(Modifier.size(16.dp))

        when (state) {
            is AuthUiState.AwaitingCode -> CodeEntry(
                state = state,
                onSubmit = onSubmitCode,
                onCancel = onCancel,
            )
            else -> SignInButton(onClick = onSignInClick)
        }
    }
}

@Composable
private fun SignInButton(onClick: () -> Unit) {
    Button(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(50),
        colors = ButtonDefaults.buttonColors(containerColor = Teal, contentColor = Color.White),
    ) {
        Text(
            text = stringResource(R.string.signin_button),
            style = MaterialTheme.typography.labelLarge,
        )
    }
}

@Composable
private fun CodeEntry(
    state: AuthUiState.AwaitingCode,
    onSubmit: (String) -> Unit,
    onCancel: () -> Unit,
) {
    var code by rememberSaveable { mutableStateOf("") }

    Text(
        text = stringResource(R.string.code_entry_prompt),
        color = BodyText,
        style = MaterialTheme.typography.bodyMedium,
    )
    Spacer(Modifier.size(8.dp))
    OutlinedTextField(
        value = code,
        onValueChange = { code = it },
        singleLine = true,
        enabled = !state.isSubmitting,
        placeholder = { Text(stringResource(R.string.code_entry_placeholder)) },
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = OutlinedTextFieldDefaults.colors(
            focusedBorderColor = Teal,
            unfocusedBorderColor = SubtitleText,
        ),
    )

    if (state.errorMessage != null) {
        Spacer(Modifier.size(6.dp))
        Text(
            text = state.errorMessage,
            color = MaterialTheme.colorScheme.error,
            style = MaterialTheme.typography.bodySmall,
        )
    }

    Spacer(Modifier.size(12.dp))
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.End,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        TextButton(
            onClick = onCancel,
            enabled = !state.isSubmitting,
        ) {
            Text(
                text = stringResource(R.string.button_cancel),
                color = SubtitleText,
            )
        }
        Spacer(Modifier.size(4.dp))
        Button(
            onClick = { onSubmit(code) },
            enabled = !state.isSubmitting && code.isNotBlank(),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(containerColor = Teal, contentColor = Color.White),
        ) {
            if (state.isSubmitting) {
                CircularProgressIndicator(
                    modifier = Modifier.size(16.dp),
                    color = Color.White,
                    strokeWidth = 2.dp,
                )
                Spacer(Modifier.size(8.dp))
            }
            Text(
                text = stringResource(R.string.button_submit),
                style = MaterialTheme.typography.labelLarge,
            )
        }
    }
}
