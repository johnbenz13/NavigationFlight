import Foundation

enum CockpitPlanError: Error, Equatable, Sendable, LocalizedError {
    case legacyPlan(version: Int)
    case emptyPlan
    case unsupportedVersion(Int)
    case malformedPlan(String)
    case fileAccess

    var errorDescription: String? {
        switch self {
        case .legacyPlan:
            "This plan has no saved execution data. Open and resave it in Navigation Editor, then try again."
        case .emptyPlan:
            "This plan has no route legs. Add a route in Navigation Editor and resave it."
        case .unsupportedVersion(let version):
            "Format version \(version) isn’t supported. Resave the plan with the current Navigation Editor."
        case .malformedPlan(let detail):
            "The plan is malformed or incomplete. \(detail)"
        case .fileAccess:
            "Navigation Flight couldn’t access the selected file. Check its location and permissions, then try again."
        }
    }
}

struct CockpitFeatureState: Equatable, Sendable {
    struct PendingReachUndo: Equatable, Sendable {
        enum Kind: Equatable, Sendable {
            case identificationPoint(String)
            case destination(legNumber: Int, isFinalLeg: Bool)

            var label: String {
                switch self {
                case .identificationPoint(let name): "\(name) reached"
                case .destination(let legNumber, let isFinalLeg):
                    isFinalLeg ? "Final arrival reached" : "Leg \(legNumber) arrival reached"
                }
            }
        }

        let kind: Kind
        let expiresAt: Date
        let flight: Flight
        let legStartChecklists: [UUID: LegStartChecklistState]
        let selectedLegIndex: Int
        let cockpitRestoration: CockpitRestoration
        var originalEventID: UUID? = nil
    }

    struct LegStartChecklistState: Equatable, Sendable {
        enum ReviewState: Equatable, Sendable {
            case pending
            case noted
        }

        enum PresentationState: Equatable, Sendable {
            case expanded
            case collapsed
        }

        enum PhaseState: Equatable, Sendable {
            case available
            case hiddenForPhase
        }

        let legID: UUID
        var reviewState: ReviewState
        var presentationState: PresentationState
        var phaseState: PhaseState
    }

    let progressionPolicy: Flight.ProgressionPolicy
    private(set) var flightPlan: FlightPlan?
    private(set) var selectedLegIndex = 0
    private(set) var mode = NavigationMode.noWind
    private(set) var flight: Flight?
    private(set) var flightPlanSourceData: Data?
    private(set) var legStartChecklists: [UUID: LegStartChecklistState] = [:]
    private(set) var areDriftLinesVisible = true
    private(set) var pendingReachUndo: PendingReachUndo?

    init(progressionPolicy: Flight.ProgressionPolicy = .automaticNextLeg) {
        self.progressionPolicy = progressionPolicy
    }

    var canSelectPreviousLeg: Bool {
        flight?.legState == .ready && flight?.legTimings.isEmpty == true && selectedLegIndex > 0
    }
    var canSelectNextLeg: Bool {
        guard flight?.legState == .ready,
              flight?.legTimings.isEmpty == true,
              case .eligible(let plannedNavigation)? = flightPlan?.plannedNavigation else { return false }
        return selectedLegIndex + 1 < plannedNavigation.legs.count
    }

    var hasChecklistAcknowledgements: Bool {
        legStartChecklists.values.contains { $0.reviewState == .noted }
    }

    var hasProtectedPilotWork: Bool {
        flight?.hasProtectedPilotWork == true || hasChecklistAcknowledgements
    }

    var isAcceptedFlightInProgress: Bool {
        guard let flight else { return false }
        return flight.legState == .ready || flight.legState == .active
    }

    var activeLegStartChecklist: LegStartChecklistState? {
        guard let flight, flight.legState == .active else { return nil }
        return legStartChecklists[flight.legIDs[flight.activeLegIndex]]
    }

