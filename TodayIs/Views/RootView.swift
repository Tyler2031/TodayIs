import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max") }

            BrowseView()
                .tabItem { Label("Browse", systemImage: "calendar") }

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

#Preview {
    RootView()
        .environmentObject(AppSettings())
        .environmentObject(ObservanceCatalog.shared)
        .environmentObject(NotificationManager.shared)
}
