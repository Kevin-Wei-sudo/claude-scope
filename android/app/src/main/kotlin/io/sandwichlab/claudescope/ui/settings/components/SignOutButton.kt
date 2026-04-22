package io.sandwichlab.claudescope.ui.settings.components

import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import io.sandwichlab.claudescope.R

@Composable
fun SignOutButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    OutlinedButton(
        onClick = onClick,
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(50),
    ) {
        Text(
            text = stringResource(R.string.settings_sign_out),
            color = MaterialTheme.colorScheme.error,
            style = MaterialTheme.typography.labelLarge,
        )
    }
}
