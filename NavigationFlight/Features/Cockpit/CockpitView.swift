import SwiftUI

private struct ReachUndoBanner: View {
    let label: String
    let expiresAt: Date
    let now: Date
    let onUndo: () -> Void

    private var remainingSeconds: Int {
        max(0, Int(ceil(expiresAt.timeIntervalSince(now))))
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(label)
                .foregroundStyle(.white)
                .accessibilityIdentifier("reach-undo-banner")
            Spacer(minLength: 12)
            Button("Undo · 00:\(remainingSeconds, format: .number.precision(.integerLength(2)))", action: onUndo)
                .foregroundStyle(Color(red: 89 / 255, green: 178 / 255, blue: 1))
                .accessibilityLabel("Undo reach report")
                .accessibilityValue("\(remainingSeconds) seconds remaining")
                .accessibilityIdentifier("undo-reach")
        }
        .font(.subheadline.weight(.semibold))
        .padding(.horizontal, 13)
        .frame(width: 390, height: 48)
        .background(Color(red: 14 / 255, green: 17 / 255, blue: 22 / 255), in: RoundedRectangle(cornerRadius: 14))
        .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color(.separator)) }
        .padding(20)
        .accessibilityElement(children: .contain)
    }
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
            displayFrequencies: populated ? [
                .init(id: "preview-frequency", phases: [.departure], service: "Very Long Preview Tower Service", serviceType: "Pilot override", frequencyMHz: 118.4, source: .user)
            ] : [],
            frequencyPlan: populated ? CockpitPresentationAdapter().makeFrequencyPlan(
                frequencies: [
                    .departure: [.init(id: "preview-frequency", phase: .departure, role: "Tower", service: "Very Long Preview Tower Service", frequencyMHz: 118.4, source: .user)]
                ],
                references: []
            ) : CockpitFrequencyPlan(entries: []),
            routeEvents: populated ? [
                .init(id: UUID(), entityIDs: [UUID()], kinds: [.altitudeChange], normalizedX: 0.40, normalizedY: 0.57, position: .init(latitudeDegrees: 32.2, longitudeDegrees: 34.6), timeFromLegStartSeconds: 132, title: "Altitude change", detail: "After passing anchor: 2,500 ft MSL"),
                .init(id: UUID(), entityIDs: [UUID()], kinds: [.radioFrequencyChange], normalizedX: 0.61, normalizedY: 0.44, position: .init(latitudeDegrees: 32.25, longitudeDegrees: 34.65), timeFromLegStartSeconds: 190, title: "Frequency change", detail: "Very Long Preview Control Service · 120.600 MHz")
            ] : []
        )
    }
}

