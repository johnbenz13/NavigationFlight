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
        let legID = UUID()
        return AviationMapPresentation(
            waypoints: [
                .init(id: fromID, name: "Departure", coordinate: from, role: .from),
                .init(id: toID, name: "Destination", coordinate: to, role: .to)
            ],
            legs: [.init(id: legID, index: 0, from: from, to: to)],
            activeLegIndex: 0,
            nextLegPreview: nil,
            endpointReferences: [],
            plannedDurationSeconds: 382,
            minuteMarkers: AviationMapSymbology.minuteMarkers(
                from: from,
                to: to,
                plannedDurationSeconds: 382
            ),
            identificationPoints: [],
            destinationTarget: .init(
                id: NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: toID),
                name: "Destination",
                plannedElapsedSeconds: 382,
                committedETASeconds: nil
            ),
            driftReferenceArms: AviationMapGeometry.driftReferenceArms(from: from, to: to, angleDegrees: 10)
        )
    }()
}

#Preview("11-inch iPad Portrait · Wind", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .cockpitPreview(heading: 74, populated: true), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, legStartChecklist: nil, checklistState: nil, session: .preview, areDriftLinesVisible: true, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: {}, onIdentificationPointReached: { _, _ in }, onOpenPilotETA: { _ in }, onAdjustPilotETA: { _, _ in }, onCommitPilotETA: { _ in }, onCancelPilotETA: { _ in }, onEditPilotETA: { _ in }, onShowPilotETACheck: { _ in }, onHidePilotETACheck: { _ in }, onCollapseChecklist: {}, onReopenChecklist: {}, onNoteChecklist: {}, onToggleDriftLines: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Portrait · No Wind · Hebrew", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .cockpitPreview(heading: nil, populated: true, hebrew: true), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, legStartChecklist: nil, checklistState: nil, session: .preview, areDriftLinesVisible: true, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: {}, onIdentificationPointReached: { _, _ in }, onOpenPilotETA: { _ in }, onAdjustPilotETA: { _, _ in }, onCommitPilotETA: { _ in }, onCancelPilotETA: { _ in }, onEditPilotETA: { _ in }, onShowPilotETACheck: { _ in }, onHidePilotETACheck: { _ in }, onCollapseChecklist: {}, onReopenChecklist: {}, onNoteChecklist: {}, onToggleDriftLines: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Landscape · Missing Optional Data", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .cockpitPreview(heading: nil, populated: false), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, legStartChecklist: nil, checklistState: nil, session: .preview, areDriftLinesVisible: true, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: {}, onIdentificationPointReached: { _, _ in }, onOpenPilotETA: { _ in }, onAdjustPilotETA: { _, _ in }, onCommitPilotETA: { _ in }, onCancelPilotETA: { _ in }, onEditPilotETA: { _ in }, onShowPilotETACheck: { _ in }, onHidePilotETACheck: { _ in }, onCollapseChecklist: {}, onReopenChecklist: {}, onNoteChecklist: {}, onToggleDriftLines: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Landscape · Dark", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .cockpitPreview(heading: 74, populated: true), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, legStartChecklist: nil, checklistState: nil, session: .preview, areDriftLinesVisible: true, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: {}, onIdentificationPointReached: { _, _ in }, onOpenPilotETA: { _ in }, onAdjustPilotETA: { _, _ in }, onCommitPilotETA: { _ in }, onCancelPilotETA: { _ in }, onEditPilotETA: { _ in }, onShowPilotETACheck: { _ in }, onHidePilotETACheck: { _ in }, onCollapseChecklist: {}, onReopenChecklist: {}, onNoteChecklist: {}, onToggleDriftLines: {}, onShowPlanInspection: {})
        .preferredColorScheme(.dark)
}
#endif

enum SelectedMapCallout: Equatable {
    case identificationPoint(IdentificationPointKey)
    case timingTarget(NavigationTimingTargetKey)
}

struct CockpitView: View {
    private let visualStyle = AviationMapVisualStyle.default
    let data: CockpitPresentationData
    let mapPresentation: AviationMapPresentation
    let nextLegPreparation: NextLegPreparation?
    let previousLegSummary: PreviousLegSummary?
    let legStartChecklist: LegStartChecklistPresentation?
    let checklistState: CockpitFeatureState.LegStartChecklistState?
    let session: FlightSession
    let areDriftLinesVisible: Bool
    let onStartLeg: () -> Void
    let onIdentifyDestination: () -> Void
    let onWaypointReached: () -> Void
    let onIdentificationPointReached: (IdentificationPointKey, AviationMapPresentation) throws -> Void
    let onOpenPilotETA: (AviationMapETATarget) -> Void
    let onAdjustPilotETA: (NavigationTimingTargetKey, Int) -> Void
    let onCommitPilotETA: (NavigationTimingTargetKey) -> Void
    let onCancelPilotETA: (NavigationTimingTargetKey) -> Void
    let onEditPilotETA: (NavigationTimingTargetKey) -> Void
    let onShowPilotETACheck: (NavigationTimingTargetKey) -> Void
    let onHidePilotETACheck: (NavigationTimingTargetKey) -> Void
    var onOpenPilotHeading: (Int) -> Void = { _ in }
    var onAdjustPilotHeading: (Int) -> Void = { _ in }
    var onCommitPilotHeading: () -> Void = {}
    var onCancelPilotHeading: () -> Void = {}
    let onCollapseChecklist: () -> Void
    let onReopenChecklist: () -> Void
    let onNoteChecklist: () -> Void
    let onToggleDriftLines: () -> Void
    let onShowPlanInspection: () -> Void
    @State private var showsChartsUnavailable = false
    @State private var mapFocusRequest = AviationMapFocusRequest(mode: .leg)
    @State private var preservedMapCamera: AviationMapCameraState?
    @State private var isMapCameraUserControlled = false
    @State private var timingTargetCalloutOffsets: [NavigationTimingTargetKey: AviationMapCalloutOffset] = [:]
    @State private var isNextPreparationPresented = false
    @State private var isPreviousDrawerPresented = false
    @State private var selectedMapCallout: SelectedMapCallout?
    @State private var identificationPointCalloutOffsets: [IdentificationPointKey: AviationMapCalloutOffset] = [:]
    @State private var vorDMECalloutOffsets: [UUID: AviationMapCalloutOffset] = [:]
    @State private var identificationPointReportError: FlightSession.TransitionError?
    @State private var showsHeadingCommitConfirmation = false

