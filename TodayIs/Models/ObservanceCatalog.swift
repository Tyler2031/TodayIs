import Foundation

/// Loads the bundled dataset and answers "what's on this date?" queries.
/// Resolved dates are cached per calendar year.
final class ObservanceCatalog: ObservableObject {

    static let shared = ObservanceCatalog()

    /// Where `observances.json` lives: the SwiftPM resource bundle when built as a
    /// package (`swift test`), the app bundle when built inside the Xcode app target.
    static var resourceBundle: Bundle {
        #if SWIFT_PACKAGE
        return .module
        #else
        return .main
        #endif
    }

    let all: [Observance]
    private let calendar: Calendar
    private var resolvedCache: [Int: [ResolvedObservance]] = [:]

    private struct ResolvedObservance {
        let date: Date          // startOfDay
        let observance: Observance
    }

    init(calendar: Calendar = .current, bundle: Bundle = ObservanceCatalog.resourceBundle, resource: String = "observances") {
        var cal = calendar
        cal.locale = Locale(identifier: "en_US_POSIX")
        self.calendar = cal

        guard let url = bundle.url(forResource: resource, withExtension: "json") else {
            assertionFailure("Missing \(resource).json in bundle")
            self.all = []
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(ObservanceFile.self, from: data)
            self.all = file.observances
        } catch {
            assertionFailure("Failed to decode \(resource).json: \(error)")
            self.all = []
        }
    }

    // MARK: - Resolution

    private func resolved(forYear year: Int) -> [ResolvedObservance] {
        if let cached = resolvedCache[year] { return cached }
        let list = all.compactMap { obs -> ResolvedObservance? in
            guard let d = obs.resolvedDate(inYear: year, calendar: calendar) else { return nil }
            return ResolvedObservance(date: d, observance: obs)
        }
        resolvedCache[year] = list
        return list
    }

    // MARK: - Queries

    /// Observances on a given day for a category, sorted primary-first (priority desc, then title).
    func observances(on day: Date, category: ObservanceCategory) -> [Observance] {
        let start = calendar.startOfDay(for: day)
        let year = calendar.component(.year, from: start)
        return resolved(forYear: year)
            .filter { $0.date == start && $0.observance.category == category }
            .map(\.observance)
            .sorted(by: Self.primaryOrder)
    }

    /// The single featured observance for a day/category, or nil.
    func primary(on day: Date, category: ObservanceCategory) -> Observance? {
        observances(on: day, category: category).first
    }

    /// Grouped day-by-day results across a date range (inclusive), skipping empty days.
    func days(from startDay: Date, through endDay: Date, category: ObservanceCategory) -> [DayObservances] {
        let start = calendar.startOfDay(for: startDay)
        let end = calendar.startOfDay(for: endDay)
        guard start <= end else { return [] }

        var result: [DayObservances] = []
        var cursor = start
        while cursor <= end {
            let hits = observances(on: cursor, category: category)
            if !hits.isEmpty {
                result.append(DayObservances(date: cursor, observances: hits))
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// Next `count` days (from `start`) that have at least one observance in the category.
    func upcoming(from start: Date = Date(), count: Int, category: ObservanceCategory) -> [DayObservances] {
        let startDay = calendar.startOfDay(for: start)
        guard let end = calendar.date(byAdding: .day, value: 400, to: startDay) else { return [] }
        return Array(days(from: startDay, through: end, category: category).prefix(count))
    }

    private static func primaryOrder(_ a: Observance, _ b: Observance) -> Bool {
        if a.priority != b.priority { return a.priority > b.priority }
        return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
    }
}
