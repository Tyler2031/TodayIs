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
                    Toggle("Show the After Hours tab", isOn: Binding(
                        get: { settings.adultUnlocked },
                        set: { newValue in
                            if newValue { showAdultConfirm = true }
                            else { settings.adultUnlocked = false }
                        }
                    ))
                } header: {
                    Text("After Hours")
                } footer: {
                    Text("Adds a set of observances with adult humor and drinking themes. Off by default and kept separate from the other tabs.")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                    Link("Privacy Policy",
                         destination: URL(string: "https://tyler2031.github.io/TodayIs/privacy.html")!)
                        .tint(Color.plannerAccent)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Settings")
            .toolbarBackground(Color.paper, for: .navigationBar)
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
            .alert("Show the After Hours tab?", isPresented: $showAdultConfirm) {
                Button("Not now", role: .cancel) { }
                Button("Show it") { settings.adultUnlocked = true }
            } message: {
                Text("This adds observances with adult humor and drinking themes. You can turn it off again anytime.")
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

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppSettings())
        .environmentObject(ObservanceCatalog.shared)
        .environmentObject(NotificationManager.shared)
}
