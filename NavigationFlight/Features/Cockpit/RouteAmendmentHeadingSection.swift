import SwiftUI

/// Nil is a real wheel choice, so presenting the editor never enters a heading.
struct RouteAmendmentHeadingSection: View {
    let entry: RouteAmendmentLegEntry
    let onIntent: (RouteAmendmentDraft.Intent) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var wheelHeight = 108
    @ScaledMetric(relativeTo: .body) private var wheelWidth = 110

    private var selection: Binding<Int?> {
        Binding(
            get: { entry.magneticHeading },
            set: { value in
                onIntent(.editLegField(.heading, value.map { String(format: "%03d", $0) } ?? ""))
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Magnetic heading")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout(spacing: 18))
            layout {
                Picker("Magnetic heading", selection: selection) {
                    Text("Not set").tag(nil as Int?)
                    ForEach(1...360, id: \.self) { heading in
                        Text(String(format: "%03d°", heading)).tag(Optional(heading))
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: min(wheelWidth, 240), height: wheelHeight)
                .clipped()
                .accessibilityValue(entry.magneticHeading.map { String(format: "%03d degrees", $0) } ?? "Not set")
                .accessibilityIdentifier("amendment-field-heading")
                Button { onIntent(.editLegField(.heading, "")) } label: {
                    Text("Clear").frame(minWidth: 44, minHeight: 44).contentShape(.rect)
                }
                .accessibilityLabel("Clear magnetic heading")
                .accessibilityIdentifier("clear-amendment-heading")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
