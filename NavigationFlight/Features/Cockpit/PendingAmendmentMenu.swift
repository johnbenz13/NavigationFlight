import SwiftUI

struct PendingAmendmentMenu: View {
    let management: PendingAmendmentManagement
    let compact: Bool
    let onDone: () -> Void
    let onReplace: () -> Void
    let onConfirm: (PendingAmendmentManagement.Confirmation) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Amendment pending")
                            .font(compact ? .title2.bold() : .headline)
                            .accessibilityAddTraits(.isHeader)
                        Text("\(management.departureName) on leg \(management.legNumber)")
                            .font(compact ? .subheadline : .footnote)
                            .foregroundStyle(PendingAmendmentPalette.secondary)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if compact {
                        Button("Done", action: onDone)
                            .foregroundStyle(PendingAmendmentPalette.quietAction)
                            .font(.body.weight(.semibold))
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityIdentifier("dismiss-pending-amendment-management")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, compact ? 10 : 12)
                .frame(minHeight: compact ? 82 : 71)
                Divider()
                row("Replace amendment", id: "replace-pending-amendment", action: onReplace)
                divider
                if let original = management.originalDestination {
                    row("Report original destination reached…", id: "report-original-destination") {
                        onConfirm(.reportOriginalDestination(original))
                    }
                    divider
                }
                row("Cancel amendment…", id: "cancel-pending-amendment", role: .destructive) {
                    onConfirm(.cancel(management.id))
                }
            }
            .padding(.horizontal, compact ? 4 : 0)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: compact ? nil : 344)
        .frame(maxHeight: compact ? .infinity : (dynamicTypeSize.isAccessibilitySize ? 460 : nil))
        .fixedSize(horizontal: false, vertical: !compact)
        .padding(.top, compact ? 12 : 0)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.height(302), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color(.systemBackground))
        .accessibilityIdentifier("pending-amendment-management")
    }

    private var divider: some View {
        Divider().padding(.horizontal, 16)
    }

    private func row(
        _ title: LocalizedStringKey, id: String, role: ButtonRole? = nil, action: @escaping () -> Void
    ) -> some View {
        Button(role: role, action: action) {
            Text(title)
                .font(compact ? .body : .subheadline)
                .foregroundStyle(role == .destructive ? PendingAmendmentPalette.destructive : Color.primary)
                .frame(maxWidth: .infinity, minHeight: compact ? 57 : 49, alignment: .leading)
                .padding(.horizontal, 16)
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
