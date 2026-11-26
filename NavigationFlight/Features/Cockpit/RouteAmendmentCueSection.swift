import SwiftUI

struct RouteAmendmentCueSection: View {
    let entry: RouteAmendmentLegEntry
    let onIntent: (RouteAmendmentDraft.Intent) -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var wheelHeight = 108
    @ScaledMetric(relativeTo: .body) private var wheelWidth = 110

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Optional cues").font(.headline).accessibilityAddTraits(.isHeader)
            Text("Altitude · ft MSL").font(.subheadline.weight(.semibold))
            adaptiveRow {
                wheel(.altitude, title: "Altitude", unit: "feet MSL")
                VStack(alignment: .leading, spacing: 8) {
                    Text("100 ft steps").font(.subheadline.weight(.semibold))
                    Text("−1,500 to 20,000 ft MSL").font(.caption).foregroundStyle(.secondary)
                    clear(.altitude, title: "Clear altitude")
                }
            }
            if entry.cueSelection(.altitude) == .custom {
                customValue("Existing altitude: \(entry.cueDisplayText(.altitude)) ft MSL", id: "altitude")
            }
            Text("Frequency · MHz").font(.subheadline.weight(.semibold))
            adaptiveRow {
                wheel(.frequencyMHz, title: "MHz", unit: "megahertz")
                wheel(.frequencyFraction, title: "Fraction", unit: "fractional megahertz")
                clear(.frequencyMHz, title: "Clear frequency")
            }
            if entry.cueSelection(.frequencyMHz) == .custom {
                customValue("Existing frequency: \(entry.cueDisplayText(.frequencyMHz)) MHz", id: "frequency")
            }
            Text("118.000–136.975 MHz · valid 25 kHz channels")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func adaptiveRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
            : AnyLayout(HStackLayout(alignment: .center, spacing: 14))
        return layout { content() }
    }

    private func wheel(
        _ component: RouteAmendmentLegEntry.CueComponent, title: LocalizedStringKey, unit: String
    ) -> some View {
        let selection = entry.cueSelection(component)
        let label = component == .altitude ? "Altitude, feet MSL"
            : component == .frequencyMHz ? "Frequency, whole megahertz" : "Frequency, fractional megahertz"
        return Picker(title, selection: Binding(
            get: { selection },
            set: { onIntent(.selectLegCue(component, $0)) }
        )) {
            Text("Not set")
                .accessibilityLabel("\(label), Not set")
                .tag(RouteAmendmentLegEntry.CueChoice.notSet)
            if selection == .custom {
                Text("Existing")
                    .accessibilityLabel("Existing \(entry.cueDisplayText(component)) \(component == .altitude ? "feet MSL" : "megahertz"), unchanged")
                    .tag(RouteAmendmentLegEntry.CueChoice.custom)
            }
            ForEach(entry.cueOptions(component), id: \.self) { value in
                Text(component == .frequencyFraction ? String(format: ".%03d", value) : value.formatted())
                    .accessibilityLabel(component == .frequencyFraction
                        ? "\(String(format: ".%03d", value)) megahertz fractional channel"
                        : "\(value.formatted()) \(unit)")
                    .tag(RouteAmendmentLegEntry.CueChoice.value(value))
            }
        }
        .pickerStyle(.wheel)
        .frame(width: min(wheelWidth, 240), height: wheelHeight)
        .clipped()
        .accessibilityLabel(label)
        .accessibilityIdentifier("amendment-field-\(component.rawValue)")
    }

    private func clear(_ component: RouteAmendmentLegEntry.CueComponent, title: String) -> some View {
        Button { onIntent(.selectLegCue(component, .notSet)) } label: {
            Text("Not set").frame(minWidth: 44, minHeight: 44).contentShape(.rect)
        }
        .accessibilityLabel(title)
        .accessibilityIdentifier(component == .altitude ? "clear-amendment-altitude" : "clear-amendment-frequency")
    }

    private func customValue(_ text: String, id: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
            Text("Unchanged until edited or cleared.")
        }
        .font(.caption).foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("amendment-custom-\(id)")
    }
}
