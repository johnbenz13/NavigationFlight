import Foundation

struct AppFeatureState: Equatable, Sendable {
    enum AppSection: Hashable, Sendable {
        case cockpit
        case flightPlans
        case settings
    }

    private(set) var selectedAppSection: AppSection
    private(set) var cockpit: CockpitFeatureState
    private(set) var flightPlans: FlightPlansFeatureState
    private(set) var pendingFlightChange: PendingFlightChange?

    init(
        selectedAppSection: AppSection = .flightPlans,
        cockpit: CockpitFeatureState = CockpitFeatureState(),
        flightPlans: FlightPlansFeatureState = FlightPlansFeatureState(),
        pendingFlightChange: PendingFlightChange? = nil
    ) {
        self.selectedAppSection = selectedAppSection
        self.cockpit = cockpit
        self.flightPlans = flightPlans
        self.pendingFlightChange = pendingFlightChange
    }

    mutating func selectAppSection(_ section: AppSection) {
        selectedAppSection = section
    }

    mutating func handleCockpitIntent(_ intent: CockpitFeatureIntent) {
        switch intent {
        case .chooseFlightPlan:
            selectAppSection(.flightPlans)
        }
    }

    mutating func updateCockpit(_ cockpit: CockpitFeatureState) {
        self.cockpit = cockpit
    }

    mutating func loadFlightPlan(
        _ snapshot: LibraryFlightPlan,
        flightID: UUID,
        pendingID: UUID = UUID()
    ) throws -> LoadFlightPlanDecision {
        try requestFlightChange(
            snapshot: snapshot.flightPlan,
            kind: .load,
            flightID: flightID,
            pendingID: pendingID
        )
    }

    mutating func loadUpdatedFlightPlan(
        _ snapshot: LibraryFlightPlan,
        flightID: UUID,
        pendingID: UUID = UUID()
    ) throws -> LoadFlightPlanDecision {
        try loadFlightPlan(snapshot, flightID: flightID, pendingID: pendingID)
    }

    mutating func restartFlight(
        flightID: UUID,
        pendingID: UUID = UUID()
    ) throws -> LoadFlightPlanDecision {
        guard let snapshot = cockpit.flightPlan else {
            throw AppFeatureError.noLoadedFlightPlan
        }
        return try requestFlightChange(
            snapshot: snapshot,
            kind: .restart,
            flightID: flightID,
            pendingID: pendingID
        )
    }

    mutating func returnToCockpit() {
        selectedAppSection = .cockpit
    }

    @discardableResult
    mutating func cancelPendingFlightChange(id: UUID) -> Bool {
        guard pendingFlightChange?.id == id else { return false }
        pendingFlightChange = nil
        return true
    }

    @discardableResult
    mutating func confirmPendingFlightChange(id: UUID) -> Bool {
        guard let pendingFlightChange, pendingFlightChange.id == id else {
            return false
        }
        cockpit = pendingFlightChange.candidateCockpit
        selectedAppSection = .cockpit
        self.pendingFlightChange = nil
        return true
    }

    private mutating func requestFlightChange(
        snapshot: FlightPlan,
        kind: PendingFlightChange.Kind,
        flightID: UUID,
        pendingID: UUID
    ) throws -> LoadFlightPlanDecision {
        var candidate = CockpitFeatureState(progressionPolicy: cockpit.progressionPolicy)
        try candidate.accept(snapshot, flightID: flightID)

        guard cockpit.hasProtectedPilotWork else {
            cockpit = candidate
            selectedAppSection = .cockpit
            pendingFlightChange = nil
            return .loaded
        }

        let pending = PendingFlightChange(
            id: pendingID,
            kind: kind,
            candidateCockpit: candidate
        )
        pendingFlightChange = pending
        return .confirmationRequired(pending)
    }
}

enum CockpitFeatureIntent: Equatable, Sendable {
    case chooseFlightPlan
}

enum AppFeatureError: Error, Equatable, Sendable {
    case noLoadedFlightPlan
}

enum LoadFlightPlanDecision: Equatable, Sendable {
    case loaded
    case confirmationRequired(PendingFlightChange)
}

struct PendingFlightChange: Equatable, Sendable, Identifiable {
    enum Kind: Equatable, Sendable {
        case load
        case restart
    }

    let id: UUID
    let kind: Kind
    let candidateCockpit: CockpitFeatureState
}

struct FlightPlansFeatureState: Equatable, Sendable {
    private(set) var records: [LibraryFlightPlan] = []
    private(set) var loadingRequestID: UUID?
    private(set) var error: FlightPlanLibraryError?

    var isLoading: Bool {
        loadingRequestID != nil
    }

    mutating func beginLoading(requestID: UUID) {
        loadingRequestID = requestID
        error = nil
    }

    @discardableResult
    mutating func completeLoading(
        requestID: UUID,
        records: [LibraryFlightPlan]?,
        error: FlightPlanLibraryError?
    ) -> Bool {
        guard loadingRequestID == requestID else { return false }
        loadingRequestID = nil
        if let records {
            self.records = records
            self.error = nil
        } else {
            self.error = error
        }
        return true
    }
}
