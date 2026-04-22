package io.sandwichlab.claudescope.ui.theme

import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Shapes
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.dp

private val LightColors = lightColorScheme(
    primary = Teal,
    onPrimary = androidx.compose.ui.graphics.Color.White,
    primaryContainer = TealLight,
    onPrimaryContainer = TealDark,
    secondary = Terracotta,
    onSecondary = androidx.compose.ui.graphics.Color.White,
    secondaryContainer = TerracottaLight,
    onSecondaryContainer = TerracottaDark,
    background = AppBackground,
    onBackground = BodyText,
    surface = CardBackground,
    onSurface = BodyText,
    surfaceVariant = PillInactiveBg,
    onSurfaceVariant = SubtitleText
)

val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(6.dp),
    small = RoundedCornerShape(10.dp),
    medium = RoundedCornerShape(16.dp),
    large = RoundedCornerShape(20.dp),
    extraLarge = RoundedCornerShape(28.dp)
)

@Composable
fun ClaudeScopeTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = LightColors,
        typography = AppTypography,
        shapes = AppShapes,
        content = content
    )
}
