import SwiftUI

struct PendingAmendmentDialog: View {
    enum Content {
        case confirm(PendingAmendmentManagement.Confirmation)
        case save(CockpitFeatureState.RouteAmendmentSave.Status)

        var title: LocalizedStringKey {
            switch self {
            case .confirm(.cancel): "Cancel this amendment?"
            case .confirm(.reportOriginalDestination): "Report original destination reached?"
            case .save(.saving): "Saving amendment"
            case .save(.failed): "Amendment could not be saved"
            }
        }

        var message: LocalizedStringKey {
            switch self {
            case .confirm(.cancel): "The original destination will be restored and the current timer will keep running."
            case .confirm(.reportOriginalDestination(let destination)):
                "You’re reporting \(destination.name) reached on the original route. Confirming cancels the pending amendment and records this reach."
            case .save(.saving): "The current route remains operational while the change is saved."
            case .save(.failed): "The last confirmed route remains active. Retry to save this action."
            }
        }

        var primaryAction: LocalizedStringKey {
            switch self {
            case .confirm(.cancel): "Cancel amendment"
            case .confirm(.reportOriginalDestination): "Cancel and record reach"
            case .save: "Retry save"
            }
        }

        var isDestructive: Bool {
            if case .confirm(.cancel) = self { return true }
            return false
        }

        var canDismiss: Bool {
            switch self {
            case .confirm: true
            case .save(.failed(let canEdit)): canEdit
            case .save(.saving): false
            }
        }
    }

    let content: Content
    let onDismiss: () -> Void
    let onConfirm: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState(for: .voiceOver) private var titleHasFocus: Bool

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    dialogContents
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: 490)
                .padding(.vertical, 26)
            } else {
                dialogContents
            }
        }
        .padding(.horizontal, 16)
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("pending-amendment-confirmation")
        .accessibilityAction(.escape) { if content.canDismiss { onDismiss() } }
        .task { titleHasFocus = true }
    }

    private var dialogContents: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(content.title)
                .font(.title3.bold())
                .accessibilityAddTraits(.isHeader)
                .accessibilityFocused($titleHasFocus)
            Text(content.message)
                .font(.subheadline)
                .foregroundStyle(PendingAmendmentPalette.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 18)
            if case .save(.saving) = content {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .accessibilityIdentifier("pending-amendment-management-saving")
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { buttons(stacked: false) }
                    VStack(spacing: 8) { buttons(stacked: true) }
                }
            }
        }
        .padding(22)
        .frame(maxWidth: 490, minHeight: horizontalSizeClass == .compact ? 0 : 261)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private func buttons(stacked: Bool) -> some View {
        if content.canDismiss {
            action("Keep pending", id: "keep-pending-amendment", color: PendingAmendmentPalette.quietAction,
                   background: PendingAmendmentPalette.quietBackground, stacked: stacked, width: stacked ? nil : 182, perform: onDismiss)
        }
        let background = content.isDestructive
            ? PendingAmendmentPalette.destructiveBackground : PendingAmendmentPalette.primaryBackground
        let ink = content.isDestructive ? PendingAmendmentPalette.destructive : .white
        let id: String = {
            if case .save = content { return "retry-pending-amendment-management" }
            return "confirm-pending-amendment-management"
        }()
        action(content.primaryAction, id: id, color: ink, background: background,
               stacked: stacked, width: stacked || !content.canDismiss ? nil : 252, perform: onConfirm)
    }

    private func action(
        _ title: LocalizedStringKey, id: String, color: Color, background: Color, stacked: Bool,
        width: CGFloat?, perform: @escaping () -> Void
    ) -> some View {
        Button(action: perform) {
            Text(title)
                .font(.body.weight(.semibold))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: !stacked, vertical: true)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(width: dynamicTypeSize.isAccessibilitySize ? nil : width)
                .frame(maxWidth: stacked || width == nil ? .infinity : nil, minHeight: 52)
                .foregroundStyle(color)
                .background(background, in: .rect(cornerRadius: 13))
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}