    mutating func accept(
        _ flightPlan: FlightPlan,
        flightID: UUID = UUID(),
        sourceData: Data? = nil
    ) throws {
        switch flightPlan.plannedNavigation {
        case .unavailableLegacyFormat(let version):
            throw CockpitPlanError.legacyPlan(version: version)
        case .emptyPlan:
            throw CockpitPlanError.emptyPlan
        case .eligible(let plannedNavigation):
            guard !plannedNavigation.legs.isEmpty else { throw CockpitPlanError.emptyPlan }
            self.flightPlan = flightPlan
            flightPlanSourceData = sourceData
            selectedLegIndex = 0
            mode = plannedNavigation.defaultMode
            flight = Flight(
                id: flightID,
                flightPlanID: flightPlan.id,
                legIDs: flightPlan.legs.map(\.id),
                activeLegIndex: selectedLegIndex,
                executionMode: mode,
                progressionPolicy: progressionPolicy
            )
            legStartChecklists = [:]
            areDriftLinesVisible = true
            pendingReachUndo = nil
        }
    }

    mutating func restore(
        flightPlan: FlightPlan,
        flight: Flight,
        sourceData: Data?
    ) {
        precondition(flight.flightPlanID == flightPlan.id)
        precondition(flight.legIDs == flightPlan.legs.map(\.id))
        self.flightPlan = flightPlan
        flightPlanSourceData = sourceData
        selectedLegIndex = flight.activeLegIndex
        mode = flight.executionMode
        self.flight = flight
        legStartChecklists = [:]
        areDriftLinesVisible = true
        pendingReachUndo = nil
    }

    mutating func toggleDriftLines() {
        areDriftLinesVisible.toggle()
    }

    mutating func selectPreviousLeg() {
        guard canSelectPreviousLeg else { return }
        let candidate = selectedLegIndex - 1
        guard (try? flight?.selectReadyLeg(index: candidate, mode: mode)) != nil else { return }
        selectedLegIndex = candidate
    }

    mutating func selectNextLeg() {
        guard canSelectNextLeg else { return }
        let candidate = selectedLegIndex + 1
        guard (try? flight?.selectReadyLeg(index: candidate, mode: mode)) != nil else { return }
        selectedLegIndex = candidate
    }

    mutating func selectMode(_ newMode: NavigationMode) {
        guard flight?.legState == .ready,
              let flightPlan, case .eligible(let plannedNavigation) = flightPlan.plannedNavigation else { return }
        if newMode == .wind && !plannedNavigation.legs.allSatisfy({ $0.withWind != nil }) { return }
        mode = newMode
        try? flight?.selectReadyLeg(index: selectedLegIndex, mode: mode)
    }

    mutating func startLeg(at timestamp: Date = .now) throws {
        guard var nextFlight = flight else {
            throw Flight.TransitionError.legNotReady
        }
        try nextFlight.startLeg(at: timestamp)
        flight = nextFlight
        createPendingLegStartChecklistForActiveLeg()
        pendingReachUndo = nil
    }

    mutating func installCommittedFlight(_ committedFlight: Flight) {
        guard let flightPlan,
              committedFlight.id == flight?.id,
              committedFlight.flightPlanID == flightPlan.id else { return }
        flight = committedFlight
        selectedLegIndex = committedFlight.activeLegIndex
        createPendingLegStartChecklistForActiveLeg()
        pendingReachUndo = nil
    }

    mutating func installCommittedDestinationIdentification(_ committedFlight: Flight) {
        installCommittedFlight(committedFlight)
        hideActiveLegStartChecklistForPhase()
    }

    mutating func installCommittedWaypointReach(
        _ committedFlight: Flight,
        originalEventID: UUID,
        cockpitRestoration: CockpitRestoration,
        at timestamp: Date
    ) {
        guard let restorationFlight = flight else { return }
        let restorationChecklists = legStartChecklists
        let restorationLegIndex = selectedLegIndex
        let departingLegID = activeLegStartChecklist?.legID
        installCommittedFlight(committedFlight)
        if let departingLegID { hideLegStartChecklist(for: departingLegID) }
        selectedLegIndex = committedFlight.activeLegIndex
        if committedFlight.legState == .active { createPendingLegStartChecklistForActiveLeg() }
        pendingReachUndo = PendingReachUndo(
            kind: .destination(
                legNumber: restorationLegIndex + 1,
                isFinalLeg: restorationLegIndex == committedFlight.legIDs.count - 1
            ),
            expiresAt: timestamp.addingTimeInterval(20),
            flight: restorationFlight,
            legStartChecklists: restorationChecklists,
            selectedLegIndex: restorationLegIndex,
            cockpitRestoration: cockpitRestoration,
            originalEventID: originalEventID
        )
    }

