import SwiftUI

private enum CockpitMapDisplayMode: String, CaseIterable, Identifiable {
    case labels = "Symbols + Labels"
    case symbolsOnly = "Symbols Only"
    var id: Self { self }
}

#if DEBUG
private extension CockpitPresentationData {
    static func cockpitPreview(heading: Double?, populated: Bool, hebrew: Bool = false) -> CockpitPresentationData {
        CockpitPresentationData(
            planTitle: "Preview training plan",
            legPosition: "Leg 2 of 5",
            origin: hebrew ? "חדרה" : "Long Departure Reporting Point",
            destination: hebrew ? "עירון" : "Long Arrival Reporting Point",
            originNormalizedX: 0.18,
            originNormalizedY: 0.69,
            destinationNormalizedX: 0.79,
            destinationNormalizedY: 0.30,
            originCrossingAltitudeFeet: 1_500,
            destinationCrossingAltitudeFeet: 2_000,
            magneticCourseDegrees: 68,
            magneticHeadingDegrees: heading,
            distanceNauticalMiles: 7.2,
            groundSpeedKnots: 98,
            legDurationSeconds: 263,
            cumulativeDurationSeconds: 742,
            initialAltitudeFeetMsl: 1_800,
            mode: heading == nil ? .noWind : .wind,
            supportsWindMode: true,
            references: populated ? [
                .init(id: UUID(), endpointName: hebrew ? "עירון" : "Long Arrival Reporting Point", station: "HDF", frequencyMHz: 113.5, magneticRadialFromDegrees: 245, slantRangeNauticalMiles: 18.6, source: .automatic)
            ] : [],
            frequencies: populated ? [
                .departure: [.init(id: "preview-frequency", phase: .departure, role: "Pilot override", service: "Very Long Preview Tower Service", frequencyMHz: 118.4, source: .user)]
            ] : [:],
            routeEvents: populated ? [
                .init(id: UUID(), entityIDs: [UUID()], kinds: [.altitudeChange], normalizedX: 0.40, normalizedY: 0.57, position: .init(latitudeDegrees: 32.2, longitudeDegrees: 34.6), timeFromLegStartSeconds: 132, title: "Altitude change", detail: "After passing anchor: 2,500 ft MSL"),
                .init(id: UUID(), entityIDs: [UUID()], kinds: [.radioFrequencyChange], normalizedX: 0.61, normalizedY: 0.44, position: .init(latitudeDegrees: 32.25, longitudeDegrees: 34.65), timeFromLegStartSeconds: 190, title: "Frequency change", detail: "Very Long Preview Control Service · 120.600 MHz")
            ] : []
        )
    }
}

private extension FlightSession {
    static let preview = FlightSession(
        flightID: UUID(),
        activeLegIndex: 1,
        executionMode: .wind
    )
}

#Preview("11-inch iPad Portrait · Wind", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .cockpitPreview(heading: 74, populated: true), session: .preview, onStartLeg: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Portrait · No Wind · Hebrew", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .cockpitPreview(heading: nil, populated: true, hebrew: true), session: .preview, onStartLeg: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Landscape · Missing Optional Data", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .cockpitPreview(heading: nil, populated: false), session: .preview, onStartLeg: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Landscape · Dark", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .cockpitPreview(heading: 74, populated: true), session: .preview, onStartLeg: {}, onShowPlanInspection: {})
        .preferredColorScheme(.dark)
}
#endif

