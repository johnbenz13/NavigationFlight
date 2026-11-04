import Foundation

nonisolated struct RecordedFlightPlanSnapshot: Equatable, Sendable {
    let id: UUID
    let title: String
    let legIDs: [UUID]
}

nonisolated enum PhysicalFlightState: Equatable, Sendable {
    case preparing
    case groundMovement
    case airborne
    case landedAwaitingStop
    case stopped
    case unavailable
}

nonisolated enum RecordedNavigationState: Equatable, Sendable {
    case ready
    case active
    case reachedFinalWaypoint
    case complete
}

nonisolated enum GPSCoverageState: Equatable, Sendable {
    case available
    case partial
    case unavailable
}

nonisolated struct FlightRecordingClosure: Equatable, Sendable {
    enum Outcome: Equatable, Sendable {
        case complete
        case incomplete
    }

    enum Cause: Equatable, Sendable {
        case automatic
        case manual
    }

    let outcome: Outcome
    let cause: Cause
    let closedAt: Date
    let elapsed: Duration
    let landingEvidenceAvailable: Bool
}

nonisolated struct FlightRecordingPromotion: Equatable, Sendable {
    var recording: FlightRecording
    let events: [RecordedFlightEvent]
}

nonisolated struct FlightRecording: Equatable, Sendable, Identifiable {
    enum TransitionError: Error, Equatable, Sendable {
        case invalidEventIdentifierCount
        case legNotInFlightPlan(UUID)
        case navigationAlreadyActive
        case recordingAlreadyClosed
        case timestampPrecedesStart
    }

    let id: UUID
    let flightID: UUID
    let flightPlanSnapshot: RecordedFlightPlanSnapshot
    let startedAt: Date
    private(set) var physicalState: PhysicalFlightState
    private(set) var navigationState: RecordedNavigationState
    private(set) var gpsCoverage: GPSCoverageState
    private(set) var closure: FlightRecordingClosure?
    private(set) var nextEventSequence: UInt64

    static func promoteForStartLeg(
        id: UUID,
        flightID: UUID,
        flightPlanSnapshot: RecordedFlightPlanSnapshot,
        legID: UUID,
        startedAt: Date,
        eventIDs: [UUID]
    ) throws -> FlightRecordingPromotion {
        guard eventIDs.count == 2 else { throw TransitionError.invalidEventIdentifierCount }
        var recording = FlightRecording(
            id: id,
            flightID: flightID,
            flightPlanSnapshot: flightPlanSnapshot,
            startedAt: startedAt,
            physicalState: .unavailable,
            navigationState: .ready,
            gpsCoverage: .unavailable,
            closure: nil,
            nextEventSequence: 0
        )
        let recordingStarted = recording.makeEvent(
            id: eventIDs[0],
            occurredAt: startedAt,
            elapsed: .zero,
            origin: .pilot,
            payload: .recordingStarted(cause: .startLegWithoutLocation)
        )
        let legStarted = try recording.startLeg(
            legID: legID,
            at: startedAt,
            elapsed: .zero,
            eventID: eventIDs[1]
        )
        return FlightRecordingPromotion(
            recording: recording,
            events: [recordingStarted, legStarted]
        )
    }

    mutating func startLeg(
        legID: UUID,
        at timestamp: Date,
        elapsed: Duration,
        eventID: UUID
    ) throws -> RecordedFlightEvent {
        guard closure == nil else { throw TransitionError.recordingAlreadyClosed }
        guard navigationState == .ready else { throw TransitionError.navigationAlreadyActive }
        guard flightPlanSnapshot.legIDs.contains(legID) else {
            throw TransitionError.legNotInFlightPlan(legID)
        }
        guard timestamp >= startedAt else { throw TransitionError.timestampPrecedesStart }

        navigationState = .active
        return makeEvent(
            id: eventID,
            occurredAt: timestamp,
            elapsed: elapsed,
            origin: .pilot,
            payload: .legStarted(legID: legID)
        )
    }

    mutating func endManually(
        at timestamp: Date,
        elapsed: Duration,
        eventIDs: [UUID]
    ) throws -> [RecordedFlightEvent] {
        guard closure == nil else { throw TransitionError.recordingAlreadyClosed }
        guard eventIDs.count == 2 else { throw TransitionError.invalidEventIdentifierCount }
        guard timestamp >= startedAt else { throw TransitionError.timestampPrecedesStart }

        let manualEnd = makeEvent(
            id: eventIDs[0],
            occurredAt: timestamp,
            elapsed: elapsed,
            origin: .pilot,
            payload: .manualEnd
        )
        let closure = FlightRecordingClosure(
            outcome: navigationState == .complete ? .complete : .incomplete,
            cause: .manual,
            closedAt: timestamp,
            elapsed: elapsed,
            landingEvidenceAvailable: false
        )
        let closed = makeEvent(
            id: eventIDs[1],
            occurredAt: timestamp,
            elapsed: elapsed,
            origin: .system,
            payload: .recordingClosed(outcome: closure.outcome, cause: closure.cause)
        )
        self.closure = closure
        return [manualEnd, closed]
    }

    mutating func completeNavigation(
        at timestamp: Date,
        elapsed: Duration,
        eventID: UUID
    ) throws -> RecordedFlightEvent {
        guard closure == nil else { throw TransitionError.recordingAlreadyClosed }
        guard navigationState == .active || navigationState == .reachedFinalWaypoint else {
            throw TransitionError.navigationAlreadyActive
        }
        guard timestamp >= startedAt else { throw TransitionError.timestampPrecedesStart }

        navigationState = .complete
        return makeEvent(
            id: eventID,
            occurredAt: timestamp,
            elapsed: elapsed,
            origin: .pilot,
            payload: .navigationCompleted
        )
    }

    mutating func recordNavigationEvents(
        at timestamp: Date,
        elapsed: Duration,
        entries: [(origin: RecordedFlightEvent.Origin, payload: RecordedFlightEventPayload)],
        eventIDs: [UUID],
        navigationState: RecordedNavigationState? = nil
    ) throws -> [RecordedFlightEvent] {
        guard closure == nil else { throw TransitionError.recordingAlreadyClosed }
        guard self.navigationState != .ready else { throw TransitionError.navigationAlreadyActive }
        guard entries.count == eventIDs.count else { throw TransitionError.invalidEventIdentifierCount }
        guard timestamp >= startedAt else { throw TransitionError.timestampPrecedesStart }

        let events = zip(entries, eventIDs).map { entry, id in
            makeEvent(
                id: id,
                occurredAt: timestamp,
                elapsed: elapsed,
                origin: entry.origin,
                payload: entry.payload
            )
        }
        if let navigationState {
            self.navigationState = navigationState
        }
        return events
    }

    private mutating func makeEvent(
        id: UUID,
        occurredAt: Date,
        elapsed: Duration,
        origin: RecordedFlightEvent.Origin,
        payload: RecordedFlightEventPayload
    ) -> RecordedFlightEvent {
        defer { nextEventSequence += 1 }
        return RecordedFlightEvent(
            id: id,
            sequence: nextEventSequence,
            occurredAt: occurredAt,
            elapsed: elapsed,
            origin: origin,
            payload: payload
        )
    }

    func restoring(
        closure: FlightRecordingClosure,
        nextEventSequence: UInt64? = nil
    ) -> FlightRecording {
        FlightRecording(
            id: id,
            flightID: flightID,
            flightPlanSnapshot: flightPlanSnapshot,
            startedAt: startedAt,
            physicalState: physicalState,
            navigationState: navigationState,
            gpsCoverage: gpsCoverage,
            closure: closure,
            nextEventSequence: nextEventSequence ?? self.nextEventSequence
        )
    }

    func restoring(
        navigationState: RecordedNavigationState,
        nextEventSequence: UInt64
    ) -> FlightRecording {
        FlightRecording(
            id: id,
            flightID: flightID,
            flightPlanSnapshot: flightPlanSnapshot,
            startedAt: startedAt,
            physicalState: physicalState,
            navigationState: navigationState,
            gpsCoverage: gpsCoverage,
            closure: closure,
            nextEventSequence: nextEventSequence
        )
    }
}
