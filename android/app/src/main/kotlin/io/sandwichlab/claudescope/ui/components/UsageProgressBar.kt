package io.sandwichlab.claudescope.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.ui.theme.ProgressTrack
import io.sandwichlab.claudescope.ui.theme.Teal

@Composable
fun UsageProgressBar(
    value: Float,
    modifier: Modifier = Modifier,
    tint: Color = Teal,
    height: Dp = 6.dp
) {
    val clamped = value.coerceIn(0f, 1f)
    val shape = RoundedCornerShape(50)
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .clip(shape)
            .background(ProgressTrack)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(clamped)
                .fillMaxHeight()
                .clip(shape)
                .background(tint)
        )
    }
}
