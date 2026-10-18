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

    let progressionPolicy: FlightSession.ProgressionPolicy
    private(set) var flight: NavigationFlight?
    private(set) var selectedLegIndex = 0
    private(set) var mode = NavigationMode.noWind
    private(set) var session: FlightSession?
    private(set) var legStartChecklists: [UUID: LegStartChecklistState] = [:]

    init(progressionPolicy: FlightSession.ProgressionPolicy = .automaticNextLeg) {
        self.progressionPolicy = progressionPolicy
    }

    var canSelectPreviousLeg: Bool {
        session?.legState == .ready && session?.legTimings.isEmpty == true && selectedLegIndex > 0
    }
    var canSelectNextLeg: Bool {
        guard session?.legState == .ready,
              session?.legTimings.isEmpty == true,
              case .eligible(let execution)? = flight?.execution else { return false }
        return selectedLegIndex + 1 < execution.legs.count
    }

    var activeLegStartChecklist: LegStartChecklistState? {
        guard let session, session.legState == .active else { return nil }
        return legStartChecklists[session.legIDs[session.activeLegIndex]]
    }

    mutating func accept(_ candidate: NavigationFlight) throws {
        switch candidate.execution {
        case .unavailableLegacyFormat(let version):
            throw CockpitPlanError.legacyPlan(version: version)
        case .emptyPlan:
            throw CockpitPlanError.emptyPlan
        case .eligible(let execution):
            guard !execution.legs.isEmpty else { throw CockpitPlanError.emptyPlan }
            flight = candidate
            selectedLegIndex = 0
            mode = execution.defaultMode
            session = FlightSession(
                flightID: candidate.id,
                legIDs: candidate.legs.map(\.id),
                activeLegIndex: selectedLegIndex,
                executionMode: mode,
                progressionPolicy: progressionPolicy
            )
            legStartChecklists = [:]
        }
    }

    mutating func selectPreviousLeg() {
        guard canSelectPreviousLeg else { return }
        let candidate = selectedLegIndex - 1
        guard (try? session?.selectReadyLeg(index: candidate, mode: mode)) != nil else { return }
        selectedLegIndex = candidate
    }

    mutating func selectNextLeg() {
        guard canSelectNextLeg else { return }
        let candidate = selectedLegIndex + 1
        guard (try? session?.selectReadyLeg(index: candidate, mode: mode)) != nil else { return }
        selectedLegIndex = candidate
    }

    mutating func selectMode(_ newMode: NavigationMode) {
        guard session?.legState == .ready,
              let flight, case .eligible(let execution) = flight.execution else { return }
        if newMode == .wind && !execution.legs.allSatisfy({ $0.withWind != nil }) { return }
        mode = newMode
        try? session?.selectReadyLeg(index: selectedLegIndex, mode: mode)
    }

    mutating func startLeg(at timestamp: Date = .now) throws {
        try session?.startLeg(at: timestamp)
        createPendingLegStartChecklistForActiveLeg()
    }

    mutating func reachCurrentWaypoint(at timestamp: Date = .now) throws {
        let departingLegID = activeLegStartChecklist?.legID
        try session?.reachCurrentWaypoint(at: timestamp)
        if let departingLegID {
            hideLegStartChecklist(for: departingLegID)
        }
        if let activeLegIndex = session?.activeLegIndex {
            selectedLegIndex = activeLegIndex
        }
        if session?.legState == .active {
            createPendingLegStartChecklistForActiveLeg()
        }
    }

    mutating func identifyDestination(at timestamp: Date = .now) throws {
        try session?.identifyDestination(at: timestamp)
        hideActiveLegStartChecklistForPhase()
    }

    mutating func reachIdentificationPoint(
        id: UUID,
        nextTarget: AviationMapETATarget?,
        at timestamp: Date = .now
    ) throws {
        try session?.reachIdentificationPoint(id: id, at: timestamp)
        if let nextTarget {
            session?.initializePilotETA(
                targetID: nextTarget.id,
                plannedElapsedSeconds: nextTarget.plannedElapsedSeconds
            )
        }
    }

    mutating func adjustPilotETA(targetID: UUID, by deltaSeconds: Int) {
        session?.adjustPilotETA(targetID: targetID, by: deltaSeconds)
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
        guard let session, session.legState == .active else { return }
        let legID = session.legIDs[session.activeLegIndex]
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
        guard let session, session.legState == .active else { return }
        let legID = session.legIDs[session.activeLegIndex]
        guard var checklist = legStartChecklists[legID] else { return }
        update(&checklist)
        legStartChecklists[legID] = checklist
    }
}

struct FPLNavFileLoader: Sendable {
    func load(_ url: URL) throws -> NavigationFlight {
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
