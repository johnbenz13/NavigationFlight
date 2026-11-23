import Foundation

nonisolated protocol FlightRecordingStore: Sendable {
    func create(_ seed: FlightRecordingSeed) async throws
    func appendEvent(
        _ event: RecordedFlightEvent,
        recordingID: UUID,
        synchronize: Bool
    ) async throws
    func commitRouteTransaction(_ transaction: FlightRouteTransaction) async throws
    func routeTransactionIsCommitted(_ transaction: FlightRouteTransaction) async throws -> Bool
    func appendTrackBatch(_ batch: RecordedTrackBatch) async throws
    func synchronizeTrack(recordingID: UUID) async throws
    func updateRecoveryCheckpoint(recordingID: UUID, at timestamp: Date) async throws
    func packages() async -> [FlightRecordingPackageResult]
    func readSnapshot(id: UUID) async throws -> FlightRecordingReadSnapshot
    func close(id: UUID, closure: FlightRecordingClosure) async throws
    func remove(id: UUID) async throws
}

extension FlightRecordingStore {
    nonisolated func commitRouteTransaction(_ transaction: FlightRouteTransaction) async throws {
        throw FlightRecordingStoreError.operationFailed(id: transaction.recordingID)
    }

    nonisolated func routeTransactionIsCommitted(_ transaction: FlightRouteTransaction) async throws -> Bool {
        let snapshot = try await readSnapshot(id: transaction.recordingID)
        return try transaction.isCommitted(in: snapshot.events)
    }
}

nonisolated struct FlightRouteTransaction: Sendable {
    let recordingID: UUID
    let expectedSequence: UInt64
    let events: [RecordedFlightEvent]

    var event: RecordedFlightEvent { events[0] }

    init(recordingID: UUID, expectedSequence: UInt64, event: RecordedFlightEvent) {
        self.init(recordingID: recordingID, expectedSequence: expectedSequence, events: [event])
    }

    init(recordingID: UUID, expectedSequence: UInt64, events: [RecordedFlightEvent]) {
        self.recordingID = recordingID
        self.expectedSequence = expectedSequence
        self.events = events
    }

    func validate() throws {
        guard let first = events.first, let context = first.cockpitContext,
              first.origin == .pilot, Set(events.map(\.id)).count == events.count,
              events.enumerated().allSatisfy({ index, item in
                  item.sequence >= expectedSequence && item.sequence - expectedSequence == UInt64(index) &&
                  item.occurredAt == first.occurredAt && item.elapsed == first.elapsed && item.cockpitContext == context
              }) else { throw FlightRecordingStoreError.invalidEventSequence(id: recordingID) }
        switch first.payload {
        case .pendingRouteAmendmentConfirmed(let amendment):
            guard events.count == 1, amendment.id == first.id, amendment.flightID == context.flightID else {
                throw FlightRecordingStoreError.invalidEventSequence(id: recordingID)
            }
        case .pendingRouteAmendmentReplaced(let previousID, let amendment):
            guard events.count == 1, amendment.id == first.id, amendment.flightID == context.flightID,
                  previousID != amendment.id else { throw FlightRecordingStoreError.invalidEventSequence(id: recordingID) }
        case .pendingRouteAmendmentCancelled(let id, let destination?, let reachID?):
            guard destination.amendmentID == id, (2...3).contains(events.count), events[1].id == reachID,
                  events[1].origin == .pilot, events[1].payload == .waypointReached(legID: destination.legID) else {
                throw FlightRecordingStoreError.invalidEventSequence(id: recordingID)
            }
            if events.count == 3 {
                switch events[2].payload {
                case .automaticNextLegTransition(let legID, _), .finalWaypointReached(let legID):
                    guard legID == destination.legID, events[2].origin == .automatic else {
                        throw FlightRecordingStoreError.invalidEventSequence(id: recordingID)
                    }
                default: throw FlightRecordingStoreError.invalidEventSequence(id: recordingID)
                }
            }
        case .pendingRouteAmendmentCancelled(_, nil, nil):
            guard events.count == 1 else { throw FlightRecordingStoreError.invalidEventSequence(id: recordingID) }
        default:
            throw FlightRecordingStoreError.invalidEventSequence(id: recordingID)
        }
    }

    func isCommitted(in journal: [RecordedFlightEvent]) throws -> Bool {
        guard let first = events.first else { throw FlightRecordingStoreError.invalidEventSequence(id: recordingID) }
        guard let offset = journal.firstIndex(where: { $0.id == first.id }) else {
            let identifiers = Set(events.map(\.id))
            guard !journal.contains(where: { identifiers.contains($0.id) }) else {
                throw FlightRecordingStoreError.invalidEventSequence(id: recordingID)
            }
            return false
        }
        // Use the journal representation, including its date precision.
        let persisted = journal.dropFirst(offset).prefix(events.count)
        guard persisted.count == events.count,
              try zip(persisted, events).allSatisfy({ recorded, candidate in
                  try FlightRecordingCoding.encoder.encode(RecordedFlightEventDTO(event: recorded))
                      == FlightRecordingCoding.encoder.encode(RecordedFlightEventDTO(event: candidate))
              }) else {
            throw FlightRecordingStoreError.invalidEventSequence(id: recordingID)
        }
        return true
    }

    func validatePendingIdentity(in journal: [RecordedFlightEvent]) throws {
        let undoneIDs = Set(journal.compactMap { item -> UUID? in
            if case .reachUndone(let id) = item.payload { return id }
            return nil
        })
        var currentID: UUID?
        for item in journal {
            switch item.payload {
            case .pendingRouteAmendmentConfirmed(let amendment), .pendingRouteAmendmentReplaced(_, let amendment):
                currentID = amendment.id
            case .pendingRouteAmendmentCancelled(_, _, let reachID):
                if reachID.map(undoneIDs.contains) != true { currentID = nil }
            default: break
            }
        }

        let expectedID: UUID?
        switch event.payload {
        case .pendingRouteAmendmentReplaced(let previousID, _),
             .pendingRouteAmendmentCancelled(let previousID, _, _):
            expectedID = previousID
        default: expectedID = nil
        }
        guard expectedID == currentID else {
            throw FlightRecordingStoreError.invalidEventSequence(id: recordingID)
        }
    }
}

