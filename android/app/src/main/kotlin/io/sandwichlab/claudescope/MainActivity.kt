package io.sandwichlab.claudescope

import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.browser.customtabs.CustomTabColorSchemeParams
import androidx.browser.customtabs.CustomTabsIntent
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.lifecycle.viewmodel.compose.viewModel
import io.sandwichlab.claudescope.ui.nav.RootNavigation
import io.sandwichlab.claudescope.ui.signin.AuthEvent
import io.sandwichlab.claudescope.ui.signin.AuthViewModel
import io.sandwichlab.claudescope.ui.theme.AppLanguageProvider
import io.sandwichlab.claudescope.ui.theme.ClaudeScopeTheme

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        val settingsService = (application as ClaudeScopeApp).settingsService

        setContent {
            val settings by settingsService.settings.collectAsState()
            val authViewModel: AuthViewModel = viewModel(factory = AuthViewModel.Factory)

            LaunchedEffect(Unit) {
                authViewModel.events.collect { event ->
                    when (event) {
                        is AuthEvent.OpenAuthorizationUrl -> launchCustomTab(event.url)
                    }
                }
            }

            AppLanguageProvider(language = settings.language) {
                ClaudeScopeTheme {
                    RootNavigation()
                }
            }
        }
    }

    private fun launchCustomTab(url: String) {
        val colorSchemeParams = CustomTabColorSchemeParams.Builder()
            .setToolbarColor(TEAL_TOOLBAR_ARGB)
            .build()
        val intent = CustomTabsIntent.Builder()
            .setDefaultColorSchemeParams(colorSchemeParams)
            .setShowTitle(true)
            .build()
        intent.launchUrl(this, Uri.parse(url))
    }

    companion object {
        private const val TEAL_TOOLBAR_ARGB = 0xFF2E8C80.toInt()
    }
}
