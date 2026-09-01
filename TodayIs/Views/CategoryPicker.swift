import SwiftUI

/// Segmented picker limited to the categories the user has unlocked.
struct CategoryPicker: View {
    @EnvironmentObject private var settings: AppSettings
    @Binding var selection: ObservanceCategory

    var body: some View {
        Picker("Category", selection: $selection) {
            ForEach(settings.availableCategories) { category in
                Text(category.displayName).tag(category)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: settings.adultUnlocked) { _, unlocked in
            if !unlocked && selection == .adult {
                selection = .general
            }
        }
    }
}
