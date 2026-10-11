import SwiftUI

struct CockpitView: View {
    let data: CockpitPresentationData
    let onOpenPlan: () -> Void
    let canSelectPreviousLeg: Bool
    let canSelectNextLeg: Bool
    let onSelectPreviousLeg: () -> Void
    let onSelectNextLeg: () -> Void
    let onSelectMode: (NavigationMode) -> Void
    @State private var selectedEventID: UUID?

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                HStack(spacing: 0) {
                    schematic
                        .frame(width: geometry.size.width * 0.62)
                    detailPanel
                }
            } else {
                VStack(spacing: 0) {
                    schematic
                        .frame(height: geometry.size.height * 0.55)
                    detailPanel
                }
            }
        }
        .background(Color(.systemBackground))
    }

    private var schematic: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.secondarySystemBackground)
                grid
                routeLine(in: geometry.size)
                waypointAnnotations(in: geometry.size)
                annotationViews(in: geometry.size)
                header
                Text("SCHEMATIC · SAVED PLAN POSITIONS · NOT LIVE AIRCRAFT POSITION")
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(14)
            }
        }
        .clipped()
    }

    private var grid: some View {
        Canvas { context, size in
            var path = Path()
            for x in stride(from: CGFloat.zero, through: size.width, by: 80) {
                path.move(to: .init(x: x, y: 0))
                path.addLine(to: .init(x: x, y: size.height))
            }
            for y in stride(from: CGFloat.zero, through: size.height, by: 80) {
                path.move(to: .init(x: 0, y: y))
                path.addLine(to: .init(x: size.width, y: y))
            }
            context.stroke(path, with: .color(.gray.opacity(0.12)))
        }
        .accessibilityHidden(true)
    }

    private func routeLine(in size: CGSize) -> some View {
        Canvas { context, _ in
            var path = Path()
            path.move(to: point(data.originNormalizedX, data.originNormalizedY, in: size))
            path.addLine(to: point(data.destinationNormalizedX, data.destinationNormalizedY, in: size))
            context.stroke(path, with: .color(.blue), style: .init(lineWidth: 4, dash: [10, 7]))
        }
        .accessibilityLabel("Schematic of the selected imported leg")
    }

    private func waypointAnnotations(in size: CGSize) -> some View {
        ZStack {
            waypoint(data.origin, subtitle: "DEPARTURE · \(Self.feet(data.originCrossingAltitudeFeet)) MSL", symbol: "circle.fill")
                .position(point(data.originNormalizedX, data.originNormalizedY, in: size))
            waypoint(data.destination, subtitle: "ARRIVAL · \(Self.feet(data.destinationCrossingAltitudeFeet)) MSL", symbol: "flag.checkered")
                .position(point(data.destinationNormalizedX, data.destinationNormalizedY, in: size))
        }
    }

    private func waypoint(_ title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Label(title, systemImage: symbol).font(.headline)
            Text(subtitle).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .combine)
    }

    private func annotationViews(in size: CGSize) -> some View {
        ZStack {
            ForEach(data.routeEvents) { event in
                Button {
                    selectedEventID = selectedEventID == event.id ? nil : event.id
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: symbol(for: event.kind))
                            .font(.headline)
                            .frame(width: 38, height: 38)
                            .foregroundStyle(.white)
                            .background(.indigo, in: Circle())
                        if selectedEventID == event.id {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title).font(.caption.weight(.bold))
                                Text(event.detail).font(.caption2)
                                Text("At +\(Self.duration(event.timeFromLegStartSeconds)) · saved position")
                                    .font(.caption2).monospacedDigit()
                                Text("Passive note · no action applied")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(.thickMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(event.title), \(event.detail), \(Self.duration(event.timeFromLegStartSeconds)) from leg start")
                .position(point(event.normalizedX, event.normalizedY, in: size))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(data.planTitle).font(.headline)
                    Text("\(data.legPosition) · \(data.origin) → \(data.destination)")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: onOpenPlan) { Label("Open Plan", systemImage: "folder") }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("open-plan")
            }
            HStack {
                Button(action: onSelectPreviousLeg) { Label("Previous", systemImage: "chevron.backward") }
                    .disabled(!canSelectPreviousLeg)
                Spacer()
                Text("Plan inspection").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button(action: onSelectNextLeg) { Label("Next", systemImage: "chevron.forward") }
                    .disabled(!canSelectNextLeg)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(16)
    }

    private var detailPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modeSelector
                metrics
                referenceSection
                frequencySections
                unavailableControls
            }
            .padding(18)
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var modeSelector: some View {
        if data.supportsWindMode {
            Picker("Whole-plan calculation mode", selection: Binding(
                get: { data.mode },
                set: onSelectMode
            )) {
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
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
            GridRow {
                metric("MAGNETIC COURSE", Self.degrees(data.magneticCourseDegrees), "Saved course", identifier: "magnetic-course")
                if let heading = data.magneticHeadingDegrees {
                    metric("MAGNETIC HEADING", Self.degrees(heading), "Saved planned heading", identifier: "magnetic-heading")
                } else {
                    metric("PLANNED HEADING", "Unavailable", "No-wind mode has no heading", identifier: "magnetic-heading")
                }
            }
            GridRow {
                metric("DISTANCE", "\(Self.decimal(data.distanceNauticalMiles, digits: 1)) NM", "Saved ground distance")
                metric("GROUNDSPEED", "\(Self.decimal(data.groundSpeedKnots, digits: 1)) kt", "Selected mode")
            }
            GridRow {
                metric("LEG TIME", Self.duration(data.legDurationSeconds), "Selected mode", identifier: "leg-time")
                metric("CUMULATIVE", Self.duration(data.cumulativeDurationSeconds), "Sum of saved durations")
            }
            GridRow {
                metric("INITIAL ALTITUDE", "\(Self.feet(data.initialAltitudeFeetMsl)) ft", "Feet MSL · start of flown leg")
                metric("ARRIVAL CROSSING", "\(Self.feet(data.destinationCrossingAltitudeFeet)) ft", "Waypoint crossing altitude MSL")
            }
        }
    }

    private func metric(_ title: String, _ value: String, _ detail: String, identifier: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(detail).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier ?? title)
    }

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Accepted VOR/DME references")
            if data.references.isEmpty {
                Text("No accepted references at this leg’s endpoints.").foregroundStyle(.secondary)
            } else {
                ForEach(data.references) { reference in
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(reference.station) · \(Self.frequency(reference.frequencyMHz)) MHz")
                            .font(.subheadline.weight(.semibold))
                        Text("\(reference.endpointName) · \(Self.degrees(reference.magneticRadialFromDegrees)) FROM · \(Self.decimal(reference.slantRangeNauticalMiles, digits: 1)) NM")
                            .font(.caption).monospacedDigit()
                        Text(reference.source == .automatic ? "Automatic saved solution" : "Manual pilot-provided solution")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var frequencySections: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Saved frequency sections · not tuned")
            ForEach(FlightPhase.allCases, id: \.self) { phase in
                VStack(alignment: .leading, spacing: 4) {
                    Text(phaseTitle(phase)).font(.caption.weight(.bold)).foregroundStyle(.secondary)
                    let entries = data.frequencies[phase] ?? []
                    if entries.isEmpty {
                        Text("None").font(.caption).foregroundStyle(.tertiary)
                    } else {
                        ForEach(entries) { entry in
                            HStack(alignment: .firstTextBaseline) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(entry.service).font(.subheadline)
                                    Text([entry.role, entry.source.rawValue].compactMap { $0 }.joined(separator: " · "))
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("\(Self.frequency(entry.frequencyMHz)) MHz")
                                    .font(.subheadline.weight(.semibold)).monospacedDigit()
                            }
                        }
                    }
                }
            }
        }
    }

    private var unavailableControls: some View {
        Label("Flight start, timers, GPS, corrected headings, reminders, and assistance are unavailable.", systemImage: "info.circle")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title.uppercased()).font(.caption.weight(.bold)).tracking(0.5)
    }

    private func symbol(for kind: ExecutionAnnotationKind) -> String {
        switch kind {
        case .identificationPoint: "diamond.fill"
        case .altitudeChange: "arrow.up.to.line.compact"
        case .radioFrequencyChange: "antenna.radiowaves.left.and.right"
        }
    }

    private func phaseTitle(_ phase: FlightPhase) -> String {
        switch phase {
        case .departure: "Departure"
        case .enRoute: "En route"
        case .arrival: "Arrival"
        }
    }

    private func point(_ x: Double, _ y: Double, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * x, y: size.height * y)
    }

    private static func degrees(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(0))))° M" }
    private static func feet(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private static func decimal(_ value: Double, digits: Int) -> String { value.formatted(.number.precision(.fractionLength(digits))) }
    private static func frequency(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2...3))) }
    private static func duration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

