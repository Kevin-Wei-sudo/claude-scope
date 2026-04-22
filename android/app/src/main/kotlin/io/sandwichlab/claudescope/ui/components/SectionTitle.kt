package io.sandwichlab.claudescope.ui.components

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.sp
import io.sandwichlab.claudescope.ui.theme.Teal
import java.util.Locale

@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text = text.uppercase(Locale.getDefault()),
        color = Teal,
        style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 2.sp),
        modifier = modifier
    )
}
