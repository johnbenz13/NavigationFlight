import Foundation

nonisolated struct StoredFlightPlan: Equatable, Sendable, Identifiable {
    static let currentStorageSchemaVersion = 1

    let id: UUID
    let modifiedAt: Date
    let importedAt: Date
    let sourceData: Data
    let storageSchemaVersion: Int
}

nonisolated struct LibraryFlightPlan: Equatable, Sendable, Identifiable {
    let flightPlan: FlightPlan
    let importedAt: Date

    var id: UUID { flightPlan.id }

    func isLoaded(in loadedFlightPlan: FlightPlan?) -> Bool {
        loadedFlightPlan?.id == id && loadedFlightPlan?.modifiedAt == flightPlan.modifiedAt
    }
}

nonisolated struct PreparedImport: Equatable, Sendable {
    let record: StoredFlightPlan
    let flightPlan: FlightPlan
}

nonisolated struct PreparedReplacement: Equatable, Sendable {
    let candidate: PreparedImport
    let expectedModifiedAt: Date
}

nonisolated enum ImportProposal: Equatable, Sendable {
    case new(PreparedImport)
    case sameRevision(existing: LibraryFlightPlan)
    case replaceNewer(PreparedReplacement)
    case replaceOlder(PreparedReplacement)
}

nonisolated enum FlightPlanStoreError: Error, Equatable, Sendable {
    case conflict(id: UUID)
    case corruptRecord(id: UUID?)
    case operationFailed(id: UUID?)
}

nonisolated enum FlightPlanLibraryError: Error, Equatable, Sendable {
    case invalidFlightPlan
    case corruptRecord(id: UUID)
    case staleProposal(id: UUID)
    case sameRevisionCannotBeCommitted
    case storageFailure(id: UUID?)
}
