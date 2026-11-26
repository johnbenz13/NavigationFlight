import SwiftUI

struct RouteAmendmentHeadingSection: View {
    let entry: RouteAmendmentLegEntry
    let onIntent: (RouteAmendmentDraft.Intent) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Magnetic heading").font(.headline).accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                Button { onIntent(.editLegField(.heading, "")) } label: {
                    Text("Clear").frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("Clear magnetic heading")
                .accessibilityIdentifier("clear-amendment-heading")
            }
            RouteAmendmentCompass(heading: entry.magneticHeading) { value in
                onIntent(.editLegField(.heading, String(format: "%03d", value)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
