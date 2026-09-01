import SwiftUI

@main
struct TodayIsApp: App {

    @StateObject private var settings = AppSettings()
    @StateObject private var catalog = ObservanceCatalog.shared
    @StateObject private var notifications = NotificationManager.shared

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(settings)
                .environmentObject(catalog)
                .environmentObject(notifications)
                .task {
                    await notifications.refreshAuthorizationStatus()
                    await notifications.reschedule(settings: settings, catalog: catalog)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task {
                    await notifications.refreshAuthorizationStatus()
                    await notifications.reschedule(settings: settings, catalog: catalog)
                }
            }
        }
    }
}
