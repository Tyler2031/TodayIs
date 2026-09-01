import Foundation
import Combine

/// User preferences, persisted in UserDefaults. No accounts, no sync.
/// Plain `ObservableObject` (not `@AppStorage`) so it composes cleanly as an
/// injected environment object and publishes changes reliably.
final class AppSettings: ObservableObject {

    private let defaults: UserDefaults

    private enum Key {
        static let notificationsEnabled = "notificationsEnabled"
        static let notifyHour = "notifyHour"
        static let notifyMinute = "notifyMinute"
        static let adultUnlocked = "adultUnlocked"
        static let notifyCategory = "notifyCategory"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.notificationsEnabled: false,
            Key.notifyHour: 8,
            Key.notifyMinute: 0,
            Key.adultUnlocked: false,
            Key.notifyCategory: ObservanceCategory.general.rawValue,
        ])
    }

    var notificationsEnabled: Bool {
        get { defaults.bool(forKey: Key.notificationsEnabled) }
        set { set(newValue, forKey: Key.notificationsEnabled) }
    }

    /// Local time the daily notification fires.
    var notifyHour: Int {
        get { defaults.integer(forKey: Key.notifyHour) }
        set { set(newValue, forKey: Key.notifyHour) }
    }
    var notifyMinute: Int {
        get { defaults.integer(forKey: Key.notifyMinute) }
        set { set(newValue, forKey: Key.notifyMinute) }
    }

    /// Whether the 18+ tab/content is available. Off by default.
    var adultUnlocked: Bool {
        get { defaults.bool(forKey: Key.adultUnlocked) }
        set { set(newValue, forKey: Key.adultUnlocked) }
    }

    /// Which category the daily notification features.
    var notifyCategory: ObservanceCategory {
        get { ObservanceCategory(rawValue: defaults.string(forKey: Key.notifyCategory) ?? "") ?? .general }
        set { set(newValue.rawValue, forKey: Key.notifyCategory) }
    }

    /// Categories the user is currently allowed to browse.
    var availableCategories: [ObservanceCategory] {
        adultUnlocked ? ObservanceCategory.allCases : ObservanceCategory.safeCases
    }

    var notifyTimeComponents: DateComponents {
        DateComponents(hour: notifyHour, minute: notifyMinute)
    }

    private func set<T>(_ value: T, forKey key: String) {
        objectWillChange.send()
        defaults.set(value, forKey: key)
    }
}
