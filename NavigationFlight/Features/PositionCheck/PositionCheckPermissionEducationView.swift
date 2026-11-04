import SwiftUI

struct PositionCheckPermissionEducationView: View {
    let onIntent: (PositionCheckPermissionIntent) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("BEFORE ENTERING THE COCKPIT")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color.accentColor)

                    Image(systemName: "location.viewfinder")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Color.orange)
                        .accessibilityHidden(true)

                    Text("Allow Location for Position Check")
                        .font(.title2.weight(.bold))

                    Text("NavigationFlight normally keeps your position hidden. While flying, Position Check can temporarily reveal a trustworthy GPS position for ten seconds when you deliberately hold its control.")
                        .font(.body)
                        .foregroundStyle(.primary)

                    Label(
                        "During an active Flight, NavigationFlight records the aircraft track and may continue location collection in the background. Recordings stay on this device and export only when you deliberately choose. Deliberately force-quitting the app may stop collection until you reopen it.",
                        systemImage: "hand.raised.fill"
                    )
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 16) { actions }
                        VStack(spacing: 12) { actions }
                    }
                }
                .frame(maxWidth: 520, alignment: .leading)
                .padding(24)
            }
            .navigationTitle("Position Check")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
        .accessibilityIdentifier("position-check-permission-education")
    }

    @ViewBuilder
    private var actions: some View {
        Button("Not Now") {
            onIntent(.continueManually)
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("position-check-not-now")

        Button("Continue") {
            onIntent(.requestWhenInUse)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("position-check-continue")
    }
}
