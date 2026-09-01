import SwiftUI
import UIKit

// MARK: - Palette (paper planner)

extension Color {
    /// Warm cream page in light mode, near-black in dark.
    static let paper = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.11, green: 0.10, blue: 0.09, alpha: 1)
            : UIColor(red: 0.966, green: 0.936, blue: 0.868, alpha: 1)
    })
    /// Primary text — dark brown-black on cream, warm off-white on dark.
    static let ink = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.91, green: 0.88, blue: 0.80, alpha: 1)
            : UIColor(red: 0.17, green: 0.14, blue: 0.11, alpha: 1)
    })
    /// Terracotta accent for the date, "today" marker, bullets.
    static let plannerAccent = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(red: 0.86, green: 0.44, blue: 0.35, alpha: 1)
            : UIColor(red: 0.70, green: 0.26, blue: 0.18, alpha: 1)
    })
    /// Faint horizontal rule.
    static let plannerRule = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(white: 1, alpha: 0.10)
            : UIColor(red: 0.17, green: 0.14, blue: 0.11, alpha: 0.13)
    })
}

// MARK: - Ruled paper background

/// Static horizontal rules plus a left margin line, like a planner page.
struct RuledPaper: View {
    var lineSpacing: CGFloat = 34
    var marginX: CGFloat = 52

    var body: some View {
        Canvas { ctx, size in
            var y = lineSpacing * 1.5
            while y < size.height {
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(line, with: .color(.plannerRule), lineWidth: 1)
                y += lineSpacing
            }
            var margin = Path()
            margin.move(to: CGPoint(x: marginX, y: 0))
            margin.addLine(to: CGPoint(x: marginX, y: size.height))
            ctx.stroke(margin, with: .color(.plannerAccent.opacity(0.35)), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Planner page (used for Today and any tapped date)

struct PlannerPage: View {
    let date: Date
    @Binding var category: ObservanceCategory
    var showsCategoryPicker: Bool = true

    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var catalog: ObservanceCatalog

    private var slate: (items: [Observance], isFallback: Bool) {
        catalog.slate(on: date, category: category)
    }

    var body: some View {
        let hits = slate.items
        ZStack(alignment: .topLeading) {
            Color.paper.ignoresSafeArea()
            RuledPaper().ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if showsCategoryPicker { categoryRow }

                    if slate.isFallback {
                        Text("No \(category.displayName) entry today — showing the general observance.")
                            .font(.system(.caption, design: .serif)).italic()
                            .foregroundStyle(Color.ink.opacity(0.45))
                    }

                    if let primary = hits.first {
                        entry(primary, isPrimary: true)
                        if hits.count > 1 {
                            Text("also today")
                                .font(.system(.subheadline, design: .serif)).italic()
                                .foregroundStyle(Color.ink.opacity(0.5))
                                .padding(.top, 6)
                            ForEach(hits.dropFirst()) { entry($0, isPrimary: false) }
                        }
                    } else {
                        Text("Nothing marked for this day.")
                            .font(.system(.body, design: .serif))
                            .foregroundStyle(Color.ink.opacity(0.5))
                            .padding(.top, 8)
                    }
                }
                .padding(.leading, 68)
                .padding(.trailing, 24)
                .padding(.vertical, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(date.formatted(.dateTime.weekday(.wide)).uppercased())
                    .font(.system(.caption, design: .serif)).tracking(3)
                    .foregroundStyle(Color.plannerAccent)
                if Calendar.current.isDateInToday(date) {
                    Text("• TODAY")
                        .font(.system(.caption2, design: .serif)).tracking(2)
                        .foregroundStyle(Color.ink.opacity(0.45))
                }
            }
            Text(date.formatted(.dateTime.month(.wide).day()))
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ink)
            Text(date.formatted(.dateTime.year()))
                .font(.system(.footnote, design: .serif))
                .foregroundStyle(Color.ink.opacity(0.45))
            Rectangle().fill(Color.ink.opacity(0.22))
                .frame(height: 1)
                .padding(.top, 6)
        }
    }

    private var categoryRow: some View {
        HStack(spacing: 6) {
            ForEach(settings.availableCategories) { c in
                Button {
                    category = c
                } label: {
                    Text(c.displayName)
                        .font(.system(.caption, design: .serif))
                        .padding(.horizontal, 11).padding(.vertical, 5)
                        .foregroundStyle(category == c ? Color.paper : Color.ink.opacity(0.6))
                        .background(category == c ? Color.plannerAccent : Color.clear)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Color.ink.opacity(0.25),
                                             lineWidth: category == c ? 0 : 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func entry(_ o: Observance, isPrimary: Bool) -> some View {
        NavigationLink(value: o) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("•").foregroundStyle(Color.plannerAccent)
                        .font(.system(isPrimary ? .title3 : .body, design: .serif))
                    Text(o.title)
                        .font(.system(isPrimary ? .title2 : .body, design: .serif))
                        .fontWeight(isPrimary ? .semibold : .regular)
                        .foregroundStyle(Color.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if isPrimary, !o.blurb.isEmpty {
                    Text(o.blurb)
                        .font(.system(.subheadline, design: .serif))
                        .foregroundStyle(Color.ink.opacity(0.68))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 18)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Tag chips (reused by detail view)

struct TagStrip: View {
    let tags: [String]
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(tags, id: \.self) { tag in
                    Text(tag)
                        .font(.system(.caption2, design: .serif))
                        .padding(.horizontal, 9).padding(.vertical, 4)
                        .overlay(Capsule().stroke(Color.ink.opacity(0.3), lineWidth: 1))
                        .foregroundStyle(Color.ink.opacity(0.7))
                }
            }
        }
    }
}
