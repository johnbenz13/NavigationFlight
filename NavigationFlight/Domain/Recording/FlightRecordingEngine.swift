import Foundation

nonisolated enum RecordedNavigationCommand: Sendable {
    case startLeg(at: Date, recordingID: UUID, eventIDs: [UUID])
    case identifyDestination(at: Date, elapsed: Duration, eventID: UUID)
    case reachIdentificationPoint(
        key: IdentificationPointKey,
        orderedActiveLegPointKeys: [IdentificationPointKey],
        at: Date,
        elapsed: Duration,
        eventID: UUID,
        nextETATarget: NavigationTimingTargetKey?,
        nextETAPlannedElapsedSeconds: Int?
    )
    case reachCurrentWaypoint(
        orderedActiveLegPointKeys: [IdentificationPointKey],
        at: Date,
        elapsed: Duration,
        eventIDs: [UUID]
    )
    case completeNavigation(at: Date, elapsed: Duration, eventID: UUID)
    case automaticLegRecovery(legID: UUID, at: Date, elapsed: Duration, eventID: UUID)
    case reviseETA(
        target: NavigationTimingTargetKey,
        plannedElapsedSeconds: Int,
        committedSeconds: Int,
        at: Date,
        elapsed: Duration,
        eventID: UUID
    )
    case reviseHeading(
        legID: UUID,
        baselineDegrees: Int,
        committedDegrees: Int,
        at: Date,
        elapsed: Duration,
        eventID: UUID
    )
    case undoReach(originalEventID: UUID, at: Date, elapsed: Duration, eventID: UUID)
    case requestPositionCheck(at: Date, elapsed: Duration, eventID: UUID)
    case endPositionCheck(outcome: PositionCheckRecordedOutcome, at: Date, elapsed: Duration, eventID: UUID)
    case recordStorageDegradation(reason: RecordingStorageDegradation, at: Date, elapsed: Duration, eventID: UUID)
}

nonisolated struct CommittedNavigationTransition: Equatable, Sendable {
    let flight: Flight
    let recording: FlightRecording
    let eventIDs: [UUID]
}

nonisolated struct FlightRecordingEngineSnapshot: Equatable, Sendable {
    let flight: Flight
    let recording: FlightRecording?
    let storageDegradations: Set<RecordingStorageDegradation>
}

