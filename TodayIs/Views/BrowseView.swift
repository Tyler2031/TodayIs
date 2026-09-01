import SwiftUI

/// Month-grid calendar. Tap a day to open its planner page.
struct BrowseView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var catalog: ObservanceCatalog

    @State private var category: ObservanceCategory = .general
    @State private var visibleMonth: Date = Calendar.current.startOfDay(for: Date())

    private let cal = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        NavigationStack {
            ZStack {
                Color.paper.ignoresSafeArea()

                VStack(spacing: 14) {
                    monthHeader
                    categoryRow
                    weekdayHeader
                    grid
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Observance.self) { ObservanceDetailView(observance: $0) }
            .navigationDestination(for: Date.self) { day in
                PlannerPage(date: day, category: .constant(category), showsCategoryPicker: false)
                    .navigationTitle(day.formatted(.dateTime.month(.abbreviated).day()))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(Color.paper, for: .navigationBar)
            }
        }
        .onChange(of: settings.adultUnlocked) { _, unlocked in
            if !unlocked, category == .adult { category = .general }
        }
    }

    // MARK: Header

    private var monthHeader: some View {
        HStack {
            navButton("chevron.left") { shiftMonth(-1) }
            Spacer()
            Text(visibleMonth.formatted(.dateTime.month(.wide).year()))
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
            Spacer()
            navButton("chevron.right") { shiftMonth(1) }
        }
    }

    private func navButton(_ system: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.plannerAccent)
                .frame(width: 40, height: 36)
                .contentShape(Rectangle())
        }
    }

    private var categoryRow: some View {
        HStack(spacing: 6) {
            ForEach(settings.availableCategories) { c in
                Button { category = c } label: {
                    Text(c.displayName)
                        .font(.system(.caption, design: .serif))
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .foregroundStyle(category == c ? Color.paper : Color.ink.opacity(0.6))
                        .background(category == c ? Color.plannerAccent : Color.clear)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.ink.opacity(0.25),
                                                  lineWidth: category == c ? 0 : 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(orderedWeekdaySymbols, id: \.self) { sym in
                Text(sym)
                    .font(.system(.caption2, design: .serif)).tracking(1)
                    .foregroundStyle(Color.ink.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(Array(monthCells.enumerated()), id: \.offset) { _, day in
                if let day {
                    NavigationLink(value: day) {
                        DayCell(
                            date: day,
                            isToday: cal.isDateInToday(day),
                            notable: isNotable(day)
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    Color.clear.frame(height: 46)
                }
            }
        }
    }

    // MARK: Data

    private var orderedWeekdaySymbols: [String] {
        let syms = cal.veryShortStandaloneWeekdaySymbols // ["S","M",...] starting Sunday
        let shift = cal.firstWeekday - 1
        return Array(syms[shift...] + syms[..<shift])
    }

    /// Cells for the visible month, leading nils for offset so week 1 aligns.
    private var monthCells: [Date?] {
        guard let interval = cal.dateInterval(of: .month, for: visibleMonth) else { return [] }
        let firstWeekday = cal.component(.weekday, from: interval.start)
        let leading = (firstWeekday - cal.firstWeekday + 7) % 7
        let dayCount = cal.range(of: .day, in: .month, for: visibleMonth)?.count ?? 30

        var cells: [Date?] = Array(repeating: nil, count: leading)
        for offset in 0..<dayCount {
            cells.append(cal.date(byAdding: .day, value: offset, to: interval.start))
        }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func isNotable(_ day: Date) -> Bool {
        (catalog.primary(on: day, category: category)?.priority ?? 0) >= 60
    }

    private func shiftMonth(_ delta: Int) {
        if let d = cal.date(byAdding: .month, value: delta, to: visibleMonth) {
            visibleMonth = d
        }
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let date: Date
    let isToday: Bool
    let notable: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(.callout, design: .serif))
                .foregroundStyle(Color.ink)
            Circle()
                .fill(notable ? Color.plannerAccent : Color.clear)
                .frame(width: 5, height: 5)
        }
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(RoundedRectangle(cornerRadius: 6).stroke(Color.ink.opacity(0.12), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.plannerAccent, lineWidth: isToday ? 2 : 0))
    }
}

#Preview {
    BrowseView()
        .environmentObject(AppSettings())
        .environmentObject(ObservanceCatalog.shared)
}
