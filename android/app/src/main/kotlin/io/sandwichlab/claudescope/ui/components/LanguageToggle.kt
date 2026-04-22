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
import io.sandwichlab.claudescope.ui.theme.Teal

enum class AppLanguage { English, SimplifiedChinese }

@Composable
fun LanguageToggle(
    language: AppLanguage,
    onChange: (AppLanguage) -> Unit,
    modifier: Modifier = Modifier
) {
    Row(modifier = modifier) {
        ToggleChip("EN", language == AppLanguage.English) { onChange(AppLanguage.English) }
        ToggleChip("中文", language == AppLanguage.SimplifiedChinese) { onChange(AppLanguage.SimplifiedChinese) }
    }
}

@Composable
private fun ToggleChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Text(
        text = label,
        color = if (selected) Color.White else BodyText,
        style = MaterialTheme.typography.labelMedium,
        modifier = Modifier
            .clip(RoundedCornerShape(50))
            .background(if (selected) Teal else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp)
    )
}