struct CockpitView: View {
    let data: CockpitPresentationData
    let session: FlightSession
    let onStartLeg: () -> Void
    let onShowPlanInspection: () -> Void
    @State private var displayMode = CockpitMapDisplayMode.labels
    @State private var selectedEventID: UUID?
    @State private var showsDisplayOptions = false
    @State private var showsChartsUnavailable = false

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                HStack(spacing: 0) {
                    mapSurface
                        .frame(width: geometry.size.width * 0.74)
                    landscapeControlPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    mapSurface
                        .frame(height: geometry.size.height * 0.74)
                    portraitControlPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showsDisplayOptions) { displayOptionsSheet }
        .alert("Charts Unavailable", isPresented: $showsChartsUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Chart presentation is a later delivery. The imported plan remains unchanged.")
        }
    }

    private var mapSurface: some View {
        GeometryReader { geometry in
            ZStack {
                Color(.secondarySystemBackground)
                schematicGrid
                routeLine(in: geometry.size)
                Color.clear.contentShape(Rectangle()).onTapGesture { selectedEventID = nil }
                waypointAnnotations(in: geometry.size)
                eventAnnotations(in: geometry.size)
                schematicNotice
                mapControls
                legHeader
            }
        }
        .clipped()
    }

    private var schematicGrid: some View {
        Canvas { context, size in
            var grid = Path()
            for x in stride(from: CGFloat.zero, through: size.width, by: 80) {
                grid.move(to: CGPoint(x: x, y: 0)); grid.addLine(to: CGPoint(x: x, y: size.height))
            }
            for y in stride(from: CGFloat.zero, through: size.height, by: 80) {
                grid.move(to: CGPoint(x: 0, y: y)); grid.addLine(to: CGPoint(x: size.width, y: y))
            }
            context.stroke(grid, with: .color(.gray.opacity(0.12)), lineWidth: 1)
        }
        .accessibilityHidden(true)
    }

    private func routeLine(in size: CGSize) -> some View {
        Canvas { context, _ in
            var route = Path()
            route.move(to: point(data.originNormalizedX, data.originNormalizedY, in: size))
            route.addLine(to: point(data.destinationNormalizedX, data.destinationNormalizedY, in: size))
            context.stroke(route, with: .color(.blue.opacity(0.82)), style: StrokeStyle(lineWidth: 4, dash: [10, 7]))
            for event in data.routeEvents {
                let position = point(event.normalizedX, event.normalizedY, in: size)
                var guide = Path()
                guide.move(to: CGPoint(x: position.x, y: position.y - 12))
                guide.addLine(to: CGPoint(x: position.x, y: position.y + 12))
                context.stroke(guide, with: .color(.blue.opacity(0.35)), lineWidth: 2)
            }
        }
        .accessibilityLabel("Schematic of the selected imported leg")
    }

    private func waypointAnnotations(in size: CGSize) -> some View {
        ZStack {
            Circle().fill(.blue).frame(width: 12, height: 12)
                .position(point(data.originNormalizedX, data.originNormalizedY, in: size))
            VStack(alignment: .leading, spacing: 7) {
                waypoint(title: data.origin, subtitle: "DEPARTURE · \(Self.feet(data.originCrossingAltitudeFeet)) FT MSL", symbol: "circle.fill")
                ForEach(data.references.filter { $0.endpointName == data.origin }) { reference in
                    referenceAnnotation(reference)
                }
            }
            .position(point(min(data.originNormalizedX + 0.10, 0.82), max(data.originNormalizedY - 0.10, 0.24), in: size))
            Image(systemName: "flag.checkered").foregroundStyle(.blue)
                .position(point(data.destinationNormalizedX, data.destinationNormalizedY, in: size))
            VStack(alignment: .leading, spacing: 7) {
                waypoint(title: data.destination, subtitle: "ARRIVAL · \(Self.feet(data.destinationCrossingAltitudeFeet)) FT MSL", symbol: "flag.checkered")
                ForEach(data.references.filter { $0.endpointName == data.destination }) { reference in
                    referenceAnnotation(reference)
                }
            }
            .position(point(max(data.destinationNormalizedX - 0.10, 0.22), max(data.destinationNormalizedY - 0.10, 0.18), in: size))
        }
    }

    private func waypoint(title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Image(systemName: symbol).font(.title3.weight(.semibold)).foregroundStyle(.blue)
            Text(title).font(.headline).lineLimit(1).minimumScaleFactor(0.7)
            Text(subtitle).font(.caption2.weight(.bold)).tracking(0.6).foregroundStyle(.secondary)
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
        .accessibilityElement(children: .combine)
    }

    private func referenceAnnotation(_ reference: CockpitPresentationData.PlannedReference) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("PLANNED REFERENCE · \(reference.source.rawValue.uppercased())")
                .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Text("\(reference.station) · \(Self.frequency(reference.frequencyMHz)) MHz · \(Self.degrees(reference.magneticRadialFromDegrees)) FROM")
                .font(.caption.weight(.semibold)).lineLimit(1)
            Text("\(Self.decimal(reference.slantRangeNauticalMiles)) NM DME")
                .font(.caption).monospacedDigit()
        }
        .padding(8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }

    private func eventAnnotations(in size: CGSize) -> some View {
        ZStack {
            ForEach(data.routeEvents) { event in
                eventAnnotation(event)
                    .position(point(event.normalizedX, event.normalizedY, in: size))
            }
        }
    }

    private func eventAnnotation(_ event: CockpitPresentationData.RouteEvent) -> some View {
        ZStack {
            Button {
                guard displayMode == .symbolsOnly else { return }
                selectedEventID = selectedEventID == event.id ? nil : event.id
            } label: {
                Image(systemName: symbol(for: event.kinds))
                    .font(.headline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(.white)
                    .background(Color.indigo, in: Circle())
                    .overlay { Circle().strokeBorder(.white.opacity(0.9), lineWidth: 2) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(event.title), \(event.detail), planned at \(Self.duration(event.timeFromLegStartSeconds)) from leg start")

            if displayMode == .labels {
                eventLabel(event, expanded: false).offset(calloutOffset(for: event))
            } else if selectedEventID == event.id {
                eventLabel(event, expanded: true).offset(calloutOffset(for: event)).zIndex(2)
            }
        }
    }

    private func eventLabel(_ event: CockpitPresentationData.RouteEvent, expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title.uppercased()).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Text(event.detail).font(.caption.weight(.semibold)).monospacedDigit()
            Text("+\(Self.duration(event.timeFromLegStartSeconds)) planned")
                .font(.caption2).foregroundStyle(.secondary).monospacedDigit()
            if expanded { Text("Passive note · no action applied").font(.caption2).foregroundStyle(.secondary) }
        }
        .lineLimit(expanded ? 3 : 1)
        .padding(.horizontal, 8).padding(.vertical, 6)
        .background(expanded ? AnyShapeStyle(.thickMaterial) : AnyShapeStyle(.regularMaterial), in: RoundedRectangle(cornerRadius: 7))
        .accessibilityElement(children: .combine)
    }

    private var schematicNotice: some View {
        Text("SCHEMATIC · SAVED POSITIONS · NOT FOR NAVIGATION")
            .font(.caption2.weight(.bold)).tracking(0.7).foregroundStyle(.secondary)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 20).padding(.bottom, 14)
    }

    private var legHeader: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Text(data.legPosition.uppercased()).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Text("·").foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Text(data.origin).lineLimit(1)
                    Image(systemName: "arrow.right").font(.caption)
                    Text(data.destination).lineLimit(1)
                }
                .font(.headline).minimumScaleFactor(0.7)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("From \(data.origin) to \(data.destination)")
            }
            Spacer(minLength: 8)
            Button { showsChartsUnavailable = true } label: {
                Label("Charts", systemImage: "map").font(.headline).frame(minHeight: 44).padding(.horizontal, 12)
            }
            .buttonStyle(.plain).foregroundStyle(.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 6)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)) }
        .frame(maxHeight: .infinity, alignment: .top).padding(20)
    }

    private var mapControls: some View {
        VStack(spacing: 8) {
            disabledMapControl(icon: "slider.horizontal.3", label: "Heading correction unavailable")
            disabledMapControl(icon: "point.topleft.down.to.point.bottomright.curvepath", label: "Route editing unavailable")
            Button { showsDisplayOptions = true } label: {
                Image(systemName: "map.circle").font(.headline).frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain).accessibilityLabel("Map Display Options")
            Button(action: onShowPlanInspection) {
                Image(systemName: "list.bullet.clipboard").font(.headline).frame(width: 44, height: 44)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
            }
            .buttonStyle(.plain).accessibilityLabel("Plan Inspection").accessibilityIdentifier("show-plan-inspection")
        }
        .padding(8).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 96).padding(.trailing, 20)
    }

    private func disabledMapControl(icon: String, label: String) -> some View {
        Button {} label: {
            Image(systemName: icon).font(.headline).frame(width: 44, height: 44)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain).disabled(true).accessibilityLabel(label)
    }

    private var portraitControlPanel: some View {
        VStack(spacing: 9) {
            HStack(alignment: .top, spacing: 0) {
                headingMetric
                timeMetric
                altitudeMetric
            }
            frequencyRow
            waypointReachedButton
        }
        .padding(.horizontal, 24).padding(.vertical, 10)
    }

    private var landscapeControlPanel: some View {
        VStack(spacing: 14) {
            headingMetric
            Divider()
            timeMetric
            Divider()
            altitudeMetric
            Divider()
            frequencyColumn
            Spacer(minLength: 8)
            waypointReachedButton
        }
        .padding(.horizontal, 18).padding(.vertical, 20)
        .background(Color(.systemBackground)).overlay(alignment: .leading) { Divider() }
    }

    private var headingMetric: some View {
        VStack(spacing: 3) {
            Text(data.magneticHeadingDegrees == nil ? "COURSE · MAGNETIC" : "HEADING · MAGNETIC")
                .font(.caption.weight(.semibold)).tracking(0.8).foregroundStyle(.secondary)
            Text(Self.degrees(data.magneticHeadingDegrees ?? data.magneticCourseDegrees))
                .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
            Text(data.magneticHeadingDegrees == nil ? "Saved course · No planned heading" : "Saved planned · Course \(Self.degrees(data.magneticCourseDegrees))")
                .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).accessibilityElement(children: .combine).accessibilityIdentifier("cockpit-heading")
    }

    private var timeMetric: some View {
        CockpitTimeMetric(
            plannedDurationSeconds: data.legDurationSeconds,
            legStartedAt: session.legStartedAt
        )
    }

    private var altitudeMetric: some View {
        VStack(spacing: 3) {
            Text("ALTITUDE").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            Text("\(Self.feet(data.initialAltitudeFeetMsl)) ft")
                .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
            Text("Initial planned · MSL").font(.caption).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity).accessibilityElement(children: .combine).accessibilityIdentifier("cockpit-altitude")
    }

    private var orderedFrequencies: [CockpitPresentationData.Frequency] {
        FlightPhase.allCases.flatMap { data.frequencies[$0] ?? [] }
    }

    private var frequencyRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 18) {
                Text("PLANNED FREQUENCIES").font(.caption2.weight(.bold)).tracking(0.7).foregroundStyle(.secondary)
                ForEach(orderedFrequencies) { frequencyValue($0) }
                if orderedFrequencies.isEmpty { Text("None").font(.caption).foregroundStyle(.secondary) }
                Text("Not tuned").font(.caption).foregroundStyle(.secondary)
            }
        }
        .scrollIndicators(.hidden).frame(minHeight: 30).padding(.horizontal, 10)
        .overlay(alignment: .top) { Divider() }.overlay(alignment: .bottom) { Divider() }
    }

    private var frequencyColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PLANNED FREQUENCIES").font(.caption2.weight(.bold)).tracking(0.7).foregroundStyle(.secondary)
                Spacer(); Text("Not tuned").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(orderedFrequencies) { frequencyValue($0) }
                    if orderedFrequencies.isEmpty { Text("None").font(.caption).foregroundStyle(.secondary) }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func frequencyValue(_ frequency: CockpitPresentationData.Frequency) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(frequency.service).font(.subheadline).lineLimit(2).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 5) {
                Text(Self.phaseAbbreviation(frequency.phase)).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text(frequency.role ?? frequency.source.rawValue).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text("\(Self.frequency(frequency.frequencyMHz)) MHz").font(.subheadline.weight(.semibold)).monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var waypointReachedButton: some View {
        if session.legState == .ready {
            Button(action: onStartLeg) {
                Label("Start Leg", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Starts timing the current navigation leg")
            .accessibilityIdentifier("start-leg")
        } else {
            Button {} label: {
                Label("Waypoint Reached", systemImage: "checkmark.circle.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.plain).foregroundStyle(.secondary)
            .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            .disabled(true)
            .accessibilityHint("Waypoint progression is not implemented in this delivery")
            .accessibilityIdentifier("waypoint-reached")
        }
    }

    private var displayOptionsSheet: some View {
        NavigationStack {
            Form {
                Section("Map annotations") {
                    Picker("Display mode", selection: $displayMode) {
                        ForEach(CockpitMapDisplayMode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    Text("Symbols Only reveals a passive event callout when its symbol is tapped.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Map Display Options")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showsDisplayOptions = false } } }
        }
        .presentationDetents([.medium])
    }

    private func symbol(for kinds: [ExecutionAnnotationKind]) -> String {
        if kinds.count > 1 { return "arrow.up.and.down.and.arrow.left.and.right" }
        switch kinds.first {
        case .identificationPoint: return "diamond"
        case .altitudeChange: return "arrow.up.to.line.compact"
        case .radioFrequencyChange: return "antenna.radiowaves.left.and.right"
        case nil: return "diamond"
        }
    }

    private func calloutOffset(for event: CockpitPresentationData.RouteEvent) -> CGSize {
        if event.normalizedX > 0.68 && event.normalizedY < 0.40 {
            return CGSize(width: -145, height: 95)
        }
        return event.normalizedY < 0.5
            ? CGSize(width: 45, height: 85)
            : CGSize(width: -45, height: -90)
    }

    private func point(_ x: Double, _ y: Double, in size: CGSize) -> CGPoint { CGPoint(x: size.width * x, y: size.height * y) }
    private static func degrees(_ value: Double) -> String { "\(value.formatted(.number.precision(.fractionLength(0))))° M" }
    private static func feet(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private static func decimal(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(1))) }
    private static func frequency(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2...3))) }
    private static func duration(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
    private static func phaseAbbreviation(_ phase: FlightPhase) -> String {
        switch phase { case .departure: "DEP"; case .enRoute: "ENR"; case .arrival: "ARR" }
    }
}

private struct CockpitTimeMetric: View {
    let plannedDurationSeconds: Int
    let legStartedAt: Date?

    var body: some View {
        if let legStartedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                metric(
                    primaryValue: duration(elapsedSeconds(from: legStartedAt, to: context.date)),
                    primaryLabel: "ELAPSED",
                    secondaryValue: "Planned  \(duration(plannedDurationSeconds))"
                )
            }
        } else {
            metric(
                primaryValue: duration(plannedDurationSeconds),
                primaryLabel: "PLANNED",
                secondaryValue: "Elapsed  --:--"
            )
        }
    }

    private func metric(
        primaryValue: String,
        primaryLabel: LocalizedStringKey,
        secondaryValue: String
    ) -> some View {
        VStack(spacing: 2) {
            Text("TIME").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            Text(primaryValue)
                .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
            Text(primaryLabel).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text(secondaryValue).font(.caption2.weight(.medium)).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cockpit-time")
    }

    private func elapsedSeconds(from start: Date, to now: Date) -> Int {
        max(0, Int(now.timeIntervalSince(start)))
    }

    private func duration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
