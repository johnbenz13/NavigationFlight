import SwiftUI

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
            displayFrequencies: populated ? [
                .init(id: "preview-frequency", phases: [.departure], service: "Very Long Preview Tower Service", serviceType: "Pilot override", frequencyMHz: 118.4, source: .user)
            ] : [],
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
        legIDs: [UUID(), UUID()],
        activeLegIndex: 1,
        executionMode: .wind
    )
}

private extension AviationMapPresentation {
    static let preview: AviationMapPresentation = {
        let from = AviationMapCoordinate(latitude: 32.45, longitude: 34.90)
        let to = AviationMapCoordinate(latitude: 32.60, longitude: 35.03)
        let fromID = UUID()
        let toID = UUID()
        return AviationMapPresentation(
            waypoints: [
                .init(id: fromID, name: "Departure", coordinate: from, role: .from),
                .init(id: toID, name: "Destination", coordinate: to, role: .to)
            ],
            legs: [.init(id: UUID(), index: 0, from: from, to: to)],
            activeLegIndex: 0,
            nextLegPreview: nil,
            endpointReferences: [],
            plannedDurationSeconds: 382,
            minuteMarkers: AviationMapSymbology.minuteMarkers(
                from: from,
                to: to,
                plannedDurationSeconds: 382
            )
        )
    }()
}

#Preview("11-inch iPad Portrait · Wind", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .cockpitPreview(heading: 74, populated: true), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, session: .preview, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Portrait · No Wind · Hebrew", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .cockpitPreview(heading: nil, populated: true, hebrew: true), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, session: .preview, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Landscape · Missing Optional Data", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .cockpitPreview(heading: nil, populated: false), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, session: .preview, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Landscape · Dark", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .cockpitPreview(heading: 74, populated: true), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, session: .preview, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: {}, onShowPlanInspection: {})
        .preferredColorScheme(.dark)
}
#endif

