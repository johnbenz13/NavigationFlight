import SwiftUI

struct RouteAmendmentTimeSection: View {
    let entry: RouteAmendmentLegEntry
    let onIntent: (RouteAmendmentDraft.Intent) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var wheelHeight = 108
    @ScaledMetric(relativeTo: .body) private var wheelWidth = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Leg time")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 18))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 18))
            layout {
                timeWheel(.minutes, title: "Minutes", unit: "minutes")
                timeWheel(.seconds, title: "Seconds", unit: "seconds")
            }
            Text("Leg time up to 60:00. At 60 minutes, seconds are limited to 00.")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if entry.preservesAcceptedDuration, let duration = entry.durationSeconds, duration > 3600 {
                Text("Existing leg time \(RouteAmendmentLegEntry.durationText(duration)) is unchanged until edited.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if entry.invalidEnteredFields.contains(.duration) {
                Text("Enter a positive leg time up to 60:00.")
                    .font(.caption).foregroundStyle(RouteAmendmentPanelStyle.overPlannedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("amendment-error-duration")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeWheel(
        _ component: RouteAmendmentLegEntry.TimeComponent, title: LocalizedStringKey, unit: String
    ) -> some View {
        let selection = entry.timeSelection(component)
        let options = entry.timeOptions(component)
        return VStack(spacing: 8) {
            Text(title).font(.caption.weight(.semibold))
            Picker(title, selection: Binding(
                get: { selection },
                set: { onIntent(.selectLegTime(component, $0)) }
            )) {
                Text("Not set")
                    .accessibilityLabel("Leg time \(unit), Not set")
                    .tag(nil as Int?)
                // A legacy/custom value has its own tag; rendering never rounds it.
                if let selection, !options.contains(selection) {
                    Text(String(format: "%02d", selection))
                        .accessibilityLabel("Leg time \(unit), \(selection) \(unit)")
                        .tag(Optional(selection))
                }
                ForEach(Array(options), id: \.self) { value in
                    Text(String(format: "%02d", value))
                        .accessibilityLabel("Leg time \(unit), \(value) \(unit)")
                        .tag(Optional(value))
                }
            }
            .pickerStyle(.wheel)
            .frame(width: min(wheelWidth, 240), height: wheelHeight)
            .clipped()
            .accessibilityLabel("Leg time \(unit)")
            .accessibilityValue(selection.map { "\($0) \(unit)" } ?? "Not set")
            .accessibilityIdentifier("amendment-field-\(component.rawValue)")
            Button { onIntent(.selectLegTime(component, nil)) } label: {
                Text("Clear").frame(minWidth: 44, minHeight: 44).contentShape(.rect)
            }
            .accessibilityLabel("Clear leg time \(unit)")
            .accessibilityIdentifier("clear-amendment-\(component.rawValue)")
        }
    }
}
