import Foundation

actor InMemoryFlightRecordingStore: FlightRecordingStore {
    enum Failure: Equatable, Sendable {
        case create
        case append
        case close
    }

    private var snapshotsByID: [UUID: FlightRecordingReadSnapshot] = [:]
    private var unavailablePackageResults: [FlightRecordingPackageResult] = []
    private let failure: Failure?

    init(
        failure: Failure? = nil,
        packageResults: [FlightRecordingPackageResult] = []
    ) {
        self.failure = failure
        for result in packageResults {
            switch result {
            case .available(let snapshot):
                snapshotsByID[snapshot.recording.id] = snapshot
            case .unsupported, .corrupt:
                unavailablePackageResults.append(result)
            }
        }
    }

    func create(_ seed: FlightRecordingSeed) throws {
        if failure == .create { throw FlightRecordingStoreError.operationFailed(id: nil) }
        guard snapshotsByID[seed.recording.id] == nil else {
            throw FlightRecordingStoreError.duplicatePackage(id: seed.recording.id)
        }
        snapshotsByID[seed.recording.id] = FlightRecordingReadSnapshot(
            recording: seed.recording,
            events: seed.events,
            trackSegments: seed.trackSegments
        )
    }

    func appendTrackBatch(_ batch: RecordedTrackBatch) throws {
        guard var current = snapshotsByID[batch.recordingID] else {
            throw FlightRecordingStoreError.corruptPackage(id: batch.recordingID)
        }
        if let index = current.trackSegments.firstIndex(where: { $0.id == batch.segmentID }) {
            current.trackSegments[index].samples.append(contentsOf: batch.samples)
        } else {
            current.trackSegments.append(RecordedTrackSegment(id: batch.segmentID, samples: batch.samples))
        }
        current = FlightRecordingReadSnapshot(
            recording: current.recording.restoring(
                gpsCoverage: current.trackSegments.count == 1 ? .available : .partial
            ),
            events: current.events,
            trackSegments: current.trackSegments
        )
        snapshotsByID[batch.recordingID] = current
    }

    func synchronizeTrack(recordingID: UUID) throws {
        guard snapshotsByID[recordingID] != nil else {
            throw FlightRecordingStoreError.corruptPackage(id: recordingID)
        }
    }

    func updateRecoveryCheckpoint(recordingID: UUID, at timestamp: Date) throws {
        guard let current = snapshotsByID[recordingID], current.recording.closure == nil else {
            throw FlightRecordingStoreError.corruptPackage(id: recordingID)
        }
        snapshotsByID[recordingID] = FlightRecordingReadSnapshot(
            recording: current.recording.restoringRecoveryCheckpoint(at: timestamp),
            events: current.events,
            trackSegments: current.trackSegments
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
        let recording: FlightRecording
        switch event.payload {
        case .navigationCompleted:
            recording = current.recording.restoring(
                navigationState: .complete,
                nextEventSequence: UInt64(events.count)
            )
        case .physicalStateChanged(_, let to), .physicalStateCorrected(_, _, let to):
            recording = current.recording.restoring(
                physicalState: to,
                nextEventSequence: UInt64(events.count)
            )
        default:
            recording = current.recording
        }
        snapshotsByID[recordingID] = FlightRecordingReadSnapshot(
            recording: recording,
            events: events,
            trackSegments: current.trackSegments
        )
    }

    func packages() -> [FlightRecordingPackageResult] {
        snapshotsByID.values.map(FlightRecordingPackageResult.available) + unavailablePackageResults
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
            events: current.events,
            trackSegments: current.trackSegments
        )
    }

    func remove(id: UUID) throws {
        guard let current = snapshotsByID[id] else {
            throw FlightRecordingStoreError.corruptPackage(id: id)
        }
        guard current.recording.closure != nil else {
            throw FlightRecordingStoreError.recordingActive(id: id)
        }
        snapshotsByID[id] = nil
    }
}
