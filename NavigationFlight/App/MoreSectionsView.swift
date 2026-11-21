import SwiftUI

struct MoreSectionsView: View {
    let onSettings: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("App sections") {
                    Button(action: onSettings) {
                        HStack {
                            Label("Settings", systemImage: "gearshape")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.forward")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("more-settings")
                    .listRowBackground(Color(.secondarySystemBackground))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .navigationTitle("More")
        }
    }
}
