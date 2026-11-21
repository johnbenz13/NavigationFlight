import SwiftUI

struct SettingsSaveFailureView: View {
    let controller: SettingsController
    let attempted: StartChecklistSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SettingsSectionHeading(title: "Couldn’t save preference")
            Text("Your start checklist is still \(controller.preferences.startChecklist.title). \(attempted.title) wasn’t saved.")
                .accessibilityIdentifier("settings-save-error")
            VStack(spacing: 0) {
                Button(action: controller.retry) {
                    SettingsActionLabel(title: "Retry", subtitle: "Try saving \(attempted.title) again")
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .contentShape(.rect)
                }
                .accessibilityIdentifier("settings-retry")
                Button(action: controller.dismissFailure) {
                    SettingsActionLabel(title: "Dismiss", subtitle: "Keep the previous saved choice")
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
                        .contentShape(.rect)
                }
                .accessibilityIdentifier("settings-dismiss-error")
            }
            .buttonStyle(.plain)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
            Text("Retry saves the attempted choice. Dismiss keeps the previous preference.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .onAppear {
            AccessibilityNotification.Announcement("Couldn’t save preference. Your start checklist is still \(controller.preferences.startChecklist.title). \(attempted.title) wasn’t saved. Retry or dismiss.").post()
        }
    }
}
