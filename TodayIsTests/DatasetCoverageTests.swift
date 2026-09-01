import XCTest
@testable import TodayIsCore

/// Dataset integrity + calendar-coverage checks.
///
/// Run from the repo root on macOS with:  swift test
/// (Inside the Xcode project instead, change the import to `@testable import TodayIs`
///  and give `observances.json` Target Membership in the test target.)
final class DatasetCoverageTests: XCTestCase {

    private var catalog: ObservanceCatalog!
    private var calendar: Calendar!

    /// Deterministic calendar for resolution (no DST/locale surprises).
    private func fixedCalendar() -> Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "en_US_POSIX")
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    override func setUpWithError() throws {
        calendar = fixedCalendar()
        // Default `bundle:` resolves to the TodayIsCore resource bundle under SwiftPM.
        catalog = ObservanceCatalog(calendar: calendar)
        try XCTSkipIf(catalog.all.isEmpty, "observances.json failed to load from the resource bundle.")
    }

    // MARK: - Integrity

    func testIDsAreUnique() {
        let ids = catalog.all.map(\.id)
        let dupes = Dictionary(grouping: ids, by: { $0 }).filter { $0.value.count > 1 }.keys.sorted()
        XCTAssertTrue(dupes.isEmpty, "Duplicate observance ids: \(dupes)")
    }

    func testExactlyOneScheduleField() {
        for obs in catalog.all {
            let hasDate = obs.date != nil
            let hasRule = obs.rule != nil
            XCTAssertTrue(hasDate != hasRule, "\(obs.id): must have exactly one of `date` or `rule` (date=\(hasDate), rule=\(hasRule))")
        }
    }

    func testEveryObservanceResolvesForCurrentYear() {
        let year = calendar.component(.year, from: Date())
        for obs in catalog.all {
            XCTAssertNotNil(obs.resolvedDate(inYear: year, calendar: calendar),
                            "\(obs.id): failed to resolve a date for \(year)")
        }
    }

    func testFixedDatesAreCalendarValid() {
        for obs in catalog.all {
            guard let d = obs.date else { continue }
            XCTAssertTrue((1...12).contains(d.month), "\(obs.id): month \(d.month) out of range")
            XCTAssertTrue((1...31).contains(d.day), "\(obs.id): day \(d.day) out of range")
            // Reject e.g. Feb 30 (use a non-leap year as the strict check).
            var comps = DateComponents(); comps.year = 2025; comps.month = d.month; comps.day = d.day
            XCTAssertNotNil(calendar.date(from: comps).flatMap {
                calendar.component(.day, from: $0) == d.day ? $0 : nil
            }, "\(obs.id): \(d.month)/\(d.day) is not a real date")
        }
    }

    func testRuleFieldsAreInRange() {
        for obs in catalog.all {
            guard let r = obs.rule else { continue }
            XCTAssertTrue((1...12).contains(r.month), "\(obs.id): rule.month \(r.month)")
            XCTAssertTrue((1...7).contains(r.weekday), "\(obs.id): rule.weekday \(r.weekday) (expect 1=Sun...7=Sat)")
            XCTAssertTrue(r.ordinal == -1 || (1...5).contains(r.ordinal), "\(obs.id): rule.ordinal \(r.ordinal)")
        }
    }

    // MARK: - Floating-rule resolver correctness (known dates)

    func testFloatingRuleResolver_knownDates() {
        // 4th Thursday of Nov 2026 -> Nov 26, 2026 (US Thanksgiving)
        assertRule(FloatingRule(month: 11, weekday: 5, ordinal: 4), inYear: 2026, equals: (2026, 11, 26))
        // 2nd Sunday of May 2026 -> May 10, 2026 (Mother's Day)
        assertRule(FloatingRule(month: 5, weekday: 1, ordinal: 2), inYear: 2026, equals: (2026, 5, 10))
        // 3rd Sunday of June 2026 -> June 21, 2026 (Father's Day)
        assertRule(FloatingRule(month: 6, weekday: 1, ordinal: 3), inYear: 2026, equals: (2026, 6, 21))
        // Last Monday of May 2026 -> May 25, 2026 (Memorial Day)
        assertRule(FloatingRule(month: 5, weekday: 2, ordinal: -1), inYear: 2026, equals: (2026, 5, 25))
        // Last Friday of Dec 2026 -> Dec 25, 2026
        assertRule(FloatingRule(month: 12, weekday: 6, ordinal: -1), inYear: 2026, equals: (2026, 12, 25))
    }

    private func assertRule(_ rule: FloatingRule, inYear year: Int, equals expected: (Int, Int, Int),
                            file: StaticString = #filePath, line: UInt = #line) {
        guard let date = rule.resolvedDate(inYear: year, calendar: calendar) else {
            return XCTFail("rule \(rule) did not resolve", file: file, line: line)
        }
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        XCTAssertEqual(c.year, expected.0, "rule \(rule): year", file: file, line: line)
        XCTAssertEqual(c.month, expected.1, "rule \(rule): month", file: file, line: line)
        XCTAssertEqual(c.day, expected.2, "rule \(rule): day", file: file, line: line)
    }

    // MARK: - Calendar coverage

    /// Informational: prints every day of the current year with no `general` observance.
    /// Does not fail the suite while the starter dataset is still being filled in.
    func testGeneralCoverageReport() throws {
        let gaps = missingDays(for: .general)
        let total = daysInYear()
        let covered = total - gaps.count
        print("""
        —— TodayIs general-category coverage (\(calendar.component(.year, from: Date()))) ——
        covered: \(covered)/\(total) days  •  gaps: \(gaps.count)
        \(gaps.map { $0.formatted(.dateTime.month(.abbreviated).day()) }.joined(separator: ", "))
        """)
        XCTAssertGreaterThan(covered, 0, "No general-category coverage at all — something is wrong with loading/resolution.")
    }

    /// Strict gate: every calendar day in the current year must have at least one
    /// general-category observance. Enforced now that the dataset targets full coverage.
    func testEveryDayHasAGeneralObservance() throws {
        let gaps = missingDays(for: .general)
        XCTAssertTrue(gaps.isEmpty, "Days with no general observance: \(gaps.map { $0.formatted(.dateTime.month().day()) })")
    }

    func testFunnyAndAdultCategoriesArePresent() {
        XCTAssertFalse(catalog.all.filter { $0.category == .funny }.isEmpty, "expected some funny observances")
        XCTAssertFalse(catalog.all.filter { $0.category == .adult }.isEmpty, "expected some adult observances")
    }

    // MARK: - Helpers

    private func yearBounds() -> (start: Date, end: Date) {
        let year = calendar.component(.year, from: Date())
        let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        let end = calendar.date(from: DateComponents(year: year, month: 12, day: 31))!
        return (start, end)
    }

    private func daysInYear() -> Int {
        let (start, end) = yearBounds()
        return (calendar.dateComponents([.day], from: start, to: end).day ?? 364) + 1
    }

    private func missingDays(for category: ObservanceCategory) -> [Date] {
        let (start, end) = yearBounds()
        var gaps: [Date] = []
        var cursor = start
        while cursor <= end {
            if catalog.observances(on: cursor, category: category).isEmpty {
                gaps.append(cursor)
            }
            cursor = calendar.date(byAdding: .day, value: 1, to: cursor)!
        }
        return gaps
    }
}
