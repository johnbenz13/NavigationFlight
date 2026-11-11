import SwiftUI

struct MapQuickFocusControls: View {
    let onShowWholeActiveLeg: () -> Void
    let onShowDestinationWaypoint: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            quickFocusButton(
                image: "MapQuickFocusActiveLeg",
                label: "Show Whole Active Leg",
                identifier: "show-whole-active-leg",
                action: onShowWholeActiveLeg
            )
            quickFocusButton(
                image: "MapQuickFocusDestination",
                label: "Show Destination Waypoint",
                identifier: "show-destination-waypoint",
                action: onShowDestinationWaypoint
            )
        }
    }

    private func quickFocusButton(
        image: String,
        label: LocalizedStringKey,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(image)
                .resizable()
                .frame(width: 60, height: 60)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}

struct CockpitMapToolsPanel: View {
    let areDriftLinesVisible: Bool
    let onToggleDriftLines: () -> Void
    let onShowChartLayers: () -> Void
    let onInspectFlightPlan: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            CockpitMapToolsHeader(onClose: onClose)
            Divider()
                .padding(.top, 10)
            Text("FRAMING")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.top, 16)
            toolButton(
                areDriftLinesVisible ? "Drift lines · On" : "Drift lines · Off",
                identifier: "map-tools-toggle-drift-lines",
                action: onToggleDriftLines
            )
            .padding(.top, 8)
            toolButton("Chart layers", identifier: "map-tools-chart-layers", action: onShowChartLayers)
                .padding(.top, 8)
            toolButton("Inspect flight plan", identifier: "map-tools-inspect-flight-plan", action: onInspectFlightPlan)
                .padding(.top, 8)
            Divider()
                .padding(.top, 108)
            Text("Framing and aids never report a target or change timing.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 72)
            Spacer(minLength: 24)
        }
        .padding(22)
        .background(Color(.systemBackground))
    }

    private func toolButton(
        _ title: LocalizedStringKey,
        identifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                .padding(.horizontal, 14)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(identifier)
    }
}

private struct CockpitMapToolsHeader: View {
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Map tools")
                    .font(.title2.bold())
                Spacer()
                Button("Close", action: onClose)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityIdentifier("close-map-tools")
            }
            Text("Map framing, chart aids, and inspection")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