    var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > geometry.size.height {
                HStack(spacing: 0) {
                    mapSurface(isLandscape: true, mapWidth: geometry.size.width * 0.74)
                        .frame(width: geometry.size.width * 0.74)
                    landscapeControlPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                VStack(spacing: 0) {
                    mapSurface(isLandscape: false, mapWidth: geometry.size.width)
                        .frame(height: geometry.size.height * 0.66)
                    portraitControlPanel
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .background(Color(.systemBackground))
        .overlay {
            ZStack {
                if let headingState = activeHeadingState, headingState.isEditing {
                    headingEditor(state: headingState)
                }
                if showsHeadingCommitConfirmation,
                   let committed = activeHeadingState?.committedDegrees {
                    VStack {
                        Spacer()
                        Label("Revised Heading \(Self.heading(committed)) is now operational", systemImage: "checkmark")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.systemGreen))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 14))
                            .shadow(color: .black.opacity(0.16), radius: 8, y: 3)
                            .padding(.bottom, 24)
                            .accessibilityIdentifier("heading-commit-confirmation")
                    }
                }
            }
        }
        .alert("Charts Unavailable", isPresented: $showsChartsUnavailable) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Chart presentation is a later delivery. The imported plan remains unchanged.")
        }
        .onChange(of: session.activeLegIndex) { _, _ in
            isNextPreparationPresented = false
            isPreviousDrawerPresented = false
            selectedMapCallout = nil
            showsHeadingCommitConfirmation = false
        }
        .onChange(of: previousLegSummary?.legIndex) { _, _ in
            isPreviousDrawerPresented = false
        }
    }

    private func mapSurface(isLandscape: Bool, mapWidth: CGFloat) -> some View {
        ZStack {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                OfflineAviationMapView(
                presentation: mapPresentation,
                legState: session.legState,
                showsDriftReferenceArms: areDriftLinesVisible,
                focusRequest: mapFocusRequest,
                etaCalloutOffset: destinationCalloutOffset,
                vorDMECalloutOffset: destinationVORDMECalloutOffset,
                identificationPointCalloutOffsets: $identificationPointCalloutOffsets,
                identificationContext: identificationContext,
                timingTargetContext: timingTargetContext(at: timeline.date),
                preservedCamera: $preservedMapCamera,
                isCameraUserControlled: $isMapCameraUserControlled,
                onSelectIdentificationPoint: selectIdentificationPoint,
                onSelectTimingTarget: selectTimingTarget,
                onDismissCallout: dismissMapCallout,
                onReachIdentificationPoint: reachSelectedIdentificationPoint,
                onAdjustPilotETA: onAdjustPilotETA,
                onCommitPilotETA: commitPilotETA,
                onEditPilotETA: onEditPilotETA,
                onShowPilotETACheck: onShowPilotETACheck,
                onHidePilotETACheck: onHidePilotETACheck
                )
                .accessibilityIdentifier("aviation-map")
            }
            mapControls
            driftLinesControl
            legHeader
            NextLegPreparationOverlay(
                preparation: session.destinationIdentifiedAt == nil ? nil : nextLegPreparation,
                isPresented: Binding(
                    get: { isNextPreparationPresented && selectedIdentificationPointID == nil },
                    set: { isNextPreparationPresented = $0 }
                )
            )
            PreviousLegDrawer(
                summary: previousLegSummary,
                isPresented: $isPreviousDrawerPresented,
                onOpen: {
                    selectedMapCallout = nil
                }
            )
            LegStartChecklistOverlay(
                checklist: legStartChecklist,
                state: checklistState,
                legStartedAt: session.legStartedAt,
                isLandscape: isLandscape,
                onCollapse: onCollapseChecklist,
                onReopen: onReopenChecklist,
                onNoted: onNoteChecklist
            )
        }
        .clipped()
    }

    private var legHeader: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Text(legStatusText)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .accessibilityIdentifier("leg-status")
                Text("·").foregroundStyle(.secondary)
                Text(data.legPosition.uppercased()).font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                if showsLegRouteInHeader {
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
            mapFocusButton(icon: "⌖", label: "Focus Leg", mode: .leg)
            mapFocusButton(icon: "◎", label: "Focus Waypoint", mode: .waypoint)
            mapFocusButton(icon: "▱", label: "Route Overview", mode: .overview)
            Button(action: onShowPlanInspection) {
                mapControlIcon("≣")
            }
            .buttonStyle(.plain).accessibilityLabel("Plan Inspection").accessibilityIdentifier("show-plan-inspection")
        }
        .padding(6)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 17))
        .shadow(color: .black.opacity(0.08), radius: 8, y: 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .padding(.top, 96).padding(.trailing, 20)
    }

    private var driftLinesControl: some View {
        Button(action: onToggleDriftLines) {
            Label(
                areDriftLinesVisible ? "Drift lines on" : "Drift lines off",
                systemImage: "wind"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(areDriftLinesVisible ? .primary : .secondary)
            .frame(width: 150, height: 40)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            areDriftLinesVisible
                ? "Hide drift lines, manual calculation aid"
                : "Show drift lines, manual calculation aid"
        )
        .accessibilityHint("Does not show the aircraft’s actual track.")
        .accessibilityIdentifier("toggle-drift-lines")
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.top, 96)
        .padding(.leading, 20)
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
            mapControlIcon(icon)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(mapControlIdentifier(for: mode))
    }

    private func mapControlIcon(_ icon: String) -> some View {
        Text(icon)
            .font(.system(size: 20, weight: .medium))
            .foregroundStyle(.black)
            .frame(width: 44, height: 44)
            .background(Color(red: 246 / 255, green: 247 / 255, blue: 250 / 255), in: RoundedRectangle(cornerRadius: 10))
    }

    private func mapControlIdentifier(for mode: AviationMapFocusMode) -> String {
        switch mode {
        case .leg: "focus-leg"
        case .waypoint: "focus-waypoint"
        case .overview: "route-overview"
        case .timingTarget: "focus-timing-target"
        }
    }

    private func disabledMapControl(icon: String, label: String) -> some View {
        Button {} label: {
            Image(systemName: icon).font(.headline).frame(width: 44, height: 44)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain).disabled(true).accessibilityLabel(label)
    }

    private var portraitControlPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ACTIVE LEG INSTRUMENTS")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(.secondary)

            HStack(alignment: .top, spacing: 12) {
                readyHeadingMetric
                portraitTimerMetric
                readyETAMetric
                readyAltitudeMetric
            }

            Divider()
            readyFrequencyRow
            Divider()
            portraitActionRow
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var portraitTimerMetric: some View {
        if session.legState == .active, let legStartedAt = session.legStartedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                readyInstrumentCard(
                    title: "LEG TIMER",
                    value: Self.duration(max(0, Int(context.date.timeIntervalSince(legStartedAt)))),
                    detail: "Running from pilot start",
                    valueColor: Color(.systemTeal),
                    accessibilityIdentifier: "cockpit-time",
                    highlighted: true
                )
            }
        } else {
            readyTimerMetric
        }
    }

    private var readyHeadingMetric: some View {
        Button {
            showsHeadingCommitConfirmation = false
            onOpenPilotHeading(importedHeadingDegrees)
        } label: {
            readyInstrumentCard(
                title: activeHeadingState?.committedDegrees == nil
                    ? (data.magneticHeadingDegrees == nil ? "PLANNED COURSE" : "PLANNED HEADING")
                    : "REVISED HEADING",
                value: Self.heading(activeHeadingState?.operationalDegrees ?? importedHeadingDegrees),
                detail: activeHeadingState?.committedDegrees == nil
                    ? (activeHeadingState?.isEditing == true
                        ? "Operational until Commit"
                        : (data.magneticHeadingDegrees == nil ? "No-wind course · magnetic" : "Planned-wind heading · magnetic"))
                    : "Baseline \(Self.heading(activeHeadingState?.baselineDegrees ?? importedHeadingDegrees)) · magnetic",
                valueColor: Color(uiColor: visualStyle.currentLegAccentColor),
                accessibilityIdentifier: "cockpit-heading",
                highlighted: true,
                highlightColor: activeHeadingState?.committedDegrees == nil ? Color(.systemBlue) : Color(.systemGreen)
            )
        }
        .buttonStyle(.plain)
        .disabled(session.legState != .active)
        .accessibilityLabel(
            activeHeadingState?.committedDegrees == nil
                ? "\(data.magneticHeadingDegrees == nil ? "PLANNED COURSE" : "PLANNED HEADING"), \(Self.heading(importedHeadingDegrees)), \(data.magneticHeadingDegrees == nil ? "No-wind course · magnetic" : "Planned-wind heading · magnetic")"
                : "REVISED HEADING, \(Self.heading(activeHeadingState?.operationalDegrees ?? importedHeadingDegrees)), Pilot-revised · magnetic"
        )
        .accessibilityHint(session.legState == .active ? "Opens the magnetic heading editor" : "Available while the leg is active")
        .accessibilityIdentifier("cockpit-heading")
    }

    private var activeHeadingState: FlightSession.PilotHeadingState? {
        guard session.legIDs.indices.contains(session.activeLegIndex) else { return nil }
        return session.pilotHeadingState(for: session.legIDs[session.activeLegIndex])
    }

    private var importedHeadingDegrees: Int {
        Int((data.magneticHeadingDegrees ?? data.magneticCourseDegrees).rounded())
    }

    private func headingEditor(state: FlightSession.PilotHeadingState) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("REVISED HEADING · MAGNETIC")
                .font(.caption.weight(.bold))
                .foregroundStyle(.blue)
            Text(state.commits.isEmpty ? "Set pilot-calculated heading" : "Revise current segment heading")
                .font(.headline)
            Divider()
            Text("IMPORTED BASELINE")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Text(state.commits.isEmpty
                    ? "\(data.magneticHeadingDegrees == nil ? "No-wind magnetic course" : "Planned magnetic heading") · \(Self.heading(state.baselineDegrees))"
                    : "Current revised \(Self.heading(state.operationalDegrees)) · baseline \(Self.heading(state.baselineDegrees))")
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                if state.draftDegrees != state.operationalDegrees {
                    Text("NOT COMMITTED")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Color(.systemOrange))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 6)
                        .background(Color(.systemOrange).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            Text("DRAFT HEADING")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.blue)
            HStack {
                headingAdjustmentButton(title: "−1°", delta: -1)
                Spacer()
                Text(Self.heading(state.draftDegrees))
                    .font(.title.weight(.bold))
                    .monospacedDigit()
                    .accessibilityIdentifier("heading-draft")
                Spacer()
                headingAdjustmentButton(title: "+1°", delta: 1)
            }
            .padding()
            .background(Color(.systemBlue).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            HStack {
                Button("Cancel", action: onCancelPilotHeading)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                Button("Commit Heading") {
                    onCommitPilotHeading()
                    showsHeadingCommitConfirmation = true
                }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("commit-heading")
            }
            Text("Pilot-calculated · no Check or recommendation")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !state.commits.isEmpty {
                Divider()
                Text("THIS SEGMENT")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text("Committed \(state.commits.map { Self.heading($0.degrees) }.joined(separator: " → "))")
                    .font(.caption)
            }
        }
        .padding(20)
        .frame(width: 370)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color(.separator)) }
        .shadow(color: .black.opacity(0.2), radius: 12, y: 5)
    }

    private func headingAdjustmentButton(title: String, delta: Int) -> some View {
        Button(title) { onAdjustPilotHeading(delta) }
            .font(.headline)
            .frame(minWidth: 64, minHeight: 44)
            .accessibilityLabel(delta < 0 ? "Decrease magnetic heading by one degree" : "Increase magnetic heading by one degree")
            .accessibilityIdentifier(delta < 0 ? "decrease-heading" : "increase-heading")
    }

    private static func heading(_ degrees: Int) -> String {
        String(format: "%03d°", FlightSession.normalizedHeading(degrees))
    }

    private var readyTimerMetric: some View {
        readyInstrumentCard(
            title: "LEG TIMER",
            value: "–:––",
            detail: "Starts when Start Leg is pressed",
            valueColor: Color(.systemTeal),
            accessibilityIdentifier: "cockpit-time",
            highlighted: true
        )
    }

    private var readyETAMetric: some View {
        readyInstrumentCard(
            title: "NEXT ETA · \(data.destination.uppercased())",
            value: Self.duration(data.legDurationSeconds),
            detail: "Planned · elapsed from leg start",
            valueColor: .primary,
            accessibilityIdentifier: "cockpit-eta"
        )
    }

    private var readyAltitudeMetric: some View {
        readyInstrumentCard(
            title: "ALTITUDE",
            value: "\(Self.feet(data.initialAltitudeFeetMsl)) ft",
            detail: "Initial planned · MSL",
            valueColor: .primary,
            accessibilityIdentifier: "cockpit-altitude"
        )
    }

    private func readyInstrumentCard(
        title: String,
        value: String,
        detail: String,
        valueColor: Color,
        accessibilityIdentifier: String,
        highlighted: Bool = false,
        highlightColor: Color = Color(.systemTeal)
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .id(detail)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(10)
        .background(
            highlighted ? highlightColor.opacity(0.12) : Color(.secondarySystemBackground),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay {
            if highlighted {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(highlightColor.opacity(0.75), lineWidth: 2)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var readyFrequencyRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLANNED FREQUENCIES")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(.secondary)

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(orderedFrequencies) { readyFrequencyCard($0) }
                    if orderedFrequencies.isEmpty {
                        Text("No planned frequencies")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 12)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .accessibilityIdentifier("planned-frequencies")
    }

    private func readyFrequencyCard(_ frequency: CockpitPresentationData.DisplayFrequency) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(frequency.service) · \(frequency.serviceType)")
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
            Text("\(Self.frequency(frequency.frequencyMHz)) MHz")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
            Text(frequency.phases.map(Self.phaseAbbreviation).joined(separator: " → "))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 11))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(frequency.service) · \(frequency.serviceType), "
                + "\(Self.frequency(frequency.frequencyMHz)) MHz, "
                + frequency.phases.map(Self.phaseAbbreviation).joined(separator: " to ")
        )
    }

    private var readyStartRow: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 5) {
                Text("LEG START · \(data.origin) → \(data.destination)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(previousLegSummary == nil
                    ? "Confirm planned values before beginning."
                    : "The previous leg is complete. Review the successor before starting.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(previousLegSummary == nil
                    ? "Timing starts only after this action."
                    : "This leg remains untimed until Start Leg.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(action: onStartLeg) {
                Label("Start Leg", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(uiColor: visualStyle.primaryActionColor))
            .frame(maxWidth: 350)
            .accessibilityHint("Starts timing the current navigation leg")
            .accessibilityIdentifier("start-leg")
        }
    }

    @ViewBuilder
    private var portraitActionRow: some View {
        switch session.legState {
        case .ready:
            readyStartRow
        case .active:
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("ARRIVAL CALL TO ACTION · \(data.destination.uppercased())")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(arrivalPrimaryGuidance)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(arrivalSecondaryGuidance)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                waypointReachedButton
                    .frame(maxWidth: 350)
            }
        case .completed:
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FLIGHT COMPLETE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("Final arrival reached at \(completedLegDurationText).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("No successor leg or timer is started.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                waypointReachedButton
                    .frame(maxWidth: 350)
            }
        }
    }

    private var legStatusText: String {
        switch session.legState {
        case .ready:
            previousLegSummary == nil ? "READY" : "READY · SUCCESSOR TRACK-UP"
        case .active:
            session.destinationIdentifiedAt == nil ? "ACTIVE" : "ACTIVE · DESTINATION IDENTIFIED"
        case .completed:
            "COMPLETE"
        }
    }

    private var showsLegRouteInHeader: Bool {
        switch session.legState {
        case .ready:
            previousLegSummary == nil
        case .active:
            session.destinationIdentifiedAt == nil
        case .completed:
            false
        }
    }

    private var arrivalPrimaryGuidance: String {
        guard let identifiedAt = session.destinationIdentifiedAt,
              let startedAt = session.legStartedAt else {
            return "Identify the waypoint when it is positively recognized."
        }
        let elapsedSeconds = max(0, Int(identifiedAt.timeIntervalSince(startedAt).rounded()))
        return "Destination identified at \(Self.duration(elapsedSeconds)). Leg timing continues."
    }

    private var arrivalSecondaryGuidance: String {
        session.destinationIdentifiedAt == nil
            ? "The active leg continues until you record reaching it."
            : "ETA revisions remain available until reach."
    }

    private var completedLegDurationText: String {
        guard let timing = session.legTimings.first(where: { $0.legIndex == session.activeLegIndex }),
              let duration = timing.actualElapsedDuration else { return "–:––" }
        return Self.duration(max(0, Int(duration.rounded())))
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
        Button {
            showsHeadingCommitConfirmation = false
            onOpenPilotHeading(importedHeadingDegrees)
        } label: {
            VStack(spacing: 3) {
            Text(activeHeadingState?.committedDegrees == nil
                ? (data.magneticHeadingDegrees == nil ? "COURSE · MAGNETIC" : "HEADING · MAGNETIC")
                : "REVISED HEADING · MAGNETIC")
                .font(.caption.weight(.semibold)).tracking(0.8).foregroundStyle(.secondary)
            Text(Self.heading(activeHeadingState?.operationalDegrees ?? importedHeadingDegrees))
                .font(.system(size: 30, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
            if let state = activeHeadingState, state.committedDegrees != nil {
                Text("Baseline \(Self.heading(state.baselineDegrees)) · pilot-revised")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            } else if data.magneticHeadingDegrees == nil {
                Text("Saved course · No planned heading")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            } else {
                Text("COURSE \(CockpitPresentationFormatter.aviationDegrees(data.magneticCourseDegrees))")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .disabled(session.legState != .active)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(activeHeadingState?.committedDegrees == nil
            ? "Planned magnetic heading, \(Self.heading(importedHeadingDegrees))"
            : "Pilot-revised magnetic heading, \(Self.heading(activeHeadingState?.operationalDegrees ?? importedHeadingDegrees))")
        .accessibilityIdentifier("cockpit-heading")
    }

    private var timeMetric: some View {
        CockpitTimeMetric(
            plannedDurationSeconds: mapPresentation.currentETATarget.committedETASeconds == nil
                ? data.legDurationSeconds
                : mapPresentation.currentETATarget.plannedElapsedSeconds,
            operationalETASeconds: mapPresentation.currentETATarget.committedETASeconds,
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
            .tint(Color(uiColor: visualStyle.primaryActionColor))
            .accessibilityHint("Starts timing the current navigation leg")
            .accessibilityIdentifier("start-leg")
        case .active:
            if session.destinationIdentifiedAt == nil {
                VStack(spacing: 2) {
                    Button {
                        selectedMapCallout = nil
                        onIdentifyDestination()
                    } label: {
                        HStack(spacing: 8) {
                            Text("◉")
                            Text("Waypoint Identified")
                        }
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(uiColor: visualStyle.primaryActionColor))
                    .accessibilityHint("Records identifying the current destination without changing the active leg")
                    .accessibilityIdentifier("waypoint-identified")
                    Button("Reached now") {
                        isNextPreparationPresented = false
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
                    onWaypointReached()
                } label: {
                    Label("Waypoint Reached", systemImage: "checkmark.circle.fill")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(uiColor: visualStyle.primaryActionColor))
                .foregroundStyle(Color(uiColor: visualStyle.cockpitProgressionActionForegroundColor))
                .accessibilityHint("Records reaching this waypoint and advances the navigation plan")
                .accessibilityIdentifier("waypoint-reached")
            }
        case .completed:
            Label("Navigation Complete", systemImage: "checkmark.circle.fill")
                .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                .foregroundStyle(.white)
                .background(
                    Color(uiColor: visualStyle.cockpitProgressionActionBackgroundColor),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .accessibilityIdentifier("navigation-complete")
        }
    }

    private static func feet(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private static func frequency(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2...3))) }
    private static func duration(_ seconds: Int) -> String { String(format: "%02d:%02d", seconds / 60, seconds % 60) }
    nonisolated private static func phaseAbbreviation(_ phase: FlightPhase) -> String {
        switch phase { case .departure: "DEP"; case .enRoute: "ENR"; case .arrival: "ARR" }
    }

    private var selectedIdentificationPoint: AviationMapIdentificationPoint? {
        guard let selectedIdentificationPointID else { return nil }
        return mapPresentation.identificationPoints.first { $0.id == selectedIdentificationPointID }
    }

    private var selectedIdentificationPointID: IdentificationPointKey? {
        guard case .identificationPoint(let id) = selectedMapCallout else { return nil }
        return id
    }

    private var selectedTimingTargetKey: NavigationTimingTargetKey? {
        guard case .timingTarget(let key) = selectedMapCallout else { return nil }
        return key
    }

    private var destinationCalloutOffset: Binding<AviationMapCalloutOffset> {
        let key = mapPresentation.destinationTarget.id
        return Binding(
            get: { timingTargetCalloutOffsets[key] ?? visualStyle.defaultEtaCalloutOffset },
            set: { timingTargetCalloutOffsets[key] = $0 }
        )
    }

    private var destinationVORDMECalloutOffset: Binding<AviationMapCalloutOffset> {
        let waypointID = mapPresentation.destinationTarget.id.targetID
        return Binding(
            get: { vorDMECalloutOffsets[waypointID] ?? visualStyle.defaultVORDMECalloutOffset },
            set: { vorDMECalloutOffsets[waypointID] = $0 }
        )
    }

    private func selectIdentificationPoint(_ id: IdentificationPointKey) {
        identificationPointReportError = nil
        if selectedIdentificationPointID == id {
            selectedMapCallout = nil
            return
        }
        selectedMapCallout = .identificationPoint(id)
        isNextPreparationPresented = false
        onCollapseChecklist()
    }

    private func commitPilotETA(_ key: NavigationTimingTargetKey) {
        onCommitPilotETA(key)
    }

    private func dismissMapCallout() {
        if let key = selectedTimingTargetKey,
           let etaState = session.pilotETAState(targetKey: key) {
            if etaState.isEditing {
                onCancelPilotETA(key)
            }
            if etaState.isCheckResultVisible {
                onHidePilotETACheck(key)
            }
        }
        selectedMapCallout = nil
    }

    private func selectTimingTarget(_ key: NavigationTimingTargetKey) {
        guard let target = mapPresentation.timingTarget(for: key) else { return }
        if selectedTimingTargetKey == key {
            dismissMapCallout()
        } else {
            if let selectedTimingTargetKey,
               session.pilotETAState(targetKey: selectedTimingTargetKey)?.isEditing == true {
                onCancelPilotETA(selectedTimingTargetKey)
            }
            selectedMapCallout = .timingTarget(key)
        }
        if selectedTimingTargetKey != nil {
            isNextPreparationPresented = false
            onCollapseChecklist()
            onOpenPilotETA(target)
            focusMap(on: target)
        }
    }

    private func reviseNextETA(_ target: AviationMapETATarget) {
        if let selectedTimingTargetKey,
           session.pilotETAState(targetKey: selectedTimingTargetKey)?.isEditing == true {
            onCancelPilotETA(selectedTimingTargetKey)
        }
        selectedMapCallout = .timingTarget(target.id)
        onOpenPilotETA(target)
        focusMap(on: target)
    }

    private func focusMap(on target: AviationMapETATarget) {
        let coordinate: AviationMapCoordinate?
        switch target.kind {
        case .destination:
            coordinate = mapPresentation.activeLeg?.to
        case .identificationPoint:
            coordinate = mapPresentation.identificationPoints.first {
                $0.id.legID == target.id.legID && $0.id.identificationPointID == target.id.targetID
            }?.coordinate
        }
        if let coordinate {
            mapFocusRequest = AviationMapFocusRequest(mode: .timingTarget(coordinate))
        }
    }

    private func reachSelectedIdentificationPoint() {
        guard let point = selectedIdentificationPoint else { return }
        do {
            try onIdentificationPointReached(point.id, mapPresentation)
            identificationPointReportError = nil
        } catch let error as FlightSession.TransitionError {
            identificationPointReportError = error
        } catch {
            identificationPointReportError = .invalidIdentificationPointOrder
        }
    }

    private var identificationContext: AviationMapIdentificationContext? {
        guard let point = selectedIdentificationPoint else { return nil }
        let nextTarget = mapPresentation.nextETATarget(after: point.id)
        let actual = session.actualLegElapsedDuration(atIdentificationPoint: point.id).map {
            IdentificationPointTimingCalculator.displaySeconds($0)
        }
        return AviationMapIdentificationContext(
            pointID: point.id,
            actualElapsedSeconds: actual,
            nextTarget: nextTarget,
            reportError: identificationPointReportError
        )
    }

    private func timingTargetContext(at timestamp: Date) -> AviationMapTimingTargetContext? {
        guard let key = selectedTimingTargetKey,
              let target = mapPresentation.timingTarget(for: key),
              let etaState = session.pilotETAState(targetKey: key) else { return nil }
        let disclosure = etaState.latestCheckDisclosure
        let reference = disclosure?.referenceSeconds
        let targetIndex = target.kind == .destination
            ? mapPresentation.identificationPoints.endIndex
            : mapPresentation.identificationPoints.firstIndex { $0.id.identificationPointID == target.id.targetID }
        let canCheck = targetIndex.map { index in
            mapPresentation.identificationPoints[..<index].contains {
                $0.plannedElapsedSeconds > 0
                    && session.identificationPointState(for: $0.id).isReached
                    && session.actualLegElapsedDuration(atIdentificationPoint: $0.id) != nil
            }
        } ?? false
        let observationBasis = disclosure.flatMap { disclosure -> String? in
            let observationKey = disclosure.observationKey
            guard let point = mapPresentation.identificationPoints.first(where: { $0.id == observationKey }),
                  let actual = session.actualLegElapsedDuration(atIdentificationPoint: observationKey) else { return nil }
            let actualSeconds = IdentificationPointTimingCalculator.displaySeconds(actual)
            return "\(point.name) · Actual \(AviationMapSymbology.formatDuration(actualSeconds)) / Planned \(AviationMapSymbology.formatDuration(point.plannedElapsedSeconds))"
        }
        return AviationMapTimingTargetContext(
            target: target,
            targetIdentifier: targetIndex.map { index in
                target.kind == .destination ? target.name.uppercased() : "IP \(index + 1)"
            } ?? target.name.uppercased(),
            pilotETAState: etaState,
            timingReferenceSeconds: reference,
            observationBasis: observationBasis,
            canCheck: canCheck,
            minimumETASeconds: FlightSession.pilotETAMinimumSeconds(
                currentElapsedSeconds: session.elapsedTime(at: timestamp)
                    .map(IdentificationPointTimingCalculator.displaySeconds) ?? 0
            )
        )
    }
}

private struct IdentificationPointContextOverlay: View {
    let point: AviationMapIdentificationPoint?
    let session: FlightSession
    let nextTarget: AviationMapETATarget?
    let isChecked: Bool
    let visualStyle: AviationMapVisualStyle
    let onDismiss: () -> Void
    let onReached: () -> Void
    let onAdjust: (NavigationTimingTargetKey, Int) -> Void
    let onCheck: () -> Void

    var body: some View {
        if let point {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("IDENTIFICATION POINT")
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .foregroundStyle(.secondary)
                        Text(point.isReached ? "\(point.name) · Reached" : point.name)
                            .font(.headline)
                    }
                    Spacer()
                    Button("Close", systemImage: "xmark", action: onDismiss)
                        .labelStyle(.iconOnly)
                        .frame(width: 44, height: 44)
                }

                timingRow(title: "PLANNED TIME", seconds: point.plannedElapsedSeconds)
                if let actualSeconds {
                    timingRow(title: "ACTUAL TIME", seconds: actualSeconds)
                    signedTimingRow(title: "Δ", seconds: actualSeconds - point.plannedElapsedSeconds)
                }

                if !point.isReached {
                    Button("Point Reached", systemImage: "checkmark.diamond", action: onReached)
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("identification-point-reached")
                } else if let nextTarget {
                    Divider()
                    Text("NEXT ETA · \(nextTarget.name)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    timingRow(title: "PLAN", seconds: nextTarget.plannedElapsedSeconds)
                    if let pilotETA = session.pilotETAState(targetKey: nextTarget.id)?.draftSeconds {
                        timingRow(title: "PILOT", seconds: pilotETA)
                        HStack(spacing: 12) {
                            adjustmentButton(label: "−5s", delta: -visualStyle.etaAdjustmentStepSeconds, targetID: nextTarget.id)
                            adjustmentButton(label: "+5s", delta: visualStyle.etaAdjustmentStepSeconds, targetID: nextTarget.id)
                        }
                        if isChecked {
                            checkResult(pilotETA: pilotETA, target: nextTarget)
                        } else {
                            Button("Check", action: onCheck)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .buttonStyle(.bordered)
                        }
                    }
                }
            }
            .padding(14)
            .frame(width: visualStyle.identificationPointPanelWidth)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.18)) }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 20)
            .padding(.bottom, 16)
            .accessibilityIdentifier("identification-point-panel")
        }
    }

    private var actualSeconds: Int? {
        guard let point else { return nil }
        return session.actualLegElapsedDuration(atIdentificationPoint: point.id).map {
            IdentificationPointTimingCalculator.displaySeconds($0)
        }
    }

    private func timingRow(title: String, seconds: Int) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(AviationMapSymbology.formatDuration(seconds)).monospacedDigit().bold()
        }
        .font(.subheadline)
    }

    private func signedTimingRow(title: String, seconds: Int) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(signedDuration(seconds)).monospacedDigit().bold()
        }
        .font(.subheadline)
    }

    private func adjustmentButton(
        label: String,
        delta: Int,
        targetID: NavigationTimingTargetKey
    ) -> some View {
        Button(label) { onAdjust(targetID, delta) }
            .font(.headline.monospacedDigit())
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.bordered)
            .buttonRepeatBehavior(.enabled)
    }

    @ViewBuilder
    private func checkResult(pilotETA: Int, target: AviationMapETATarget) -> some View {
        if let reference = IdentificationPointTimingCalculator.referenceTargetElapsed(
            plannedReachedElapsed: point.map { TimeInterval($0.plannedElapsedSeconds) },
            actualReachedElapsed: actualSeconds.map(TimeInterval.init),
            plannedTargetElapsed: TimeInterval(target.plannedElapsedSeconds)
        ) {
            let referenceSeconds = IdentificationPointTimingCalculator.displaySeconds(reference)
            VStack(spacing: 5) {
                timingRow(title: "YOUR ETA", seconds: pilotETA)
                timingRow(title: "REFERENCE", seconds: referenceSeconds)
                signedTimingRow(title: "DIFFERENCE", seconds: pilotETA - referenceSeconds)
            }
        } else {
            Text("Check unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func signedDuration(_ seconds: Int) -> String {
        let sign = seconds >= 0 ? "+" : "−"
        return sign + AviationMapSymbology.formatDuration(abs(seconds))
    }
}

private struct LegStartChecklistOverlay: View {
    let checklist: LegStartChecklistPresentation?
    let state: CockpitFeatureState.LegStartChecklistState?
    let legStartedAt: Date?
    let isLandscape: Bool
    let onCollapse: () -> Void
    let onReopen: () -> Void
    let onNoted: () -> Void

    var body: some View {
        if let checklist,
           let state,
           state.phaseState == .available,
           checklist.legID == state.legID,
           let legStartedAt {
            Group {
                if state.presentationState == .expanded {
                    LegStartChecklistCard(
                        checklist: checklist,
                        reviewState: state.reviewState,
                        legStartedAt: legStartedAt,
                        onCollapse: onCollapse,
                        onNoted: onNoted
                    )
                } else {
                    Button(action: onReopen) {
                        HStack(spacing: 8) {
                            if state.reviewState == .noted {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(Color(red: 0, green: 133 / 255, blue: 102 / 255))
                            }
                            Text(checklist.template.collapsedTitle)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color(red: 20 / 255, green: 26 / 255, blue: 36 / 255))
                                .lineLimit(1)
                            Image(systemName: "chevron.up")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color(red: 77 / 255, green: 87 / 255, blue: 102 / 255))
                        }
                        .padding(.horizontal, 14)
                        .frame(width: 254, height: 46)
                    }
                    .buttonStyle(.plain)
                    .background(Color(red: 251 / 255, green: 252 / 255, blue: 1).opacity(0.96), in: Capsule())
                    .overlay { Capsule().stroke(Color(red: 31 / 255, green: 41 / 255, blue: 56 / 255).opacity(0.2)) }
                    .shadow(color: .black.opacity(0.14), radius: 6, y: 4)
                    .accessibilityLabel(state.reviewState == .noted
                        ? "Review noted start of leg checklist"
                        : "Open start of leg checklist")
                    .accessibilityIdentifier("leg-start-checklist-chip")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, isLandscape ? 32 : 24)
            .padding(.bottom, isLandscape ? 74 : 16)
        }
    }
}

