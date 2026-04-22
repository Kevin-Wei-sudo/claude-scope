package io.sandwichlab.claudescope.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.ui.theme.CardBackground
import io.sandwichlab.claudescope.ui.theme.CardShadowColor

@Composable
fun CardView(
    modifier: Modifier = Modifier,
    content: @Composable ColumnScope.() -> Unit
) {
    val shape = RoundedCornerShape(16.dp)
    Column(
        modifier = modifier
            .shadow(
                elevation = 2.dp,
                shape = shape,
                ambientColor = CardShadowColor,
                spotColor = CardShadowColor
            )
            .clip(shape)
            .background(CardBackground)
            .padding(16.dp),
        content = content
    )
}
