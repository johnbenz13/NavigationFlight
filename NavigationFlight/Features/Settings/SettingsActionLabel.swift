import SwiftUI

struct SettingsActionLabel: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).foregroundStyle(.primary)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
        .fixedSize(horizontal: false, vertical: true)
    }
}
