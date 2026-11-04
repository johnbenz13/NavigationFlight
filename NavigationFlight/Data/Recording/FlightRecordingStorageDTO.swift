import CryptoKit
import Foundation

nonisolated struct FlightRecordingManifestDTO: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: UUID
    let flightID: UUID
    let startedAt: Date
    let physicalState: String
    var navigationState: String
    let gpsCoverage: String
    var closure: FlightRecordingClosureDTO?
    var nextEventSequence: UInt64

    init(recording: FlightRecording) {
        schemaVersion = Self.currentSchemaVersion
        id = recording.id
        flightID = recording.flightID
        startedAt = recording.startedAt
        physicalState = recording.physicalState.storageValue
        navigationState = recording.navigationState.storageValue
        gpsCoverage = recording.gpsCoverage.storageValue
        closure = recording.closure.map(FlightRecordingClosureDTO.init)
        nextEventSequence = recording.nextEventSequence
    }

    func domain(
        snapshot: RecordedFlightPlanSnapshot,
        physicalState restoredPhysicalState: PhysicalFlightState? = nil,
        navigationState restoredNavigationState: RecordedNavigationState? = nil,
        gpsCoverage restoredGPSCoverage: GPSCoverageState? = nil,
        nextEventSequence: UInt64? = nil
    ) throws -> FlightRecording {
        guard schemaVersion == Self.currentSchemaVersion else {
            throw FlightRecordingStoreError.unsupportedVersion(id: id, schemaVersion: schemaVersion)
        }
        guard let physicalState = PhysicalFlightState(storageValue: physicalState),
              let navigationState = RecordedNavigationState(storageValue: navigationState),
              let gpsCoverage = GPSCoverageState(storageValue: gpsCoverage) else {
            throw FlightRecordingStoreError.corruptPackage(id: id)
        }
        return FlightRecording(
            id: id,
            flightID: flightID,
            flightPlanSnapshot: snapshot,
            startedAt: startedAt,
            physicalState: restoredPhysicalState ?? physicalState,
            navigationState: restoredNavigationState ?? navigationState,
            gpsCoverage: restoredGPSCoverage ?? gpsCoverage,
            closure: closure?.domain,
            nextEventSequence: nextEventSequence ?? self.nextEventSequence
        )
    }
}

nonisolated struct RecordedFlightPlanSnapshotDTO: Codable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let id: UUID
    let title: String
    let legIDs: [UUID]

    init(snapshot: RecordedFlightPlanSnapshot) {
        schemaVersion = Self.currentSchemaVersion
        id = snapshot.id
        title = snapshot.title
        legIDs = snapshot.legIDs
    }

    var domain: RecordedFlightPlanSnapshot {
        RecordedFlightPlanSnapshot(id: id, title: title, legIDs: legIDs)
    }
}

nonisolated struct FlightRecordingClosureDTO: Codable {
    let outcome: String
    let cause: String
    let closedAt: Date
    let elapsedSeconds: Int64
    let elapsedAttoseconds: Int64
    let landingEvidenceAvailable: Bool

    init(closure: FlightRecordingClosure) {
        outcome = closure.outcome == .complete ? "complete" : "incomplete"
        cause = closure.cause == .automatic ? "automatic" : "manual"
        closedAt = closure.closedAt
        let components = closure.elapsed.components
        elapsedSeconds = components.seconds
        elapsedAttoseconds = components.attoseconds
        landingEvidenceAvailable = closure.landingEvidenceAvailable
    }

    var domain: FlightRecordingClosure? {
        guard let outcome = FlightRecordingClosure.Outcome(storageValue: outcome),
              let cause = FlightRecordingClosure.Cause(storageValue: cause) else { return nil }
        return FlightRecordingClosure(
            outcome: outcome,
            cause: cause,
            closedAt: closedAt,
            elapsed: Duration(
                secondsComponent: elapsedSeconds,
                attosecondsComponent: elapsedAttoseconds
            ),
            landingEvidenceAvailable: landingEvidenceAvailable
        )
    }
}