private struct LegStartChecklistCard: View {
    let checklist: LegStartChecklistPresentation
    let reviewState: CockpitFeatureState.LegStartChecklistState.ReviewState
    let legStartedAt: Date
    let onCollapse: () -> Void
    let onNoted: () -> Void
    private let primaryText = Color(red: 20 / 255, green: 26 / 255, blue: 36 / 255)
    private let secondaryText = Color(red: 87 / 255, green: 99 / 255, blue: 117 / 255)
    private let actionBlue = Color(red: 0, green: 107 / 255, blue: 199 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(checklist.template.featureTitle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(secondaryText)
                    Text(checklist.template.displayName)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(primaryText)
                }
                Spacer(minLength: 4)
                Button(action: onCollapse) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color(red: 51 / 255, green: 61 / 255, blue: 77 / 255))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Collapse start of leg checklist")
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 9) {
                    LegStartFlightCheckSection(
                        checklist: checklist,
                        legStartedAt: legStartedAt
                    )
                    Divider()
                    LegStartCruiseSection(checklist: checklist)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 320)

            Button(action: onNoted) {
                Label("Noted", systemImage: reviewState == .noted ? "checkmark.circle.fill" : "checkmark")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(actionBlue)
            .accessibilityLabel("Mark leg start checklist noted")
            .accessibilityHint("Records that the checklist review is finished")
            .accessibilityIdentifier("leg-start-checklist-noted")
        }
        .padding(14)
        .frame(width: 280)
        .background(
            Color(red: 251 / 255, green: 252 / 255, blue: 1).opacity(0.97),
            in: RoundedRectangle(cornerRadius: 14)
        )
        .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color(red: 31 / 255, green: 41 / 255, blue: 56 / 255).opacity(0.2), lineWidth: 1) }
        .shadow(color: .black.opacity(0.18), radius: 9, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("leg-start-checklist")
    }
}

