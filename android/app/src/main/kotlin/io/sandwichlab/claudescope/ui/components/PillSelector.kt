package io.sandwichlab.claudescope.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.PillInactiveBg
import io.sandwichlab.claudescope.ui.theme.Teal

@Composable
fun <T> PillSelector(
    options: List<T>,
    selected: T,
    onSelect: (T) -> Unit,
    modifier: Modifier = Modifier,
    label: @Composable (T) -> String = { it.toString() }
) {
    Row(
        modifier = modifier
            .clip(RoundedCornerShape(50))
            .background(PillInactiveBg)
    ) {
        options.forEach { option ->
            val isSelected = option == selected
            Text(
                text = label(option),
                color = if (isSelected) Color.White else BodyText,
                style = MaterialTheme.typography.labelMedium,
                modifier = Modifier
                    .clip(RoundedCornerShape(50))
                    .background(if (isSelected) Teal else Color.Transparent)
                    .clickable { onSelect(option) }
                    .padding(horizontal = 16.dp, vertical = 8.dp)
            )
        }
    }
}