nonisolated struct FlightRecordingSeed: Equatable, Sendable {
    let recording: FlightRecording
    let events: [RecordedFlightEvent]
    let trackSegments: [RecordedTrackSegment]
    let detectorPolicy: PhysicalFlightDetectionPolicySnapshot

    init(
        recording: FlightRecording,
        events: [RecordedFlightEvent],
        trackSegments: [RecordedTrackSegment] = [],
        detectorPolicy: PhysicalFlightDetectionPolicySnapshot = .production
    ) {
        self.recording = recording
        self.events = events
        self.trackSegments = trackSegments
        self.detectorPolicy = detectorPolicy
    }
}

nonisolated struct FlightRecordingReadSnapshot: Equatable, Sendable {
    let recording: FlightRecording
    let events: [RecordedFlightEvent]
    var trackSegments: [RecordedTrackSegment]
    let approximateSizeBytes: Int64?
    let evidenceSummary: FlightRecordingEvidenceSummary
    let detectorPolicy: PhysicalFlightDetectionPolicySnapshot?

    var latestDurableEvidenceAt: Date {
        max(
            recording.startedAt,
            recording.lastRecoveryCheckpointAt ?? recording.startedAt,
            events.lazy.map(\.occurredAt).max() ?? recording.startedAt,
            trackSegments.lazy.flatMap(\.samples).map(\.observedAt).max() ?? recording.startedAt
        )
    }

    init(
        recording: FlightRecording,
        events: [RecordedFlightEvent],
        trackSegments: [RecordedTrackSegment] = [],
        approximateSizeBytes: Int64? = nil,
        evidenceSummary: FlightRecordingEvidenceSummary? = nil,
        detectorPolicy: PhysicalFlightDetectionPolicySnapshot? = nil
    ) {
        self.recording = recording
        self.events = events
        self.trackSegments = trackSegments
        self.approximateSizeBytes = approximateSizeBytes
        self.detectorPolicy = detectorPolicy
        self.evidenceSummary = evidenceSummary ?? FlightRecordingSummaryProjector().project(
            trackSegments: trackSegments,
            startedAt: recording.startedAt,
            endedAt: recording.closure?.closedAt
                ?? (events.map(\.occurredAt) + trackSegments.flatMap(\.samples).map(\.observedAt)).max(),
            knownGapIntervals: []
        )
    }
}

nonisolated enum FlightRecordingPackageResult: Equatable, Sendable {
    case available(FlightRecordingReadSnapshot)
    case unsupported(id: UUID, schemaVersion: Int)
    case corrupt(id: UUID?)
}

nonisolated enum FlightRecordingStoreError: Error, Equatable, Sendable {
    case duplicatePackage(id: UUID)
    case invalidEventSequence(id: UUID)
    case unsupportedVersion(id: UUID, schemaVersion: Int)
    case corruptPackage(id: UUID?)
    case operationFailed(id: UUID?)
    case recordingActive(id: UUID)
}