#if DEBUG
private extension CockpitPresentationData {
    static let preview = CockpitPresentationData(
        planTitle: "Preview training plan",
        legPosition: "Leg 2 of 5",
        origin: "Preview departure",
        destination: "Preview arrival",
        originNormalizedX: 0.18,
        originNormalizedY: 0.72,
        destinationNormalizedX: 0.82,
        destinationNormalizedY: 0.28,
        originCrossingAltitudeFeet: 1_500,
        destinationCrossingAltitudeFeet: 2_000,
        magneticCourseDegrees: 68,
        magneticHeadingDegrees: 74,
        distanceNauticalMiles: 7.2,
        groundSpeedKnots: 98,
        legDurationSeconds: 263,
        cumulativeDurationSeconds: 742,
        initialAltitudeFeetMsl: 1_800,
        mode: .wind,
        supportsWindMode: true,
        references: [],
        frequencies: [:],
        routeEvents: []
    )
}

#Preview("Cockpit portrait", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .preview, onOpenPlan: {}, canSelectPreviousLeg: true, canSelectNextLeg: true, onSelectPreviousLeg: {}, onSelectNextLeg: {}, onSelectMode: { _ in })
}

#Preview("Cockpit landscape", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .preview, onOpenPlan: {}, canSelectPreviousLeg: true, canSelectNextLeg: true, onSelectPreviousLeg: {}, onSelectNextLeg: {}, onSelectMode: { _ in })
}
#endif
