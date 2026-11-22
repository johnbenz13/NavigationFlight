import SwiftUI

struct RouteAmendmentModeSelectionView: View {
    let controller: SettingsController

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Choose the mode for your next route amendment.")
                    .foregroundStyle(.secondary)
                if let failure = controller.failedAttempt, case .routeAmendmentMode(let attempted) = failure.change {
                    failurePanel(attempted)
                }
                VStack(alignment: .leading, spacing: 10) {
                    SettingsSectionHeading(title: "Amendment mode")
                    VStack(spacing: 0) {
                        option(.manual, subtitle: "Enter heading and time. Use Check to compare.")
                        Divider().padding(.horizontal, 16)
                        option(.assisted, subtitle: "Save Assisted for when estimates and map aids are available.")
                    }
                    .buttonStyle(.plain)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
                }
                Text("A draft keeps the mode it started with.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .frame(maxWidth: 690, alignment: .leading)
            .padding(.vertical, 24)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Amend Route")
        .navigationBarTitleDisplayMode(.large)
    }

    private func option(_ mode: RouteAmendmentMode, subtitle: String) -> some View {
        let selected = controller.preferences.routeAmendmentMode == mode
        return Button {
            controller.change(.routeAmendmentMode(mode))
        } label: {
            HStack(spacing: 12) {
                SettingsActionLabel(title: mode.title, subtitle: subtitle)
                Spacer(minLength: 8)
                if selected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .frame(minHeight: 62)
            .contentShape(.rect)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("amendment-mode-\(mode.rawValue)")
    }

    private func failurePanel(_ attempted: RouteAmendmentMode) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeading(title: "Couldn’t save preference")
            Text("The amendment mode is still \(controller.preferences.routeAmendmentMode.title). \(attempted.title) wasn’t saved.")
                .accessibilityIdentifier("settings-amendment-save-error")
            Button("Retry", action: controller.retry)
                .frame(minHeight: 44)
            Button("Dismiss", action: controller.dismissFailure)
                .frame(minHeight: 44)
        }
    }
}

extension RouteAmendmentMode {
    var title: String {
        switch self {
        case .manual: String(localized: "Manual")
        case .assisted: String(localized: "Assisted")
        }
    }
}
