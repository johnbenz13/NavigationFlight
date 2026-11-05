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

nonisolated enum FlightRecordingLocationOutcome: Equatable, Sendable {
    case none
    case provisionalBegan
    case provisionalDiscarded
    case promoted(FlightRecording, partial: Bool)
    case physicalStateChanged(FlightRecording)
    case physicalStateCorrected(FlightRecording)
    case closed(FlightRecording)
    case promotionPersistenceFailed
}

actor FlightRecordingEngine {
    enum EngineError: Error, Equatable, Sendable {
        case navigationNotReadyForCompletion
    }

    private let store: any FlightRecordingStore
    private let flightPlanSnapshot: RecordedFlightPlanSnapshot
    private var detector: PhysicalFlightDetector
    private var flight: Flight
    private var recording: FlightRecording?
    private var storageDegradations: Set<RecordingStorageDegradation> = []
    private var isArmed = false
    private var rollingBuffer: [RecordedTrackSample] = []
    private var deliveredSamples: [RecordedTrackSample] = []
    private var activeSegmentID: UUID?
    private var segmentNeedsReopening = false
    private var lastPhysicalTransitionEventID: UUID?
    private var latestRelativeBarometricAltitude: (meters: Double, observedAt: Date)?
    private var latestDeviceHeading: (degrees: Double, accuracyDegrees: Double?, observedAt: Date)?
    private var barometricAltitudeAnchorOffsetMeters: Double?
    private static let supplementalFreshnessInterval: TimeInterval = 5

    init(
        store: any FlightRecordingStore,
        flight: Flight,
        flightPlanSnapshot: RecordedFlightPlanSnapshot,
        detectorPolicy: PhysicalFlightDetectionPolicy = .production
    ) {
        self.store = store
        self.flight = flight
        self.flightPlanSnapshot = flightPlanSnapshot
        detector = PhysicalFlightDetector(policy: detectorPolicy)
    }

    init(
        store: any FlightRecordingStore,
        recoveredFlight: Flight,
        recoveredRecording: FlightRecording,
        detectorPolicy: PhysicalFlightDetectionPolicy = .production,
        storageDegradations: Set<RecordingStorageDegradation> = []
    ) {
        self.store = store
        flight = recoveredFlight
        flightPlanSnapshot = recoveredRecording.flightPlanSnapshot
        recording = recoveredRecording
        self.storageDegradations = storageDegradations
        detector = PhysicalFlightDetector(policy: detectorPolicy)
        segmentNeedsReopening = true
    }

    func arm() {
        isArmed = true
    }

    func disarm() {
        isArmed = false
        rollingBuffer.removeAll()
        deliveredSamples.removeAll()
        activeSegmentID = nil
        segmentNeedsReopening = false
        latestRelativeBarometricAltitude = nil
        latestDeviceHeading = nil
        barometricAltitudeAnchorOffsetMeters = nil
    }

    func ingestSupplemental(_ event: SupplementalSensorEvent) {
        switch event {
        case .relativeBarometricAltitude(let meters, let observedAt):
            guard meters.isFinite, observedAt.timeIntervalSinceReferenceDate.isFinite else { return }
            latestRelativeBarometricAltitude = (meters, observedAt)
        case .deviceHeading(let degrees, let accuracyDegrees, let observedAt):
            guard degrees.isFinite, (0..<360).contains(degrees),
                  observedAt.timeIntervalSinceReferenceDate.isFinite,
                  accuracyDegrees.map({ $0.isFinite && $0 >= 0 }) ?? true else { return }
            latestDeviceHeading = (degrees, accuracyDegrees, observedAt)
        }
    }

    func ingest(_ event: LocationSourceEvent, monotonicTime: Duration) async -> FlightRecordingLocationOutcome {
        guard isArmed else { return .none }
        switch event {
        case .sample(let sourceSample, _):
            guard let baseSample = RecordedTrackSample(sourceSample) else { return .none }
            let sample = associateSupplemental(with: baseSample)
            guard !deliveredSamples.contains(sample) else { return .none }
            deliveredSamples.append(sample)
            if recording == nil {
                rollingBuffer.append(sample)
                let cutoff = sample.observedAt.addingTimeInterval(-120)
                rollingBuffer.removeAll { $0.observedAt < cutoff }
                let events = detector.process(sourceSample, monotonicTime: monotonicTime)
                if events.contains(.provisionalTimedOut) {
                    rollingBuffer.removeAll()
                    return .provisionalDiscarded
                }
                if events.contains(.takeoffDetected) || events.contains(.partialStartDetected) {
                    let partial = events.contains(.partialStartDetected)
                    let promotion = FlightRecording.promoteAutomatically(
                        id: UUID(),
                        flightID: flight.id,
                        flightPlanSnapshot: flightPlanSnapshot,
                        startedAt: rollingBuffer.first?.observedAt ?? sourceSample.observedAt,
                        promotedAt: sourceSample.observedAt,
                        partial: partial,
                        eventID: UUID()
                    )
                    let segmentID = UUID()
                    activeSegmentID = segmentID
                    do {
                        try await store.create(FlightRecordingSeed(
                            recording: promotion.recording,
                            events: promotion.events,
                            trackSegments: [RecordedTrackSegment(id: segmentID, samples: rollingBuffer)]
                        ))
                    } catch {
                        activeSegmentID = nil
                        return .promotionPersistenceFailed
                    }
                    recording = promotion.recording
                    lastPhysicalTransitionEventID = promotion.events.last?.id
                    return .promoted(promotion.recording, partial: partial)
                }
                if events.contains(.groundMovementBegan) {
                    return .provisionalBegan
                }
            } else if let currentRecording = recording {
                if segmentNeedsReopening {
                    var resumedRecording = currentRecording
                    let elapsed = Duration.seconds(max(0, sourceSample.observedAt.timeIntervalSince(resumedRecording.startedAt)))
                    if let event = try? resumedRecording.recordLocationAvailabilityChange(
                        .resumed,
                        at: sourceSample.observedAt,
                        elapsed: elapsed,
                        eventID: UUID()
                    ), (try? await store.appendEvent(
                        event,
                        recordingID: resumedRecording.id,
                        synchronize: true
                    )) != nil {
                        recording = resumedRecording
                    }
                }
                if segmentNeedsReopening || activeSegmentID == nil {
                    activeSegmentID = UUID()
                    segmentNeedsReopening = false
                }
                guard let segmentID = activeSegmentID else { return .none }
                try? await store.appendTrackBatch(RecordedTrackBatch(
                    recordingID: currentRecording.id,
                    segmentID: segmentID,
                    samples: [sample]
                ))
                var candidateDetector = detector
                let physicalEvents = candidateDetector.process(sourceSample, monotonicTime: monotonicTime)
                guard let physicalEvent = physicalEvents.first else {
                    detector = candidateDetector
                    break
                }
                var candidateRecording = currentRecording
                let elapsed = Duration.seconds(max(0, sourceSample.observedAt.timeIntervalSince(candidateRecording.startedAt)))
                do {
                    switch physicalEvent {
                    case .landingDetected:
                        let event = try candidateRecording.recordPhysicalTransition(
                            to: .landedAwaitingStop,
                            at: sourceSample.observedAt,
                            elapsed: elapsed,
                            eventID: UUID()
                        )
                        try await store.appendEvent(event, recordingID: candidateRecording.id, synchronize: true)
                        lastPhysicalTransitionEventID = event.id
                        detector = candidateDetector
                        recording = candidateRecording
                        return .physicalStateChanged(candidateRecording)
                    case .sustainedStopDetected:
                        let transition = try candidateRecording.recordPhysicalTransition(
                            to: .stopped,
                            at: sourceSample.observedAt,
                            elapsed: elapsed,
                            eventID: UUID()
                        )
                        try await store.appendEvent(transition, recordingID: candidateRecording.id, synchronize: true)
                        if candidateRecording.navigationState == .active
                            || candidateRecording.navigationState == .reachedFinalWaypoint {
                            lastPhysicalTransitionEventID = transition.id
                            detector = candidateDetector
                            recording = candidateRecording
                            return .physicalStateChanged(candidateRecording)
                        }
                        let closed = try candidateRecording.closeAutomatically(
                            at: sourceSample.observedAt,
                            elapsed: elapsed,
                            eventID: UUID()
                        )
                        try await store.appendEvent(closed, recordingID: candidateRecording.id, synchronize: true)
                        if let closure = candidateRecording.closure {
                            try await store.close(id: candidateRecording.id, closure: closure)
                        }
                        lastPhysicalTransitionEventID = transition.id
                        detector = candidateDetector
                        recording = candidateRecording
                        isArmed = false
                        return .closed(candidateRecording)
                    case .correction(let previous, let corrected):
                        guard let originalEventID = lastPhysicalTransitionEventID else { break }
                        let event = try candidateRecording.recordPhysicalCorrection(
                            originalEventID: originalEventID,
                            from: previous,
                            to: corrected,
                            at: sourceSample.observedAt,
                            elapsed: elapsed,
                            eventID: UUID()
                        )
                        try await store.appendEvent(event, recordingID: candidateRecording.id, synchronize: true)
                        detector = candidateDetector
                        recording = candidateRecording
                        return .physicalStateCorrected(candidateRecording)
                    case .groundMovementBegan, .takeoffDetected, .partialStartDetected:
                        let state: PhysicalFlightState = physicalEvent == .groundMovementBegan ? .groundMovement : .airborne
                        let event = try candidateRecording.recordPhysicalTransition(
                            to: state,
                            at: sourceSample.observedAt,
                            elapsed: elapsed,
                            eventID: UUID()
                        )
                        try await store.appendEvent(event, recordingID: candidateRecording.id, synchronize: true)
                        lastPhysicalTransitionEventID = event.id
                        detector = candidateDetector
                        recording = candidateRecording
                        return .physicalStateChanged(candidateRecording)
                    case .provisionalTimedOut:
                        break
                    }
                } catch {
                    return .none
                }
            }
        case .servicesDisabled, .signalLost, .authorization(.denied), .authorization(.restricted):
            if var recording, !segmentNeedsReopening {
                let availability: RecordingLocationAvailability
                switch event {
                case .servicesDisabled: availability = .servicesDisabled
                case .signalLost: availability = .signalLost
                case .authorization(.denied): availability = .permissionDenied
                case .authorization(.restricted): availability = .permissionRestricted
                case .sample, .authorization(.notDetermined), .authorization(.whenInUse): return .none
                }
                let timestamp = Date.now
                let elapsed = Duration.seconds(max(0, timestamp.timeIntervalSince(recording.startedAt)))
                if let availabilityEvent = try? recording.recordLocationAvailabilityChange(
                    availability,
                    at: timestamp,
                    elapsed: elapsed,
                    eventID: UUID()
                ), (try? await store.appendEvent(
                    availabilityEvent,
                    recordingID: recording.id,
                    synchronize: true
                )) != nil {
                    self.recording = recording.restoring(gpsCoverage: .partial)
                }
                segmentNeedsReopening = true
            }
        case .authorization(.notDetermined), .authorization(.whenInUse):
            break
        }
        return .none
    }

    private func associateSupplemental(with sample: RecordedTrackSample) -> RecordedTrackSample {
        let relativeAltitude = latestRelativeBarometricAltitude.flatMap { evidence -> Double? in
            guard abs(sample.observedAt.timeIntervalSince(evidence.observedAt)) <= Self.supplementalFreshnessInterval else {
                return nil
            }
            if barometricAltitudeAnchorOffsetMeters == nil, let gpsAltitude = sample.altitudeMeters, gpsAltitude.isFinite {
                barometricAltitudeAnchorOffsetMeters = gpsAltitude - evidence.meters
            }
            return barometricAltitudeAnchorOffsetMeters.map { evidence.meters + $0 }
        }
        let heading = latestDeviceHeading.flatMap { evidence in
            abs(sample.observedAt.timeIntervalSince(evidence.observedAt)) <= Self.supplementalFreshnessInterval
                ? evidence
                : nil
        }
        return sample.addingSupplemental(
            barometricAltitudeMeters: relativeAltitude,
            deviceHeadingDegrees: heading?.degrees,
            deviceHeadingAccuracyDegrees: heading?.accuracyDegrees
        )
    }

    @discardableResult
    func ingest(_ event: LocationSourceEvent) async -> FlightRecordingLocationOutcome {
        let timestamp: Date
        switch event {
        case .sample(_, let receivedAt):
            timestamp = receivedAt
        case .servicesDisabled, .signalLost, .authorization:
            timestamp = .distantPast
        }
        return await ingest(
            event,
            monotonicTime: .seconds(timestamp.timeIntervalSinceReferenceDate)
        )
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
            let currentFlight = flight
            let candidateFlight = try await MainActor.run {
                var candidate = currentFlight
                try candidate.startLeg(at: timestamp)
                return candidate
            }
            let legID = candidateFlight.legIDs[candidateFlight.activeLegIndex]
            if var candidateRecording = recording {
                guard eventIDs.count == 1 else {
                    throw FlightRecording.TransitionError.invalidEventIdentifierCount
                }
                let elapsed = Duration.seconds(max(0, timestamp.timeIntervalSince(candidateRecording.startedAt)))
                let event = try candidateRecording.startLeg(
                    legID: legID,
                    at: timestamp,
                    elapsed: elapsed,
                    eventID: eventIDs[0]
                )
                try await store.appendEvent(event, recordingID: candidateRecording.id, synchronize: true)
                flight = candidateFlight
                recording = candidateRecording
                return CommittedNavigationTransition(
                    flight: candidateFlight,
                    recording: candidateRecording,
                    eventIDs: [event.id]
                )
            }
            var promotion = try FlightRecording.promoteForStartLeg(
                id: recordingID,
                flightID: candidateFlight.id,
                flightPlanSnapshot: flightPlanSnapshot,
                legID: legID,
                startedAt: timestamp,
                eventIDs: eventIDs
            )

            let bufferedSegment: [RecordedTrackSegment]
            if rollingBuffer.isEmpty {
                bufferedSegment = []
            } else {
                let segmentID = UUID()
                activeSegmentID = segmentID
                bufferedSegment = [RecordedTrackSegment(id: segmentID, samples: rollingBuffer)]
            }
            if !bufferedSegment.isEmpty {
                promotion.recording = promotion.recording.restoring(gpsCoverage: .available)
            }
            try await store.create(FlightRecordingSeed(
                recording: promotion.recording,
                events: promotion.events,
                trackSegments: bufferedSegment
            ))
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
            var committedEventIDs = [eventID]
            if candidateRecording.physicalState == .stopped {
                let closed = try candidateRecording.closeAutomatically(
                    at: timestamp,
                    elapsed: elapsed,
                    eventID: UUID()
                )
                try await store.appendEvent(closed, recordingID: candidateRecording.id, synchronize: true)
                if let closure = candidateRecording.closure {
                    try await store.close(id: candidateRecording.id, closure: closure)
                }
                isArmed = false
                committedEventIDs.append(closed.id)
            }
            recording = candidateRecording
            return CommittedNavigationTransition(
                flight: flight,
                recording: candidateRecording,
                eventIDs: committedEventIDs
            )
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
        eventIDs: [UUID],
        forcedOutcome: FlightRecordingClosure.Outcome? = nil
    ) async throws -> FlightRecordingEngineSnapshot {
        guard var candidate = recording else {
            throw FlightRecording.TransitionError.recordingAlreadyClosed
        }
        let events = try candidate.endManually(
            at: timestamp,
            elapsed: elapsed,
            eventIDs: eventIDs,
            forcedOutcome: forcedOutcome
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