private extension Flight {
    static let preview = Flight(
        flightPlanID: UUID(),
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
    CockpitView(data: .cockpitPreview(heading: 74, populated: true), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, legStartChecklist: nil, checklistState: nil, flight: .preview, areDriftLinesVisible: true, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: { _ in }, onIdentificationPointReached: { _, _, _ in }, onOpenPilotETA: { _ in }, onAdjustPilotETA: { _, _ in }, onCommitPilotETA: { _ in }, onCancelPilotETA: { _ in }, onEditPilotETA: { _ in }, onShowPilotETACheck: { _ in }, onHidePilotETACheck: { _ in }, onCollapseChecklist: {}, onReopenChecklist: {}, onNoteChecklist: {}, onToggleDriftLines: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Portrait · No Wind · Hebrew", traits: .fixedLayout(width: 834, height: 1210)) {
    CockpitView(data: .cockpitPreview(heading: nil, populated: true, hebrew: true), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, legStartChecklist: nil, checklistState: nil, flight: .preview, areDriftLinesVisible: true, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: { _ in }, onIdentificationPointReached: { _, _, _ in }, onOpenPilotETA: { _ in }, onAdjustPilotETA: { _, _ in }, onCommitPilotETA: { _ in }, onCancelPilotETA: { _ in }, onEditPilotETA: { _ in }, onShowPilotETACheck: { _ in }, onHidePilotETACheck: { _ in }, onCollapseChecklist: {}, onReopenChecklist: {}, onNoteChecklist: {}, onToggleDriftLines: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Landscape · Missing Optional Data", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .cockpitPreview(heading: nil, populated: false), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, legStartChecklist: nil, checklistState: nil, flight: .preview, areDriftLinesVisible: true, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: { _ in }, onIdentificationPointReached: { _, _, _ in }, onOpenPilotETA: { _ in }, onAdjustPilotETA: { _, _ in }, onCommitPilotETA: { _ in }, onCancelPilotETA: { _ in }, onEditPilotETA: { _ in }, onShowPilotETACheck: { _ in }, onHidePilotETACheck: { _ in }, onCollapseChecklist: {}, onReopenChecklist: {}, onNoteChecklist: {}, onToggleDriftLines: {}, onShowPlanInspection: {})
}

#Preview("11-inch iPad Landscape · Dark", traits: .fixedLayout(width: 1210, height: 834)) {
    CockpitView(data: .cockpitPreview(heading: 74, populated: true), mapPresentation: .preview, nextLegPreparation: nil, previousLegSummary: nil, legStartChecklist: nil, checklistState: nil, flight: .preview, areDriftLinesVisible: true, onStartLeg: {}, onIdentifyDestination: {}, onWaypointReached: { _ in }, onIdentificationPointReached: { _, _, _ in }, onOpenPilotETA: { _ in }, onAdjustPilotETA: { _, _ in }, onCommitPilotETA: { _ in }, onCancelPilotETA: { _ in }, onEditPilotETA: { _ in }, onShowPilotETACheck: { _ in }, onHidePilotETACheck: { _ in }, onCollapseChecklist: {}, onReopenChecklist: {}, onNoteChecklist: {}, onToggleDriftLines: {}, onShowPlanInspection: {})
        .preferredColorScheme(.dark)
}
#endif

enum SelectedMapCallout: Equatable, Sendable {
    case identificationPoint(IdentificationPointKey)
    case timingTarget(NavigationTimingTargetKey)
}

struct CockpitRestoration: Equatable, Sendable {
    let camera: AviationMapCameraState?
    let isCameraUserControlled: Bool
    let selectedCallout: SelectedMapCallout?
    let focusRequest: AviationMapFocusRequest
}

extension CockpitRestoration {
    static let empty = CockpitRestoration(
        camera: nil,
        isCameraUserControlled: false,
        selectedCallout: nil,
        focusRequest: AviationMapFocusRequest(mode: .leg)
    )
}

struct CockpitView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion
    private let visualStyle = AviationMapVisualStyle.default
    let data: CockpitPresentationData
    let mapPresentation: AviationMapPresentation
    let nextLegPreparation: NextLegPreparation?
    let previousLegSummary: PreviousLegSummary?
    let legStartChecklist: LegStartChecklistPresentation?
    let checklistState: CockpitFeatureState.LegStartChecklistState?
    let flight: Flight
    let areDriftLinesVisible: Bool
    var operationalCues: CockpitOperationalCueState? = nil
    var emphasizedCueEvents: Set<CockpitOperationalCueState.DueEvent> = []
    var pendingReachUndo: CockpitFeatureState.PendingReachUndo? = nil
    var positionCheck: PositionCheckPresentation? = nil
    var recordingStatus: RecordingStatusPresentation? = nil
    var isRecordingCommitInFlight = false
    var isNavigationCompletionCommitted = false
    var positionCheckMapRestoration: PositionCheckMapRestorationCommand? = nil
    var onPositionCheckMapRestored: (UUID) -> Void = { _ in }
    var onPositionCheckAction: (PositionCheckControlAction, CockpitRestoration) async -> Void = { _, _ in }
    var onEndRecording: () -> Void = {}
    var onNavigationComplete: () -> Void = {}
    let onStartLeg: () -> Void
    let onIdentifyDestination: () -> Void
    let onWaypointReached: (CockpitRestoration) -> Void
    let onIdentificationPointReached: (IdentificationPointKey, AviationMapPresentation, CockpitRestoration) throws -> Void
    var onUndoReach: (Date) async -> CockpitRestoration? = { _ in nil }
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
    @State private var identificationPointReportError: Flight.TransitionError?
    @State private var showsHeadingCommitConfirmation = false
    @State private var isRestoringReach = false
    @State private var mapIdentity = UUID()
    @State private var showsCompactFrequencies = false
    @State private var isRecordingStatusPresented = false
    @State private var isCompactMapChromeVisible = true
    @State private var isCompactChecklistPresented = false
    @State private var compactMapChromeVisibilityID = 0
    @State private var positionCheckRestoration: CockpitRestoration?
    @State private var cockpitPresentationState = CockpitPresentationState()

    var body: some View {
        GeometryReader { geometry in
            restingCockpitLayout(in: geometry.size)
                .accessibilityHidden(activeHeadingState?.isEditing == true)
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
        .sheet(isPresented: compactMapToolsBinding) {
            mapToolsPanel
                .presentationDetents([.large])
        }
        .sheet(isPresented: compactFrequencyPlanBinding) {
            frequencyPlanPanel
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: compactChecklistBinding) {
            if let legStartChecklist,
               let legStartedAt = flight.legStartedAt {
                CompactLegStartChecklistSheet(
                    checklist: legStartChecklist,
                    legStartedAt: legStartedAt,
                    onCollapse: onCollapseChecklist,
                    onNoted: onNoteChecklist
                )
                .presentationDetents([.fraction(0.84), .large])
                .presentationDragIndicator(.visible)
            }
        }
        .onChange(of: flight.activeLegIndex) { _, _ in
            if isRestoringReach {
                isRestoringReach = false
                return
            }
            isNextPreparationPresented = false
            isPreviousDrawerPresented = false
            selectedMapCallout = nil
            showsHeadingCommitConfirmation = false
            showsCompactFrequencies = false
        }
        .onChange(of: flight.legState) { _, newValue in
            guard horizontalSizeClass == .compact else { return }
            isCompactMapChromeVisible = newValue != .active
            compactMapChromeVisibilityID += 1
        }
        .onChange(of: checklistState, initial: true) { _, newValue in
            syncCompactChecklistPresentation(with: newValue)
        }
        .task(id: compactMapChromeVisibilityID) {
            guard horizontalSizeClass == .compact,
                  flight.legState == .active,
                  isCompactMapChromeVisible else { return }
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            isCompactMapChromeVisible = false
        }
        .task(id: cockpitPresentationState.quickFocusHideDeadline) {
            guard let deadline = cockpitPresentationState.quickFocusHideDeadline else { return }
            let remaining = deadline.timeIntervalSinceNow
            if remaining > 0 {
                try? await Task.sleep(for: .seconds(remaining))
            }
            guard !Task.isCancelled else { return }
            cockpitPresentationState.hideQuickFocusControlsIfExpired(at: .now)
        }
        .onChange(of: previousLegSummary?.legIndex) { _, _ in
            isPreviousDrawerPresented = false
        }
        .onChange(of: mapPresentation.gpsDisclosureOverlay) { oldValue, newValue in
            if let newValue, oldValue == nil {
                selectedMapCallout = nil
                isMapCameraUserControlled = false
                mapFocusRequest = AviationMapFocusRequest(
                    mode: .positionCheck(
                        aircraft: newValue.coordinate,
                        intercept: newValue.interceptCoordinate
                    )
                )
            }
        }
        .onChange(of: positionCheckMapRestoration, initial: true) { _, command in
            guard let command else { return }
            let restoration = command.restoration
            preservedMapCamera = restoration.camera
            isMapCameraUserControlled = restoration.isCameraUserControlled
            selectedMapCallout = restoration.selectedCallout
            mapFocusRequest = restoration.focusRequest
            mapIdentity = UUID()
            positionCheckRestoration = nil
            onPositionCheckMapRestored(command.id)
        }
    }

    @ViewBuilder
    private func restingCockpitLayout(in size: CGSize) -> some View {
        let layout = CockpitRestingLayoutPolicy.layout(
            for: .init(
                width: size.width,
                height: size.height,
                horizontalSizeClass: horizontalSizeClass == .compact ? .compact : .regular
            )
        )

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 0) {
                mapSurface(isLandscape: false, mapWidth: size.width)
                    .frame(height: size.height * 0.47)
                ScrollView {
                    accessibilityControlPanel
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("compact-cockpit-console")
            }
        } else if layout.composition == .sideRail {
            HStack(spacing: 0) {
                mapSurface(isLandscape: true, mapWidth: layout.mapExtent)
                    .frame(width: layout.mapExtent)
                landscapeControlPanel
                    .frame(width: layout.consoleExtent)
                    .frame(maxHeight: .infinity)
            }
        } else {
            VStack(spacing: 0) {
                mapSurface(isLandscape: false, mapWidth: size.width)
                    .frame(height: layout.mapExtent)
                if horizontalSizeClass == .compact {
                    compactControlPanel
                        .frame(height: layout.consoleExtent)
                        .frame(maxWidth: .infinity)
                } else {
                    portraitControlPanel
                        .frame(height: layout.consoleExtent)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var accessibilityControlPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            activeLegInstrumentsHeader
            portraitTimerMetric
            readyETAMetric
            compactHeadingButton
            readyAltitudeMetric
            fixedImmediateFrequencyColumn
            Button("Frequency plan ›") {
                cockpitPresentationState.setFrequencyPlanPresented(true)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityIdentifier("open-frequency-plan")
            positionCheckAndProgressionControls
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(Color(.systemBackground))
    }

    private func mapSurface(isLandscape: Bool, mapWidth: CGFloat) -> some View {
        ZStack(alignment: .bottomLeading) {
            TimelineView(.periodic(from: .now, by: 1)) { timeline in
                OfflineAviationMapView(
                presentation: mapPresentation,
                legState: flight.legState,
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
                onHidePilotETACheck: onHidePilotETACheck,
                onMapInteraction: mapInteractionOccurred
                )
                .id(mapIdentity)
                .accessibilityIdentifier("aviation-map")
                .accessibilitySortPriority(90)
            }
            if shouldShowMapChrome {
                legHeader
                    .accessibilitySortPriority(100)
            }
            if cockpitPresentationState.areQuickFocusControlsVisible {
                MapQuickFocusControls(
                    onShowWholeActiveLeg: { focusMap(.leg) },
                    onShowDestinationWaypoint: { focusMap(.waypoint) }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, horizontalSizeClass == .compact ? 72 : 100)
                .padding(.trailing, horizontalSizeClass == .compact ? 12 : 20)
                .accessibilitySortPriority(80)
            }
            if horizontalSizeClass != .compact, cockpitPresentationState.isMapToolsPresented {
                mapToolsPanel
                    .frame(width: min(380, mapWidth - 40))
                    .frame(maxHeight: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
                    .padding(.vertical, 18)
                    .padding(.trailing, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .accessibilitySortPriority(95)
            }
            if horizontalSizeClass != .compact, cockpitPresentationState.isFrequencyPlanPresented {
                frequencyPlanPanel
                    .frame(width: min(380, mapWidth - 40))
                    .frame(maxHeight: 760)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.18), radius: 12, y: 8)
                    .padding(.vertical, 18)
                    .padding(.trailing, 18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .accessibilitySortPriority(95)
            }
            if let recovery = positionCheck?.recovery {
                PositionCheckRecoveryGuidanceView(recovery: recovery)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.leading, horizontalSizeClass == .compact ? 12 : 20)
                    .padding(.top, horizontalSizeClass == .compact ? 58 : 80)
                    .accessibilitySortPriority(85)
            }
            NextLegPreparationOverlay(
                preparation: flight.destinationIdentifiedAt == nil ? nil : nextLegPreparation,
                isPresented: Binding(
                    get: { isNextPreparationPresented && selectedIdentificationPointID == nil },
                    set: { isNextPreparationPresented = $0 }
                )
            )
            if let pendingReachUndo {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    if context.date < pendingReachUndo.expiresAt {
                        ReachUndoBanner(
                            label: pendingReachUndo.kind.label,
                            expiresAt: pendingReachUndo.expiresAt,
                            now: context.date,
                            onUndo: { restoreReach(at: context.date) }
                        )
                    }
                }
                .frame(width: 430, height: 88, alignment: .bottomLeading)
            }
            PreviousLegDrawer(
                summary: previousLegSummary,
                isPresented: $isPreviousDrawerPresented,
                bottomInset: pendingReachUndo == nil ? 0 : 60,
                onOpen: {
                    selectedMapCallout = nil
                }
            )
            LegStartChecklistOverlay(
                checklist: legStartChecklist,
                state: checklistState,
                legStartedAt: flight.legStartedAt,
                isCompact: horizontalSizeClass == .compact,
                onCollapse: onCollapseChecklist,
                onReopen: {
                    if horizontalSizeClass == .compact {
                        isCompactChecklistPresented = true
                    }
                    onReopenChecklist()
                },
                onNoted: onNoteChecklist
            )
        }
        .clipped()
    }

    private var shouldShowMapChrome: Bool {
        horizontalSizeClass != .compact || flight.legState != .active || isCompactMapChromeVisible
    }

    private func syncCompactChecklistPresentation(
        with state: CockpitFeatureState.LegStartChecklistState?
    ) {
        guard horizontalSizeClass == .compact,
              let state,
              state.phaseState == .available,
              state.presentationState == .expanded,
              legStartChecklist?.legID == state.legID else {
            isCompactChecklistPresented = false
            return
        }
        isCompactChecklistPresented = true
    }

    private func revealCompactMapChrome() {
        guard horizontalSizeClass == .compact, flight.legState == .active else { return }
        isCompactMapChromeVisible = true
        compactMapChromeVisibilityID += 1
    }

    private func mapInteractionOccurred() {
        revealCompactMapChrome()
        cockpitPresentationState.mapInteractionOccurred(at: .now)
    }

    private func focusMap(_ mode: AviationMapFocusMode) {
        isMapCameraUserControlled = false
        mapFocusRequest = AviationMapFocusRequest(mode: mode)
    }

    private var compactMapToolsBinding: Binding<Bool> {
        Binding(
            get: { horizontalSizeClass == .compact && cockpitPresentationState.isMapToolsPresented },
            set: { cockpitPresentationState.setMapToolsPresented($0) }
        )
    }

    private var compactFrequencyPlanBinding: Binding<Bool> {
        Binding(
            get: { horizontalSizeClass == .compact && cockpitPresentationState.isFrequencyPlanPresented },
            set: { cockpitPresentationState.setFrequencyPlanPresented($0) }
        )
    }

    private var compactChecklistBinding: Binding<Bool> {
        Binding(
            get: { isCompactChecklistPresented },
            set: { isPresented in
                isCompactChecklistPresented = isPresented
                if !isPresented {
                    onCollapseChecklist()
                }
            }
        )
    }

    private var mapToolsPanel: some View {
        CockpitMapToolsPanel(
            areDriftLinesVisible: areDriftLinesVisible,
            onShowFullRoute: {
                focusMap(.overview)
                cockpitPresentationState.setMapToolsPresented(false)
            },
            onToggleDriftLines: onToggleDriftLines,
            onShowChartLayers: { showsChartsUnavailable = true },
            onInspectFlightPlan: {
                cockpitPresentationState.setMapToolsPresented(false)
                onShowPlanInspection()
            },
            onClose: { cockpitPresentationState.setMapToolsPresented(false) }
        )
    }

    private var frequencyPlanPanel: some View {
        CockpitFrequencyPlanView(
            plan: data.frequencyPlan,
            onClose: { cockpitPresentationState.setFrequencyPlanPresented(false) }
        )
    }

    @ViewBuilder
    private var legHeader: some View {
        if horizontalSizeClass == .compact, !dynamicTypeSize.isAccessibilitySize {
            compactLegHeader
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)) }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(12)
        } else {
            ViewThatFits(in: .horizontal) {
                regularLegHeader
                accessibilityLegHeader
            }
            .padding(.horizontal, 16).padding(.vertical, 6)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.08)) }
            .frame(maxHeight: .infinity, alignment: .top).padding(20)
        }
    }

    private var compactLegHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Text(legStatusText)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
                    .accessibilityIdentifier("leg-status")
                Text("·").foregroundStyle(.secondary)
                Text(data.legPosition.uppercased())
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button { cockpitPresentationState.setMapToolsPresented(true) } label: {
                    Label("Map tools", systemImage: "map")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
            Text("\(data.origin) → \(data.destination)")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityLabel("From \(data.origin) to \(data.destination)")
        }
    }

    private var regularLegHeader: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Text(legStatusText)
                    .font(.subheadline.weight(.bold))
                    .lineLimit(1)
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
                    .font(.headline)
                    .environment(\.layoutDirection, .leftToRight)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("From \(data.origin) to \(data.destination)")
                }
            }
            Spacer(minLength: 8)
            Button { cockpitPresentationState.setMapToolsPresented(true) } label: {
                Label("Map tools", systemImage: "map").font(.headline).frame(minHeight: 44).padding(.horizontal, 12)
            }
            .buttonStyle(.plain).foregroundStyle(.primary)
        }
    }

    private var accessibilityLegHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(legStatusText)
                    .font(.subheadline.weight(.bold))
                    .accessibilityIdentifier("leg-status")
                Spacer()
                Button("Map tools", systemImage: "map") { cockpitPresentationState.setMapToolsPresented(true) }
                    .frame(minHeight: 44)
                    .buttonStyle(.plain)
            }
            Text(data.legPosition.uppercased())
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(data.origin) → \(data.destination)")
                .font(.headline)
                .environment(\.layoutDirection, .leftToRight)
                .accessibilityLabel("From \(data.origin) to \(data.destination)")
        }
    }

    @ViewBuilder
    private var activeLegInstrumentsHeader: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 6) {
                activeLegInstrumentsTitle
                recordingStatusControl
            }
        } else {
            HStack(alignment: .center, spacing: 10) {
                activeLegInstrumentsTitle
                Spacer(minLength: 8)
                recordingStatusControl
            }
        }
    }

    private var activeLegInstrumentsTitle: some View {
        Text("ACTIVE LEG INSTRUMENTS")
            .font(.caption2.weight(.bold))
            .tracking(0.7)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var recordingStatusControl: some View {
        if let recordingStatus {
            Button {
                isRecordingStatusPresented = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: recordingStatus.systemImage)
                    ViewThatFits(in: .horizontal) {
                        Text(recordingStatus.title)
                        Text(recordingStatus.compactTitle)
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(recordingStatusColor(recordingStatus.tone))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .frame(minHeight: 44)
                .background(recordingStatusBackground(recordingStatus.tone), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(recordingStatus.title)
            .accessibilityHint(recordingStatus.detail)
            .accessibilityIdentifier("recording-status")
            .popover(isPresented: $isRecordingStatusPresented) {
                recordingStatusDetails(recordingStatus)
                    .presentationCompactAdaptation(.popover)
            }
        }
    }

    private func recordingStatusDetails(
        _ recordingStatus: RecordingStatusPresentation
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(recordingStatus.title, systemImage: recordingStatus.systemImage)
                .font(.headline)
                .foregroundStyle(recordingStatusColor(recordingStatus.tone))
            Text(recordingStatus.detail)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            if recordingStatus.showsEndRecordingAction {
                Button("End Recording…", role: .destructive) {
                    isRecordingStatusPresented = false
                    onEndRecording()
                }
                .accessibilityHint("Opens confirmation to close the recording as incomplete")
                .accessibilityIdentifier("end-recording")
            }
        }
        .padding()
        .frame(idealWidth: 300, alignment: .leading)
    }

    private func recordingStatusColor(_ tone: RecordingStatusPresentation.Tone) -> Color {
        switch tone {
        case .neutral: Color.secondary
        case .caution, .destructive: Color.primary
        }
    }

    private func recordingStatusBackground(_ tone: RecordingStatusPresentation.Tone) -> Color {
        switch tone {
        case .neutral: Color(.secondarySystemBackground)
        case .caution: Color(.systemOrange).opacity(0.14)
        case .destructive: Color(.systemRed).opacity(0.14)
        }
    }

    private var portraitControlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active leg")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            portraitOperationalScanLine
            Divider()

            HStack(alignment: .top, spacing: 18) {
                fixedImmediateFrequencyRow
                    .frame(width: 408)
                waypointReachedButton
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .background(Color(.systemBackground))
    }

    private var portraitOperationalScanLine: some View {
        HStack(alignment: .top, spacing: 0) {
            Button {
                showsHeadingCommitConfirmation = false
                onCollapseChecklist()
                onOpenPilotHeading(importedHeadingDegrees)
            } label: {
                portraitOperationalMetric(
                    label: "Operational heading",
                    value: Self.heading(activeHeadingState?.operationalDegrees ?? importedHeadingDegrees),
                    detail: headingProvenance,
                    identifier: "cockpit-heading"
                )
            }
            .buttonStyle(.plain)
            .disabled(flight.legState != .active)

            portraitInstrumentDivider
            portraitTimerInstrument
            portraitInstrumentDivider
            Button {
                selectTimingTarget(mapPresentation.destinationTarget.id)
            } label: {
                portraitOperationalMetric(
                    label: "Next ETA · \(data.destination)",
                    value: Self.duration(mapPresentation.operationalDestinationETASeconds),
                    detail: mapPresentation.isDestinationETARevised ? "Revised · elapsed" : "Planned · elapsed",
                    identifier: "cockpit-eta"
                )
            }
            .buttonStyle(.plain)
            portraitInstrumentDivider
            portraitOperationalMetric(
                label: "Planned altitude",
                value: "\(Self.feet(operationalCues?.currentAltitude.value ?? data.initialAltitudeFeetMsl)) ft",
                detail: "MSL",
                identifier: "cockpit-altitude"
            )
        }
        .frame(height: 84)
    }

    @ViewBuilder
    private var portraitTimerInstrument: some View {
        if flight.legState == .active, let legStartedAt = flight.legStartedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                portraitOperationalMetric(
                    label: "Leg timer",
                    value: Self.duration(max(0, Int(context.date.timeIntervalSince(legStartedAt)))),
                    detail: "Elapsed from leg start",
                    identifier: "cockpit-time"
                )
            }
        } else {
            portraitOperationalMetric(
                label: "Leg timer",
                value: "–:––",
                detail: "Starts on Start Leg",
                identifier: "cockpit-time"
            )
        }
    }

    private func portraitOperationalMetric(
        label: String,
        value: String,
        detail: String,
        identifier: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
                .lineLimit(1)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 84, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var portraitInstrumentDivider: some View {
        Rectangle()
            .fill(Color(.separator))
            .frame(width: 1, height: 70)
    }

    private var compactControlPanel: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Active leg")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: 8) {
                compactHeadingInstrument
                compactTimerInstrument
            }
            HStack(spacing: 8) {
                Button {
                    selectTimingTarget(mapPresentation.destinationTarget.id)
                } label: {
                    compactInstrument(label: "Next ETA · \(data.destination)", value: Self.duration(mapPresentation.operationalDestinationETASeconds), detail: mapPresentation.isDestinationETARevised ? "Revised · elapsed" : "Planned · elapsed", identifier: "cockpit-eta")
                }
                .buttonStyle(.plain)
                compactInstrument(label: "Planned altitude", value: "\(Self.feet(operationalCues?.currentAltitude.value ?? data.initialAltitudeFeetMsl)) ft", detail: "MSL", identifier: "cockpit-altitude")
            }

            compactImmediateFrequencies
            waypointReachedButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.systemBackground))
    }

    private var headingProvenance: String {
        activeHeadingState?.committedDegrees == nil ? "Planned · magnetic" : "Revised · magnetic"
    }

    private var compactHeadingInstrument: some View {
        Button {
            showsHeadingCommitConfirmation = false
            onCollapseChecklist()
            onOpenPilotHeading(importedHeadingDegrees)
        } label: {
            compactInstrument(
                label: "Operational heading",
                value: Self.heading(activeHeadingState?.operationalDegrees ?? importedHeadingDegrees),
                detail: headingProvenance,
                identifier: "cockpit-heading"
            )
        }
        .buttonStyle(.plain)
        .disabled(flight.legState != .active)
        .accessibilityLabel("Operational heading, \(Self.heading(activeHeadingState?.operationalDegrees ?? importedHeadingDegrees)), \(headingProvenance)")
        .accessibilityHint("Opens the magnetic heading editor")
        .accessibilityIdentifier("cockpit-heading")
    }

    @ViewBuilder
    private var compactTimerInstrument: some View {
        if flight.legState == .active, let legStartedAt = flight.legStartedAt {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let elapsed = Self.duration(max(0, Int(context.date.timeIntervalSince(legStartedAt))))
                compactInstrument(
                    label: "Leg timer",
                    value: elapsed,
                    detail: "Elapsed from leg start",
                    identifier: "cockpit-time"
                )
                .accessibilityLabel("Leg timer, \(elapsed), Running from pilot start")
            }
        } else {
            compactInstrument(label: "Leg timer", value: "–:––", detail: "Starts on Start Leg", identifier: "cockpit-time")
        }
    }

    private func compactInstrument(label: String, value: String, detail: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            Text(value).font(.headline).monospacedDigit().lineLimit(1)
            Text(detail).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(identifier)
    }

    private var compactImmediateFrequencies: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { index in
                let entry = immediateFrequencyEntry(at: index)
                Button {
                    cockpitPresentationState.setFrequencyPlanPresented(true)
                } label: {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(index == 0 ? "Planned now" : "Planned next")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(entry.map { "\($0.service) · \(Self.frequency($0.frequencyMHz)) MHz" } ?? "None in imported plan")
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                    }
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .padding(.horizontal, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(immediateFrequencyAccessibilityLabel(entry, index: index))
                .accessibilityHint("Opens the complete imported frequency plan")
                .accessibilityIdentifier(index == 0 ? "planned-now" : "planned-next")
            }
        }
    }

    private var compactSummaryButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                compactHeadingButton
                compactSummary("ALT \(Self.feet(data.initialAltitudeFeetMsl)) ft", identifier: "cockpit-altitude")
                compactFrequencyButton
            }
            VStack(spacing: 8) {
                compactHeadingButton
                compactSummary("ALTITUDE \(Self.feet(data.initialAltitudeFeetMsl)) ft", identifier: "cockpit-altitude")
                compactFrequencyButton
            }
        }
    }

    private var compactOperationalSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            compactHeadingButton
            compactSummary(
                "NEXT ETA \(Self.duration(data.legDurationSeconds))",
                identifier: "cockpit-eta"
            )
            compactSummary("ALTITUDE \(Self.feet(data.initialAltitudeFeetMsl)) ft", identifier: "cockpit-altitude")
            compactFrequencyButton
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private var compactHeadingButton: some View {
        Button {
            showsHeadingCommitConfirmation = false
            onCollapseChecklist()
            onOpenPilotHeading(importedHeadingDegrees)
        } label: {
            Text("HEADING \(Self.heading(activeHeadingState?.operationalDegrees ?? importedHeadingDegrees))")
                .font(.subheadline.weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(flight.legState != .active)
        .accessibilityLabel("Magnetic heading, \(Self.heading(activeHeadingState?.operationalDegrees ?? importedHeadingDegrees))")
        .accessibilityHint("Opens the magnetic heading editor")
        .accessibilityIdentifier("cockpit-heading")
    }

    private var compactFrequencyButton: some View {
        Button {
            showsCompactFrequencies.toggle()
        } label: {
            Text("FREQUENCIES \(orderedFrequencies.count) \(showsCompactFrequencies ? "▴" : "▾")")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.tint)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Planned frequencies")
        .accessibilityValue(showsCompactFrequencies ? "Expanded" : "Collapsed, \(orderedFrequencies.count) frequencies")
        .accessibilityHint(showsCompactFrequencies ? "Collapses planned frequencies" : "Shows planned frequencies")
        .accessibilityIdentifier("compact-frequencies")
    }

    private func compactSummary(_ label: String, identifier: String) -> some View {
        Text(label)
            .font(.subheadline.weight(.bold))
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var portraitTimerMetric: some View {
        if flight.legState == .active, let legStartedAt = flight.legStartedAt {
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
            onCollapseChecklist()
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
        .disabled(flight.legState != .active)
        .accessibilityLabel(
            activeHeadingState?.committedDegrees == nil
                ? "\(data.magneticHeadingDegrees == nil ? "PLANNED COURSE" : "PLANNED HEADING"), \(Self.heading(importedHeadingDegrees)), \(data.magneticHeadingDegrees == nil ? "No-wind course · magnetic" : "Planned-wind heading · magnetic")"
                : "REVISED HEADING, \(Self.heading(activeHeadingState?.operationalDegrees ?? importedHeadingDegrees)), Pilot-revised · magnetic"
        )
        .accessibilityHint(flight.legState == .active ? "Opens the magnetic heading editor" : "Available while the leg is active")
        .accessibilityIdentifier("cockpit-heading")
    }

    private var activeHeadingState: Flight.PilotHeadingState? {
        guard flight.legIDs.indices.contains(flight.activeLegIndex) else { return nil }
        return flight.pilotHeadingState(for: flight.legIDs[flight.activeLegIndex])
    }

    private var importedHeadingDegrees: Int {
        Int((data.magneticHeadingDegrees ?? data.magneticCourseDegrees).rounded())
    }

    private func headingEditor(state: Flight.PilotHeadingState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Revise heading")
                .font(.title3.bold())
            Text("Pilot-authored · magnetic")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
            Divider()
                .padding(.top, 14)

            HStack {
                Text("Imported baseline")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Self.heading(state.baselineDegrees))
                    .font(.title3.bold())
                    .monospacedDigit()
            }
            .font(.caption)
            .padding(.top, 14)

            Text("Draft")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 16)
            Text(Self.heading(state.draftDegrees))
                .font(.largeTitle.bold())
                .monospacedDigit()
                .accessibilityIdentifier("heading-draft")

            HStack(spacing: 12) {
                headingAdjustmentButton(title: "− 1°", delta: -1)
                headingAdjustmentButton(title: "+ 1°", delta: 1)
            }
            .padding(.top, 12)

            Button("Commit revised heading") {
                    onCommitPilotHeading()
                    showsHeadingCommitConfirmation = true
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .buttonStyle(.borderedProminent)
                .padding(.top, 16)
                .accessibilityIdentifier("commit-heading")

            Button("Cancel", action: onCancelPilotHeading)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .buttonStyle(.plain)
                .accessibilityIdentifier("cancel-heading")
        }
        .padding(20)
        .frame(width: 344)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 18))
        .shadow(color: .black.opacity(0.2), radius: 11, y: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: horizontalSizeClass == .compact ? .center : .topTrailing)
        .padding(.top, horizontalSizeClass == .compact ? 0 : 96)
        .padding(.trailing, horizontalSizeClass == .compact ? 0 : 24)
    }

    private func headingAdjustmentButton(title: String, delta: Int) -> some View {
        RepeatingActionButton(action: { onAdjustPilotHeading(delta) }) {
            Text(title)
        }
            .font(.subheadline.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 44)
            .buttonStyle(.bordered)
            .accessibilityLabel(delta < 0 ? "Decrease magnetic heading by one degree" : "Increase magnetic heading by one degree")
            .accessibilityIdentifier(delta < 0 ? "decrease-heading" : "increase-heading")
    }

    private static func heading(_ degrees: Int) -> String {
        String(format: "%03d°", Flight.normalizedHeading(degrees))
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
        let currentAltitude = operationalCues?.currentAltitude.value ?? data.initialAltitudeFeetMsl
        let nextAltitude = operationalCues?.nextAltitude
        let displayedTransition = containsAltitudeEmphasis
            ? operationalCues?.dueAltitude
            : nextAltitude
        let transitionStatus = containsAltitudeEmphasis ? "DUE" : "NEXT"
        return readyInstrumentCard(
            title: "TARGET ALTITUDE",
            value: "\(Self.feet(currentAltitude)) ft",
            detail: "Current planned · MSL",
            valueColor: nextAltitude == nil ? .primary : Self.cueAmber,
            accessibilityIdentifier: "cockpit-altitude",
            trailingTitle: displayedTransition.map {
                "\($0.direction == .up ? "↑" : "↓") \(Self.feet($0.target.value)) \(transitionStatus)"
            },
            accessibilityValue: operationalCues?.altitudeAccessibilityDescription,
            emphasized: containsAltitudeEmphasis
        )
    }

    private func readyInstrumentCard(
        title: String,
        value: String,
        detail: String,
        valueColor: Color,
        accessibilityIdentifier: String,
        highlighted: Bool = false,
        highlightColor: Color = Color(.systemTeal),
        trailingTitle: String? = nil,
        accessibilityValue: String? = nil,
        emphasized: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 2)
                if let trailingTitle {
                    Text(trailingTitle)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(Self.cueAmber)
                        .padding(.horizontal, emphasized && accessibilityReduceMotion ? 5 : 0)
                        .padding(.vertical, emphasized && accessibilityReduceMotion ? 2 : 0)
                        .background(
                            emphasized && accessibilityReduceMotion ? Self.cueAmber.opacity(0.16) : .clear,
                            in: Capsule()
                        )
                        .cuePulse(
                            active: emphasized && !accessibilityReduceMotion,
                            scale: 1.08
                        )
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            Text(value)
                .font(.title2.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .foregroundStyle(valueColor)
                .lineLimit(1)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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
        .accessibilityValue(accessibilityValue ?? "")
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var readyFrequencyRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PLANNED FREQUENCIES")
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .foregroundStyle(.secondary)

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(orderedFrequencyCues) { readyFrequencyCard($0) }
                        if orderedFrequencies.isEmpty {
                            Text("No planned frequencies")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 12)
                        }
                    }
                }
                .scrollIndicators(.hidden)
                .onChange(of: currentFrequencyID, initial: true) { _, frequencyID in
                    centerFrequency(frequencyID, using: proxy)
                }
            }
        }
        .accessibilityIdentifier("planned-frequencies")
        .accessibilitySortPriority(60)
    }

    private var fixedImmediateFrequencyRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Planned frequencies")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("planned-frequencies")
                Spacer()
                Button("Frequency plan ›") {
                    cockpitPresentationState.setFrequencyPlanPresented(true)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityIdentifier("open-frequency-plan")
            }
            .font(.caption)
            HStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { index in
                    immediateFrequencyCard(immediateFrequencyEntry(at: index), index: index)
                }
            }
        }
    }

    private var fixedImmediateFrequencyColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Planned frequencies")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(0..<2, id: \.self) { index in
                immediateFrequencyCard(immediateFrequencyEntry(at: index), index: index)
            }
        }
        .accessibilityIdentifier("planned-frequencies")
    }

    private func immediateFrequencyCard(_ entry: CockpitFrequencyPlan.Entry?, index: Int) -> some View {
        let sequence = index == 0 ? "Planned now" : "Planned next"
        return VStack(alignment: .leading, spacing: 3) {
            Text(sequence)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(entry.map { "\($0.service) · \(Self.frequency($0.frequencyMHz)) MHz" } ?? "None in imported plan")
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, minHeight: 42, alignment: .leading)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(immediateFrequencyAccessibilityLabel(entry, index: index))
        .accessibilityIdentifier(sequence == "Planned now" ? "planned-now" : "planned-next")
    }

    private func immediateFrequencyEntry(at index: Int) -> CockpitFrequencyPlan.Entry? {
        guard data.frequencyPlan.immediateEntries.indices.contains(index) else { return nil }
        return data.frequencyPlan.immediateEntries[index]
    }

    private func immediateFrequencyAccessibilityLabel(
        _ entry: CockpitFrequencyPlan.Entry?,
        index: Int
    ) -> String {
        let sequence = index == 0 ? "Planned now" : "Planned next"
        guard let entry else { return "\(sequence), none in imported plan" }
        return "\(sequence), \(entry.service), \(Self.frequency(entry.frequencyMHz)) megahertz"
    }

    private func readyFrequencyCard(_ cue: CockpitOperationalCueState.FrequencyCue) -> some View {
        let frequency = cue.frequency
        let isEmphasized = cue.status == .current && containsFrequencyEmphasis
        return VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(frequency.service) · \(frequency.serviceType)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 4)
                if let statusLabel = cue.statusLabel {
                    Text(statusLabel)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(cueForeground(for: cue.status))
                }
            }
            Text("\(Self.frequency(frequency.frequencyMHz)) MHz")
                .font(.subheadline.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(cueForeground(for: cue.status))
            Text(frequency.phases.map(Self.phaseAbbreviation).joined(separator: " → "))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minWidth: 176, alignment: .leading)
        .background(cueBackground(for: cue.status), in: RoundedRectangle(cornerRadius: 13))
        .overlay {
            RoundedRectangle(cornerRadius: 13)
                .stroke(
                    cueBorder(for: cue.status),
                    lineWidth: isEmphasized && accessibilityReduceMotion ? 4 : (cue.status == .other ? 1 : 2)
                )
        }
        .cuePulse(
            active: isEmphasized && !accessibilityReduceMotion,
            scale: 1.04
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(cue.accessibilityDescription)
        .accessibilityValue(cue.statusLabel?.lowercased() ?? "planned")
        .accessibilityIdentifier("frequency-\(frequency.id)")
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
            .disabled(isRecordingCommitInFlight)
        }
    }

    @ViewBuilder
    private var portraitActionRow: some View {
        switch flight.legState {
        case .ready:
            readyStartRow
        case .active:
            positionCheckAndProgressionControls
                .frame(maxWidth: .infinity)
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

                positionCheckAndProgressionControls
                    .frame(maxWidth: 350)
            }
        }
    }

    private var legStatusText: String {
        switch flight.legState {
        case .ready:
            previousLegSummary == nil ? "READY" : "READY · SUCCESSOR TRACK-UP"
        case .active:
            flight.destinationIdentifiedAt == nil ? "ACTIVE" : "ACTIVE · DESTINATION IDENTIFIED"
        case .completed:
            "COMPLETE"
        }
    }

    private var showsLegRouteInHeader: Bool {
        switch flight.legState {
        case .ready:
            previousLegSummary == nil
        case .active:
            flight.destinationIdentifiedAt == nil
        case .completed:
            false
        }
    }

    private var arrivalPrimaryGuidance: String {
        guard let identifiedAt = flight.destinationIdentifiedAt,
              let startedAt = flight.legStartedAt else {
            return "Identify the waypoint when it is positively recognized."
        }
        let elapsedSeconds = max(0, Int(identifiedAt.timeIntervalSince(startedAt).rounded()))
        return "Destination identified at \(Self.duration(elapsedSeconds)). Leg timing continues."
    }

    private var arrivalSecondaryGuidance: String {
        flight.destinationIdentifiedAt == nil
            ? "The active leg continues until you record reaching it."
            : "ETA revisions remain available until reach."
    }

    private var completedLegDurationText: String {
        guard let timing = flight.legTimings.first(where: { $0.legIndex == flight.activeLegIndex }),
              let duration = timing.actualElapsedDuration else { return "–:––" }
        return Self.duration(max(0, Int(duration.rounded())))
    }

    private var landscapeControlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            activeLegInstrumentsHeader
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                readyHeadingMetric
                portraitTimerMetric
                readyETAMetric
                readyAltitudeMetric
            }
            Divider()
            fixedImmediateFrequencyColumn
            Button("Frequency plan ›") {
                cockpitPresentationState.setFrequencyPlanPresented(true)
            }
            .font(.caption)
            .buttonStyle(.plain)
            .foregroundStyle(.tint)
            .accessibilityIdentifier("open-frequency-plan")
            Divider()
            positionCheckAndProgressionControls
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
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
        .disabled(flight.legState != .active)
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
            legStartedAt: flight.legState == .active ? flight.legStartedAt : nil
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

    private var orderedFrequencyCues: [CockpitOperationalCueState.FrequencyCue] {
        operationalCues?.frequencies ?? orderedFrequencies.map {
            CockpitOperationalCueState.FrequencyCue(frequency: $0, status: .other)
        }
    }

    private var currentFrequencyID: String? {
        orderedFrequencyCues.first(where: { $0.status == .current })?.id
    }

    private var frequencyRow: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 18) {
                    Text("PLANNED FREQUENCIES").font(.caption2.weight(.bold)).tracking(0.7).foregroundStyle(.secondary)
                    ForEach(orderedFrequencyCues) { frequencyValue($0) }
                    if orderedFrequencies.isEmpty { Text("None").font(.caption).foregroundStyle(.secondary) }
                    Text("Not tuned").font(.caption).foregroundStyle(.secondary)
                }
            }
            .scrollIndicators(.hidden).frame(minHeight: 30).padding(.horizontal, 10)
            .overlay(alignment: .top) { Divider() }.overlay(alignment: .bottom) { Divider() }
            .onChange(of: currentFrequencyID, initial: true) { _, frequencyID in
                centerFrequency(frequencyID, using: proxy)
            }
        }
    }

    private func centerFrequency(_ frequencyID: String?, using proxy: ScrollViewProxy) {
        guard let frequencyID else { return }
        withAnimation(.easeInOut(duration: 0.35)) {
            proxy.scrollTo(frequencyID, anchor: .center)
        }
    }

    private var frequencyColumn: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PLANNED FREQUENCIES").font(.caption2.weight(.bold)).tracking(0.7).foregroundStyle(.secondary)
                Spacer(); Text("Not tuned").font(.caption).foregroundStyle(.secondary)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(orderedFrequencyCues) { frequencyValue($0) }
                    if orderedFrequencies.isEmpty { Text("None").font(.caption).foregroundStyle(.secondary) }
                }
            }
            .frame(maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("planned-frequencies")
    }

    private func frequencyValue(_ cue: CockpitOperationalCueState.FrequencyCue) -> some View {
        readyFrequencyCard(cue)
    }

    private var containsFrequencyEmphasis: Bool {
        emphasizedCueEvents.contains { if case .frequency = $0 { true } else { false } }
    }

    private var containsAltitudeEmphasis: Bool {
        emphasizedCueEvents.contains { if case .altitude = $0 { true } else { false } }
    }

    private func cueForeground(for status: CockpitOperationalCueState.FrequencyCue.Status) -> Color {
        switch status {
        case .current: Self.cueGreen
        case .next: Self.cueAmber
        case .other: .primary
        }
    }

    private func cueBackground(for status: CockpitOperationalCueState.FrequencyCue.Status) -> Color {
        switch status {
        case .current: Self.cueGreenBackground
        case .next: Self.cueAmberBackground
        case .other: Color(.secondarySystemBackground)
        }
    }

    private func cueBorder(for status: CockpitOperationalCueState.FrequencyCue.Status) -> Color {
        switch status {
        case .current: Self.cueGreen
        case .next: Self.cueAmber
        case .other: Color(.separator)
        }
    }

    private static let cueGreen = Color(red: 10 / 255, green: 122 / 255, blue: 74 / 255)
    private static let cueGreenBackground = Color(red: 222 / 255, green: 247 / 255, blue: 232 / 255)
    private static let cueAmber = Color(red: 176 / 255, green: 80 / 255, blue: 0 / 255)
    private static let cueAmberBackground = Color(red: 255 / 255, green: 240 / 255, blue: 209 / 255)

    @ViewBuilder
    private var waypointReachedButton: some View {
        switch flight.legState {
        case .ready:
            Button(action: onStartLeg) {
                Label("Start Leg", systemImage: "play.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(uiColor: visualStyle.primaryActionColor))
            .accessibilityHint("Starts timing the current navigation leg")
            .accessibilityIdentifier("start-leg")
            .disabled(isRecordingCommitInFlight)
        case .active:
            if flight.destinationIdentifiedAt == nil {
                VStack(spacing: 2) {
                    Button {
                        selectedMapCallout = nil
                        onIdentifyDestination()
                    } label: {
                        HStack(spacing: 8) {
                            Text("◉")
                            Text("Report Destination Identified")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: horizontalSizeClass == .compact ? 40 : 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(horizontalSizeClass == .compact ? .small : .regular)
                    .tint(Color(uiColor: visualStyle.primaryActionColor))
                    .accessibilityLabel("Report Destination Identified")
                    .accessibilityHint("Records identifying the current destination without changing the active leg")
                    .accessibilityIdentifier("waypoint-identified")
                    Button {
                        isNextPreparationPresented = false
                        onWaypointReached(cockpitRestoration)
                    } label: {
                        Text("Report Destination Reached")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Report Destination Reached")
                    .accessibilityHint("Records reaching the waypoint now without identifying it first")
                    .accessibilityIdentifier("reached-now")
                }
            } else {
                Button {
                    onWaypointReached(cockpitRestoration)
                } label: {
                    Label("Report Destination Reached", systemImage: "checkmark.circle.fill")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(uiColor: visualStyle.primaryActionColor))
                .foregroundStyle(Color(uiColor: visualStyle.cockpitProgressionActionForegroundColor))
                .accessibilityLabel("Report Destination Reached")
                .accessibilityHint("Records reaching this waypoint and advances the navigation plan")
                .accessibilityIdentifier("waypoint-reached")
            }
        case .completed:
            if isNavigationCompletionCommitted {
                Label("Navigation Complete · Recording Continues", systemImage: "checkmark.circle.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("navigation-complete-committed")
            } else {
                Button(action: onNavigationComplete) {
                    Label("Navigation Complete", systemImage: "checkmark.circle.fill")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(uiColor: visualStyle.cockpitProgressionActionBackgroundColor))
                .foregroundStyle(.white)
                .accessibilityHint("Commits navigation completion while recording continues")
                .accessibilityIdentifier("navigation-complete")
            }
        }
    }

    @ViewBuilder
    private var positionCheckAndProgressionControls: some View {
        if flight.legState == .active, let positionCheck {
            if horizontalSizeClass == .compact {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: 10) {
                        PositionCheckControl(
                            presentation: positionCheck,
                            onAction: handlePositionCheckAction
                        )
                        waypointReachedButton
                    }
                } else {
                    HStack(alignment: .top, spacing: 10) {
                        PositionCheckControl(
                            presentation: positionCheck,
                            onAction: handlePositionCheckAction
                        )
                        .frame(maxWidth: .infinity)
                        waypointReachedButton
                            .frame(maxWidth: .infinity)
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    PositionCheckControl(
                        presentation: positionCheck,
                        onAction: handlePositionCheckAction
                    )
                    .frame(minWidth: 174)
                    waypointReachedButton
                        .frame(minWidth: 204)
                }
                VStack(spacing: 10) {
                    PositionCheckControl(
                        presentation: positionCheck,
                        onAction: handlePositionCheckAction
                    )
                    waypointReachedButton
                }
                }
            }
        } else {
            waypointReachedButton
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
           let etaState = flight.pilotETAState(targetKey: key) {
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
        guard flight.legState != .completed else { return }
        guard let target = mapPresentation.timingTarget(for: key) else { return }
        if selectedTimingTargetKey == key {
            dismissMapCallout()
        } else {
            if let selectedTimingTargetKey,
               flight.pilotETAState(targetKey: selectedTimingTargetKey)?.isEditing == true {
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
        guard flight.legState != .completed else { return }
        if let selectedTimingTargetKey,
           flight.pilotETAState(targetKey: selectedTimingTargetKey)?.isEditing == true {
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
            try onIdentificationPointReached(point.id, mapPresentation, cockpitRestoration)
            identificationPointReportError = nil
        } catch let error as Flight.TransitionError {
            identificationPointReportError = error
        } catch {
            identificationPointReportError = .invalidIdentificationPointOrder
        }
    }

    private var cockpitRestoration: CockpitRestoration {
        CockpitRestoration(
            camera: preservedMapCamera,
            isCameraUserControlled: isMapCameraUserControlled,
            selectedCallout: selectedMapCallout,
            focusRequest: mapFocusRequest
        )
    }

    private func handlePositionCheckAction(_ action: PositionCheckControlAction) {
        if action == .holdCompleted, positionCheckRestoration == nil {
            positionCheckRestoration = cockpitRestoration
        }
        let restoration = positionCheckRestoration ?? cockpitRestoration
        Task {
            await onPositionCheckAction(action, restoration)
        }
    }

    private func restoreReach(at now: Date) {
        Task {
            guard let restoration = await onUndoReach(now) else { return }
            isRestoringReach = true
            preservedMapCamera = restoration.camera
            isMapCameraUserControlled = restoration.isCameraUserControlled
            selectedMapCallout = restoration.selectedCallout
            mapFocusRequest = restoration.focusRequest
            mapIdentity = UUID()
            identificationPointReportError = nil
        }
    }

    private var identificationContext: AviationMapIdentificationContext? {
        guard let point = selectedIdentificationPoint else { return nil }
        let nextTarget = mapPresentation.nextETATarget(after: point.id)
        let actual = flight.actualLegElapsedDuration(atIdentificationPoint: point.id).map {
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
              let etaState = flight.pilotETAState(targetKey: key) else { return nil }
        let disclosure = etaState.latestCheckDisclosure
        let reference = disclosure?.referenceSeconds
        let targetIndex = target.kind == .destination
            ? mapPresentation.identificationPoints.endIndex
            : mapPresentation.identificationPoints.firstIndex { $0.id.identificationPointID == target.id.targetID }
        let canCheck = targetIndex.map { index in
            mapPresentation.identificationPoints[..<index].contains {
                $0.plannedElapsedSeconds > 0
                    && flight.identificationPointState(for: $0.id).isReached
                    && flight.actualLegElapsedDuration(atIdentificationPoint: $0.id) != nil
            }
        } ?? false
        let observationBasis = disclosure.flatMap { disclosure -> String? in
            let observationKey = disclosure.observationKey
            guard let point = mapPresentation.identificationPoints.first(where: { $0.id == observationKey }),
                  let actual = flight.actualLegElapsedDuration(atIdentificationPoint: observationKey) else { return nil }
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
            minimumETASeconds: Flight.pilotETAMinimumSeconds(
                currentElapsedSeconds: flight.elapsedTime(at: timestamp)
                    .map(IdentificationPointTimingCalculator.displaySeconds) ?? 0
            )
        )
    }
}

private extension View {
    @ViewBuilder
    func cuePulse(active: Bool, scale: CGFloat) -> some View {
        if active {
            phaseAnimator([false, true]) { content, expanded in
                content.scaleEffect(expanded ? scale : 1)
            } animation: { _ in
                .easeInOut(duration: 0.65)
            }
        } else {
            self
        }
    }
}

private struct IdentificationPointContextOverlay: View {
    let point: AviationMapIdentificationPoint?
    let flight: Flight
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
                    if let pilotETA = flight.pilotETAState(targetKey: nextTarget.id)?.draftSeconds {
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
        return flight.actualLegElapsedDuration(atIdentificationPoint: point.id).map {
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
    let isCompact: Bool
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
                if state.presentationState == .expanded, !isCompact {
                    LegStartChecklistCard(
                        checklist: checklist,
                        legStartedAt: legStartedAt,
                        isCompact: false,
                        onCollapse: onCollapse,
                        onNoted: onNoted
                    )
                } else if state.presentationState == .collapsed {
                    Button(action: onReopen) {
                        HStack(spacing: 8) {
                            Text(state.reviewState == .noted ? "Checklist · Noted" : "Checklist")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color(red: 18 / 255, green: 20 / 255, blue: 26 / 255))
                                .lineLimit(2)
                            Spacer(minLength: 8)
                            Text("›")
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(Color(red: 0, green: 97 / 255, blue: 224 / 255))
                                .frame(width: 14)
                        }
                        .padding(.horizontal, 13)
                        .frame(width: 230, height: 40)
                    }
                    .buttonStyle(.plain)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .stroke(Color(red: 209 / 255, green: 212 / 255, blue: 217 / 255))
                    }
                    .shadow(color: .black.opacity(0.14), radius: 3.5, y: 2)
                    .accessibilityLabel(state.reviewState == .noted ? "Checklist · Noted" : "Checklist")
                    .accessibilityHint("Opens the start of leg checklist")
                    .accessibilityIdentifier("leg-start-checklist-chip")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: state.presentationState == .expanded ? .topTrailing : .bottomLeading)
            .padding(.horizontal, 18)
            .padding(.vertical, state.presentationState == .expanded ? 34 : 14)
        }
    }
}

private struct LegStartChecklistCard: View {
    let checklist: LegStartChecklistPresentation
    let legStartedAt: Date
    let isCompact: Bool
    let onCollapse: () -> Void
    let onNoted: () -> Void
    private let primaryText = Color(red: 20 / 255, green: 26 / 255, blue: 36 / 255)
    private let secondaryText = Color(red: 87 / 255, green: 99 / 255, blue: 117 / 255)
    private let actionBlue = Color(red: 0, green: 107 / 255, blue: 199 / 255)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Checklist")
                        .font(.title2.bold())
                        .foregroundStyle(primaryText)
                    Text("Selected template · \(checklist.template.displayName)")
                        .font(.subheadline)
                        .foregroundStyle(secondaryText)
                }
                Spacer(minLength: 4)
                Button(action: onCollapse) {
                    Text(isCompact ? "Done" : "Close")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .frame(minWidth: 46, minHeight: 46)
                .contentShape(Rectangle())
                .accessibilityLabel(isCompact ? "Done" : "Close checklist")
                .accessibilityIdentifier("leg-start-checklist-close")
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
                Text("Mark checklist noted")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity, minHeight: 32)
            }
            .buttonStyle(.borderedProminent)
            .tint(actionBlue)
            .accessibilityLabel("Mark leg start checklist noted")
            .accessibilityHint("Dismisses the rendered checklist without certifying completion of individual items")
            .accessibilityIdentifier("leg-start-checklist-noted")
            Text("Noting folds the checklist into a compact chip; it does not certify completion of each item.")
                .font(.subheadline)
                .foregroundStyle(secondaryText)
        }
        .padding(.horizontal, isCompact ? 20 : 22)
        .padding(.vertical, isCompact ? 16 : 14)
        .frame(width: isCompact ? nil : 380, height: isCompact ? nil : 760, alignment: .topLeading)
        .frame(maxWidth: isCompact ? .infinity : nil, maxHeight: isCompact ? .infinity : nil, alignment: .topLeading)
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

private struct CompactLegStartChecklistSheet: View {
    @Environment(\.dismiss) private var dismiss
    let checklist: LegStartChecklistPresentation
    let legStartedAt: Date
    let onCollapse: () -> Void
    let onNoted: () -> Void

    var body: some View {
        LegStartChecklistCard(
            checklist: checklist,
            legStartedAt: legStartedAt,
            isCompact: true,
            onCollapse: {
                dismiss()
                onCollapse()
            },
            onNoted: {
                dismiss()
                onNoted()
            }
        )
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
                    Text(timerItem.title).font(.caption.weight(.bold)).foregroundStyle(secondaryText)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text("Started · \(duration(from: legStartedAt, to: context.date))")
                            .font(.subheadline.weight(.semibold)).foregroundStyle(primaryText).monospacedDigit()
                    }
                }
            }
            if let directionItem = checklist.template.item(.direction) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(directionLabel(templateTitle: directionItem.title))
                        .font(.caption.weight(.bold)).foregroundStyle(secondaryText)
                    Text(directionValue).font(.title2.bold()).foregroundStyle(headingBlue).monospacedDigit()
                    if let instruction = directionItem.instruction {
                        Text(instruction).font(.caption).foregroundStyle(secondaryText)
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
                        .font(.caption.weight(.bold))
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
            Text(title).font(.caption.weight(.semibold))
                .foregroundStyle(Color(red: 20 / 255, green: 26 / 255, blue: 36 / 255))
            Text(lines.joined(separator: "\n"))
                .font(.caption.weight(.semibold))
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
    let bottomInset: CGFloat
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
            .padding(.bottom, (isPresented ? 62 : 0) + bottomInset)
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
