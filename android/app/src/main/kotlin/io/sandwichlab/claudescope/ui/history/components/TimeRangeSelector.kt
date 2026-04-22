package io.sandwichlab.claudescope.ui.history.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.data.model.TimeRange
import io.sandwichlab.claudescope.ui.theme.BodyText
import io.sandwichlab.claudescope.ui.theme.PillInactiveBg
import io.sandwichlab.claudescope.ui.theme.Teal

@Composable
fun TimeRangeSelector(
    selected: TimeRange,
    onSelect: (TimeRange) -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(50))
            .background(PillInactiveBg),
    ) {
        TimeRange.entries.forEach { range ->
            val isSelected = range == selected
            Box(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(50))
                    .background(if (isSelected) Teal else Color.Transparent)
                    .clickable { onSelect(range) }
                    .padding(vertical = 8.dp),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = range.label,
                    color = if (isSelected) Color.White else BodyText,
                    style = MaterialTheme.typography.labelMedium,
                )
            }
        }
    }
}
