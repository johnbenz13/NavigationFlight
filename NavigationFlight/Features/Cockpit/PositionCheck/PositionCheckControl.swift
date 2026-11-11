import SwiftUI

enum PositionCheckControlAction: Equatable, Sendable {
    case holdCompleted
    case cancel
    case end
    case retry
    case requestPermission
    case openSettings
    case dismiss
}

struct PositionCheckControl: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    @State private var isHolding = false

    let presentation: PositionCheckPresentation
    let onAction: (PositionCheckControlAction) -> Void

    var body: some View {
        Group {
            if presentation.status == .ready || presentation.status == .acquiring {
                content
                    .overlay(alignment: .bottomLeading) {
                        GeometryReader { geometry in
                            Capsule()
                                .fill(holdColor)
                                .frame(width: isHolding ? geometry.size.width : 0, height: 4)
                                .animation(
                                    accessibilityReduceMotion ? nil : .linear(duration: 1),
                                    value: isHolding
                                )
                        }
                        .frame(height: 4)
                    }
                    .onLongPressGesture(minimumDuration: 1, maximumDistance: 20) {
                        onAction(.holdCompleted)
                    } onPressingChanged: { pressing in
                        isHolding = pressing
                    }
            } else if presentation.status == .active {
                Button { onAction(.end) } label: { content }
                    .buttonStyle(.plain)
                    .highPriorityGesture(
                        LongPressGesture(minimumDuration: 1, maximumDistance: 20)
                            .onEnded { _ in
                                onAction(.holdCompleted)
                            }
                    )
            } else if let action {
                Button { onAction(action) } label: { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
        .accessibilityValue(presentation.accessibilityValue)
        .accessibilityHint(presentation.accessibilityHint)
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { performAccessibilityAction() }
        .accessibilityIdentifier("position-check-control")
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: dynamicTypeSize.isAccessibilitySize ? 5 : 2) {
            if dynamicTypeSize.isAccessibilitySize {
                PositionCheckStatus(presentation: presentation)
            }
            Text(presentation.title)
                .font((dynamicTypeSize.isAccessibilitySize ? Font.title3 : .subheadline).weight(.bold))
                .foregroundStyle(.primary)
            Text(presentation.detail)
                .font(dynamicTypeSize.isAccessibilitySize ? .footnote : .caption2)
                .foregroundStyle(statusColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 74 : 58, alignment: .leading)
        .padding(.horizontal, 14)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(borderColor, lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    private var action: PositionCheckControlAction? {
        switch presentation.status {
        case .ready, .acquiring:
            nil
        case .requesting:
            .cancel
        case .active:
            .end
        case .unavailable:
            .retry
        case .permissionRequired:
            presentation.remedy == "Allow Location" ? .requestPermission : .openSettings
        case .signalLost:
            .dismiss
        }
    }

    private func performAccessibilityAction() {
        switch presentation.status {
        case .ready, .acquiring:
            onAction(.holdCompleted)
        case .active:
            onAction(.end)
        case .requesting:
            onAction(.cancel)
        case .unavailable:
            onAction(.retry)
        case .permissionRequired:
            onAction(presentation.remedy == "Allow Location" ? .requestPermission : .openSettings)
        case .signalLost:
            onAction(.dismiss)
        }
    }

    private var statusColor: Color {
        switch presentation.status {
        case .ready:
            Color(red: 22 / 255, green: 143 / 255, blue: 71 / 255)
        case .acquiring, .requesting:
            Color(red: 10 / 255, green: 102 / 255, blue: 232 / 255)
        case .unavailable, .permissionRequired, .signalLost:
            Color(red: 196 / 255, green: 75 / 255, blue: 66 / 255)
        case .active:
            Color(red: 154 / 255, green: 74 / 255, blue: 0)
        }
    }

    private var borderColor: Color {
        presentation.status == .ready
            ? Color(red: 255 / 255, green: 138 / 255, blue: 0)
            : statusColor
    }

    private var backgroundColor: Color {
        presentation.status == .ready
            ? Color(red: 1, green: 244 / 255, blue: 229 / 255)
            : Color(.systemBackground)
    }

    private var holdColor: Color {
        Color(red: 255 / 255, green: 138 / 255, blue: 0)
    }
}
