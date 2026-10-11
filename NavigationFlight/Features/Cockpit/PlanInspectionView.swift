import SwiftUI

struct PlanInspectionView: View {
    let data: CockpitPresentationData
    let canSelectPreviousLeg: Bool
    let canSelectNextLeg: Bool
    let onOpenPlan: () -> Void
    let onOpenCockpit: () -> Void
    let onSelectPreviousLeg: () -> Void
    let onSelectNextLeg: () -> Void
    let onSelectMode: (NavigationMode) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    routeSummary
                    modeSelector
                    metrics
                    references
                    annotations
                    frequencies
                }
                .padding(24)
            }
            .navigationTitle("Plan Inspection")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button(action: onOpenPlan) {
                        Label("Open Plan", systemImage: "folder")
                    }
                    .accessibilityIdentifier("open-plan")
                    Button(action: onOpenCockpit) {
                        Label("Cockpit", systemImage: "airplane")
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("open-cockpit")
                }
            }
        }
    }

    private var routeSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(data.planTitle).font(.title2.weight(.semibold))
            HStack {
                Button(action: onSelectPreviousLeg) { Label("Previous", systemImage: "chevron.backward") }
                    .disabled(!canSelectPreviousLeg)
                Spacer()
                VStack(spacing: 3) {
                    Text(data.legPosition).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        Text(data.origin)
                        Image(systemName: "arrow.right")
                        Text(data.destination)
                    }
                    .font(.headline)
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("From \(data.origin) to \(data.destination)")
                }
                Spacer()
                Button(action: onSelectNextLeg) { Label("Next", systemImage: "chevron.forward") }
                    .disabled(!canSelectNextLeg)
            }
            .buttonStyle(.bordered)
        }
    }

    @ViewBuilder
    private var modeSelector: some View {
        if data.supportsWindMode {
            Picker("Whole-plan calculation mode", selection: Binding(get: { data.mode }, set: onSelectMode)) {
                Text("No wind").tag(NavigationMode.noWind)
                Text("Wind").tag(NavigationMode.wind)
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("calculation-mode")
        } else {
            LabeledContent("Calculation mode", value: "No wind")
        }
    }

    private var metrics: some View {
        Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 14) {
            GridRow {
                value("MAGNETIC COURSE", Self.degrees(data.magneticCourseDegrees), "Saved course", id: "magnetic-course")
                value("MAGNETIC HEADING", data.magneticHeadingDegrees.map { Self.degrees($0) } ?? "Unavailable", data.magneticHeadingDegrees == nil ? "No-wind mode has no heading" : "Saved planned heading", id: "magnetic-heading")
            }
            GridRow {
                value("DISTANCE", "\(Self.decimal(data.distanceNauticalMiles)) NM", "Saved ground distance")
                value("GROUNDSPEED", "\(Self.decimal(data.groundSpeedKnots)) kt", "Selected mode")
            }
            GridRow {
                value("LEG TIME", Self.duration(data.legDurationSeconds), "Selected mode", id: "leg-time")
                value("CUMULATIVE", Self.duration(data.cumulativeDurationSeconds), "Sum of saved durations")
            }
            GridRow {
                value("INITIAL ALTITUDE", "\(Self.feet(data.initialAltitudeFeetMsl)) ft", "Feet MSL · start of flown leg")
                value("ARRIVAL CROSSING", "\(Self.feet(data.destinationCrossingAltitudeFeet)) ft", "Waypoint crossing altitude MSL")
            }
        }
    }

    private var references: some View {
        section("Accepted VOR/DME references") {
            if data.references.isEmpty {
                Text("No accepted references at this leg’s endpoints.").foregroundStyle(.secondary)
            } else {
                ForEach(data.references) { reference in
                    Text("\(reference.endpointName): \(reference.station) · \(Self.frequency(reference.frequencyMHz)) MHz · \(Self.degrees(reference.magneticRadialFromDegrees)) FROM · \(Self.decimal(reference.slantRangeNauticalMiles)) NM · \(reference.source.rawValue)")
                        .font(.subheadline).monospacedDigit()
                }
            }
        }
    }

    private var annotations: some View {
        section("Saved passive annotations") {
            if data.routeEvents.isEmpty {
                Text("No annotations on this leg.").foregroundStyle(.secondary)
            } else {
                ForEach(data.routeEvents) { event in
                    Text("\(event.title) · \(event.detail) · +\(Self.duration(event.timeFromLegStartSeconds))")
                        .font(.subheadline).monospacedDigit()
                }
            }
        }
    }

    private var frequencies: some View {
        section("Saved frequency sections · not tuned") {
            ForEach(FlightPhase.allCases, id: \.self) { phase in
                VStack(alignment: .leading, spacing: 4) {
                    Text(Self.phaseTitle(phase)).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    ForEach(data.frequencies[phase] ?? []) { entry in
                        Text("\(entry.service) · \(entry.role ?? entry.source.rawValue) · \(Self.frequency(entry.frequencyMHz)) MHz")
                            .font(.subheadline)
                    }
                    if (data.frequencies[phase] ?? []).isEmpty {
                        Text("None").font(.caption).foregroundStyle(.tertiary)
                    }
                }
            }
        }
    }

    private func value(_ title: String, _ value: String, _ detail: String, id: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(id ?? title)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.weight(.bold)).tracking(0.5)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private static func degrees(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(0))))° M" }
    private static func feet(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private static func decimal(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(1))) }
    private static func frequency(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2...3))) }
    private static func duration(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
    private static func phaseTitle(_ phase: FlightPhase) -> String {
        switch phase { case .departure: "Departure"; case .enRoute: "En route"; case .arrival: "Arrival" }
    }
}
