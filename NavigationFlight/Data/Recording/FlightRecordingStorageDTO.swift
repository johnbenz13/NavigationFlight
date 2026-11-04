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
        navigationState restoredNavigationState: RecordedNavigationState? = nil,
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
            physicalState: physicalState,
            navigationState: restoredNavigationState ?? navigationState,
            gpsCoverage: gpsCoverage,
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

nonisolated struct RecordedFlightEventDTO: Codable {
    let id: UUID
    let sequence: UInt64
    let occurredAt: Date
    let elapsedSeconds: Int64
    let elapsedAttoseconds: Int64
    let origin: RecordedFlightEvent.Origin
    let kind: String
    let legID: UUID?
    let startCause: String?
    let outcome: String?
    let closureCause: String?

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
            startCause = "startLegWithoutLocation"
            outcome = nil
            closureCause = nil
        case .legStarted(let value):
            kind = "legStarted"
            legID = value
            startCause = nil
            outcome = nil
            closureCause = nil
        case .navigationCompleted:
            kind = "navigationCompleted"
            legID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .manualEnd:
            kind = "manualEnd"
            legID = nil
            startCause = nil
            outcome = nil
            closureCause = nil
        case .recordingClosed(let value, let cause):
            kind = "recordingClosed"
            legID = nil
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
