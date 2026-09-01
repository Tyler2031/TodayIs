import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var catalog: ObservanceCatalog
    @EnvironmentObject private var notifications: NotificationManager

    @State private var showAdultConfirm = false
    @State private var notifyTime: Date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily Notification") {
                    Toggle("Send a daily notification", isOn: $settings.notificationsEnabled)

                    if settings.notificationsEnabled {
                        DatePicker("Time", selection: $notifyTime, displayedComponents: .hourAndMinute)

                        Picker("Feature category", selection: Binding(
                            get: { settings.notifyCategory },
                            set: { settings.notifyCategory = $0 }
                        )) {
                            ForEach(settings.availableCategories) { c in
                                Text(c.displayName).tag(c)
                            }
                        }

                        if notifications.authorization == .denied {
                            Label("Notifications are turned off in iOS Settings.", systemImage: "exclamationmark.triangle")
                                .font(.footnote)
                                .foregroundStyle(.orange)
                        }
                    }
                }

                Section {
                    Toggle("Show 18+ tab", isOn: Binding(
                        get: { settings.adultUnlocked },
                        set: { newValue in
                            if newValue { showAdultConfirm = true }
                            else { settings.adultUnlocked = false }
                        }
                    ))
                } header: {
                    Text("Adult Content")
                } footer: {
                    Text("Adds an 18+ category with adult humor. Off by default and kept separate from the General and Funny tabs.")
                }

                #if DEBUG
                Section("Developer") {
                    Button("Send test notification (5s)") {
                        Task { await notifications.sendTestNotification(settings: settings, catalog: catalog) }
                    }
                    Button("Re-arm scheduled notifications") {
                        Task { await notifications.reschedule(settings: settings, catalog: catalog) }
                    }
                }
                #endif

                Section {
                    LabeledContent("Observances in dataset", value: "\(catalog.all.count)")
                    LabeledContent("Schema version", value: "1")
                }
            }
            .navigationTitle("Settings")
            .onAppear { notifyTime = timeFromSettings() }
            .onChange(of: notifyTime) { _, newValue in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                settings.notifyHour = comps.hour ?? 8
                settings.notifyMinute = comps.minute ?? 0
                Task { await notifications.reschedule(settings: settings, catalog: catalog) }
            }
            .onChange(of: settings.notificationsEnabled) { _, enabled in
                Task {
                    if enabled { await notifications.requestAuthorization() }
                    await notifications.reschedule(settings: settings, catalog: catalog)
                }
            }
            .onChange(of: settings.notifyCategory) { _, _ in
                Task { await notifications.reschedule(settings: settings, catalog: catalog) }
            }
            .alert("Show 18+ content?", isPresented: $showAdultConfirm) {
                Button("Cancel", role: .cancel) { }
                Button("I'm 18 or older") { settings.adultUnlocked = true }
            } message: {
                Text("This unlocks a separate 18+ tab with adult humor. You can turn it off again anytime.")
            }
        }
    }

    private func timeFromSettings() -> Date {
        Calendar.current.date(
            bySettingHour: settings.notifyHour,
            minute: settings.notifyMinute,
            second: 0,
            of: Date()
        ) ?? Date()
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
        .environmentObject(ObservanceCatalog.shared)
        .environmentObject(NotificationManager.shared)
}
