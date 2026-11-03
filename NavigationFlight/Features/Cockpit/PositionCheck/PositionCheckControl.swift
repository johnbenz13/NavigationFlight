import SwiftUI

enum PositionCheckControlAction: Equatable, Sendable {
    case retry
    case requestPermission
    case openSettings
}

struct PositionCheckControl: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let presentation: PositionCheckPresentation
    let onAction: (PositionCheckControlAction) -> Void

    var body: some View {
        Group {
            if let action {
                Button { onAction(action) } label: { content }
                    .buttonStyle(.plain)
            } else {
                content
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(presentation.statusLabel), \(presentation.title), \(presentation.detail)")
        .accessibilityHint(presentation.remedy)
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
        .frame(maxWidth: .infinity, minHeight: dynamicTypeSize.isAccessibilitySize ? 74 : 60, alignment: .leading)
        .padding(.horizontal, 14)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
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
        case .unavailable:
            .retry
        case .permissionRequired:
            presentation.remedy == "Allow Location" ? .requestPermission : .openSettings
        }
    }

    private var statusColor: Color {
        switch presentation.status {
        case .ready:
            Color(red: 22 / 255, green: 143 / 255, blue: 71 / 255)
        case .acquiring:
            Color(red: 10 / 255, green: 102 / 255, blue: 232 / 255)
        case .unavailable, .permissionRequired:
            Color(red: 196 / 255, green: 75 / 255, blue: 66 / 255)
        }
    }

    private var borderColor: Color {
        presentation.status == .ready
            ? Color(red: 255 / 255, green: 138 / 255, blue: 0)
            : statusColor
    }
}