struct CockpitView: View {
    let data: CockpitPresentationData
    let mapPresentation: AviationMapPresentation
    let nextLegPreparation: NextLegPreparation?
    let previousLegSummary: PreviousLegSummary?
    let session: FlightSession
    let onStartLeg: () -> Void
    let onIdentifyDestination: () -> Void
    let onWaypointReached: () -> Void
    let onShowPlanInspection: () -> Void
    @State private var showsChartsUnavailable = false
    @State private var mapFocusRequest = AviationMapFocusRequest(mode: .leg)
    @State private var preservedMapCamera: AviationMapCameraState?
    @State private var isMapCameraUserControlled = false
    @State private var etaCalloutOffset = AviationMapVisualStyle.default.defaultEtaCalloutOffset
    @State private var isNextPreparationPresented = false
    @State private var isPreviousDrawerPresented = false

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
        .alert("Charts Unavailable", isPresented: $showsChartsUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Chart presentation is a later delivery. The imported plan remains unchanged.")
        }
        .onChange(of: session.activeLegIndex) { _, _ in
            etaCalloutOffset = AviationMapVisualStyle.default.defaultEtaCalloutOffset
            isNextPreparationPresented = false
            isPreviousDrawerPresented = false
        }
        .onChange(of: previousLegSummary?.legIndex) { _, _ in
            isPreviousDrawerPresented = false
        }
    }

    private var mapSurface: some View {
        ZStack {
            OfflineAviationMapView(
                presentation: mapPresentation,
                legState: session.legState,
                focusRequest: mapFocusRequest,
                etaCalloutOffset: $etaCalloutOffset,
                preservedCamera: $preservedMapCamera,
                isCameraUserControlled: $isMapCameraUserControlled
            )
            mapControls
            legHeader
            NextLegPreparationOverlay(
                preparation: session.legState == .active ? nextLegPreparation : nil,
                isPresented: $isNextPreparationPresented
            )
            PreviousLegDrawer(
                summary: previousLegSummary,
                isPresented: $isPreviousDrawerPresented
            )
        }
        .clipped()
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
            mapFocusButton(icon: "location.north.line.fill", label: "Focus Leg", mode: .leg)
            mapFocusButton(icon: "scope", label: "Focus Waypoint", mode: .waypoint)
            mapFocusButton(icon: "map", label: "Route Overview", mode: .overview)
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

    private func mapFocusButton(
        icon: String,
        label: String,
        mode: AviationMapFocusMode
    ) -> some View {
        Button {
            isMapCameraUserControlled = false
            mapFocusRequest = AviationMapFocusRequest(mode: mode)
        } label: {
            Image(systemName: icon).font(.headline).frame(width: 44, height: 44)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
        .padding(.horizontal, 24).padding(.top, 6).padding(.bottom, 10)
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
            Text(CockpitPresentationFormatter.aviationDegrees(data.magneticHeadingDegrees ?? data.magneticCourseDegrees))
                .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
            if data.magneticHeadingDegrees == nil {
                Text("Saved course · No planned heading")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            } else {
                Text("COURSE \(CockpitPresentationFormatter.aviationDegrees(data.magneticCourseDegrees))")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity).accessibilityElement(children: .combine).accessibilityIdentifier("cockpit-heading")
    }

    private var timeMetric: some View {
        CockpitTimeMetric(
            plannedDurationSeconds: data.legDurationSeconds,
            legStartedAt: session.legState == .active ? session.legStartedAt : nil
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

    private var orderedFrequencies: [CockpitPresentationData.DisplayFrequency] {
        data.displayFrequencies
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

    private func frequencyValue(_ frequency: CockpitPresentationData.DisplayFrequency) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 7) {
                Text("\(frequency.service) · \(frequency.serviceType)")
                    .font(.subheadline).lineLimit(1).minimumScaleFactor(0.8)
                Text("\(Self.frequency(frequency.frequencyMHz)) MHz")
                    .font(.subheadline.weight(.semibold)).monospacedDigit().lineLimit(1)
            }
            Text(frequency.phases.map(Self.phaseAbbreviation).joined(separator: " → "))
                .font(.caption2.weight(.bold)).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var waypointReachedButton: some View {
        switch session.legState {
        case .ready:
            Button(action: onStartLeg) {
                Label("Start Leg", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityHint("Starts timing the current navigation leg")
            .accessibilityIdentifier("start-leg")
        case .active:
            if session.destinationIdentifiedAt == nil {
                VStack(spacing: 2) {
                    Button {
                        isNextPreparationPresented = true
                        onIdentifyDestination()
                    } label: {
                        Label("Waypoint Identified", systemImage: "eye.fill")
                            .font(.headline).frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityHint("Records identifying the current destination without changing the active leg")
                    .accessibilityIdentifier("waypoint-identified")
                    Button("Reached now") {
                        etaCalloutOffset = AviationMapVisualStyle.default.defaultEtaCalloutOffset
                        onWaypointReached()
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .accessibilityHint("Records reaching the waypoint now without identifying it first")
                    .accessibilityIdentifier("reached-now")
                }
            } else {
                Button {
                    etaCalloutOffset = AviationMapVisualStyle.default.defaultEtaCalloutOffset
                    onWaypointReached()
                } label: {
                    Label("Waypoint Reached", systemImage: "checkmark.circle.fill")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Records reaching this waypoint and advances the navigation plan")
                .accessibilityIdentifier("waypoint-reached")
            }
        case .completed:
            Label("Navigation Complete", systemImage: "checkmark.circle.fill")
                .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.secondary)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier("navigation-complete")
        }
    }

    private static func feet(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private static func frequency(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2...3))) }
    nonisolated private static func phaseAbbreviation(_ phase: FlightPhase) -> String {
        switch phase { case .departure: "DEP"; case .enRoute: "ENR"; case .arrival: "ARR" }
    }
}

private struct NextLegPreparationOverlay: View {
    let preparation: NextLegPreparation?
    @Binding var isPresented: Bool
    private let style = AviationMapVisualStyle.default

    var body: some View {
        if let preparation {
            VStack(alignment: .trailing, spacing: 6) {
                if isPresented {
                    NextLegPreparationCard(preparation: preparation) {
                        withAnimation(.easeOut(duration: 0.2)) { isPresented = false }
                    }
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { isPresented = true }
                    } label: {
                        Label("NEXT", systemImage: "arrow.turn.up.right")
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 12)
                            .frame(minHeight: 36)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(uiColor: style.nextLegAccentColor))
                    .background(.regularMaterial, in: Capsule())
                    .overlay {
                        Capsule().stroke(Color(uiColor: style.nextLegAccentColor), lineWidth: 1.5)
                    }
                    .accessibilityIdentifier("next-leg-preview")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
    }
}

private struct NextLegPreparationCard: View {
    let preparation: NextLegPreparation
    let onCollapse: () -> Void
    private let style = AviationMapVisualStyle.default

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("NEXT · LEG \(preparation.legIndex + 1)")
                    .font(.caption.weight(.bold))
                Spacer()
                Button(action: onCollapse) {
                    Image(systemName: "chevron.down")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Collapse next leg")
            }
            preparationRow(label: directionLabel, value: directionValue)
            preparationRow(label: "ALT", value: altitudeValue)
            preparationRow(label: "FREQ", value: frequencyValue)
        }
        .padding(12)
        .frame(width: 224)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(uiColor: style.nextLegAccentColor), lineWidth: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("next-leg-card")
    }

    private func preparationRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
    }

    private var directionLabel: String {
        switch preparation.direction {
        case .heading: "HDG"
        case .course: "COURSE"
        }
    }

    private var directionValue: String {
        switch preparation.direction {
        case .heading(let degrees), .course(let degrees):
            CockpitPresentationFormatter.aviationDegrees(degrees)
        }
    }

    private var altitudeValue: String {
        let value = preparation.immediateAltitudeFeetMsl ?? preparation.initialAltitudeFeetMsl
        let formatted = value.formatted(.number.precision(.fractionLength(0)))
        return preparation.immediateAltitudeFeetMsl == nil ? "\(formatted) ft" : "→ \(formatted) ft"
    }

    private var frequencyValue: String {
        guard let change = preparation.immediateFrequencyChange else { return "No change" }
        let frequency = change.frequencyMHz.formatted(.number.precision(.fractionLength(2...3)))
        return "→ \(change.service) \(frequency)"
    }
}

private struct PreviousLegDrawer: View {
    let summary: PreviousLegSummary?
    @Binding var isPresented: Bool

    var body: some View {
        if let summary {
            Group {
                if isPresented {
                    PreviousLegSummaryCard(summary: summary) {
                        withAnimation(.easeOut(duration: 0.2)) { isPresented = false }
                    }
                    .gesture(closeGesture)
                } else {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { isPresented = true }
                    } label: {
                        VStack(spacing: 3) {
                            Text("PREV").font(.caption2.weight(.bold))
                            Text(CockpitPresentationFormatter.signedDuration(summary.deltaSeconds))
                                .font(.caption.weight(.semibold)).monospacedDigit()
                        }
                        .frame(width: 54, height: 58)
                    }
                    .buttonStyle(.plain)
                    .background(.regularMaterial, in: UnevenRoundedRectangle(bottomTrailingRadius: 10, topTrailingRadius: 10))
                    .accessibilityIdentifier("previous-leg-tab")
                    .gesture(openGesture)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    private var openGesture: some Gesture {
        DragGesture(minimumDistance: 32).onEnded { value in
            guard value.translation.width > 44,
                  abs(value.translation.width) > abs(value.translation.height) else { return }
            withAnimation(.easeOut(duration: 0.2)) { isPresented = true }
        }
    }

    private var closeGesture: some Gesture {
        DragGesture(minimumDistance: 32).onEnded { value in
            guard value.translation.width < -44,
                  abs(value.translation.width) > abs(value.translation.height) else { return }
            withAnimation(.easeOut(duration: 0.2)) { isPresented = false }
        }
    }

}

private struct PreviousLegSummaryCard: View {
    let summary: PreviousLegSummary
    let onClose: () -> Void
    private let style = AviationMapVisualStyle.default

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PREVIOUS · LEG \(summary.legIndex + 1)")
                    .font(.caption.weight(.bold))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "chevron.left").frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close previous leg")
            }
            Text("\(summary.origin) → \(summary.destination)")
                .font(.subheadline.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.8)
            Divider()
            row("PLAN", duration(summary.plannedDurationSeconds))
            row("ACTUAL", duration(summary.actualDurationSeconds))
            row("Δ", CockpitPresentationFormatter.signedDuration(summary.deltaSeconds))
            if let heading = summary.magneticHeadingDegrees {
                row("HDG", CockpitPresentationFormatter.aviationDegrees(heading))
            }
            row("COURSE", CockpitPresentationFormatter.aviationDegrees(summary.magneticCourseDegrees))
            if let reference = summary.vorDme {
                Divider()
                Text("VOR/DME").font(.caption2.weight(.bold)).foregroundStyle(.secondary)
                Text(referenceText(reference))
                    .font(.caption.weight(.semibold)).monospacedDigit()
            }
        }
        .padding(14)
        .frame(width: 272)
        .background(.regularMaterial, in: UnevenRoundedRectangle(bottomTrailingRadius: 14, topTrailingRadius: 14))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Color(uiColor: style.previousLegAccentColor)).frame(width: 2)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("previous-leg-drawer")
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption2.weight(.bold)).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.subheadline.weight(.semibold)).monospacedDigit()
        }
    }

    private func duration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

    private func referenceText(_ reference: PreviousLegSummary.VORDME) -> String {
        let radial = Int(reference.magneticRadialFromDegrees.rounded())
        let distance = reference.slantRangeNauticalMiles.formatted(.number.precision(.fractionLength(1)))
        return "\(reference.station) · R-\(String(format: "%03d", radial)) FROM · \(distance) NM"
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
                    secondaryValue: "PLAN \(duration(plannedDurationSeconds))"
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
            Text(secondaryValue).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
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
