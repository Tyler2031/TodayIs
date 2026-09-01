import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var catalog: ObservanceCatalog

    @State private var category: ObservanceCategory = .general
    @State private var anchorDate: Date = Calendar.current.startOfDay(for: Date())

    private var days: [DayObservances] {
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -7, to: anchorDate) ?? anchorDate
        let end = cal.date(byAdding: .day, value: 60, to: anchorDate) ?? anchorDate
        return catalog.days(from: start, through: end, category: category)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    CategoryPicker(selection: $category)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    DatePicker("Jump to date", selection: $anchorDate, displayedComponents: .date)
                }

                ForEach(days) { day in
                    Section(day.date.formatted(.dateTime.weekday(.abbreviated).month().day())) {
                        ForEach(day.observances) { obs in
                            NavigationLink(value: obs) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(obs.title).font(.headline)
                                        if obs.id == day.primary?.id {
                                            Text("PRIMARY")
                                                .font(.caption2.bold())
                                                .padding(.horizontal, 5).padding(.vertical, 2)
                                                .background(Capsule().fill(.tint.opacity(0.2)))
                                        }
                                    }
                                    if !obs.blurb.isEmpty {
                                        Text(obs.blurb)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                            }
                        }
                    }
                }

                if days.isEmpty {
                    ContentUnavailableView("No observances in range", systemImage: "calendar")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Browse")
            .navigationDestination(for: Observance.self) { ObservanceDetailView(observance: $0) }
        }
    }
}

#Preview {
    BrowseView()
        .environmentObject(AppSettings())
        .environmentObject(ObservanceCatalog.shared)
}