private struct LegStartFlightCheckSection: View {
    let checklist: LegStartChecklistPresentation
    let legStartedAt: Date
    private let primaryText = Color(red: 20 / 255, green: 26 / 255, blue: 36 / 255)
    private let secondaryText = Color(red: 87 / 255, green: 99 / 255, blue: 117 / 255)
    private let headingBlue = Color(red: 0, green: 97 / 255, blue: 191 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if let timerItem = checklist.template.item(.timer) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(timerItem.title).font(.system(size: 11, weight: .bold)).foregroundStyle(secondaryText)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Started · \(duration(from: legStartedAt, to: context.date))")
                            .font(.system(size: 15, weight: .semibold)).foregroundStyle(primaryText).monospacedDigit()
                    }
                }
            }
            if let directionItem = checklist.template.item(.direction) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(directionLabel(templateTitle: directionItem.title))
                        .font(.system(size: 11, weight: .bold)).foregroundStyle(secondaryText)
                    Text(directionValue).font(.system(size: 22, weight: .bold)).foregroundStyle(headingBlue).monospacedDigit()
                    if let instruction = directionItem.instruction {
                        Text(instruction).font(.system(size: 12)).foregroundStyle(secondaryText)
                    }
                }
            }
        }
    }

    private func directionLabel(templateTitle: String) -> String {
        switch checklist.direction { case .heading: templateTitle; case .course: "COURSE" }
    }

    private var directionValue: String {
        switch checklist.direction {
        case .heading(let value), .course(let value):
            CockpitPresentationFormatter.aviationDegrees(value)
        }
    }

    private func duration(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct LegStartCruiseSection: View {
    let checklist: LegStartChecklistPresentation
    private let primaryText = Color(red: 20 / 255, green: 26 / 255, blue: 36 / 255)
    private let secondaryText = Color(red: 87 / 255, green: 99 / 255, blue: 117 / 255)

    var body: some View {
        if let section = checklist.template.cruiseSection {
            VStack(alignment: .leading, spacing: 8) {
                if let title = section.title {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(secondaryText)
                        .frame(maxWidth: .infinity, alignment: checklist.template.layoutDirection == .rightToLeft ? .trailing : .leading)
                }
                if let altitudeItem = checklist.template.item(.altitude) {
                    LegStartStaticItem(
                        title: altitudeItem.title,
                        lines: ["\(feet(checklist.plannedAltitudeFeetMsl)) ft"]
                    )
                }
                if let speedItem = checklist.template.item(.speedAndEngine) {
                    LegStartStaticItem(
                        title: speedItem.title,
                        lines: [speedText] + speedItem.staticLines
                    )
                }
                if let reportingItem = checklist.template.item(.reporting) {
                    LegStartStaticItem(
                        title: reportingItem.title,
                        lines: reportingItem.instruction.map { [$0] } ?? []
                    )
                }
            }
        }
    }

    private var speedText: String {
        checklist.plannedIndicatedAirspeedKnots.map { "\(knots($0)) KIAS" } ?? "Planned IAS unavailable"
    }

    private func feet(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func knots(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }
}

private struct LegStartStaticItem: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 20 / 255, green: 26 / 255, blue: 36 / 255))
            Text(lines.joined(separator: "\n"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color(red: 20 / 255, green: 26 / 255, blue: 36 / 255))
        }
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
    let onOpen: () -> Void

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
                        onOpen()
                        withAnimation(.easeOut(duration: 0.2)) { isPresented = true }
                    } label: {
                        HStack(spacing: 6) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("PREVIOUS LEG")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color(red: 97 / 255, green: 110 / 255, blue: 125 / 255))
                                Text("Leg \(summary.legIndex + 1) · \(summary.origin) → \(summary.destination)")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Color(red: 10 / 255, green: 28 / 255, blue: 46 / 255))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                            }
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.up")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color(red: 0, green: 107 / 255, blue: 199 / 255))
                        }
                        .padding(.horizontal, 13)
                        .frame(width: 236, height: 48)
                    }
                    .buttonStyle(.plain)
                    .background(Color(red: 247 / 255, green: 250 / 255, blue: 252 / 255), in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).stroke(Color(red: 194 / 255, green: 204 / 255, blue: 214 / 255)) }
                    .shadow(color: .black.opacity(0.16), radius: 5, y: 3)
                    .accessibilityIdentifier("previous-leg-tab")
                    .gesture(openGesture)
                }
            }
            .frame(
                maxWidth: .infinity,
                maxHeight: .infinity,
                alignment: .bottom
            )
            .padding(.bottom, isPresented ? 62 : 0)
        }
    }

    private var openGesture: some Gesture {
        DragGesture(minimumDistance: 32).onEnded { value in
            guard value.translation.width > 44,
                  abs(value.translation.width) > abs(value.translation.height) else { return }
            onOpen()
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
        ZStack(alignment: .topLeading) {
            HStack {
                Text("PREVIOUS LEG · LEG \(summary.legIndex + 1)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(uiColor: style.previousLegAccentColor))
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 20, weight: .regular))
                        .frame(width: 24, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close previous leg")
            }.frame(width: 378, height: 28)
                .offset(x: 24, y: 14)
            Text("\(summary.origin) → \(summary.destination)")
                .font(.system(size: 23, weight: .semibold))
                .lineLimit(1).minimumScaleFactor(0.8)
                .frame(width: 340, height: 30, alignment: .leading)
                .offset(x: 24, y: 48)
            Rectangle()
                .fill(.primary.opacity(0.14))
                .frame(width: 372, height: 1)
                .offset(x: 24, y: 88)
            sectionLabel("TIMING")
                .offset(x: 24, y: 108)
            Text("Planned \(duration(summary.plannedDurationSeconds))     Actual \(duration(summary.actualDurationSeconds))     \(CockpitPresentationFormatter.signedDuration(summary.deltaSeconds))")
                .font(.system(size: 14))
                .monospacedDigit()
                .frame(width: 372, height: 20, alignment: .leading)
                .offset(x: 24, y: 130)
            sectionLabel("TARGET HISTORY")
                .offset(x: 24, y: 170)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(summary.targets) { target in
                    targetHistory(target)
                }
            }
            .frame(width: 205, height: 90, alignment: .topLeading)
            .offset(x: 24, y: 192)
            sectionLabel("HEADING HISTORY")
                .offset(x: 244, y: 170)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 8) {
                    historyLine(
                        CockpitPresentationFormatter.aviationDegrees(Double(summary.headingHistory.baselineDegrees)),
                        detail: "planned"
                    )
                    ForEach(Array(summary.headingHistory.commits.enumerated()), id: \.offset) { _, degrees in
                        historyLine(CockpitPresentationFormatter.aviationDegrees(Double(degrees)), detail: "revised")
                    }
                }
            }
            .frame(width: 152, height: 90, alignment: .topLeading)
            .offset(x: 244, y: 192)
            Text("Review only · current leg continues unchanged")
                .font(.system(size: 12))
                .foregroundStyle(Color(red: 87 / 255, green: 94 / 255, blue: 107 / 255))
                .frame(width: 340, height: 18, alignment: .leading)
                .offset(x: 24, y: 302)
        }
        .frame(width: 420, height: 336, alignment: .topLeading)
        .background(Color.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 20))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.16), radius: 10, y: 3)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("previous-leg-drawer")
    }

    private func targetHistory(_ target: PreviousLegSummary.Target) -> some View {
        HStack(spacing: 8) {
            Text(target.name).fontWeight(.semibold)
            switch target.outcome {
            case .reached(let actualETASeconds, _):
                Text("Reached \(duration(actualETASeconds))")
            case .passedWithoutReport:
                Text("Passed without report")
            }
        }
        .font(.system(size: 14))
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(red: 87 / 255, green: 94 / 255, blue: 107 / 255))
            .frame(height: 16, alignment: .leading)
    }

    private func historyLine(_ value: String, detail: String) -> some View {
        Text("\(value) · \(detail)")
            .font(.system(size: 14))
            .monospacedDigit()
            .fixedSize(horizontal: false, vertical: true)
    }

    private func duration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }

}

private struct CockpitTimeMetric: View {
    let plannedDurationSeconds: Int
    let operationalETASeconds: Int?
    let legStartedAt: Date?

    var body: some View {
        if let legStartedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                activeMetric(elapsed: elapsedSeconds(from: legStartedAt, to: context.date))
            }
        } else {
            metric(
                primaryValue: duration(plannedDurationSeconds),
                primaryLabel: "PLANNED",
                secondaryValue: "Elapsed  --:--"
            )
        }
    }

    private func activeMetric(elapsed: Int) -> some View {
        VStack(spacing: 2) {
            Text("TIME").font(.caption.weight(.semibold)).tracking(1).foregroundStyle(.secondary)
            Text(duration(elapsed))
                .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit().lineLimit(1)
            Text("ELAPSED").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if let operationalETASeconds {
                Text("ETA \(duration(operationalETASeconds))")
                    .font(.subheadline.weight(.bold)).monospacedDigit()
                Text("PLAN \(duration(plannedDurationSeconds))")
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            } else {
                Text("PLAN \(duration(plannedDurationSeconds))")
                    .font(.subheadline.weight(.semibold)).foregroundStyle(.secondary).monospacedDigit()
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("cockpit-time")
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