nonisolated struct RecordedFlightEventEnvelopeDTO: Codable {
    static let currentPayloadVersion = 1

    let payloadVersion: Int
    let event: RecordedFlightEventDTO
    let checksum: String

    init(event: RecordedFlightEvent) throws {
        payloadVersion = Self.currentPayloadVersion
        self.event = RecordedFlightEventDTO(event: event)
        checksum = try Self.checksum(for: self.event)
    }

    func domain() throws -> RecordedFlightEvent {
        guard payloadVersion == Self.currentPayloadVersion,
              checksum == (try Self.checksum(for: event)) else {
            throw FlightRecordingStoreError.corruptPackage(id: nil)
        }
        return try event.domain()
    }

    private static func checksum(for event: RecordedFlightEventDTO) throws -> String {
        let digest = SHA256.hash(data: try FlightRecordingCoding.encoder.encode(event))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated struct RecordedTrackBatchEnvelopeDTO: Codable {
    static let currentPayloadVersion = 1

    let payloadVersion: Int
    let batch: RecordedTrackBatchDTO
    let checksum: String

    init(batch: RecordedTrackBatch) throws {
        payloadVersion = Self.currentPayloadVersion
        self.batch = RecordedTrackBatchDTO(batch: batch)
        checksum = try Self.checksum(for: self.batch)
    }

    func domain() throws -> RecordedTrackBatch {
        guard payloadVersion == Self.currentPayloadVersion,
              checksum == (try Self.checksum(for: batch)) else {
            throw FlightRecordingStoreError.corruptPackage(id: batch.recordingID)
        }
        return batch.domain
    }

    private static func checksum(for batch: RecordedTrackBatchDTO) throws -> String {
        let digest = SHA256.hash(data: try FlightRecordingCoding.encoder.encode(batch))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated struct RecordedTrackBatchDTO: Codable {
    let recordingID: UUID
    let segmentID: UUID
    let samples: [RecordedTrackSampleDTO]

    init(batch: RecordedTrackBatch) {
        recordingID = batch.recordingID
        segmentID = batch.segmentID
        samples = batch.samples.map(RecordedTrackSampleDTO.init)
    }

    var domain: RecordedTrackBatch {
        RecordedTrackBatch(
            recordingID: recordingID,
            segmentID: segmentID,
            samples: samples.map(\.domain)
        )
    }
}

nonisolated struct RecordedTrackSampleDTO: Codable {
    let latitudeDegrees: Double
    let longitudeDegrees: Double
    let observedAt: Date
    let horizontalAccuracyMeters: Double
    let altitudeMeters: Double?
    let verticalAccuracyMeters: Double?
    let groundSpeedMetersPerSecond: Double?
    let speedAccuracyMetersPerSecond: Double?
    let courseDegrees: Double?
    let courseAccuracyDegrees: Double?

    init(sample: RecordedTrackSample) {
        latitudeDegrees = sample.coordinate.latitudeDegrees
        longitudeDegrees = sample.coordinate.longitudeDegrees
        observedAt = sample.observedAt
        horizontalAccuracyMeters = sample.horizontalAccuracyMeters
        altitudeMeters = sample.altitudeMeters
        verticalAccuracyMeters = sample.verticalAccuracyMeters
        groundSpeedMetersPerSecond = sample.groundSpeedMetersPerSecond
        speedAccuracyMetersPerSecond = sample.speedAccuracyMetersPerSecond
        courseDegrees = sample.courseDegrees
        courseAccuracyDegrees = sample.courseAccuracyDegrees
    }

    var domain: RecordedTrackSample {
        RecordedTrackSample(
            coordinate: WGS84Coordinate(
                latitudeDegrees: latitudeDegrees,
                longitudeDegrees: longitudeDegrees
            ),
            observedAt: observedAt,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            altitudeMeters: altitudeMeters,
            verticalAccuracyMeters: verticalAccuracyMeters,
            groundSpeedMetersPerSecond: groundSpeedMetersPerSecond,
            speedAccuracyMetersPerSecond: speedAccuracyMetersPerSecond,
            courseDegrees: courseDegrees,
            courseAccuracyDegrees: courseAccuracyDegrees
        )
    }
}

nonisolated struct RecordedFlightEventDTO: Codable {
    let id: UUID
    let sequence: UInt64
    let occurredAt: Date
    let elapsedSeconds: Int64
    let elapsedAttoseconds: Int64
    let origin: RecordedFlightEvent.Origin
    let kind: String
    let legID: UUID?
    let targetID: UUID?
    let successorLegID: UUID?
    let startCause: String?
    let outcome: String?
    let closureCause: String?
    var targetKind: String? = nil
    var priorValue: Int? = nil
    var committedValue: Int? = nil
    var linkedEventID: UUID? = nil
    var latitudeDegrees: Double? = nil
    var longitudeDegrees: Double? = nil
    var sampleObservedAt: Date? = nil
    var sampleAccuracyMeters: Double? = nil
    var degradationReason: String? = nil
    var physicalStateFrom: String? = nil
    var physicalStateTo: String? = nil

    init(event: RecordedFlightEvent) {
        id = event.id
        sequence = event.sequence
        occurredAt = event.occurredAt
        let components = event.elapsed.components
        elapsedSeconds = components.seconds
        elapsedAttoseconds = components.attoseconds
        origin = event.origin
        switch event.payload {
        case .recordingStarted:
            kind = "recordingStarted"
            legID = nil
            targetID = nil
            successorLegID = nil
            startCause = "startLegWithoutLocation"
            outcome = nil
            closureCause = nil
        case .legStarted(let value):
            kind = "legStarted"
            legID = value
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .destinationIdentified(let value):
            kind = "destinationIdentified"
            legID = value
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .identificationPointReached(let key):
            kind = "identificationPointReached"
            legID = key.legID
            targetID = key.identificationPointID
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .waypointReached(let value):
            kind = "waypointReached"
            legID = value
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .automaticNextLegTransition(let fromLegID, let toLegID):
            kind = "automaticNextLegTransition"
            legID = fromLegID
            targetID = nil
            successorLegID = toLegID
            startCause = nil
            outcome = nil
            closureCause = nil
        case .finalWaypointReached(let value):
            kind = "finalWaypointReached"
            legID = value
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .automaticLegRecovery(let value):
            kind = "automaticLegRecovery"
            legID = value
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .etaRevised(let target, let priorSeconds, let committedSeconds):
            kind = "etaRevised"
            legID = target.legID
            targetID = target.targetID
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
            switch target.kind {
            case .destination: targetKind = "destination"
            case .identificationPoint: targetKind = "identificationPoint"
            }
            priorValue = priorSeconds
            committedValue = committedSeconds
        case .headingRevised(let value, let priorDegrees, let committedDegrees):
            kind = "headingRevised"
            legID = value
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
            priorValue = priorDegrees
            committedValue = committedDegrees
        case .reachUndone(let originalEventID):
            kind = "reachUndone"
            legID = nil
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
            linkedEventID = originalEventID
        case .positionCheckRequested:
            kind = "positionCheckRequested"
            legID = nil
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .positionCheckEnded(let value):
            kind = "positionCheckEnded"
            legID = nil
            targetID = nil
            successorLegID = nil
            startCause = nil
            closureCause = nil
            switch value {
            case .endedWithoutDisclosure:
                outcome = "endedWithoutDisclosure"
            case .disclosed(let sample):
                outcome = "disclosed"
                latitudeDegrees = sample.coordinate.latitudeDegrees
                longitudeDegrees = sample.coordinate.longitudeDegrees
                sampleObservedAt = sample.observedAt
                sampleAccuracyMeters = sample.horizontalAccuracyMeters
            }
        case .storageDegraded(let reason):
            kind = "storageDegraded"
            legID = nil
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
            degradationReason = reason.rawValue
        case .physicalStateChanged(let from, let to):
            kind = "physicalStateChanged"
            legID = nil
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
            physicalStateFrom = from.rawValue
            physicalStateTo = to.rawValue
        case .physicalStateCorrected(let originalEventID, let from, let to):
            kind = "physicalStateCorrected"
            legID = nil
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
            linkedEventID = originalEventID
            physicalStateFrom = from.rawValue
            physicalStateTo = to.rawValue
        case .navigationCompleted:
            kind = "navigationCompleted"
            legID = nil
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .manualEnd:
            kind = "manualEnd"
            legID = nil
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .recordingClosed(let value, let cause):
            kind = "recordingClosed"
            legID = nil
            targetID = nil
            successorLegID = nil
            startCause = nil
            outcome = value == .complete ? "complete" : "incomplete"
            closureCause = cause == .automatic ? "automatic" : "manual"
        }
    }

    func domain() throws -> RecordedFlightEvent {
        let payload: RecordedFlightEventPayload
        switch kind {
        case "recordingStarted" where startCause == "startLegWithoutLocation":
            payload = .recordingStarted(cause: .startLegWithoutLocation)
        case "legStarted":
            guard let legID else { throw FlightRecordingStoreError.corruptPackage(id: nil) }
            payload = .legStarted(legID: legID)
        case "destinationIdentified":
            guard let legID else { throw FlightRecordingStoreError.corruptPackage(id: nil) }
            payload = .destinationIdentified(legID: legID)
        case "identificationPointReached":
            guard let legID, let targetID else { throw FlightRecordingStoreError.corruptPackage(id: nil) }
            payload = .identificationPointReached(key: IdentificationPointKey(
                legID: legID,
                identificationPointID: targetID
            ))
        case "waypointReached":
            guard let legID else { throw FlightRecordingStoreError.corruptPackage(id: nil) }
            payload = .waypointReached(legID: legID)
        case "automaticNextLegTransition":
            guard let legID, let successorLegID else { throw FlightRecordingStoreError.corruptPackage(id: nil) }
            payload = .automaticNextLegTransition(fromLegID: legID, toLegID: successorLegID)
        case "finalWaypointReached":
            guard let legID else { throw FlightRecordingStoreError.corruptPackage(id: nil) }
            payload = .finalWaypointReached(legID: legID)
        case "automaticLegRecovery":
            guard let legID else { throw FlightRecordingStoreError.corruptPackage(id: nil) }
            payload = .automaticLegRecovery(legID: legID)
        case "etaRevised":
            guard let legID, let targetID, let targetKind, let committedValue else {
                throw FlightRecordingStoreError.corruptPackage(id: nil)
            }
            let kind: NavigationTimingTargetKey.Kind = targetKind == "destination" ? .destination : .identificationPoint
            payload = .etaRevised(
                target: NavigationTimingTargetKey(legID: legID, kind: kind, targetID: targetID),
                priorSeconds: priorValue,
                committedSeconds: committedValue
            )
        case "headingRevised":
            guard let legID, let priorValue, let committedValue else {
                throw FlightRecordingStoreError.corruptPackage(id: nil)
            }
            payload = .headingRevised(legID: legID, priorDegrees: priorValue, committedDegrees: committedValue)
        case "reachUndone":
            guard let linkedEventID else { throw FlightRecordingStoreError.corruptPackage(id: nil) }
            payload = .reachUndone(originalEventID: linkedEventID)
        case "positionCheckRequested":
            payload = .positionCheckRequested
        case "positionCheckEnded" where outcome == "endedWithoutDisclosure":
            payload = .positionCheckEnded(outcome: .endedWithoutDisclosure)
        case "positionCheckEnded" where outcome == "disclosed":
            guard let latitudeDegrees, let longitudeDegrees, let sampleObservedAt, let sampleAccuracyMeters else {
                throw FlightRecordingStoreError.corruptPackage(id: nil)
            }
            payload = .positionCheckEnded(outcome: .disclosed(sample: PositionCheckRecordedSample(
                coordinate: WGS84Coordinate(latitudeDegrees: latitudeDegrees, longitudeDegrees: longitudeDegrees),
                observedAt: sampleObservedAt,
                horizontalAccuracyMeters: sampleAccuracyMeters
            )))
        case "storageDegraded":
            guard let degradationReason, let reason = RecordingStorageDegradation(rawValue: degradationReason) else {
                throw FlightRecordingStoreError.corruptPackage(id: nil)
            }
            payload = .storageDegraded(reason: reason)
        case "physicalStateChanged":
            guard let from = physicalStateFrom.flatMap(PhysicalFlightState.init(rawValue:)),
                  let to = physicalStateTo.flatMap(PhysicalFlightState.init(rawValue:)) else {
                throw FlightRecordingStoreError.corruptPackage(id: nil)
            }
            payload = .physicalStateChanged(from: from, to: to)
        case "physicalStateCorrected":
            guard let linkedEventID,
                  let from = physicalStateFrom.flatMap(PhysicalFlightState.init(rawValue:)),
                  let to = physicalStateTo.flatMap(PhysicalFlightState.init(rawValue:)) else {
                throw FlightRecordingStoreError.corruptPackage(id: nil)
            }
            payload = .physicalStateCorrected(originalEventID: linkedEventID, from: from, to: to)
        case "navigationCompleted":
            payload = .navigationCompleted
        case "manualEnd":
            payload = .manualEnd
        case "recordingClosed":
            guard let outcome = outcome.flatMap(FlightRecordingClosure.Outcome.init(storageValue:)),
                  let cause = closureCause.flatMap(FlightRecordingClosure.Cause.init(storageValue:)) else {
                throw FlightRecordingStoreError.corruptPackage(id: nil)
            }
            payload = .recordingClosed(outcome: outcome, cause: cause)
        default:
            throw FlightRecordingStoreError.corruptPackage(id: nil)
        }
        return RecordedFlightEvent(
            id: id,
            sequence: sequence,
            occurredAt: occurredAt,
            elapsed: Duration(
                secondsComponent: elapsedSeconds,
                attosecondsComponent: elapsedAttoseconds
            ),
            origin: origin,
            payload: payload
        )
    }
}

nonisolated enum FlightRecordingCoding {
    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

nonisolated private extension PhysicalFlightState {
    var storageValue: String {
        switch self {
        case .preparing: "preparing"
        case .groundMovement: "groundMovement"
        case .airborne: "airborne"
        case .landedAwaitingStop: "landedAwaitingStop"
        case .stopped: "stopped"
        case .unavailable: "unavailable"
        }
    }

    init?(storageValue: String) {
        switch storageValue {
        case "preparing": self = .preparing
        case "groundMovement": self = .groundMovement
        case "airborne": self = .airborne
        case "landedAwaitingStop": self = .landedAwaitingStop
        case "stopped": self = .stopped
        case "unavailable": self = .unavailable
        default: return nil
        }
    }
}

nonisolated private extension RecordedNavigationState {
    var storageValue: String {
        switch self {
        case .ready: "ready"
        case .active: "active"
        case .reachedFinalWaypoint: "reachedFinalWaypoint"
        case .complete: "complete"
        }
    }

    init?(storageValue: String) {
        switch storageValue {
        case "ready": self = .ready
        case "active": self = .active
        case "reachedFinalWaypoint": self = .reachedFinalWaypoint
        case "complete": self = .complete
        default: return nil
        }
    }
}

nonisolated private extension GPSCoverageState {
    var storageValue: String {
        switch self {
        case .available: "available"
        case .partial: "partial"
        case .unavailable: "unavailable"
        }
    }

    init?(storageValue: String) {
        switch storageValue {
        case "available": self = .available
        case "partial": self = .partial
        case "unavailable": self = .unavailable
        default: return nil
        }
    }
}

nonisolated private extension FlightRecordingClosure.Outcome {
    init?(storageValue: String) {
        switch storageValue {
        case "complete": self = .complete
        case "incomplete": self = .incomplete
        default: return nil
        }
    }
}

nonisolated private extension FlightRecordingClosure.Cause {
    init?(storageValue: String) {
        switch storageValue {
        case "automatic": self = .automatic
        case "manual": self = .manual
        default: return nil
        }
    }
}
