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
    private(set) var cockpitPresentationRequestID: UUID?

    init(
        selectedAppSection: AppSection = .flightPlans,
        cockpit: CockpitFeatureState = CockpitFeatureState(),
        flightPlans: FlightPlansFeatureState = FlightPlansFeatureState(),
        pendingFlightChange: PendingFlightChange? = nil,
        cockpitPresentationRequestID: UUID? = nil
    ) {
        self.selectedAppSection = selectedAppSection
        self.cockpit = cockpit
        self.flightPlans = flightPlans
        self.pendingFlightChange = pendingFlightChange
        self.cockpitPresentationRequestID = cockpitPresentationRequestID
    }

    mutating func selectAppSection(_ section: AppSection) {
        selectedAppSection = section
    }

    mutating func chooseFlightPlanFromCockpit() {
        selectAppSection(.flightPlans)
    }

    mutating func updateCockpit(_ cockpit: CockpitFeatureState) {
        self.cockpit = cockpit
    }

    mutating func updateFlightPlans(_ flightPlans: FlightPlansFeatureState) {
        self.flightPlans = flightPlans
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
        cockpitPresentationRequestID = cockpit.flight?.id
        self.pendingFlightChange = nil
        return true
    }

    private mutating func requestFlightChange(
        snapshot: FlightPlan,
        kind: PendingFlightChange.Kind,
        flightID: UUID,
        pendingID: UUID
    ) throws -> LoadFlightPlanDecision {
        if let pendingFlightChange {
            return .confirmationRequired(pendingFlightChange)
        }

        var candidate = CockpitFeatureState(progressionPolicy: cockpit.progressionPolicy)
        try candidate.accept(snapshot, flightID: flightID)

        guard cockpit.hasProtectedPilotWork else {
            cockpit = candidate
            selectedAppSection = .cockpit
            cockpitPresentationRequestID = flightID
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
    case restartFlight
}

enum FlightPlansFeatureIntent: Equatable, Sendable {
    case loadInCockpit(LibraryFlightPlan)
    case returnToCockpit
    case loadUpdatedPlan(LibraryFlightPlan)
    case restartFlight
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
    private(set) var selectedRecordID: UUID?
    private(set) var inFlightRequestID: UUID?
    private(set) var pendingImport: PendingFlightPlanImport?
    private(set) var pendingRemoval: PendingFlightPlanRemoval?
    private(set) var activeRemoval: ActiveFlightPlanRemoval?
    private(set) var presentation: FlightPlansPresentation?
    private(set) var error: FlightPlanLibraryError?

    var isLoading: Bool {
        inFlightRequestID != nil
    }

    var selectedRecord: LibraryFlightPlan? {
        guard let selectedRecordID else { return nil }
        return records.first { $0.id == selectedRecordID }
    }

    mutating func beginLoading(requestID: UUID) {
        inFlightRequestID = requestID
        error = nil
    }

    @discardableResult
    mutating func completeLoading(
        requestID: UUID,
        records: [LibraryFlightPlan]?,
        error: FlightPlanLibraryError?
    ) -> Bool {
        guard inFlightRequestID == requestID else { return false }
        inFlightRequestID = nil
        if let records {
            self.records = records
            if let selectedRecordID, records.contains(where: { $0.id == selectedRecordID }) == false {
                self.selectedRecordID = nil
            }
            self.error = nil
        } else {
            self.error = error
        }
        return true
    }

    @discardableResult
    mutating func beginImport(requestID: UUID) -> Bool {
        guard inFlightRequestID == nil else { return false }
        inFlightRequestID = requestID
        error = nil
        presentation = nil
        return true
    }

    mutating func completeImportPreparation(
        requestID: UUID,
        proposalID: UUID,
        proposal: ImportProposal
    ) -> FlightPlanImportDecision? {
        guard inFlightRequestID == requestID else { return nil }
        inFlightRequestID = nil
        switch proposal {
        case .new:
            pendingImport = PendingFlightPlanImport(id: proposalID, proposal: proposal)
            return .commit(proposalID: proposalID)
        case .sameRevision(let existing):
            pendingImport = nil
            presentation = .alreadyImported(title: existing.flightPlan.title)
            return .some(.none)
        case .replaceNewer, .replaceOlder:
            pendingImport = PendingFlightPlanImport(id: proposalID, proposal: proposal)
            return .confirmation(proposalID: proposalID)
        }
    }

    mutating func beginCommit(proposalID: UUID, requestID: UUID) -> ImportProposal? {
        guard inFlightRequestID == nil, pendingImport?.id == proposalID else { return nil }
        inFlightRequestID = requestID
        return pendingImport?.proposal
    }

    @discardableResult
    mutating func completeCommit(
        requestID: UUID,
        proposalID: UUID,
        records: [LibraryFlightPlan]
    ) -> Bool {
        guard inFlightRequestID == requestID, pendingImport?.id == proposalID else { return false }
        let title = pendingImport?.proposal.candidateTitle ?? "Flight Plan"
        self.records = records
        inFlightRequestID = nil
        pendingImport = nil
        presentation = .imported(title: title)
        return true
    }

    @discardableResult
    mutating func failImport(requestID: UUID, failure: FlightPlansFailure) -> Bool {
        guard inFlightRequestID == requestID else { return false }
        inFlightRequestID = nil
        pendingImport = nil
        presentation = .failure(failure)
        return true
    }

    @discardableResult
    mutating func cancelPendingImport(proposalID: UUID) -> Bool {
        guard pendingImport?.id == proposalID, inFlightRequestID == nil else { return false }
        pendingImport = nil
        return true
    }

    mutating func dismissPresentation() {
        presentation = nil
    }

    mutating func presentFlightChangeFailure() {
        presentation = .flightChangeFailure
    }

    mutating func selectRecord(id: UUID) {
        selectedRecordID = id
    }

    @discardableResult
    mutating func requestRemoval(
        recordID: UUID,
        loadedFlightPlanID: UUID?,
        confirmationID: UUID = UUID()
    ) -> Bool {
        guard inFlightRequestID == nil,
              pendingRemoval == nil,
              records.contains(where: { $0.id == recordID }) else { return false }
        pendingRemoval = PendingFlightPlanRemoval(
            id: confirmationID,
            recordID: recordID,
            isLoadedFlightPlan: loadedFlightPlanID == recordID
        )
        return true
    }

    @discardableResult
    mutating func cancelPendingRemoval(confirmationID: UUID) -> Bool {
        guard pendingRemoval?.id == confirmationID, inFlightRequestID == nil else { return false }
        pendingRemoval = nil
        return true
    }

    mutating func beginRemoval(confirmationID: UUID, requestID: UUID) -> UUID? {
        guard inFlightRequestID == nil,
              let pendingRemoval,
              pendingRemoval.id == confirmationID else { return nil }
        inFlightRequestID = requestID
        activeRemoval = ActiveFlightPlanRemoval(
            requestID: requestID,
            recordID: pendingRemoval.recordID
        )
        self.pendingRemoval = nil
        presentation = nil
        error = nil
        return pendingRemoval.recordID
    }

    @discardableResult
    mutating func completeRemoval(
        requestID: UUID,
        recordID: UUID,
        records: [LibraryFlightPlan]
    ) -> Bool {
        guard inFlightRequestID == requestID,
              activeRemoval == ActiveFlightPlanRemoval(
                requestID: requestID,
                recordID: recordID
              ) else { return false }
        self.records = records
        if selectedRecordID == recordID {
            selectedRecordID = nil
        }
        inFlightRequestID = nil
        activeRemoval = nil
        error = nil
        return true
    }

    @discardableResult
    mutating func failRemoval(requestID: UUID, recordID: UUID) -> Bool {
        guard inFlightRequestID == requestID,
              activeRemoval == ActiveFlightPlanRemoval(
                requestID: requestID,
                recordID: recordID
              ) else { return false }
        inFlightRequestID = nil
        activeRemoval = nil
        presentation = .removalFailure
        return true
    }
}

struct PendingFlightPlanImport: Equatable, Sendable, Identifiable {
    let id: UUID
    let proposal: ImportProposal
}

struct PendingFlightPlanRemoval: Equatable, Sendable, Identifiable {
    let id: UUID
    let recordID: UUID
    let isLoadedFlightPlan: Bool
}

struct ActiveFlightPlanRemoval: Equatable, Sendable {
    let requestID: UUID
    let recordID: UUID
}

enum FlightPlanImportDecision: Equatable, Sendable {
    case commit(proposalID: UUID)
    case confirmation(proposalID: UUID)
    case none
}

enum FlightPlansPresentation: Equatable, Sendable {
    case alreadyImported(title: String)
    case imported(title: String)
    case failure(FlightPlansFailure)
    case flightChangeFailure
    case removalFailure
}

enum FlightPlansFailure: Equatable, Sendable {
    case unreadableFile
    case invalidFlightPlan
    case staleProposal
    case storageFailure
    case libraryUnavailable
}

private extension ImportProposal {
    var candidateTitle: String {
        switch self {
        case .new(let prepared):
            prepared.flightPlan.title
        case .sameRevision(let existing):
            existing.flightPlan.title
        case .replaceNewer(let replacement), .replaceOlder(let replacement):
            replacement.candidate.flightPlan.title
        }
    }
}
