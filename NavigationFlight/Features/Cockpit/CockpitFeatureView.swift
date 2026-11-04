import SwiftUI
import UIKit
import UniformTypeIdentifiers

extension UTType {
    static let fplnav = UTType(filenameExtension: "fplnav") ?? .data
}

struct CockpitFeatureView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Binding private var state: CockpitFeatureState
    @State private var isImporterPresented = false
    @State private var isCockpitPresented = false
    @State private var presentedError: PresentedError?
    @State private var locationAvailability: LocationAvailability = .acquiring
    @State private var positionCheckCoordinator: PositionCheckCoordinator
    @State private var pendingPositionCheckAcceptanceFeedback = false
    @State private var isEndRecordingConfirmationPresented = false
    private let loader = FPLNavFileLoader()
    private let adapter = CockpitPresentationAdapter()
    private let presentationRequestID: UUID?
    private let locationService: AircraftLocationService
    private let isSectionSelected: Bool
    private let recordingCoordinator: FlightRecordingCoordinator
    private let onIntent: (CockpitFeatureIntent) -> Void

    init(
        state: Binding<CockpitFeatureState>,
        presentationRequestID: UUID? = nil,
        locationService: AircraftLocationService,
        positionCheckTiming: PositionCheckTiming = .standard,
        isSectionSelected: Bool,
        recordingCoordinator: FlightRecordingCoordinator,
        onIntent: @escaping (CockpitFeatureIntent) -> Void
    ) {
        _state = state
        self.presentationRequestID = presentationRequestID
        self.locationService = locationService
        _positionCheckCoordinator = State(initialValue: PositionCheckCoordinator(timing: positionCheckTiming))
        self.isSectionSelected = isSectionSelected
        self.recordingCoordinator = recordingCoordinator
        self.onIntent = onIntent
    }

    var body: some View {
        content
            .onChange(of: presentationRequestID, initial: true) { _, newValue in
                if newValue != nil {
                    isCockpitPresented = true
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    positionCheckCoordinator.send(.sceneBecameInactive)
                }
            }
            .onChange(of: state.flight?.id) { oldValue, newValue in
                if oldValue != nil, oldValue != newValue {
                    positionCheckCoordinator.send(.activeFlightLost)
                }
            }
            .onChange(of: state.flight?.activeLegIndex) { _, _ in
                positionCheckCoordinator.send(.activeLegChanged)
            }
            .onChange(of: state.flight?.legState) { _, legState in
                if legState != .active {
                    positionCheckCoordinator.send(.activeFlightLost)
                }
            }
            .onChange(of: isSectionSelected) { _, selected in
                if !selected {
                    positionCheckCoordinator.send(.cockpitDismissed)
                }
            }
            .onChange(of: isCockpitPresented) { _, presented in
                if !presented {
                    positionCheckCoordinator.send(.cockpitDismissed)
                }
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.fplnav],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result)
            } onCancellation: {
                state.cancelImport()
            }
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert("End Recording?", isPresented: $isEndRecordingConfirmationPresented) {
                Button(endRecordingConfirmationAction, role: .destructive) {
                    endRecording()
                }
                Button("Keep Recording", role: .cancel) {}
            } message: {
                Text(endRecordingConfirmationMessage)
            }
            .task(id: shouldMonitorLocation) {
                guard shouldMonitorLocation else {
                    await locationService.stopMonitoring()
                    return
                }
                let updates = await locationService.availabilityUpdates()
                await locationService.startMonitoring()
                for await availability in updates {
                    if Task.isCancelled { break }
                    locationAvailability = availability
                    positionCheckCoordinator.send(.locationAvailabilityChanged(availability))
                }
                await locationService.stopMonitoring()
            }
    }

    @ViewBuilder
    private var content: some View {
        if let flightPlan = state.flightPlan,
           let flight = state.flight,
           let presentation = try? adapter.makePresentation(
               flightPlan: flightPlan,
               legIndex: state.selectedLegIndex,
               mode: state.mode
           ) {
            if isCockpitPresented {
                if let mapPresentation = try? AviationMapPresentationFactory().makePresentation(
                    flightPlan: flightPlan,
                    flight: flight
                ) {
                    let nextLegPreparation = try? adapter.makeNextLegPreparation(
                        flightPlan: flightPlan,
                        flight: flight
                    )
                    let previousLegSummary = try? adapter.makePreviousLegSummary(
                        flightPlan: flightPlan,
                        flight: flight
                    )
                    let legStartChecklist = try? adapter.makeLegStartChecklist(
                        flightPlan: flightPlan,
                        flight: flight
                    )
                    let positionCheck = adapter.makePositionCheckPresentation(
                        for: locationAvailability,
                        state: positionCheckCoordinator.state,
                        remainingSeconds: positionCheckCoordinator.remainingSeconds,
                        recoveryOutcome: recoveryOutcome(
                            mapPresentation: mapPresentation,
                            magneticCourseDegrees: presentation.magneticCourseDegrees
                        )
                    )
                    CockpitOperationalCueTimeline(
                        flightPlan: flightPlan,
                        flight: flight,
                        isVisible: isSectionSelected && scenePhase == .active
                    ) { operationalCues, emphasizedCueEvents in
                    CockpitView(
                        data: presentation,
                        mapPresentation: addingGPSDisclosure(
                            mapPresentation,
                            disclosing: positionCheck.disclosedPosition,
                            recoveryOutcome: recoveryOutcome(
                                mapPresentation: mapPresentation,
                                magneticCourseDegrees: presentation.magneticCourseDegrees
                            )
                        ),
                        nextLegPreparation: nextLegPreparation,
                        previousLegSummary: previousLegSummary,
                        legStartChecklist: legStartChecklist,
                        checklistState: state.activeLegStartChecklist,
                        flight: flight,
                        areDriftLinesVisible: state.areDriftLinesVisible,
                        operationalCues: operationalCues,
                        emphasizedCueEvents: emphasizedCueEvents,
                        pendingReachUndo: state.pendingReachUndo,
                        positionCheck: positionCheck,
                        recordingStatus: RecordingStatusPresentation(status: recordingCoordinator.status),
                        isRecordingCommitInFlight: recordingCoordinator.isCommitting,
                        isNavigationCompletionCommitted: recordingCoordinator.status == .navigationCompleteRecordingContinues
                            || recordingCoordinator.status == .closedComplete,
                        positionCheckMapRestoration: positionCheckCoordinator.pendingMapRestoration,
                        onPositionCheckMapRestored: positionCheckCoordinator.acknowledgeMapRestoration,
                        onPositionCheckAction: handlePositionCheckAction,
                        onEndRecording: { isEndRecordingConfirmationPresented = true },
                        onNavigationComplete: completeNavigation,
                        onStartLeg: startLeg,
                        onIdentifyDestination: identifyDestination,
                        onWaypointReached: { restoration in
                            reachCurrentWaypoint(mapPresentation: mapPresentation, restoration: restoration)
                        },
                        onIdentificationPointReached: { pointID, mapPresentation, restoration in
                            reachIdentificationPoint(
                                pointID,
                                mapPresentation: mapPresentation,
                                restoration: restoration
                            )
                        },
                        onUndoReach: { state.undoMostRecentReach(at: $0) },
                        onOpenPilotETA: { state.openPilotETAEditor(target: $0) },
                        onAdjustPilotETA: { targetID, delta in
                            state.adjustPilotETA(targetKey: targetID, by: delta)
                        },
                        onCommitPilotETA: { state.commitPilotETA(targetKey: $0) },
                        onCancelPilotETA: { state.cancelPilotETAEditing(targetKey: $0) },
                        onEditPilotETA: { state.beginEditingPilotETA(targetKey: $0) },
                        onShowPilotETACheck: {
                            state.showPilotETACheck(targetKey: $0, mapPresentation: mapPresentation)
                        },
                        onHidePilotETACheck: { state.hidePilotETACheck(targetKey: $0) },
                        onOpenPilotHeading: { baseline in state.openPilotHeadingEditor(baselineDegrees: baseline) },
                        onAdjustPilotHeading: { state.adjustPilotHeading(by: $0) },
                        onCommitPilotHeading: { state.commitPilotHeading() },
                        onCancelPilotHeading: { state.cancelPilotHeadingEditing() },
                        onCollapseChecklist: { state.collapseLegStartChecklist() },
                        onReopenChecklist: { state.reopenLegStartChecklist() },
                        onNoteChecklist: { state.noteLegStartChecklist() },
                        onToggleDriftLines: { state.toggleDriftLines() },
                        onShowPlanInspection: { isCockpitPresented = false }
                    )
                    }
                    .onChange(of: positionCheck) { previous, current in
                        let feedback = PositionCheckFeedbackPolicy().feedback(
                            previous: previous,
                            current: current,
                            activationAccepted: pendingPositionCheckAcceptanceFeedback
                        )
                        pendingPositionCheckAcceptanceFeedback = false
                        if let announcement = feedback.announcement {
                            UIAccessibility.post(notification: .announcement, argument: announcement)
                        }
                    }
                }
            } else {
                PlanInspectionView(
                    data: presentation,
                    canSelectPreviousLeg: state.canSelectPreviousLeg,
                    canSelectNextLeg: state.canSelectNextLeg,
                    onOpenPlan: { isImporterPresented = true },
                    onOpenCockpit: { isCockpitPresented = true },
                    onRestartFlight: { onIntent(.restartFlight) },
                    onSelectPreviousLeg: { state.selectPreviousLeg() },
                    onSelectNextLeg: { state.selectNextLeg() },
                    onSelectMode: { state.selectMode($0) }
                )
            }
        } else {
            ContentUnavailableView {
                Label("Choose a Flight Plan to begin", systemImage: "airplane")
            } description: {
                Text("No Flight Plan is loaded. Import remains a Flight Plans responsibility.")
            } actions: {
                Button {
                    onIntent(.chooseFlightPlan)
                } label: {
                    Label("Choose a Flight Plan", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("choose-flight-plan")
            }
            .accessibilityIdentifier("empty-cockpit")
        }
    }

    private func handleImport(_ result: Result<[URL], any Error>) {
        do {
            guard let url = try result.get().first else { return }
            let candidate = try loader.load(url)
            try state.accept(candidate)
            isCockpitPresented = false
        } catch let error as CockpitPlanError {
            presentedError = .init(title: "Couldn’t Open Plan", message: error.localizedDescription)
        } catch {
            presentedError = .init(
                title: "Couldn’t Open Plan",
                message: "The selected file couldn’t be opened. \(error.localizedDescription)"
            )
        }
    }

    private func startLeg() {
        guard let flight = state.flight, let flightPlan = state.flightPlan else { return }
        Task {
            do {
                let transition = try await recordingCoordinator.startLeg(
                    flight: flight,
                    flightPlanSnapshot: RecordedFlightPlanSnapshot(
                        id: flightPlan.id,
                        title: flightPlan.title,
                        legIDs: flightPlan.legs.map(\.id)
                    ),
                    at: .now,
                    recordingID: UUID(),
                    eventIDs: [UUID(), UUID()]
                )
                state.installCommittedFlight(transition.flight)
            } catch {
                presentedError = .init(
                    title: "Couldn’t Start Leg",
                    message: "The recording couldn’t be saved. The leg remains ready."
                )
            }
        }
    }

    private func endRecording() {
        guard let recording = recordingCoordinator.snapshot.recording else { return }
        let now = Date.now
        let elapsed = Duration.seconds(max(0, now.timeIntervalSince(recording.startedAt)))
        Task {
            do {
                try await recordingCoordinator.endManually(
                    at: now,
                    elapsed: elapsed,
                    eventIDs: [UUID(), UUID()]
                )
            } catch {
                presentedError = .init(
                    title: "Couldn’t End Recording",
                    message: "The recording remains active and no saved data was discarded."
                )
            }
        }
    }

    private func identifyDestination() {
        guard let timing = recordingTiming() else { return }
        Task {
            do {
                let transition = try await recordingCoordinator.commitNavigation(.identifyDestination(
                    at: timing.now,
                    elapsed: timing.elapsed,
                    eventID: UUID()
                ))
                state.installCommittedDestinationIdentification(transition.flight)
            } catch {
                presentNavigationCommitFailure("Identify Waypoint")
            }
        }
    }

    private func reachCurrentWaypoint(
        mapPresentation: AviationMapPresentation,
        restoration: CockpitRestoration
    ) {
        guard let timing = recordingTiming() else { return }
        Task {
            do {
                let transition = try await recordingCoordinator.commitNavigation(.reachCurrentWaypoint(
                    orderedActiveLegPointKeys: mapPresentation.identificationPoints.map(\.id),
                    at: timing.now,
                    elapsed: timing.elapsed,
                    eventIDs: [UUID(), UUID()]
                ))
                state.installCommittedWaypointReach(
                    transition.flight,
                    cockpitRestoration: restoration,
                    at: timing.now
                )
            } catch {
                presentNavigationCommitFailure("Reach Waypoint")
            }
        }
    }

    private func reachIdentificationPoint(
        _ key: IdentificationPointKey,
        mapPresentation: AviationMapPresentation,
        restoration: CockpitRestoration
    ) {
        guard let timing = recordingTiming(),
              let selectedIndex = mapPresentation.identificationPoints.firstIndex(where: { $0.id == key }) else { return }
        let nextTarget = mapPresentation.identificationPoints[(selectedIndex + 1)...].first.map { point in
            (NavigationTimingTargetKey(
                legID: point.id.legID,
                kind: .identificationPoint,
                targetID: point.id.identificationPointID
            ), point.plannedElapsedSeconds)
        } ?? (mapPresentation.destinationTarget.id, mapPresentation.destinationTarget.plannedElapsedSeconds)
        Task {
            do {
                let transition = try await recordingCoordinator.commitNavigation(.reachIdentificationPoint(
                    key: key,
                    orderedActiveLegPointKeys: mapPresentation.identificationPoints.map(\.id),
                    at: timing.now,
                    elapsed: timing.elapsed,
                    eventID: UUID(),
                    nextETATarget: nextTarget.0,
                    nextETAPlannedElapsedSeconds: nextTarget.1
                ))
                try state.installCommittedIdentificationPointReach(
                    transition.flight,
                    key: key,
                    mapPresentation: mapPresentation,
                    cockpitRestoration: restoration,
                    at: timing.now
                )
            } catch {
                presentNavigationCommitFailure("Reach Identification Point")
            }
        }
    }

    private func recordingTiming() -> (now: Date, elapsed: Duration)? {
        guard let recording = recordingCoordinator.snapshot.recording else { return nil }
        let now = Date.now
        return (now, .seconds(max(0, now.timeIntervalSince(recording.startedAt))))
    }

    private func presentNavigationCommitFailure(_ action: String) {
        presentedError = .init(
            title: "Couldn’t \(action)",
            message: "The recording couldn’t be saved. Navigation remains unchanged."
        )
    }

    private func completeNavigation() {
        guard let flight = state.flight,
              let recording = recordingCoordinator.snapshot.recording else { return }
        let now = Date.now
        let elapsed = Duration.seconds(max(0, now.timeIntervalSince(recording.startedAt)))
        Task {
            do {
                try await recordingCoordinator.completeNavigation(
                    flight: flight,
                    at: now,
                    elapsed: elapsed,
                    eventID: UUID()
                )
            } catch {
                presentedError = .init(
                    title: "Couldn’t Complete Navigation",
                    message: "Navigation remains unchanged and the recording continues."
                )
            }
        }
    }

    private var endRecordingConfirmationAction: String {
        recordingCoordinator.status == .navigationCompleteRecordingContinues
            ? "End Recording"
            : "End and mark incomplete"
    }

    private var endRecordingConfirmationMessage: String {
        recordingCoordinator.status == .navigationCompleteRecordingContinues
            ? "Navigation is complete. The action-only recording will close as complete."
            : "The action-only recording will close as incomplete. Navigation remains available."
    }

    private var shouldMonitorLocation: Bool {
        PositionCheckMonitoringScope.shouldMonitor(
            sectionSelected: isSectionSelected,
            cockpitPresented: isCockpitPresented,
            hasFlight: state.flight != nil,
            sceneActive: scenePhase == .active
        )
    }

    private func handlePositionCheckAction(
        _ action: PositionCheckControlAction,
        restoration: CockpitRestoration
    ) {
        switch action {
        case .holdCompleted:
            let intent: PositionCheckIntent = positionCheckCoordinator.state.activeSession == nil
                ? .holdCompleted(availability: locationAvailability, restoration: restoration)
                : .restartHoldCompleted(availability: locationAvailability, restoration: restoration)
            let effect = positionCheckCoordinator.send(intent)
            if case .scheduleDeadline = effect {
                pendingPositionCheckAcceptanceFeedback = true
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }
        case .cancel:
            positionCheckCoordinator.send(.cancel)
        case .end:
            positionCheckCoordinator.send(.end)
        case .retry:
            Task {
                await locationService.stopMonitoring()
                await locationService.startMonitoring()
            }
        case .requestPermission:
            Task { await locationService.requestWhenInUseAuthorization() }
        case .openSettings:
            if let url = URL(string: UIApplication.openSettingsURLString) {
                openURL(url)
            }
        case .dismiss:
            positionCheckCoordinator.send(.dismissFailure)
        }
    }

    private func addingGPSDisclosure(
        _ presentation: AviationMapPresentation,
        disclosing projection: PositionCheckProjection?,
        recoveryOutcome: ActiveLegRecoveryOutcome?
    ) -> AviationMapPresentation {
        var result = presentation
        result.gpsDisclosureOverlay = projection.map { GPSDisclosureOverlay(projection: $0, recoveryOutcome: recoveryOutcome) }
        return result
    }

    private func recoveryOutcome(
        mapPresentation: AviationMapPresentation,
        magneticCourseDegrees: Double
    ) -> ActiveLegRecoveryOutcome? {
        positionCheckCoordinator.recoveryOutcome(
            for: locationAvailability,
            activeLeg: mapPresentation.activeLeg,
            importedMagneticCourseDegrees: magneticCourseDegrees
        )
    }
}

private struct CockpitOperationalCueTimeline<Content: View>: View {
    let flightPlan: FlightPlan
    let flight: Flight
    let isVisible: Bool
    @ViewBuilder let content: (CockpitOperationalCueState, Set<CockpitOperationalCueState.DueEvent>) -> Content

    @State private var emphasis = CockpitDueEmphasis()
    private let projector = CockpitOperationalCueProjector()

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            if let cues = try? projector.project(flightPlan: flightPlan, flight: flight, at: timeline.date) {
                content(cues, emphasis.activeEvents(at: timeline.date))
                    .onChange(of: cues.dueEvents, initial: true) { _, events in
                        emphasis.observe(
                            events,
                            contextID: contextID,
                            isVisible: isVisible,
                            at: timeline.date
                        )
                    }
                    .onChange(of: isVisible) { _, visible in
                        emphasis.observe(
                            cues.dueEvents,
                            contextID: contextID,
                            isVisible: visible,
                            at: timeline.date
                        )
                    }
                    .onChange(of: contextID) { _, _ in
                        emphasis.observe(
                            cues.dueEvents,
                            contextID: contextID,
                            isVisible: isVisible,
                            at: timeline.date
                        )
                    }
            }
        }
    }

    private var contextID: String {
        "\(flight.id.uuidString):\(flight.activeLegIndex)"
    }
}

private struct PresentedError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
