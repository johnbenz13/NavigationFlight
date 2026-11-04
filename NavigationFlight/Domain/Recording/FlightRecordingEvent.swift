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
        case automaticTakeoff
        case partialStart
    }

    case recordingStarted(cause: RecordingStartCause)
    case legStarted(legID: UUID)
    case destinationIdentified(legID: UUID)
    case identificationPointReached(key: IdentificationPointKey)
    case waypointReached(legID: UUID)
    case automaticNextLegTransition(fromLegID: UUID, toLegID: UUID)
    case finalWaypointReached(legID: UUID)
    case automaticLegRecovery(legID: UUID)
    case etaRevised(
        target: NavigationTimingTargetKey,
        priorSeconds: Int?,
        committedSeconds: Int
    )
    case headingRevised(legID: UUID, priorDegrees: Int, committedDegrees: Int)
    case reachUndone(originalEventID: UUID)
    case positionCheckRequested
    case positionCheckEnded(outcome: PositionCheckRecordedOutcome)
    case storageDegraded(reason: RecordingStorageDegradation)
    case locationAvailabilityChanged(RecordingLocationAvailability)
    case physicalStateChanged(from: PhysicalFlightState, to: PhysicalFlightState)
    case physicalStateCorrected(
        originalEventID: UUID,
        from: PhysicalFlightState,
        to: PhysicalFlightState
    )
    case navigationCompleted
    case manualEnd
    case recordingClosed(
        outcome: FlightRecordingClosure.Outcome,
        cause: FlightRecordingClosure.Cause
    )
}

nonisolated enum RecordingLocationAvailability: String, Codable, Equatable, Sendable {
    case servicesDisabled
    case signalLost
    case permissionDenied
    case permissionRestricted
    case resumed
}

nonisolated enum PositionCheckRecordedOutcome: Equatable, Sendable {
    case disclosed(sample: PositionCheckRecordedSample)
    case endedWithoutDisclosure
}

nonisolated struct PositionCheckRecordedSample: Equatable, Sendable {
    let coordinate: WGS84Coordinate
    let observedAt: Date
    let horizontalAccuracyMeters: Double
}

nonisolated enum RecordingStorageDegradation: String, Codable, Equatable, Sendable {
    case trackWriteFailed
    case lowStorage
    case bufferOverflow
}
