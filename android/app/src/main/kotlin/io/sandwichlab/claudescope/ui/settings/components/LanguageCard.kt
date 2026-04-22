package io.sandwichlab.claudescope.ui.settings.components

import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.service.settings.AppLanguage
import io.sandwichlab.claudescope.ui.components.CardView
import io.sandwichlab.claudescope.ui.components.PillSelector
import io.sandwichlab.claudescope.ui.components.SectionTitle

@Composable
fun LanguageCard(
    language: AppLanguage,
    onSelect: (AppLanguage) -> Unit,
    modifier: Modifier = Modifier,
) {
    CardView(modifier = modifier.fillMaxWidth()) {
        SectionTitle(stringResource(R.string.settings_language_title))
        Spacer(Modifier.size(12.dp))
        val options = listOf(AppLanguage.System, AppLanguage.English, AppLanguage.SimplifiedChinese)
        PillSelector(
            options = options,
            selected = language,
            onSelect = onSelect,
            label = { stringResource(it.labelRes()) },
            modifier = Modifier.fillMaxWidth(),
        )
    }
}

private fun AppLanguage.labelRes(): Int = when (this) {
    AppLanguage.System -> R.string.settings_language_system
    AppLanguage.English -> R.string.settings_language_english
    AppLanguage.SimplifiedChinese -> R.string.settings_language_chinese
}
