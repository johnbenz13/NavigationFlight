import SwiftUI

struct SettingsSectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.footnote)
            .fontWeight(.regular)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}
