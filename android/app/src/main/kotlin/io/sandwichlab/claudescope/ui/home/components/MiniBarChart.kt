package io.sandwichlab.claudescope.ui.home.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.ui.theme.Teal
import io.sandwichlab.claudescope.ui.theme.Terracotta
import kotlin.math.max

/**
 * Mini bar chart matching iOS `MiniBarChart` — older points terracotta, latest
 * teal, bar height scaled to the max point in the series.
 *
 * [points] is already normalized into the 0..1 range.
 */
@Composable
fun MiniBarChart(
    points: List<Double>,
    modifier: Modifier = Modifier,
) {
    if (points.isEmpty()) return
    val maxValue = max(points.max(), 0.01)
    val lastIndex = points.size - 1

    Canvas(modifier = modifier.fillMaxSize()) {
        val spacingPx = 3.dp.toPx()
        val totalSpacing = spacingPx * (points.size - 1)
        val barWidth = max(4.dp.toPx(), (size.width - totalSpacing) / points.size)
        val minBarHeight = 4.dp.toPx()
        val cornerRadius = CornerRadius(3.dp.toPx(), 3.dp.toPx())

        points.forEachIndexed { index, value ->
            val normalized = value / maxValue
            val barHeight = max(minBarHeight.toDouble(), size.height * normalized).toFloat()
            val x = index * (barWidth + spacingPx)
            val y = size.height - barHeight
            drawRoundRect(
                color = if (index == lastIndex) Teal else Terracotta,
                topLeft = Offset(x, y),
                size = Size(barWidth, barHeight),
                cornerRadius = cornerRadius,
            )
        }
    }
}