    mutating func installCommittedIdentificationPointReach(
        _ committedFlight: Flight,
        originalEventID: UUID,
        key: IdentificationPointKey,
        mapPresentation: AviationMapPresentation,
        cockpitRestoration: CockpitRestoration,
        at timestamp: Date
    ) throws {
        guard let restorationFlight = flight,
              let point = mapPresentation.identificationPoints.first(where: { $0.id == key }) else {
            throw Flight.TransitionError.invalidIdentificationPointOrder
        }
        let restorationChecklists = legStartChecklists
        let restorationLegIndex = selectedLegIndex
        installCommittedFlight(committedFlight)
        pendingReachUndo = PendingReachUndo(
            kind: .identificationPoint(point.name),
            expiresAt: timestamp.addingTimeInterval(20),
            flight: restorationFlight,
            legStartChecklists: restorationChecklists,
            selectedLegIndex: restorationLegIndex,
            cockpitRestoration: cockpitRestoration,
            originalEventID: originalEventID
        )
    }

    mutating func reachCurrentWaypoint(
        cockpitRestoration: CockpitRestoration,
        at timestamp: Date = .now
    ) throws {
        guard let flightPlan, var nextFlight = flight else {
            throw Flight.TransitionError.legNotActive
        }
        let mapPresentation = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: nextFlight
        )
        let departingLegID = activeLegStartChecklist?.legID
        let restorationFlight = nextFlight
        let restorationChecklists = legStartChecklists
        let restorationLegIndex = selectedLegIndex
        try nextFlight.reachCurrentWaypoint(
            orderedActiveLegPointKeys: mapPresentation.identificationPoints.map(\.id),
            at: timestamp
        )
        flight = nextFlight
        if let departingLegID {
            hideLegStartChecklist(for: departingLegID)
        }
        if let activeLegIndex = flight?.activeLegIndex {
            selectedLegIndex = activeLegIndex
        }
        if flight?.legState == .active {
            createPendingLegStartChecklistForActiveLeg()
        }
        pendingReachUndo = PendingReachUndo(
            kind: .destination(
                legNumber: restorationLegIndex + 1,
                isFinalLeg: restorationLegIndex == nextFlight.legIDs.count - 1
            ),
            expiresAt: timestamp.addingTimeInterval(20),
            flight: restorationFlight,
            legStartChecklists: restorationChecklists,
            selectedLegIndex: restorationLegIndex,
            cockpitRestoration: cockpitRestoration
        )
    }

    mutating func reachCurrentWaypoint(at timestamp: Date = .now) throws {
        try reachCurrentWaypoint(cockpitRestoration: .empty, at: timestamp)
    }

    mutating func identifyDestination(at timestamp: Date = .now) throws {
        guard var nextFlight = flight else { throw Flight.TransitionError.legNotActive }
        try nextFlight.identifyDestination(at: timestamp)
        flight = nextFlight
        hideActiveLegStartChecklistForPhase()
        pendingReachUndo = nil
    }

    mutating func reachIdentificationPoint(
        key: IdentificationPointKey,
        mapPresentation: AviationMapPresentation,
        cockpitRestoration: CockpitRestoration = .empty,
        at timestamp: Date = .now
    ) throws {
        guard var nextFlight = flight else {
            throw Flight.TransitionError.legNotActive
        }
        let orderedPoints = mapPresentation.identificationPoints
        let restorationFlight = nextFlight
        let restorationChecklists = legStartChecklists
        let restorationLegIndex = selectedLegIndex
        try nextFlight.reachIdentificationPoint(
            key: key,
            orderedActiveLegPointKeys: orderedPoints.map(\.id),
            at: timestamp
        )
        guard let selectedIndex = orderedPoints.firstIndex(where: { $0.id == key }) else {
            throw Flight.TransitionError.invalidIdentificationPointOrder
        }
        let nextTarget = orderedPoints[(selectedIndex + 1)...]
            .first(where: { nextFlight.identificationPointState(for: $0.id) == .future })
            .map { point in
                AviationMapETATarget(
                    id: NavigationTimingTargetKey(
                        legID: point.id.legID,
                        kind: .identificationPoint,
                        targetID: point.id.identificationPointID
                    ),
                    name: point.name,
                    plannedElapsedSeconds: point.plannedElapsedSeconds,
                    committedETASeconds: point.committedETASeconds
                )
            } ?? mapPresentation.destinationTarget
        nextFlight.initializePilotETA(
            targetKey: nextTarget.id,
            plannedElapsedSeconds: nextTarget.plannedElapsedSeconds
        )
        flight = nextFlight
        let name = orderedPoints[selectedIndex].name
        pendingReachUndo = PendingReachUndo(
            kind: .identificationPoint(name),
            expiresAt: timestamp.addingTimeInterval(20),
            flight: restorationFlight,
            legStartChecklists: restorationChecklists,
            selectedLegIndex: restorationLegIndex,
            cockpitRestoration: cockpitRestoration
        )
    }

    func availableReachUndo(at now: Date) -> PendingReachUndo? {
        guard let pendingReachUndo, now < pendingReachUndo.expiresAt else { return nil }
        return pendingReachUndo
    }

    mutating func undoMostRecentReach(at now: Date = .now) -> CockpitRestoration? {
        guard let undo = availableReachUndo(at: now) else { return nil }
        flight = undo.flight
        legStartChecklists = undo.legStartChecklists
        selectedLegIndex = undo.selectedLegIndex
        pendingReachUndo = nil
        return undo.cockpitRestoration
    }

    mutating func openPilotETAEditor(target: AviationMapETATarget) {
        let elapsedSeconds = currentLegElapsedSeconds()
        flight?.initializePilotETA(
            targetKey: target.id,
            plannedElapsedSeconds: target.plannedElapsedSeconds,
            currentElapsedSeconds: elapsedSeconds
        )
    }

    mutating func adjustPilotETA(targetKey: NavigationTimingTargetKey, by deltaSeconds: Int) {
        let elapsedSeconds = currentLegElapsedSeconds()
        flight?.adjustPilotETA(
            targetKey: targetKey,
            by: deltaSeconds,
            currentElapsedSeconds: elapsedSeconds
        )
    }

    mutating func commitPilotETA(targetKey: NavigationTimingTargetKey) {
        let elapsedSeconds = currentLegElapsedSeconds()
        let previousSession = flight
        flight?.commitPilotETA(
            targetKey: targetKey,
            currentElapsedSeconds: elapsedSeconds
        )
        if flight != previousSession { pendingReachUndo = nil }
    }

    mutating func beginEditingPilotETA(targetKey: NavigationTimingTargetKey) {
        let elapsedSeconds = currentLegElapsedSeconds()
        flight?.beginEditingPilotETA(
            targetKey: targetKey,
            currentElapsedSeconds: elapsedSeconds
        )
    }

    mutating func cancelPilotETAEditing(targetKey: NavigationTimingTargetKey) {
        flight?.cancelPilotETAEditing(targetKey: targetKey)
    }

    mutating func showPilotETACheck(
        targetKey: NavigationTimingTargetKey,
        mapPresentation: AviationMapPresentation
    ) {
        guard var nextFlight = flight,
              let target = mapPresentation.timingTarget(for: targetKey),
              let observationKey = nextFlight.latestEligibleTimingObservation(
                before: targetKey,
                orderedPointKeys: mapPresentation.identificationPoints.map(\.id)
              ),
              let observation = mapPresentation.identificationPoints.first(where: { $0.id == observationKey }),
              let actual = nextFlight.actualLegElapsedDuration(atIdentificationPoint: observation.id),
              nextFlight.showPilotETACheck(
                targetKey: targetKey,
                observationKey: observation.id,
                plannedObservationElapsed: TimeInterval(observation.plannedElapsedSeconds),
                actualObservationElapsed: actual,
                plannedTargetElapsed: TimeInterval(target.plannedElapsedSeconds)
              ) else { return }
        flight = nextFlight
    }

    mutating func hidePilotETACheck(targetKey: NavigationTimingTargetKey) {
        flight?.hidePilotETACheck(targetKey: targetKey)
    }

    mutating func openPilotHeadingEditor(baselineDegrees: Int) {
        flight?.openPilotHeadingEditor(baselineDegrees: baselineDegrees)
    }

    mutating func adjustPilotHeading(by deltaDegrees: Int) {
        flight?.adjustPilotHeading(by: deltaDegrees)
    }

    mutating func commitPilotHeading() {
        let previousSession = flight
        flight?.commitPilotHeading()
        if flight != previousSession { pendingReachUndo = nil }
    }

    mutating func cancelPilotHeadingEditing() {
        flight?.cancelPilotHeadingEditing()
    }

    private func currentLegElapsedSeconds(at timestamp: Date = .now) -> Int {
        flight?.elapsedTime(at: timestamp).map(IdentificationPointTimingCalculator.displaySeconds) ?? 0
    }

    mutating func cancelImport() {
        // Intentionally preserve the loaded plan, selected leg, and calculation mode.
    }

    mutating func collapseLegStartChecklist() {
        updateActiveChecklist { $0.presentationState = .collapsed }
    }

    mutating func reopenLegStartChecklist() {
        updateActiveChecklist {
            guard $0.phaseState == .available else { return }
            $0.presentationState = .expanded
        }
    }

    mutating func noteLegStartChecklist() {
        updateActiveChecklist {
            $0.reviewState = .noted
            $0.presentationState = .collapsed
        }
    }

    private mutating func hideActiveLegStartChecklistForPhase() {
        updateActiveChecklist { $0.phaseState = .hiddenForPhase }
    }

    private mutating func hideLegStartChecklist(for legID: UUID) {
        guard var checklist = legStartChecklists[legID] else { return }
        checklist.phaseState = .hiddenForPhase
        legStartChecklists[legID] = checklist
    }

    private mutating func createPendingLegStartChecklistForActiveLeg() {
        guard let flight, flight.legState == .active else { return }
        let legID = flight.legIDs[flight.activeLegIndex]
        guard legStartChecklists[legID] == nil else { return }
        legStartChecklists[legID] = LegStartChecklistState(
            legID: legID,
            reviewState: .pending,
            presentationState: .expanded,
            phaseState: .available
        )
    }

    private mutating func updateActiveChecklist(
        _ update: (inout LegStartChecklistState) -> Void
    ) {
        guard let flight, flight.legState == .active else { return }
        let legID = flight.legIDs[flight.activeLegIndex]
        guard var checklist = legStartChecklists[legID] else { return }
        update(&checklist)
        legStartChecklists[legID] = checklist
    }
}

