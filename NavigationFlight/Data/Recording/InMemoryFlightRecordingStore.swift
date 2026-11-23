import Foundation

actor InMemoryFlightRecordingStore: FlightRecordingStore {
    enum Failure: Equatable, Sendable {
        case create
        case append
        case close
        case remove
    }

    private var snapshotsByID: [UUID: FlightRecordingReadSnapshot] = [:]
    private var unavailablePackageResults: [FlightRecordingPackageResult] = []
    private let failure: Failure?
    private let failReadOnCall: Int?
    private var readCallCount = 0
    private(set) var removeCallCount = 0

    init(
        failure: Failure? = nil,
        failReadOnCall: Int? = nil,
        packageResults: [FlightRecordingPackageResult] = []
    ) {
        self.failure = failure
        self.failReadOnCall = failReadOnCall
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
            trackSegments: seed.trackSegments,
            detectorPolicy: seed.detectorPolicy
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
            trackSegments: current.trackSegments,
            detectorPolicy: current.detectorPolicy
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
            trackSegments: current.trackSegments,
            detectorPolicy: current.detectorPolicy
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
        var recording: FlightRecording
        switch event.payload {
        case .reachUndone, .legStarted:
            recording = current.recording.restoring(
                navigationState: .active, nextEventSequence: UInt64(events.count)
            )
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
            recording = current.recording.restoring(
                navigationState: current.recording.navigationState,
                nextEventSequence: UInt64(events.count)
            )
        }
        if event.cockpitContext != nil, recording.sourceSchemaVersion < 3 {
            recording.sourceSchemaVersion = 3
            recording.cockpitContextStartSequence = event.sequence
        }
        snapshotsByID[recordingID] = FlightRecordingReadSnapshot(
            recording: recording,
            events: events,
            trackSegments: current.trackSegments,
            detectorPolicy: current.detectorPolicy
        )
    }

    func commitRouteTransaction(_ transaction: FlightRouteTransaction) async throws {
        try transaction.validate()
        let id = transaction.recordingID
        guard let current = snapshotsByID[id] else { throw FlightRecordingStoreError.corruptPackage(id: id) }
        if try transaction.isCommitted(in: current.events) { return }
        guard failure != .append, current.recording.closure == nil,
              current.recording.nextEventSequence == transaction.expectedSequence else {
            throw FlightRecordingStoreError.operationFailed(id: id)
        }
        try transaction.validatePendingIdentity(in: current.events)
        let events = current.events + transaction.events
        var navigationState: RecordedNavigationState = switch transaction.events.last?.payload {
        case .finalWaypointReached: .reachedFinalWaypoint
        case .waypointReached: .ready
        default: current.recording.navigationState
        }
        for event in transaction.events {
            if case .routeAmendmentActivated(let departure) = event.payload {
                navigationState = departure.startsReplacement ? .active : .ready
            }
        }
        var recording = current.recording.restoring(
            navigationState: navigationState, nextEventSequence: UInt64(events.count)
        )
        if recording.sourceSchemaVersion < 3 {
            recording.cockpitContextStartSequence = transaction.expectedSequence
        }
        recording.sourceSchemaVersion = 4
        snapshotsByID[id] = FlightRecordingReadSnapshot(
            recording: recording, events: events, trackSegments: current.trackSegments, detectorPolicy: current.detectorPolicy
        )
    }

    func packages() -> [FlightRecordingPackageResult] {
        snapshotsByID.values.map(FlightRecordingPackageResult.available) + unavailablePackageResults
    }

    func readSnapshot(id: UUID) throws -> FlightRecordingReadSnapshot {
        readCallCount += 1
        if readCallCount == failReadOnCall {
            throw FlightRecordingStoreError.operationFailed(id: id)
        }
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
            trackSegments: current.trackSegments,
            detectorPolicy: current.detectorPolicy
        )
    }

    func remove(id: UUID) throws {
        removeCallCount += 1
        if failure == .remove { throw FlightRecordingStoreError.operationFailed(id: id) }
        guard let current = snapshotsByID[id] else {
            if let index = unavailablePackageResults.firstIndex(where: { result in
                switch result {
                case .unsupported(let packageID, _): packageID == id
                case .corrupt(let packageID): packageID == id
                case .available: false
                }
            }) {
                unavailablePackageResults.remove(at: index)
                return
            }
            throw FlightRecordingStoreError.corruptPackage(id: id)
        }
        guard current.recording.closure != nil else {
            throw FlightRecordingStoreError.recordingActive(id: id)
        }
        snapshotsByID[id] = nil
    }
}