actor FlightRecordingEngine {
    enum EngineError: Error, Equatable, Sendable {
        case navigationNotReadyForCompletion
    }

    private let store: any FlightRecordingStore
    private let flightPlanSnapshot: RecordedFlightPlanSnapshot
    private var flight: Flight
    private var recording: FlightRecording?
    private var storageDegradations: Set<RecordingStorageDegradation> = []

    init(
        store: any FlightRecordingStore,
        flight: Flight,
        flightPlanSnapshot: RecordedFlightPlanSnapshot
    ) {
        self.store = store
        self.flight = flight
        self.flightPlanSnapshot = flightPlanSnapshot
    }

    func promoteForStartLeg(
        at timestamp: Date,
        recordingID: UUID,
        eventIDs: [UUID]
    ) async throws -> CommittedNavigationTransition {
        try await commit(
            .startLeg(at: timestamp, recordingID: recordingID, eventIDs: eventIDs)
        )
    }

    func commit(
        _ command: RecordedNavigationCommand
    ) async throws -> CommittedNavigationTransition {
        switch command {
        case .startLeg(let timestamp, let recordingID, let eventIDs):
            guard recording == nil else {
                throw FlightRecording.TransitionError.navigationAlreadyActive
            }
            let currentFlight = flight
            let candidateFlight = try await MainActor.run {
                var candidate = currentFlight
                try candidate.startLeg(at: timestamp)
                return candidate
            }
            let legID = candidateFlight.legIDs[candidateFlight.activeLegIndex]
            let promotion = try FlightRecording.promoteForStartLeg(
                id: recordingID,
                flightID: candidateFlight.id,
                flightPlanSnapshot: flightPlanSnapshot,
                legID: legID,
                startedAt: timestamp,
                eventIDs: eventIDs
            )

            try await store.create(
                FlightRecordingSeed(recording: promotion.recording, events: promotion.events)
            )
            flight = candidateFlight
            recording = promotion.recording
            return CommittedNavigationTransition(
                flight: candidateFlight,
                recording: promotion.recording,
                eventIDs: promotion.events.map(\.id)
            )
        case .identifyDestination(let timestamp, let elapsed, let eventID):
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: [eventID]) { candidate in
                let legID = candidate.legIDs[candidate.activeLegIndex]
                try candidate.identifyDestination(at: timestamp)
                return ([(.pilot, .destinationIdentified(legID: legID))], nil)
            }
        case .reachIdentificationPoint(
            let key,
            let orderedKeys,
            let timestamp,
            let elapsed,
            let eventID,
            let nextETATarget,
            let nextETAPlannedElapsedSeconds
        ):
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: [eventID]) { candidate in
                try candidate.reachIdentificationPoint(
                    key: key,
                    orderedActiveLegPointKeys: orderedKeys,
                    at: timestamp
                )
                if let nextETATarget, let nextETAPlannedElapsedSeconds {
                    candidate.initializePilotETA(
                        targetKey: nextETATarget,
                        plannedElapsedSeconds: nextETAPlannedElapsedSeconds
                    )
                }
                return ([(.pilot, .identificationPointReached(key: key))], nil)
            }
        case .reachCurrentWaypoint(let orderedKeys, let timestamp, let elapsed, let eventIDs):
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: eventIDs) { candidate in
                let departingLegID = candidate.legIDs[candidate.activeLegIndex]
                try candidate.reachCurrentWaypoint(orderedActiveLegPointKeys: orderedKeys, at: timestamp)
                if candidate.legState == .completed {
                    return ([
                        (.pilot, .waypointReached(legID: departingLegID)),
                        (.automatic, .finalWaypointReached(legID: departingLegID))
                    ], .reachedFinalWaypoint)
                }
                let successorLegID = candidate.legIDs[candidate.activeLegIndex]
                return ([
                    (.pilot, .waypointReached(legID: departingLegID)),
                    (.automatic, .automaticNextLegTransition(
                        fromLegID: departingLegID,
                        toLegID: successorLegID
                    ))
                ], nil)
            }
        case .completeNavigation(let timestamp, let elapsed, let eventID):
            guard var candidateRecording = recording else {
                throw EngineError.navigationNotReadyForCompletion
            }
            let currentFlight = flight
            let isComplete = await MainActor.run { currentFlight.legState == .completed }
            guard isComplete else { throw EngineError.navigationNotReadyForCompletion }
            let event = try candidateRecording.completeNavigation(
                at: timestamp,
                elapsed: elapsed,
                eventID: eventID
            )
            try await store.appendEvent(event, recordingID: candidateRecording.id, synchronize: true)
            recording = candidateRecording
            return CommittedNavigationTransition(flight: flight, recording: candidateRecording, eventIDs: [eventID])
        case .automaticLegRecovery(let legID, let timestamp, let elapsed, let eventID):
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: [eventID]) { candidate in
                guard candidate.legState == .active,
                      candidate.legIDs[candidate.activeLegIndex] == legID else {
                    throw Flight.TransitionError.legNotActive
                }
                return ([(.recovery, .automaticLegRecovery(legID: legID))], nil)
            }
        case .reviseETA(
            let target,
            let plannedElapsedSeconds,
            let committedSeconds,
            let timestamp,
            let elapsed,
            let eventID
        ):
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: [eventID]) { candidate in
                let prior = candidate.committedPilotETA(targetKey: target)
                candidate.initializePilotETA(
                    targetKey: target,
                    plannedElapsedSeconds: prior ?? plannedElapsedSeconds
                )
                if prior != nil {
                    candidate.beginEditingPilotETA(targetKey: target)
                }
                candidate.adjustPilotETA(
                    targetKey: target,
                    by: committedSeconds - (candidate.pilotETAState(targetKey: target)?.draftSeconds ?? committedSeconds)
                )
                guard candidate.commitPilotETA(targetKey: target) == nil,
                      candidate.committedPilotETA(targetKey: target) == committedSeconds,
                      prior != committedSeconds else {
                    throw Flight.TransitionError.legNotActive
                }
                return ([(.pilot, .etaRevised(
                    target: target,
                    priorSeconds: prior,
                    committedSeconds: committedSeconds
                ))], nil)
            }
        case .reviseHeading(
            let legID,
            let baselineDegrees,
            let committedDegrees,
            let timestamp,
            let elapsed,
            let eventID
        ):
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: [eventID]) { candidate in
                guard candidate.legIDs[candidate.activeLegIndex] == legID else {
                    throw Flight.TransitionError.legNotActive
                }
                let prior = candidate.pilotHeadingState(for: legID)?.operationalDegrees
                    ?? Flight.normalizedHeading(baselineDegrees)
                guard prior != Flight.normalizedHeading(committedDegrees) else {
                    throw Flight.TransitionError.legNotActive
                }
                candidate.openPilotHeadingEditor(baselineDegrees: baselineDegrees)
                candidate.adjustPilotHeading(by: committedDegrees - (candidate.pilotHeadingState(for: legID)?.draftDegrees ?? committedDegrees))
                candidate.commitPilotHeading()
                return ([(.pilot, .headingRevised(
                    legID: legID,
                    priorDegrees: prior,
                    committedDegrees: Flight.normalizedHeading(committedDegrees)
                ))], nil)
            }
        case .undoReach(let originalEventID, let timestamp, let elapsed, let eventID):
            return try await appendOperationalEvent(
                .reachUndone(originalEventID: originalEventID),
                origin: .pilot,
                at: timestamp,
                elapsed: elapsed,
                eventID: eventID
            )
        case .requestPositionCheck(let timestamp, let elapsed, let eventID):
            return try await appendOperationalEvent(
                .positionCheckRequested,
                origin: .pilot,
                at: timestamp,
                elapsed: elapsed,
                eventID: eventID
            )
        case .endPositionCheck(let outcome, let timestamp, let elapsed, let eventID):
            return try await appendOperationalEvent(
                .positionCheckEnded(outcome: outcome),
                origin: .system,
                at: timestamp,
                elapsed: elapsed,
                eventID: eventID
            )
        case .recordStorageDegradation(let reason, let timestamp, let elapsed, let eventID):
            let transition = try await appendOperationalEvent(
                .storageDegraded(reason: reason),
                origin: .system,
                at: timestamp,
                elapsed: elapsed,
                eventID: eventID
            )
            storageDegradations.insert(reason)
            return transition
        }
    }

    private func commitExistingRecording(
        at timestamp: Date,
        elapsed: Duration,
        eventIDs: [UUID],
        transition: @MainActor (inout Flight) throws -> (
            entries: [(RecordedFlightEvent.Origin, RecordedFlightEventPayload)],
            navigationState: RecordedNavigationState?
        )
    ) async throws -> CommittedNavigationTransition {
        guard var candidateRecording = recording else {
            throw FlightRecording.TransitionError.recordingAlreadyClosed
        }
        let currentFlight = flight
        let result = try await MainActor.run {
            var candidateFlight = currentFlight
            let output = try transition(&candidateFlight)
            return (candidateFlight, output)
        }
        let events = try candidateRecording.recordNavigationEvents(
            at: timestamp,
            elapsed: elapsed,
            entries: result.1.entries,
            eventIDs: eventIDs,
            navigationState: result.1.navigationState
        )
        for (index, event) in events.enumerated() {
            try await store.appendEvent(
                event,
                recordingID: candidateRecording.id,
                synchronize: index == events.indices.last
            )
        }
        flight = result.0
        recording = candidateRecording
        return CommittedNavigationTransition(
            flight: result.0,
            recording: candidateRecording,
            eventIDs: events.map(\.id)
        )
    }

    private func appendOperationalEvent(
        _ payload: RecordedFlightEventPayload,
        origin: RecordedFlightEvent.Origin,
        at timestamp: Date,
        elapsed: Duration,
        eventID: UUID
    ) async throws -> CommittedNavigationTransition {
        guard var candidateRecording = recording else {
            throw FlightRecording.TransitionError.recordingAlreadyClosed
        }
        let events = try candidateRecording.recordNavigationEvents(
            at: timestamp,
            elapsed: elapsed,
            entries: [(origin, payload)],
            eventIDs: [eventID]
        )
        try await store.appendEvent(events[0], recordingID: candidateRecording.id, synchronize: true)
        recording = candidateRecording
        return CommittedNavigationTransition(
            flight: flight,
            recording: candidateRecording,
            eventIDs: [eventID]
        )
    }

    func endManually(
        at timestamp: Date,
        elapsed: Duration,
        eventIDs: [UUID]
    ) async throws -> FlightRecordingEngineSnapshot {
        guard var candidate = recording else {
            throw FlightRecording.TransitionError.recordingAlreadyClosed
        }
        let events = try candidate.endManually(
            at: timestamp,
            elapsed: elapsed,
            eventIDs: eventIDs
        )
        for event in events {
            try await store.appendEvent(
                event,
                recordingID: candidate.id,
                synchronize: true
            )
        }
        guard let closure = candidate.closure else {
            throw FlightRecording.TransitionError.recordingAlreadyClosed
        }
        try await store.close(id: candidate.id, closure: closure)
        recording = candidate
        return snapshot()
    }

    func completeNavigation(
        flight completedFlight: Flight,
        at timestamp: Date,
        elapsed: Duration,
        eventID: UUID
    ) async throws -> FlightRecordingEngineSnapshot {
        let currentFlightID = flight.id
        let isReadyForCompletion = await MainActor.run {
            completedFlight.id == currentFlightID && completedFlight.legState == .completed
        }
        guard isReadyForCompletion, var candidate = recording else {
            throw EngineError.navigationNotReadyForCompletion
        }
        let event = try candidate.completeNavigation(
            at: timestamp,
            elapsed: elapsed,
            eventID: eventID
        )
        try await store.appendEvent(event, recordingID: candidate.id, synchronize: true)
        flight = completedFlight
        recording = candidate
        return snapshot()
    }

    func snapshot() -> FlightRecordingEngineSnapshot {
        FlightRecordingEngineSnapshot(
            flight: flight,
            recording: recording,
            storageDegradations: storageDegradations
        )
    }
}
