import SwiftUI

struct PositionCheckStatus: View {
    let presentation: PositionCheckPresentation

    var body: some View {
        Label(presentation.statusLabel, systemImage: presentation.systemImage)
            .font(.caption2.weight(.bold))
            .foregroundStyle(statusColor)
            .accessibilityElement(children: .combine)
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
}
