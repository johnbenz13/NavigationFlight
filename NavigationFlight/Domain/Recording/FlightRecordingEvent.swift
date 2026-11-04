import Foundation

nonisolated struct RecordedFlightEvent: Equatable, Sendable, Identifiable {
    enum Origin: String, Codable, Sendable {
        case pilot
        case automatic
        case recovery
        case system
    }

    let id: UUID
    let sequence: UInt64
    let occurredAt: Date
    let elapsed: Duration
    let origin: Origin
    let payload: RecordedFlightEventPayload
}

nonisolated enum RecordedFlightEventPayload: Equatable, Sendable {
    enum RecordingStartCause: Equatable, Sendable {
        case startLegWithoutLocation
    }

    case recordingStarted(cause: RecordingStartCause)
    case legStarted(legID: UUID)
    case navigationCompleted
    case manualEnd
    case recordingClosed(
        outcome: FlightRecordingClosure.Outcome,
        cause: FlightRecordingClosure.Cause
    )
}
