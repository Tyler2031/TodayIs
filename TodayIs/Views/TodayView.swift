import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var catalog: ObservanceCatalog

    @State private var category: ObservanceCategory = .general

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var hits: [Observance] { catalog.observances(on: today, category: category) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    CategoryPicker(selection: $category)
                        .padding(.horizontal)

                    Text(today.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let primary = hits.first {
                        NavigationLink(value: primary) {
                            PrimaryObservanceCard(observance: primary)
                        }
                        .buttonStyle(.plain)

                        if hits.count > 1 {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Also today")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(hits.dropFirst()) { obs in
                                    NavigationLink(value: obs) {
                                        ObservanceRow(observance: obs)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    } else {
                        ContentUnavailableView(
                            "Nothing logged for today",
                            systemImage: "calendar.badge.exclamationmark",
                            description: Text("No \(category.displayName) observance in the dataset for \(today.formatted(.dateTime.month().day())).")
                        )
                        .padding(.top, 40)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Today Is")
            .navigationDestination(for: Observance.self) { ObservanceDetailView(observance: $0) }
        }
    }
}

struct PrimaryObservanceCard: View {
    let observance: Observance

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(observance.title)
                .font(.largeTitle.bold())
                .multilineTextAlignment(.leading)
            if !observance.blurb.isEmpty {
                Text(observance.blurb)
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            if !observance.tags.isEmpty {
                TagStrip(tags: observance.tags)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 20).fill(.thinMaterial))
        .padding(.horizontal)
    }
}

struct ObservanceRow: View {
    let observance: Observance

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(observance.title).font(.headline)
                if !observance.blurb.isEmpty {
                    Text(observance.blurb)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(.thinMaterial))
    }
}

struct TagStrip: View {
    let tags: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(.quaternary))
                }
            }
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(AppSettings())
        .environmentObject(ObservanceCatalog.shared)
}
