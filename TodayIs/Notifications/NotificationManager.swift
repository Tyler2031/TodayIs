import Foundation
import UserNotifications

/// Schedules daily local notifications. No server: we pre-schedule a rolling
/// window of individual notifications and re-arm every time the app becomes active.
@MainActor
final class NotificationManager: NSObject, ObservableObject {

    static let shared = NotificationManager()

    /// How many days ahead we keep scheduled at any time.
    private let windowDays = 14
    private let identifierPrefix = "todayis.daily."

    @Published private(set) var authorization: UNAuthorizationStatus = .notDetermined

    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    // MARK: - Authorization

    func refreshAuthorizationStatus() async {
        let settings = await center.notificationSettings()
        authorization = settings.authorizationStatus
    }

    /// Returns true if we are authorized after the call.
    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await refreshAuthorizationStatus()
            return granted
        } catch {
            await refreshAuthorizationStatus()
            return false
        }
    }

    // MARK: - Scheduling

    /// Clears our pending notifications and, if enabled + authorized, schedules the next `windowDays`.
    func reschedule(settings: AppSettings, catalog: ObservanceCatalog, calendar: Calendar = .current) async {
        await cancelAll()

        guard settings.notificationsEnabled else { return }
        await refreshAuthorizationStatus()
        guard authorization == .authorized || authorization == .provisional else { return }

        let category = settings.notifyCategory
        let today = calendar.startOfDay(for: Date())

        for offset in 0..<windowDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let hits = catalog.observances(on: day, category: category)
            guard let primary = hits.first else { continue }

            // Skip today if the fire time has already passed.
            var fire = calendar.dateComponents([.year, .month, .day], from: day)
            fire.hour = settings.notifyHour
            fire.minute = settings.notifyMinute
            if offset == 0, let fireDate = calendar.date(from: fire), fireDate <= Date() {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = "Today is \(primary.title)"
            content.body = notificationBody(primary: primary, extraCount: hits.count - 1)
            content.sound = .default
            content.userInfo = ["observanceID": primary.id]

            let trigger = UNCalendarNotificationTrigger(dateMatching: fire, repeats: false)
            let request = UNNotificationRequest(
                identifier: "\(identifierPrefix)\(offset)",
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }

    private func notificationBody(primary: Observance, extraCount: Int) -> String {
        var body = primary.blurb.isEmpty ? "Tap to see what today is about." : primary.blurb
        if extraCount == 1 {
            body += " (+1 more observance today)"
        } else if extraCount > 1 {
            body += " (+\(extraCount) more observances today)"
        }
        return body
    }

    func cancelAll() async {
        let pending = await center.pendingNotificationRequests()
        let ids = pending.map(\.identifier).filter { $0.hasPrefix(identifierPrefix) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    #if DEBUG
    /// Fires a test notification ~5 seconds out using today's primary observance.
    func sendTestNotification(settings: AppSettings, catalog: ObservanceCatalog) async {
        guard let primary = catalog.primary(on: Date(), category: settings.notifyCategory)
            ?? catalog.primary(on: Date(), category: .general) else { return }
        let content = UNMutableNotificationContent()
        content.title = "Today is \(primary.title)"
        content.body = primary.blurb
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false)
        try? await center.add(UNNotificationRequest(identifier: "todayis.test", content: content, trigger: trigger))
    }
    #endif
}

// MARK: - Foreground presentation

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
