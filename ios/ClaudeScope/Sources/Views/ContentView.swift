import SwiftUI

struct ContentView: View {
    @EnvironmentObject var usageService: UsageService
    @State private var selectedTab = 0

    private var isEN: Bool { AppLanguage.stored.isEnglish }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tag(0)
                .tabItem { Label(isEN ? "Home" : "首页", systemImage: "house.fill") }

            HistoryView()
                .tag(1)
                .tabItem { Label(isEN ? "History" : "历史", systemImage: "chart.bar.fill") }

            WidgetSettingsView()
                .tag(2)
                .tabItem { Label(isEN ? "Widget" : "组件", systemImage: "square.text.square.fill") }

            SettingsView()
                .tag(3)
                .tabItem { Label(isEN ? "Settings" : "设置", systemImage: "gearshape.fill") }
        }
        .tabViewStyle(.tabBarOnly)
        .tint(Theme.teal)
        .onChange(of: selectedTab) { _, newValue in
            let tabNames = ["home", "history", "widget", "settings"]
            if newValue < tabNames.count {
                AnalyticsService.shared.trackTabSelected(tabNames[newValue])
            }
        }
    }
}
