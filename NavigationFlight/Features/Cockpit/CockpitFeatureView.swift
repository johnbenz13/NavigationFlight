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
    private let loader = FPLNavFileLoader()
    private let adapter = CockpitPresentationAdapter()
    private let presentationRequestID: UUID?
    private let locationService: AircraftLocationService
    private let isSectionSelected: Bool
    private let onIntent: (CockpitFeatureIntent) -> Void

    init(
        state: Binding<CockpitFeatureState>,
        presentationRequestID: UUID? = nil,
        locationService: AircraftLocationService,
        positionCheckTiming: PositionCheckTiming = .standard,
        isSectionSelected: Bool,
        onIntent: @escaping (CockpitFeatureIntent) -> Void
    ) {
        _state = state
        self.presentationRequestID = presentationRequestID
        self.locationService = locationService
        _positionCheckCoordinator = State(initialValue: PositionCheckCoordinator(timing: positionCheckTiming))
        self.isSectionSelected = isSectionSelected
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
                        pendingReachUndo: state.pendingReachUndo,
                        positionCheck: positionCheck,
                        positionCheckMapRestoration: positionCheckCoordinator.pendingMapRestoration,
                        onPositionCheckMapRestored: positionCheckCoordinator.acknowledgeMapRestoration,
                        onPositionCheckAction: handlePositionCheckAction,
                        onStartLeg: startLeg,
                        onIdentifyDestination: { try? state.identifyDestination(at: .now) },
                        onWaypointReached: { restoration in
                            try? state.reachCurrentWaypoint(cockpitRestoration: restoration, at: .now)
                        },
                        onIdentificationPointReached: { pointID, mapPresentation, restoration in
                            try state.reachIdentificationPoint(
                                key: pointID,
                                mapPresentation: mapPresentation,
                                cockpitRestoration: restoration,
                                at: .now
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
        do {
            try state.startLeg(at: .now)
        } catch {
            presentedError = .init(title: "Couldn’t Start Leg", message: error.localizedDescription)
        }
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

private struct PresentedError: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
