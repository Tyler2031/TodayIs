import SwiftUI

struct ObservanceDetailView: View {
    let observance: Observance

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(observance.title)
                    .font(.largeTitle.bold())

                Label(observance.category.displayName, systemImage: "tag")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if !observance.blurb.isEmpty {
                    Text(observance.blurb)
                        .font(.body)
                }

                if !observance.tags.isEmpty {
                    TagStrip(tags: observance.tags)
                }

                if let source = observance.source, let url = URL(string: source), !source.isEmpty {
                    Link(destination: url) {
                        Label("Source", systemImage: "link")
                    }
                    .font(.footnote)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .navigationTitle(observance.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
