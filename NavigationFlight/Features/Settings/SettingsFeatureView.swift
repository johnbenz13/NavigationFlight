import SwiftUI

struct SettingsFeatureView: View {
    let controller: SettingsController
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var path: [String] = []
    @State private var requestID: UUID?
    @State private var availableSize: CGSize = .zero

    var body: some View {
        NavigationStack(path: $path) {
            let widePortrait = availableSize.width >= 700 && availableSize.height > availableSize.width
            let margin: CGFloat = availableSize.width >= 700 ? 72 : 20
            ScrollView {
                VStack(alignment: .leading, spacing: widePortrait ? 30 : 24) {
                    Text("Preferences saved on this device.")
                        .foregroundStyle(.secondary)
                    if let failure = controller.failedAttempt,
                       case .startChecklist(let attempted) = failure.change {
                        SettingsSaveFailureView(controller: controller, attempted: attempted)
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        SettingsSectionHeading(title: "Cockpit")
                        NavigationLink(value: "startChecklist") {
                            HStack(spacing: 12) {
                                if widePortrait && !dynamicTypeSize.isAccessibilitySize {
                                    SettingsActionLabel(title: "Start checklist", subtitle: "Applies to the next leg start")
                                    Spacer(minLength: 12)
                                    Text(controller.preferences.startChecklist.title).foregroundStyle(.secondary)
                                } else if dynamicTypeSize.isAccessibilitySize {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Start checklist").foregroundStyle(.primary)
                                        Text(controller.preferences.startChecklist.title).foregroundStyle(.primary)
                                        Text("Next leg start").foregroundStyle(.secondary)
                                    }
                                    .padding(.vertical, 16)
                                    Spacer(minLength: 0)
                                } else {
                                    SettingsActionLabel(title: "Start checklist", subtitle: "\(controller.preferences.startChecklist.title) · Next leg start")
                                    Spacer(minLength: 0)
                                }
                                Image(systemName: "chevron.right").accessibilityHidden(true)
                            }
                            .padding(.leading, 16)
                            .padding(.trailing, 20)
                            .frame(maxWidth: .infinity, minHeight: widePortrait ? 82 : 76, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
                        .accessibilityLabel("Start checklist")
                        .accessibilityValue(controller.preferences.startChecklist.title)
                        .accessibilityHint("Applies to subsequent leg starts, including automatic starts")
                        .accessibilityIdentifier("settings-start-checklist")
                    }
                    Text("Changes save automatically. Your current Flight continues unchanged.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 24)
                .padding(.horizontal, margin)
            }
            .background(Color(.systemGroupedBackground))
            .onGeometryChange(for: CGSize.self) { $0.size } action: { availableSize = $0 }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { _ in
                StartChecklistSelectionView(selection: controller.preferences.startChecklist) { selection in
                    requestID = controller.change(.startChecklist(selection))
                }
            }
            .onChange(of: path) { _, _ in requestID = nil }
            .onChange(of: controller.completedRequestID) { _, completed in
                if completed == requestID { path = []; requestID = nil }
            }
            .onChange(of: controller.failedAttempt) { _, failure in
                if failure?.id == requestID { path = []; requestID = nil }
            }
        }
    }
}
