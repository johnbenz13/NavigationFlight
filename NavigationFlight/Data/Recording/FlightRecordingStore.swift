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

    init(recordingID: UUID, expectedSequence: UInt64, events: [RecordedFlightEvent]) {
        self.recordingID = recordingID
        self.expectedSequence = expectedSequence
        self.events = events
    }

    init(recordingID: UUID, expectedSequence: UInt64, event: RecordedFlightEvent) {
        self.init(recordingID: recordingID, expectedSequence: expectedSequence, events: [event])
    }

    func validate() throws {
        let invalid = FlightRecordingStoreError.invalidEventSequence(id: recordingID)
        guard let first = events.first, let context = first.cockpitContext,
              Set(events.map(\.id)).count == events.count,
              events.enumerated().allSatisfy({ offset, event in
                  event.sequence >= expectedSequence && event.sequence - expectedSequence == UInt64(offset) &&
                      event.occurredAt == first.occurredAt && event.elapsed == first.elapsed &&
                      event.cockpitContext == context
              }) else { throw invalid }
        let activationIndex: Int
        let immediate: Bool
        switch first.payload {
        case .pendingRouteAmendmentConfirmed(let amendment):
            guard amendment.id == first.id, context.flightID == amendment.flightID, first.origin == .pilot else {
                throw invalid
            }
            immediate = amendment.startsImmediately == true
            if !immediate {
                guard events.count == 1 else { throw invalid }
                return
            }
            activationIndex = 1
            guard events.indices.contains(activationIndex),
                  case .routeAmendmentActivated(let departure) = events[activationIndex].payload,
                  departure.amendmentID == amendment.id else { throw invalid }
        case .routeAmendmentActivated:
            activationIndex = 0
            immediate = false
        default:
            throw invalid
        }
        guard case .routeAmendmentActivated(let departure) = events[activationIndex].payload,
              events[activationIndex].origin == .pilot,
              immediate == false || (departure.startsReplacement && !departure.recordedOriginalArrival) else {
            throw invalid
        }
        let following = events.dropFirst(activationIndex + 1)
        let companions = RecordedFlightEventPayload.routeActivationCompanions(departure, immediate: immediate)
        guard following.count == companions.count,
              zip(following, companions).allSatisfy({ $0.origin == $1.origin && $0.payload == $1.payload }) else {
            throw invalid
        }
        if departure.startsReplacement {
            guard context.checklists[departure.firstReplacementLegID] != nil else { throw invalid }
        }
    }

    func validatePendingIdentity(in journal: [RecordedFlightEvent]) throws {
        var pendingID: UUID?
        for event in journal {
            switch event.payload {
            case .pendingRouteAmendmentConfirmed(let amendment): pendingID = amendment.id
            case .routeAmendmentActivated: pendingID = nil
            default: break
            }
        }
        switch event.payload {
        case .pendingRouteAmendmentConfirmed where pendingID == nil:
            return
        case .routeAmendmentActivated(let departure) where pendingID == departure.amendmentID:
            return
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