struct FPLNavFileLoader: Sendable {
    func load(_ url: URL) throws -> FlightPlan {
        guard url.pathExtension.lowercased() == "fplnav" else {
            throw CockpitPlanError.malformedPlan("Select a file with the .fplnav extension.")
        }
        let accessed = url.startAccessingSecurityScopedResource()
        defer { if accessed { url.stopAccessingSecurityScopedResource() } }
        do {
            return try FPLNavDecoder().decode(Data(contentsOf: url, options: .mappedIfSafe))
        } catch let error as CockpitPlanError {
            throw error
        } catch let error as FPLNavDecoderError {
            throw map(error)
        } catch {
            throw CockpitPlanError.fileAccess
        }
    }

    private func map(_ error: FPLNavDecoderError) -> CockpitPlanError {
        switch error {
        case .unsupportedFormatVersion(let version):
            .unsupportedVersion(version)
        case .invalidMetadata:
            .malformedPlan("The file doesn’t contain valid format metadata.")
        case .invalidV7Execution(let issue):
            .malformedPlan("\(issue.path): \(issue.reason).")
        case .invalidV5Document(let detail), .invalidV7Document(let detail):
            .malformedPlan(detail)
        case .mapping(let issue):
            .malformedPlan(String(describing: issue))
        }
    }
}
