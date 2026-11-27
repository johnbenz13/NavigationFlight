import SwiftUI
import UIKit

struct CockpitFeatureView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Binding private var state: CockpitFeatureState
    @State private var presentedError: PresentedError?
    @State private var locationAvailability: LocationAvailability = .acquiring
    @State private var positionCheckCoordinator: PositionCheckCoordinator
    @State private var pendingPositionCheckAcceptanceFeedback = false
    @State private var suppressNextPositionCheckEndRecording = false
    @State private var isEndRecordingConfirmationPresented = false
    @State private var progressionNotice: CockpitProgressionNotice?
    @State private var failedRouteBoundaryReport: RouteBoundaryReport?
    @State private var isRouteBoundaryFailurePresented = false
    @State private var isRouteBoundaryOutcomeUncertain = false

    private struct RouteBoundaryReport {
        let command: RecordedNavigationCommand
        let checklist: StartChecklistSelection
        let target: NavigationTimingTargetKey
        let navigationGeneration: UUID?
        let isRejoin: Bool
    }
    private let amendmentMode: () -> RouteAmendmentMode
    private let checklistSelection: () -> StartChecklistSelection
    private let adapter = CockpitPresentationAdapter()
    private let locationService: AircraftLocationService
    private let isSectionSelected: Bool
    private let recordingCoordinator: FlightRecordingCoordinator
    private let draftPersistence: AmendmentDraftPersistence?
    private let chartCatalog: ChartCatalog?
    private let chartResources: ChartResources
    private let shouldSimulateRecordingDegradation: Bool
    private let onIntent: (CockpitFeatureIntent) -> Void

    init(
        state: Binding<CockpitFeatureState>,
        locationService: AircraftLocationService,
        positionCheckTiming: PositionCheckTiming = .standard,
        isSectionSelected: Bool,
        recordingCoordinator: FlightRecordingCoordinator,
        draftPersistence: AmendmentDraftPersistence? = nil,
        checklistSelection: @escaping () -> StartChecklistSelection = { .tzeKivun },
        amendmentMode: @escaping () -> RouteAmendmentMode,
        chartCatalog: ChartCatalog? = nil,
        chartResources: ChartResources = .bundled,
        shouldSimulateRecordingDegradation: Bool = false,
        onIntent: @escaping (CockpitFeatureIntent) -> Void
    ) {
        self.checklistSelection = checklistSelection
        self.amendmentMode = amendmentMode
        _state = state
        self.locationService = locationService
        _positionCheckCoordinator = State(initialValue: PositionCheckCoordinator(timing: positionCheckTiming))
        self.isSectionSelected = isSectionSelected
        self.recordingCoordinator = recordingCoordinator
        self.draftPersistence = draftPersistence
        self.chartCatalog = chartCatalog
        self.chartResources = chartResources
        self.shouldSimulateRecordingDegradation = shouldSimulateRecordingDegradation
        self.onIntent = onIntent
    }

    var body: some View {
        content
            .onChange(of: positionCheckCoordinator.state) { previous, current in
                let ended = (previous.activeSession != nil || previous.acquisitionRequest != nil)
                    && current.activeSession == nil
                    && current.acquisitionRequest == nil
                guard ended else { return }
                if suppressNextPositionCheckEndRecording {
                    suppressNextPositionCheckEndRecording = false
                    return
                }
                let sample = previous.activeSession.map {
                    PositionCheckRecordedSample(
                        coordinate: $0.projection.coordinate,
                        observedAt: $0.projection.observedAt,
                        horizontalAccuracyMeters: $0.projection.horizontalAccuracyMeters
                    )
                }
                recordPositionCheckEnd(sample: sample)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active {
                    endPositionCheck(.sceneBecameInactive)
                }
            }
            .onChange(of: state.flight?.id) { oldValue, newValue in
                if oldValue != nil, oldValue != newValue {
                    endPositionCheck(.activeFlightLost)
                }
            }
            .onChange(of: state.flight?.activeLegID) { _, _ in
                endPositionCheck(.activeLegChanged)
            }
            .onChange(of: state.flight?.legState) { _, legState in
                if legState != .active {
                    endPositionCheck(.activeFlightLost)
                }
            }
            .onChange(of: isSectionSelected) { _, selected in
                if !selected {
                    endPositionCheck(.cockpitDismissed)
                }
            }
            .alert(item: $presentedError) { error in
                Alert(
                    title: Text(error.title),
                    message: Text(error.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .alert(
                failedRouteBoundaryReport?.isRejoin == true ? "Rejoin could not be saved" : "Departure could not be saved",
                isPresented: $isRouteBoundaryFailurePresented,
                presenting: failedRouteBoundaryReport
            ) { report in
                Button(report.isRejoin ? "Keep flying" : "Keep pending", role: .cancel) {
                    if !isRouteBoundaryOutcomeUncertain { failedRouteBoundaryReport = nil }
                }
                Button("Retry save") { commitRouteBoundaryReport(report) }
            } message: { _ in
                Text("The last confirmed route remains operational.")
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
               mode: state.mode, flight: flight
           ) {
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
                    let legStartChecklist = state.activeLegStartChecklist.flatMap { captured in
                        try? adapter.makeLegStartChecklist(
                            flightPlan: flightPlan, flight: flight, captured: captured
                        )
                    }
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
                        isSectionSelected: isSectionSelected,
                        chartCatalog: chartCatalog,
                        chartResources: chartResources,
                        operationalContext: flightPlan.operationalContext,
                        operationalCues: operationalCues,
                        emphasizedCueEvents: emphasizedCueEvents,
                        pendingReachUndo: state.pendingReachUndo,
                        progressionNotice: progressionNotice,
                        positionCheck: positionCheck,
                        recordingStatus: RecordingStatusPresentation(status: recordingCoordinator.effectiveStatus),
                        isRecordingCommitInFlight: recordingCoordinator.isCommitting,
                        isNavigationCompletionCommitted: recordingCoordinator.isNavigationCompletionCommitted,
                        positionCheckMapRestoration: positionCheckCoordinator.pendingMapRestoration,
                        onPositionCheckMapRestored: positionCheckCoordinator.acknowledgeMapRestoration,
                        routeForAmendment: state.routeForAmendment,
                        routeAmendmentDraft: state.routeAmendmentDraft,
                        isAmendmentWorkspaceVisible: state.isAmendmentWorkspaceVisible,
                        isAmendmentPlotting: state.isAmendmentPlotting,
                        amendmentDisplayDate: amendmentDisplayDate,
                        isReplacingPendingAmendment: state.replacingPendingAmendmentID != nil,
                        pendingAmendmentManagement: state.pendingAmendmentManagement,
                        pendingManagementSave: state.pendingAmendmentManagementSave,
                        onManagePendingAmendment: managePendingAmendment,
                        amendmentSaveStatus: state.amendmentSave?.status,
                        draftPersistenceStatus: draftPersistence?.statuses[flight.id],
                        onRetryDraftSave: { draftPersistence?.retry(flightID: flight.id) },
                        onRetryDraftDiscard: discardAmendmentDraft,
                        onConfirmAmendment: { confirmAmendment(startNow: false) },
                        onStartAmendmentNow: { confirmAmendment(startNow: true) },
                        canStartAmendmentNow: canConfirmAmendment(startNow: true),
                        canConfirmAmendmentForLater: canConfirmAmendment(startNow: false),
                        activatedAmendmentSourceRoute: activatedAmendmentSourceRoute,
                        onKeepEditingAmendment: { state.amendmentSave = nil },
                        onRouteAmendment: updateAmendmentDraft,
                        onPositionCheckAction: handlePositionCheckAction,
                        onEndRecording: { isEndRecordingConfirmationPresented = true },
                        onNavigationComplete: completeNavigation,
                        onStartLeg: startLeg,
                        onIdentifyDestination: {
                            identifyDestination(targetID: mapPresentation.destinationTarget.id.targetID)
                        },
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
                        onUndoReach: undoMostRecentReach,
                        onOpenPilotETA: { state.openPilotETAEditor(target: $0) },
                        onAdjustPilotETA: { targetID, delta in
                            state.adjustPilotETA(targetKey: targetID, by: delta)
                        },
                        onCommitPilotETA: commitPilotETA,
                        onCancelPilotETA: { state.cancelPilotETAEditing(targetKey: $0) },
                        onEditPilotETA: { state.beginEditingPilotETA(targetKey: $0) },
                        onShowPilotETACheck: {
                            state.showPilotETACheck(targetKey: $0, mapPresentation: mapPresentation)
                        },
                        onHidePilotETACheck: { state.hidePilotETACheck(targetKey: $0) },
                        onOpenPilotHeading: { baseline in state.openPilotHeadingEditor(baselineDegrees: baseline) },
                        onAdjustPilotHeading: { state.adjustPilotHeading(by: $0) },
                        onCommitPilotHeading: commitPilotHeading,
                        onCancelPilotHeading: { state.cancelPilotHeadingEditing() },
                        onCollapseChecklist: { state.collapseLegStartChecklist() },
                        onReopenChecklist: { state.reopenLegStartChecklist() },
                        onNoteChecklist: { state.noteLegStartChecklist() },
                        onToggleDriftLines: { state.toggleDriftLines() },
                        onShowPlanInspection: { onIntent(.chooseFlightPlan) }
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

    private var amendmentDisplayDate: Date? {
#if DEBUG
        let fixture = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_WORKSPACE"]
        if fixture?.hasPrefix("A") == true || fixture == "C",
           let start = state.flight?.legStartedAt {
            return start.addingTimeInterval(442)
        }
#endif
        return nil
    }

    private func startLeg() {
        guard let flight = state.flight, let flightPlan = state.flightPlan else { return }
        let selection = checklistSelection()
        let context = state.recordingCockpitContext
        let sourceData = state.flightPlanSourceData
        Task {
            do {
                let transition = try await recordingCoordinator.startLeg(
                    flight: flight,
                    flightPlanSnapshot: RecordedFlightPlanSnapshot(
                        id: flightPlan.id,
                        title: flightPlan.title,
                        legIDs: flightPlan.legs.map(\.id),
                        sourceData: sourceData
                    ),
                    at: .now,
                    recordingID: UUID(),
                    eventIDs: [UUID(), UUID()], context: context, checklistSelection: selection
                )
                state.installCommittedFlight(transition.flight)
                state.installCockpitContext(transition.cockpitContext)
#if DEBUG
                let workspaceFixture = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_WORKSPACE"]
                if ["C", "A", "A-progress", "A-progress-cues", "A-progress-heading", "A-progress-partial", "A-partial", "B-open-overlap", "B-overlap-choice", "B-multiple-choice", "B-overlap-occurrences", "armed"].contains(workspaceFixture ?? ""), state.routeAmendmentDraft == nil,
                   state.flight?.activatedRouteAmendment == nil {
                    state.prepareAmendmentConfirmationFixture(workspaceFixture: true,
                                                              partialWorkspaceFixture: ["A-partial", "A-progress-partial", "B-open-overlap", "B-overlap-choice", "B-multiple-choice", "B-overlap-occurrences"].contains(workspaceFixture ?? ""),
                                                              overlapWorkspaceFixture: ["B-open-overlap", "B-overlap-choice", "B-multiple-choice", "B-overlap-occurrences"].contains(workspaceFixture ?? ""),
                                                              completedFirstLegFixture: workspaceFixture?.hasPrefix("A-progress") == true,
                                                              overlapChoiceFixture: ["B-overlap-choice", "B-multiple-choice", "B-overlap-occurrences"].contains(workspaceFixture ?? ""),
                                                              multipleOverlapFixture: workspaceFixture == "B-multiple-choice",
                                                              overlapOccurrencesFixture: workspaceFixture == "B-overlap-occurrences")
                    if workspaceFixture == "A-progress-heading",
                       let route = state.routeForAmendment,
                       let legs = state.routeAmendmentDraft?.reviewLegs(on: route), legs.count == 3 {
                        // AP-04 fixture: independent heading-only and duration-only entries.
                        for (index, leg) in legs.enumerated() {
                            state.updateRouteAmendment(.editLeg(leg.id))
                            if index == 1 { state.updateRouteAmendment(.editLegField(.heading, "")) }
                            else { state.updateRouteAmendment(.editLegField(.duration, "")) }
                            state.updateRouteAmendment(.saveLegValues)
                        }
                    }
                    if workspaceFixture == "C", let route = state.routeForAmendment,
                       let leg = state.routeAmendmentDraft?.reviewLegs(on: route).dropFirst().first {
                        state.updateRouteAmendment(.editLeg(leg.id))
                        state.updateRouteAmendment(.editLegField(.duration, ""))
                        state.updateRouteAmendment(.editLegField(.visualReference, "Fixture C · junction"))
                        state.updateRouteAmendment(.toggleCues)
                    }
                    state.updateRouteAmendment(.pause)
                    if workspaceFixture == "armed" { confirmAmendment(startNow: false) }
                }
#endif
                if shouldSimulateRecordingDegradation {
                    try? await recordingCoordinator.recordStorageDegradation(
                        .trackWriteFailed,
                        at: .now,
                        elapsed: .zero,
                        eventID: UUID()
                    )
                }
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

    private func discardAmendmentDraft() {
        guard let id = state.flight?.id else { return }
        guard let draftPersistence else { state.updateRouteAmendment(.discard); return }
        Task {
            if await draftPersistence.discard(flightID: id), state.flight?.id == id {
                state.updateRouteAmendment(.discard)
            }
        }
    }

    private func updateAmendmentDraft(_ intent: RouteAmendmentDraft.Intent) {
        if case .discard = intent, state.replacingPendingAmendmentID == nil {
            discardAmendmentDraft()
            return
        }
        if let id = state.flight?.id, draftPersistence?.statuses[id] == .recoveryFailed {
            presentedError = .init(title: "Amendment draft unavailable",
                                   message: "The saved draft couldn’t be recovered. Its data is preserved. The operational route continues.")
            return
        }
        if let id = state.flight?.id, draftPersistence?.statuses[id] == .deleting {
            if case .pause = intent { state.updateRouteAmendment(.pause) }
            if case .toggleWorkspace = intent, state.isAmendmentWorkspaceVisible { state.updateRouteAmendment(.pause) }
            return
        }
        state.updateRouteAmendment(intent, mode: amendmentMode())
#if DEBUG
        let fixture = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_CONFIRMATION"]
        let rejoinFixture = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_REJOIN"]
        if isOpeningAmendmentWorkspace(intent),
           state.routeAmendmentDraft?.hasContent == false,
           ["1", "2", "3"].contains(fixture ?? "") || rejoinFixture != nil,
           state.flight != nil {
            if state.flight?.activatedRouteAmendment != nil { return }
            state.prepareAmendmentConfirmationFixture(
                includesAdvisoryValues: fixture == "2" || rejoinFixture != nil,
                isFutureDeparture: fixture == "3",
                rejoinFixture: rejoinFixture
            )
        }
#endif
    }

    private func isOpeningAmendmentWorkspace(_ intent: RouteAmendmentDraft.Intent) -> Bool {
        switch intent {
        case .open, .toggleWorkspace: state.isAmendmentWorkspaceVisible
        default: false
        }
    }

    private func canConfirmAmendment(startNow: Bool) -> Bool {
        guard let flight = state.flight, let route = state.routeForAmendment,
              let departure = state.routeAmendmentDraft?.departure else { return false }
        return PendingRouteAmendment.canConfirm(departure, flight: flight, route: route, startNow: startNow)
    }

    private var activatedAmendmentSourceRoute: RouteAmendmentRoute? {
        guard let plan = state.flightPlan, let flight = state.flight,
              let activation = flight.activatedRouteAmendment else { return nil }
        return .init(legs: plan.legs, firstAvailable: activation.amendment.departure,
                     navigationMode: flight.executionMode)
    }

    private func confirmAmendment(startNow: Bool) {
        guard let flight = state.flight, let plan = state.flightPlan, let route = state.routeForAmendment,
              let draft = state.routeAmendmentDraft, let timing = recordingTiming() else { return }
        if state.amendmentSave?.status == .saving { return }
        let operation: CockpitFeatureState.RouteAmendmentSave
        if let retry = state.amendmentSave {
            let canRecaptureTiming = retry.status == .failed(canEdit: true)
                && retry.amendment.startsImmediately != true
            operation = .init(
                amendment: retry.amendment, replacingPendingID: retry.replacingPendingID,
                timestamp: canRecaptureTiming ? timing.now : retry.timestamp,
                elapsed: canRecaptureTiming ? timing.elapsed : retry.elapsed, status: .saving,
                eventIDs: retry.eventIDs, checklistSelection: retry.checklistSelection
            )
        } else {
            do {
                let replacingID = state.replacingPendingAmendmentID
                let amendment = try PendingRouteAmendment(
                    id: UUID(), draft: draft, flight: flight, route: route, startNow: startNow, replacing: replacingID
                )
                operation = .init(
                    amendment: amendment, replacingPendingID: replacingID, timestamp: timing.now, elapsed: timing.elapsed, status: .saving,
                    eventIDs: startNow ? [UUID(), UUID()] : [], checklistSelection: checklistSelection()
                )
            } catch PendingRouteAmendment.Validation.unavailableDeparture {
                state.invalidateAmendmentDeparture()
                return
            } catch {
                presentedError = .init(title: "Amendment could not be confirmed", message: "Review the departure, return point and values for each leg.")
                return
            }
        }
        state.amendmentSave = operation
        let context = state.recordingCockpitContext
        Task {
            do {
                let command: RecordedNavigationCommand
                if let previousID = operation.replacingPendingID {
                    command = .managePendingAmendment(.replace(expectedPendingID: previousID, amendment: operation.amendment),
                        plan: plan, at: operation.timestamp, elapsed: operation.elapsed, eventID: operation.amendment.id)
                } else if operation.amendment.startsImmediately == true {
                    command = .startAmendmentNow(
                        operation.amendment, plan: plan, at: operation.timestamp, elapsed: operation.elapsed,
                        eventIDs: operation.eventIDs
                    )
                } else {
                    command = .confirmPendingAmendment(
                        operation.amendment, plan: plan, at: operation.timestamp, elapsed: operation.elapsed
                    )
                }
                let transition = try await recordingCoordinator.commitNavigation(
                    command, context: context, checklistSelection: operation.checklistSelection
                )
                guard state.amendmentSave?.amendment.id == operation.amendment.id else { return }
                state.installPendingAmendment(transition)
                await draftPersistence?.retire(flightID: flight.id)
                progressionNotice = nil
                if flight.activeLegID != transition.flight.activeLegID
                    || flight.activePartwayDeparture != transition.flight.activePartwayDeparture {
                    endPositionCheck(.activeLegChanged)
                }
            } catch {
                guard state.amendmentSave?.amendment.id == operation.amendment.id else { return }
                if error as? PendingRouteAmendment.Validation == .unavailableDeparture {
                    state.amendmentSave = nil
                    state.invalidateAmendmentDeparture()
                } else {
                    let canEdit = error as? FlightRecordingEngine.EngineError != .routeOutcomeUncertain
                    state.amendmentSave?.status = .failed(canEdit: canEdit)
                }
            }
        }
    }

    private func managePendingAmendment(_ intent: PendingAmendmentManagement.Intent) {
        switch intent {
        case .replace(let pendingID):
            state.openReplacementDraft(pendingID: pendingID)
        case .dismissFailedSave:
            if state.pendingAmendmentManagementSave?.status == .failed(canEdit: true) {
                state.pendingAmendmentManagementSave = nil
            }
        case .retry:
            if let operation = state.pendingAmendmentManagementSave, operation.status != .saving {
                commitPendingAmendmentManagement(operation)
            }
        case .confirm(let confirmation, let restoration):
            guard state.pendingAmendmentManagementSave == nil, let timing = recordingTiming() else { return }
            let change: PendingAmendmentChange
            let destinationName: String?
            switch confirmation {
            case .cancel(let pendingID):
                change = .cancel(expectedPendingID: pendingID)
                destinationName = nil
            case .reportOriginalDestination(let original):
                change = .reportOriginalDestination(original.report, reachEventID: UUID(), automaticEventID: UUID())
                destinationName = original.name
            }
            commitPendingAmendmentManagement(.init(
                change: change, eventID: UUID(), timestamp: timing.now, elapsed: timing.elapsed,
                restoration: restoration, destinationName: destinationName, status: .saving
            ))
        }
    }

    private func commitPendingAmendmentManagement(_ requested: CockpitFeatureState.PendingAmendmentManagementSave) {
        guard let plan = state.flightPlan else { return }
        var operation = requested
        operation.status = .saving
        state.pendingAmendmentManagementSave = operation
        let context = state.recordingCockpitContext
        let currentPartwayDeparture = state.flight?.activePartwayDeparture
        let selection = checklistSelection()
        Task {
            do {
                let transition = try await recordingCoordinator.commitNavigation(.managePendingAmendment(
                    operation.change, plan: plan, at: operation.timestamp, elapsed: operation.elapsed, eventID: operation.eventID
                ), context: context, checklistSelection: selection)
                guard state.pendingAmendmentManagementSave?.eventID == operation.eventID else { return }
                state.pendingAmendmentManagementSave = nil
                switch operation.change {
                case .reportOriginalDestination(_, let reachID, _):
                    state.installCommittedWaypointReach(
                        transition.flight, originalEventID: reachID, cockpitRestoration: operation.restoration, at: operation.timestamp
                    )
                    state.installCockpitContext(transition.cockpitContext)
                    state.clearAmendmentDraft()
                    if let destination = operation.destinationName {
                        progressionNotice = .arrivalReached(
                            waypoint: destination, progressionPolicy: transition.flight.progressionPolicy,
                            hasSuccessor: transition.flight.legState != .completed
                        )
                    }
                case .cancel:
                    state.installPendingAmendment(transition)
                    progressionNotice = nil
                case .replace: break
                }
                if currentPartwayDeparture != nil { endPositionCheck(.activeLegChanged) }
            } catch PendingRouteAmendment.Validation.stalePendingAmendment {
                guard state.pendingAmendmentManagementSave?.eventID == operation.eventID else { return }
                state.pendingAmendmentManagementSave = nil
                presentedError = .init(title: "Amendment changed", message: "Open the pending amendment to see the available actions.")
            } catch {
                guard state.pendingAmendmentManagementSave?.eventID == operation.eventID else { return }
                state.pendingAmendmentManagementSave?.status = .failed(
                    canEdit: error as? FlightRecordingEngine.EngineError != .routeOutcomeUncertain
                )
            }
        }
    }

    private func identifyDestination(targetID: UUID) {
        guard let timing = recordingTiming() else { return }
        let context = state.recordingCockpitContext
        Task {
            do {
                let transition = try await recordingCoordinator.commitNavigation(.identifyDestination(
                    at: timing.now,
                    elapsed: timing.elapsed,
                    eventID: UUID(), targetID: targetID
                ), context: context)
                state.installCommittedDestinationIdentification(transition.flight)
                state.installNavigationGeneration(transition.cockpitContext)
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
        let destination = mapPresentation.destinationTarget
        let isRejoin = state.flight?.awaitsAmendmentRejoin == true
        let isAmendmentDeparture = state.flight?.pendingRouteAmendment?.departure.legID == destination.id.legID
        if isRejoin || isAmendmentDeparture {
            let generation = state.recordingCockpitContext?.navigationGeneration
            if let failedRouteBoundaryReport, failedRouteBoundaryReport.target == destination.id,
               failedRouteBoundaryReport.navigationGeneration == generation {
                commitRouteBoundaryReport(failedRouteBoundaryReport)
                return
            }
            let report = RouteBoundaryReport(command: .reachCurrentWaypoint(
                orderedActiveLegPointKeys: mapPresentation.identificationPoints.map(\.id),
                at: timing.now, elapsed: timing.elapsed, eventIDs: [UUID(), UUID(), UUID()],
                expectedLegID: destination.id.legID, expectedTargetID: destination.id.targetID
            ), checklist: checklistSelection(), target: destination.id, navigationGeneration: generation, isRejoin: isRejoin)
            commitRouteBoundaryReport(report)
            return
        }
        let hasSuccessor = state.flight.map { $0.activeLegIndex + 1 < $0.legIDs.count } ?? false
        let eventIDs = hasSuccessor && state.flight?.progressionPolicy == .manualNextLeg ? [UUID()] : [UUID(), UUID()]
        let selection = checklistSelection()
        let context = state.recordingCockpitContext
        Task {
            do {
                let transition = try await recordingCoordinator.commitNavigation(.reachCurrentWaypoint(
                    orderedActiveLegPointKeys: mapPresentation.identificationPoints.map(\.id),
                    at: timing.now,
                    elapsed: timing.elapsed,
                    eventIDs: eventIDs, expectedLegID: mapPresentation.destinationTarget.id.legID
                ), context: context, checklistSelection: selection)
                state.installCommittedWaypointReach(
                    transition.flight,
                    originalEventID: transition.eventIDs[0],
                    cockpitRestoration: restoration,
                    at: timing.now
                )
                state.installCockpitContext(transition.cockpitContext)
                progressionNotice = .arrivalReached(
                    waypoint: mapPresentation.destinationTarget.name,
                    progressionPolicy: transition.flight.progressionPolicy,
                    hasSuccessor: transition.flight.legState != .completed
                )
            } catch is PendingRouteAmendment.Validation {
                progressionNotice = .rejected(.actionUnavailable)
            } catch {
                if let transitionError = error as? Flight.TransitionError {
                    progressionNotice = progressionRejection(for: transitionError)
                } else if error as? FlightRecordingCoordinator.CoordinationError == .commandInFlight {
                    progressionNotice = .rejected(.actionUnavailable)
                } else {
                    presentNavigationCommitFailure("Reach Waypoint")
                }
            }
        }
    }

    private func commitRouteBoundaryReport(_ report: RouteBoundaryReport) {
        let context = state.recordingCockpitContext
        guard context?.navigationGeneration == report.navigationGeneration else {
            failedRouteBoundaryReport = nil
            progressionNotice = .rejected(.actionUnavailable)
            return
        }
        Task {
            do {
                let transition = try await recordingCoordinator.commitNavigation(
                    report.command, context: context, checklistSelection: report.checklist
                )
                if report.isRejoin {
                    state.installCommittedFlight(transition.flight)
                    state.installCockpitContext(transition.cockpitContext)
                } else {
                    state.installPendingAmendment(transition)
                }
                failedRouteBoundaryReport = nil
                progressionNotice = nil
            } catch is PendingRouteAmendment.Validation {
                progressionNotice = .rejected(.actionUnavailable)
            } catch {
                failedRouteBoundaryReport = report
                isRouteBoundaryOutcomeUncertain = error as? FlightRecordingEngine.EngineError == .routeOutcomeUncertain
                isRouteBoundaryFailurePresented = true
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
        let context = state.recordingCockpitContext
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
                ), context: context)
                try state.installCommittedIdentificationPointReach(
                    transition.flight,
                    originalEventID: transition.eventIDs[0],
                    key: key,
                    mapPresentation: mapPresentation,
                    cockpitRestoration: restoration,
                    at: timing.now
                )
                state.installNavigationGeneration(transition.cockpitContext)
            } catch {
                presentNavigationCommitFailure("Reach Identification Point")
            }
        }
    }

    private func commitPilotETA(_ target: NavigationTimingTargetKey) {
        guard let timing = recordingTiming(),
              let draft = state.flight?.pilotETAState(targetKey: target)?.draftSeconds else { return }
        let context = state.recordingCockpitContext
        Task {
            do {
                let transition = try await recordingCoordinator.commitNavigation(.reviseETA(
                    target: target,
                    plannedElapsedSeconds: draft,
                    committedSeconds: draft,
                    at: timing.now,
                    elapsed: timing.elapsed,
                    eventID: UUID()
                ), context: context)
                state.installCommittedFlight(transition.flight)
                state.installNavigationGeneration(transition.cockpitContext)
            } catch {
                presentNavigationCommitFailure("Revise ETA")
            }
        }
    }

    private func commitPilotHeading() {
        guard let timing = recordingTiming(),
              let flight = state.flight else { return }
        let legID = flight.legIDs[flight.activeLegIndex]
        guard let heading = flight.pilotHeadingState(for: legID) else { return }
        let context = state.recordingCockpitContext
        Task {
            do {
                let transition = try await recordingCoordinator.commitNavigation(.reviseHeading(
                    legID: legID,
                    baselineDegrees: heading.baselineDegrees,
                    committedDegrees: heading.draftDegrees,
                    at: timing.now,
                    elapsed: timing.elapsed,
                    eventID: UUID()
                ), context: context)
                state.installCommittedFlight(transition.flight)
                state.installNavigationGeneration(transition.cockpitContext)
            } catch {
                presentNavigationCommitFailure("Revise Heading")
            }
        }
    }

    private func undoMostRecentReach(at timestamp: Date) async -> CockpitRestoration? {
        guard let undo = state.availableReachUndo(at: timestamp),
              let originalEventID = undo.originalEventID,
              let timing = recordingTiming() else {
            progressionNotice = .rejected(.undoExpired)
            return nil
        }
        do {
            let transition = try await recordingCoordinator.commitNavigation(.undoReach(
                originalEventID: originalEventID,
                restoredFlight: undo.flight,
                at: timing.now,
                elapsed: timing.elapsed,
                eventID: UUID()
            ), context: RecordingCockpitContext(flightID: undo.flight.id, checklists: undo.legStartChecklists, areDriftLinesVisible: state.areDriftLinesVisible))
            let restoration = state.undoMostRecentReach(at: timestamp)
            state.installNavigationGeneration(transition.cockpitContext)
            progressionNotice = nil
            return restoration
        } catch {
            presentNavigationCommitFailure("Undo Reach")
            return nil
        }
    }

    private func progressionRejection(
        for error: Flight.TransitionError
    ) -> CockpitProgressionNotice {
        switch error {
        case .waypointAlreadyReached, .identificationPointAlreadyReached:
            .rejected(.alreadyReportedReached)
        case .timestampPrecedesStart:
            .rejected(.invalidTimestamp)
        default:
            .rejected(.actionUnavailable)
        }
    }

    private func recordPositionCheckRequest() async throws {
        guard let timing = recordingTiming() else { return }
        _ = try await recordingCoordinator.commitNavigation(.requestPositionCheck(
            at: timing.now,
            elapsed: timing.elapsed,
            eventID: UUID()
        ))
    }

    private func recordPositionCheckEnd(sample: PositionCheckRecordedSample?) {
        guard let timing = recordingTiming() else { return }
        Task {
            _ = try? await recordingCoordinator.commitNavigation(.endPositionCheck(
                outcome: sample.map(PositionCheckRecordedOutcome.disclosed) ?? .endedWithoutDisclosure,
                at: timing.now,
                elapsed: timing.elapsed,
                eventID: UUID()
            ))
        }
    }

    private func recordPositionCheckRestart(sample: PositionCheckRecordedSample) async throws {
        guard let timing = recordingTiming() else { return }
        _ = try await recordingCoordinator.commitNavigation(.endPositionCheck(
            outcome: .disclosed(sample: sample),
            at: timing.now,
            elapsed: timing.elapsed,
            eventID: UUID()
        ))
        do {
            _ = try await recordingCoordinator.commitNavigation(.requestPositionCheck(
                at: timing.now,
                elapsed: timing.elapsed,
                eventID: UUID()
            ))
        } catch {
            suppressNextPositionCheckEndRecording = true
            positionCheckCoordinator.send(.end)
            throw error
        }
    }

    private func endPositionCheck(_ intent: PositionCheckIntent) {
        positionCheckCoordinator.send(intent)
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
            cockpitPresented: true,
            hasFlight: state.flight != nil,
            sceneActive: scenePhase == .active
        )
    }

    private func handlePositionCheckAction(
        _ action: PositionCheckControlAction,
        restoration: CockpitRestoration
    ) async {
        switch action {
        case .holdCompleted:
            let activeSession = positionCheckCoordinator.state.activeSession
            do {
                if let activeSession {
                    try await recordPositionCheckRestart(sample: PositionCheckRecordedSample(
                        coordinate: activeSession.projection.coordinate,
                        observedAt: activeSession.projection.observedAt,
                        horizontalAccuracyMeters: activeSession.projection.horizontalAccuracyMeters
                    ))
                } else {
                    try await recordPositionCheckRequest()
                }
            } catch {
                presentNavigationCommitFailure(activeSession == nil ? "Start Position Check" : "Restart Position Check")
                return
            }
            let intent: PositionCheckIntent = activeSession == nil
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
        "\(flight.id.uuidString):\(flight.activeLegID.uuidString)"
    }
}

private struct PresentedError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
