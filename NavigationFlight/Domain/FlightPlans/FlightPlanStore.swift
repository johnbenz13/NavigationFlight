import Foundation

nonisolated protocol FlightPlanStore: Sendable {
    func records() async throws -> [StoredFlightPlan]
    func replace(_ record: StoredFlightPlan, expecting: Date?) async throws
    func remove(id: UUID) async throws
}

actor InMemoryFlightPlanStore: FlightPlanStore {
    private var recordsByID: [UUID: StoredFlightPlan]

    init(records: [StoredFlightPlan] = []) {
        recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
    }

    func records() -> [StoredFlightPlan] {
        Array(recordsByID.values)
    }

    func replace(_ record: StoredFlightPlan, expecting expectedModifiedAt: Date?) throws {
        let existing = recordsByID[record.id]
        guard existing?.modifiedAt == expectedModifiedAt else {
            throw FlightPlanStoreError.conflict(id: record.id)
        }
        recordsByID[record.id] = record
    }

    func remove(id: UUID) {
        recordsByID[id] = nil
    }
}
