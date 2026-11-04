import Foundation

actor InMemoryFlightRecordingStore: FlightRecordingStore {
    enum Failure: Equatable, Sendable {
        case create
        case append
        case close
    }

    private var snapshotsByID: [UUID: FlightRecordingReadSnapshot] = [:]
    private let failure: Failure?

    init(failure: Failure? = nil) {
        self.failure = failure
    }

    func create(_ seed: FlightRecordingSeed) throws {
        if failure == .create { throw FlightRecordingStoreError.operationFailed(id: nil) }
        guard snapshotsByID[seed.recording.id] == nil else {
            throw FlightRecordingStoreError.duplicatePackage(id: seed.recording.id)
        }
        snapshotsByID[seed.recording.id] = FlightRecordingReadSnapshot(
            recording: seed.recording,
            events: seed.events
        )
    }

    func appendEvent(
        _ event: RecordedFlightEvent,
        recordingID: UUID,
        synchronize: Bool
    ) throws {
        if failure == .append { throw FlightRecordingStoreError.operationFailed(id: recordingID) }
        guard let current = snapshotsByID[recordingID] else {
            throw FlightRecordingStoreError.corruptPackage(id: recordingID)
        }
        let expectedSequence = current.events.last.map { $0.sequence + 1 } ?? 0
        guard event.sequence == expectedSequence else {
            throw FlightRecordingStoreError.invalidEventSequence(id: recordingID)
        }
        let events = current.events + [event]
        let recording = event.payload == .navigationCompleted
            ? current.recording.restoring(
                navigationState: .complete,
                nextEventSequence: UInt64(events.count)
            )
            : current.recording
        snapshotsByID[recordingID] = FlightRecordingReadSnapshot(
            recording: recording,
            events: events
        )
    }

    func packages() -> [FlightRecordingPackageResult] {
        snapshotsByID.values.map(FlightRecordingPackageResult.available)
    }

    func readSnapshot(id: UUID) throws -> FlightRecordingReadSnapshot {
        guard let snapshot = snapshotsByID[id] else {
            throw FlightRecordingStoreError.corruptPackage(id: id)
        }
        return snapshot
    }

    func close(id: UUID, closure: FlightRecordingClosure) throws {
        if failure == .close { throw FlightRecordingStoreError.operationFailed(id: id) }
        guard let current = snapshotsByID[id] else {
            throw FlightRecordingStoreError.corruptPackage(id: id)
        }
        snapshotsByID[id] = FlightRecordingReadSnapshot(
            recording: current.recording.restoring(
                closure: closure,
                nextEventSequence: UInt64(current.events.count)
            ),
            events: current.events
        )
    }
}
