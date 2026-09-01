import SwiftUI

struct RootView: View {
    init() {
        // Paper-colored tab bar to match the planner pages.
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.paper)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "book.closed") }

            BrowseView()
                .tabItem { Label("Calendar", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .tint(Color.plannerAccent)
    }
}

#Preview {
    RootView()
        .environmentObject(AppSettings())
        .environmentObject(ObservanceCatalog.shared)
        .environmentObject(NotificationManager.shared)
}
