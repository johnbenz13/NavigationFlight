import Foundation

nonisolated enum AmendmentDraftStoreError: Error, Equatable {
    case invalidData
    case unsupportedSchema(Int)
    case operationFailed
    case staleRevision
}

/// Local preparation data only. No recording package, journal or export owns it.
nonisolated struct AmendmentDraftRecord: Codable, Equatable, Sendable {
    static let currentSchema = 1
    let schemaVersion: Int
    let flightID: UUID
    let revision: UInt64
    let recordingSequence: UInt64
    let payload: Data

    init(flightID: UUID, revision: UInt64, recordingSequence: UInt64, payload: Data,
         schemaVersion: Int = currentSchema) {
        self.schemaVersion = schemaVersion
        self.flightID = flightID
        self.revision = revision
        self.recordingSequence = recordingSequence
        self.payload = payload
    }

    func validate(for flightID: UUID) throws {
        guard schemaVersion == Self.currentSchema else {
            throw AmendmentDraftStoreError.unsupportedSchema(schemaVersion)
        }
        guard self.flightID == flightID, revision < UInt64.max else { throw AmendmentDraftStoreError.invalidData }
    }
}

nonisolated protocol AmendmentDraftStore: Sendable {
    func load(flightID: UUID) async throws -> AmendmentDraftRecord?
    /// Returns only after accepting the record; rejected revisions must throw.
    func save(_ record: AmendmentDraftRecord) async throws
    func remove(flightID: UUID) async throws
}
