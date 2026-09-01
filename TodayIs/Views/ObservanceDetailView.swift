import SwiftUI

struct ObservanceDetailView: View {
    let observance: Observance

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.paper.ignoresSafeArea()
            RuledPaper().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(observance.category.displayName.uppercased())
                        .font(.system(.caption, design: .serif)).tracking(3)
                        .foregroundStyle(Color.plannerAccent)

                    Text(observance.title)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)

                    Rectangle().fill(Color.ink.opacity(0.22)).frame(height: 1)

                    if !observance.blurb.isEmpty {
                        Text(observance.blurb)
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Color.ink.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !observance.tags.isEmpty {
                        TagStrip(tags: observance.tags).padding(.top, 4)
                    }

                    if let source = observance.source,
                       let url = URL(string: source), !source.isEmpty {
                        Link(destination: url) {
                            Label("Source", systemImage: "link")
                                .font(.system(.footnote, design: .serif))
                        }
                        .tint(Color.plannerAccent)
                        .padding(.top, 4)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.leading, 68)
                .padding(.trailing, 24)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(observance.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.paper, for: .navigationBar)
    }
}
