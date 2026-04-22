package io.sandwichlab.claudescope.ui.nav

import androidx.annotation.StringRes
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.BarChart
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Widgets
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import io.sandwichlab.claudescope.R
import io.sandwichlab.claudescope.service.analytics.AnalyticsService
import io.sandwichlab.claudescope.ui.history.HistoryScreen
import io.sandwichlab.claudescope.ui.home.HomeScreen
import io.sandwichlab.claudescope.ui.settings.SettingsScreen
import io.sandwichlab.claudescope.ui.theme.AppBackground
import io.sandwichlab.claudescope.ui.theme.SubtitleText
import io.sandwichlab.claudescope.ui.theme.Teal
import io.sandwichlab.claudescope.ui.widget.WidgetSettingsScreen

enum class RootTab(
    val route: String,
    @StringRes val labelRes: Int,
    val icon: ImageVector
) {
    Home("home", R.string.tab_home, Icons.Filled.Home),
    History("history", R.string.tab_history, Icons.Filled.BarChart),
    Widget("widget", R.string.tab_widget, Icons.Filled.Widgets),
    Settings("settings", R.string.tab_settings, Icons.Filled.Settings)
}

@Composable
fun RootNavigation() {
    val navController = rememberNavController()

    Scaffold(
        containerColor = AppBackground,
        bottomBar = {
            val backStackEntry by navController.currentBackStackEntryAsState()
            val currentRoute = backStackEntry?.destination?.route

            NavigationBar(containerColor = Color.White) {
                RootTab.entries.forEach { tab ->
                    val selected = backStackEntry?.destination?.hierarchy
                        ?.any { it.route == tab.route } == true || currentRoute == tab.route

                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            if (!selected) AnalyticsService.trackTabSelected(tab.route)
                            navController.navigate(tab.route) {
                                popUpTo(navController.graph.findStartDestination().id) {
                                    saveState = true
                                }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(tab.icon, contentDescription = null) },
                        label = { Text(stringResource(tab.labelRes)) },
                        colors = NavigationBarItemDefaults.colors(
                            selectedIconColor = Color.White,
                            selectedTextColor = Teal,
                            indicatorColor = Teal,
                            unselectedIconColor = SubtitleText,
                            unselectedTextColor = SubtitleText
                        )
                    )
                }
            }
        }
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = RootTab.Home.route,
            modifier = Modifier.padding(innerPadding)
        ) {
            composable(RootTab.Home.route) { HomeScreen() }
            composable(RootTab.History.route) { HistoryScreen() }
            composable(RootTab.Widget.route) { WidgetSettingsScreen() }
            composable(RootTab.Settings.route) { SettingsScreen() }
        }
    }
}
