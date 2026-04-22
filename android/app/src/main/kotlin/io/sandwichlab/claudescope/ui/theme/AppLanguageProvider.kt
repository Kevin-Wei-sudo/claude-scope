package io.sandwichlab.claudescope.ui.theme

import android.content.res.Configuration
import androidx.activity.compose.LocalActivityResultRegistryOwner
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import io.sandwichlab.claudescope.service.settings.AppLanguage

/**
 * Wraps [content] with a Context/Configuration whose locale is the user's
 * in-app choice. `stringResource`, `DateUtils`, and any `Resources`-backed
 * lookup inside this subtree respect the override without restarting the
 * Activity.
 *
 * We also explicitly re-provide [LocalActivityResultRegistryOwner] because
 * `createConfigurationContext` returns a plain ContextWrapper that doesn't
 * implement ActivityResultRegistryOwner — without this, any composable
 * calling `rememberLauncherForActivityResult` (e.g. SettingsScreen's
 * notification permission request) would crash.
 */
@Composable
fun AppLanguageProvider(
    language: AppLanguage,
    content: @Composable () -> Unit,
) {
    val baseContext = LocalContext.current
    val baseConfig = LocalConfiguration.current
    val activityResultRegistryOwner = LocalActivityResultRegistryOwner.current!!

    val wrappedContext = remember(language, baseContext) {
        if (language == AppLanguage.System) {
            baseContext
        } else {
            val newConfig = Configuration(baseConfig).apply { setLocale(language.toLocale()) }
            baseContext.createConfigurationContext(newConfig)
        }
    }
    val wrappedConfig = remember(language, wrappedContext) {
        Configuration(wrappedContext.resources.configuration)
    }

    CompositionLocalProvider(
        LocalContext provides wrappedContext,
        LocalConfiguration provides wrappedConfig,
        LocalActivityResultRegistryOwner provides activityResultRegistryOwner,
        content = content,
    )
}
