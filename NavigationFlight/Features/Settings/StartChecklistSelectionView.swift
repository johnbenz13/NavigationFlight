import SwiftUI

struct StartChecklistSelectionView: View {
    let selection: StartChecklistSelection
    let onSelect: (StartChecklistSelection) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    SettingsSectionHeading(title: "Choose one")
                    VStack(spacing: 0) {
                        ForEach(StartChecklistSelection.allCases) { choice in
                            Button { onSelect(choice) } label: {
                                HStack(spacing: 16) {
                                    Text(choice.title).foregroundStyle(.primary)
                                        .fixedSize(horizontal: false, vertical: true)
                                    Spacer(minLength: 12)
                                    if choice == selection {
                                        Image(systemName: "checkmark").foregroundStyle(.primary)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                                .contentShape(.rect)
                            }
                            .accessibilityAddTraits(choice == selection ? [.isSelected] : [])
                            .accessibilityIdentifier("checklist-choice-\(choice.rawValue)")
                        }
                    }
                    .buttonStyle(.plain)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
                }
                Text(explanation).font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
            .padding(.horizontal, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Start checklist")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("start-checklist-selector")
    }

    private var explanation: String {
        switch selection {
        case .tzeKivun:
            "Applies to subsequent leg starts, including automatic starts. Existing checklists stay unchanged. Selecting saves immediately and returns to Settings. Back cancels without a change."
        case .establishHeading:
            "Applies to the next leg start. Selecting saves immediately and returns to Settings. Back cancels without a change."
        case .none:
            "No automatic checklist or checklist chip for subsequent starts. Leg timing is unchanged. Selecting saves immediately and returns to Settings. Back cancels without a change."
        }
    }
}
