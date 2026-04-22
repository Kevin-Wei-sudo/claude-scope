package io.sandwichlab.claudescope.ui.widget.components

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.SectionTitle
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Teal

@Composable
fun InstallTipCard(modifier: Modifier = Modifier) {
    var showDialog by remember { mutableStateOf(false) }

    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.widget_install_title))
        Spacer(Modifier.size(8.dp))
        Text(
            text = stringResource(R.string.widget_install_instructions),
            color = SubtitleText,
            style = MaterialTheme.typography.bodyMedium,
        )
        Spacer(Modifier.size(12.dp))
        Button(
            onClick = { showDialog = true },
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(50),
            colors = ButtonDefaults.buttonColors(
                containerColor = Teal,
                contentColor = Color.White,
            ),
        ) {
            Text(stringResource(R.string.widget_install_cta))
        }
    }

    if (showDialog) {
        AlertDialog(
            onDismissRequest = { showDialog = false },
            confirmButton = {
                TextButton(onClick = { showDialog = false }) {
                    Text(stringResource(R.string.widget_install_dialog_ok))
                }
            },
            title = { Text(stringResource(R.string.widget_install_dialog_title)) },
            text = { Text(stringResource(R.string.widget_install_dialog_body)) },
        )
    }
}
