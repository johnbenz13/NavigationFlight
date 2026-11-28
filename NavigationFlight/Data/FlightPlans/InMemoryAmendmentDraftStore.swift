import Foundation

actor InMemoryAmendmentDraftStore: AmendmentDraftStore {
    enum Failure: Sendable { case load, save, remove }
    private var records: [UUID: AmendmentDraftRecord]
    private var failure: Failure?

    init(records: [UUID: AmendmentDraftRecord] = [:], failure: Failure? = nil) {
        self.records = records
        self.failure = failure
    }

    func setFailure(_ failure: Failure?) { self.failure = failure }

    func load(flightID: UUID) throws -> AmendmentDraftRecord? {
        if failure == .load { throw AmendmentDraftStoreError.operationFailed }
        let record = records[flightID]
        try record?.validate(for: flightID)
        return record
    }

    func save(_ record: AmendmentDraftRecord) throws {
        try record.validate(for: record.flightID)
        if failure == .save { throw AmendmentDraftStoreError.operationFailed }
        try records[record.flightID]?.validate(for: record.flightID)
        guard records[record.flightID].map({ $0.revision <= record.revision }) ?? true else { throw AmendmentDraftStoreError.staleRevision }
        records[record.flightID] = record
    }

    func remove(flightID: UUID) throws {
        if failure == .remove { throw AmendmentDraftStoreError.operationFailed }
        records[flightID] = nil
    }
}
