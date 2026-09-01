import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var settings: AppSettings

    @State private var category: ObservanceCategory = .general

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    var body: some View {
        NavigationStack {
            PlannerPage(date: today, category: $category)
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Observance.self) { ObservanceDetailView(observance: $0) }
        }
        .onChange(of: settings.adultUnlocked) { _, unlocked in
            if !unlocked, category == .adult { category = .general }
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(AppSettings())
        .environmentObject(ObservanceCatalog.shared)
}
