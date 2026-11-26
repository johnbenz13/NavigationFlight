import SwiftUI

struct RouteAmendmentTimeSection: View {
    let entry: RouteAmendmentLegEntry
    let onIntent: (RouteAmendmentDraft.Intent) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var wheelHeight = 108
    @ScaledMetric(relativeTo: .body) private var wheelWidth = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Leg time").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Text("\(entry.minutes.isEmpty ? "--" : entry.minutes):\(entry.seconds.isEmpty ? "--" : entry.seconds)")
                    .font(.title3.weight(.semibold)).monospacedDigit()
                    .accessibilityLabel("Leg time, \(entry.minutes.isEmpty ? "minutes Not set" : entry.minutes + " minutes"), \(entry.seconds.isEmpty ? "seconds Not set" : entry.seconds + " seconds")")
                    .accessibilityIdentifier("amendment-duration-readout")
            }
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(alignment: .top, spacing: 14))
            layout {
                timeWheel(.minutes, title: "Minutes")
                timeWheel(.seconds, title: "Seconds")
            }
            if entry.preservesAcceptedDuration, let duration = entry.durationSeconds, duration >= 3600 {
                Text("Existing leg time \(RouteAmendmentLegEntry.durationText(duration)) is unchanged until edited.")
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if entry.invalidEnteredFields.contains(.duration) {
                Text("Enter a positive leg time up to 59:59.")
                    .font(.caption).foregroundStyle(RouteAmendmentPanelStyle.overPlannedInk)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("amendment-error-duration")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timeWheel(_ component: RouteAmendmentLegEntry.TimeComponent, title: LocalizedStringKey) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.footnote).foregroundStyle(.secondary)
                Spacer(minLength: 4)
                Button { onIntent(.selectLegTime(component, nil)) } label: {
                    Text("Clear").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear leg time \(component.rawValue)")
                .accessibilityIdentifier("clear-amendment-\(component.rawValue)")
            }
            RouteAmendmentCyclicTimeWheel(selection: entry.timeSelection(component), component: component) {
                onIntent(.advanceLegTime(component, $0))
            }
            .frame(width: min(wheelWidth, 240), height: wheelHeight)
            .clipped()
        }
        .frame(maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : 152)
    }
}
