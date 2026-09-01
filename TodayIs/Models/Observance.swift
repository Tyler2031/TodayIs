import Foundation

// MARK: - Category

/// Content buckets. `adult` is gated behind an explicit opt-in in Settings.
enum ObservanceCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case general
    case funny
    case adult

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .general: return "General"
        case .funny:   return "Funny"
        case .adult:   return "18+"
        }
    }

    /// Categories a user can pick without unlocking anything.
    static var safeCases: [ObservanceCategory] { [.general, .funny] }

    var requiresUnlock: Bool { self == .adult }
}

// MARK: - Scheduling

/// A fixed calendar date, e.g. { month: 7, day: 4 }.
struct FixedDate: Codable, Hashable {
    let month: Int   // 1...12
    let day: Int     // 1...31
}

/// A floating rule: the Nth weekday of a month.
/// weekday: 1 = Sunday ... 7 = Saturday (matches Foundation.Calendar).
/// ordinal: 1...5 = nth occurrence; -1 = last occurrence in the month.
struct FloatingRule: Codable, Hashable {
    let month: Int
    let weekday: Int
    let ordinal: Int

    func resolvedDate(inYear year: Int, calendar: Calendar) -> Date? {
        if ordinal > 0 {
            var comps = DateComponents()
            comps.year = year
            comps.month = month
            comps.weekday = weekday
            comps.weekdayOrdinal = ordinal
            return calendar.date(from: comps)
        }

        // ordinal == -1: last matching weekday of the month.
        var startOfNextMonth = DateComponents()
        startOfNextMonth.year = year
        startOfNextMonth.month = month + 1   // Calendar normalizes month 13 -> Jan next year
        startOfNextMonth.day = 1
        guard let firstOfNext = calendar.date(from: startOfNextMonth),
              var cursor = calendar.date(byAdding: .day, value: -1, to: firstOfNext) else {
            return nil
        }
        for _ in 0..<7 {
            if calendar.component(.weekday, from: cursor) == weekday {
                return calendar.startOfDay(for: cursor)
            }
            guard let prev = calendar.date(byAdding: .day, value: -1, to: cursor) else { return nil }
            cursor = prev
        }
        return nil
    }
}

// MARK: - Observance

struct Observance: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let blurb: String
    let category: ObservanceCategory
    let tags: [String]
    /// Higher wins when a day has multiple observances in the same category.
    let priority: Int
    let source: String?

    // Exactly one of these is populated.
    let date: FixedDate?
    let rule: FloatingRule?

    enum CodingKeys: String, CodingKey {
        case id, title, blurb, category, tags, priority, source, date, rule
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        blurb = try c.decodeIfPresent(String.self, forKey: .blurb) ?? ""
        category = try c.decode(ObservanceCategory.self, forKey: .category)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        priority = try c.decodeIfPresent(Int.self, forKey: .priority) ?? 50
        source = try c.decodeIfPresent(String.self, forKey: .source)
        date = try c.decodeIfPresent(FixedDate.self, forKey: .date)
        rule = try c.decodeIfPresent(FloatingRule.self, forKey: .rule)
    }

    func resolvedDate(inYear year: Int, calendar: Calendar) -> Date? {
        if let date {
            var comps = DateComponents()
            comps.year = year
            comps.month = date.month
            comps.day = date.day
            return calendar.date(from: comps).map(calendar.startOfDay(for:))
        }
        return rule?.resolvedDate(inYear: year, calendar: calendar)
    }
}

// MARK: - File wrapper

struct ObservanceFile: Codable {
    let schemaVersion: Int
    let observances: [Observance]
}

// MARK: - Grouped result

/// All observances that land on a single calendar day, already sorted (primary first).
struct DayObservances: Identifiable, Hashable {
    let date: Date
    let observances: [Observance]

    var id: Date { date }
    var primary: Observance? { observances.first }
    var others: [Observance] { Array(observances.dropFirst()) }
}
