import Foundation

nonisolated enum RecordedNavigationCommand: Sendable {
    case startLeg(at: Date, recordingID: UUID, eventIDs: [UUID])
    case confirmPendingAmendment(PendingRouteAmendment, plan: FlightPlan, at: Date, elapsed: Duration)
    case managePendingAmendment(PendingAmendmentChange, plan: FlightPlan, at: Date, elapsed: Duration, eventID: UUID)
    case identifyDestination(at: Date, elapsed: Duration, eventID: UUID, targetID: UUID? = nil)
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
        eventIDs: [UUID],
        expectedLegID: UUID? = nil
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
    case undoReach(
        originalEventID: UUID,
        restoredFlight: Flight,
        at: Date,
        elapsed: Duration,
        eventID: UUID
    )
    case requestPositionCheck(at: Date, elapsed: Duration, eventID: UUID)
    case endPositionCheck(outcome: PositionCheckRecordedOutcome, at: Date, elapsed: Duration, eventID: UUID)
    case recordStorageDegradation(reason: RecordingStorageDegradation, at: Date, elapsed: Duration, eventID: UUID)
}

nonisolated struct CommittedNavigationTransition: Equatable, Sendable {
    let flight: Flight
    let recording: FlightRecording
    let eventIDs: [UUID]
    var cockpitContext: RecordingCockpitContext? = nil
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
    case trackPersistenceFailed
}

actor FlightRecordingEngine {
    enum EngineError: Error, Equatable, Sendable {
        case navigationNotReadyForCompletion
        case routeOutcomeUncertain
    }

    private let store: any FlightRecordingStore
    private let flightPlanSnapshot: RecordedFlightPlanSnapshot
    private let detectorPolicySnapshot: PhysicalFlightDetectionPolicySnapshot
    private var detector: PhysicalFlightDetector
    private var flight: Flight
    private var unresolvedRouteWrite: (transaction: FlightRouteTransaction, transition: CommittedNavigationTransition)?
    private var mutationInProgress = false
    private var mutationWaiters: [CheckedContinuation<Void, Never>] = []
    var queuedMutationCount: Int { mutationWaiters.count }
    private var cockpitContext: RecordingCockpitContext?
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
        detectorPolicy: PhysicalFlightDetectionPolicy = .production,
        initialCockpitContext: RecordingCockpitContext? = nil
    ) {
        self.store = store
        cockpitContext = initialCockpitContext
        self.flight = flight
        self.flightPlanSnapshot = flightPlanSnapshot
        detectorPolicySnapshot = PhysicalFlightDetectionPolicySnapshot(policy: detectorPolicy)
        detector = PhysicalFlightDetector(policy: detectorPolicySnapshot.policy)
    }

    init(
        store: any FlightRecordingStore,
        recoveredFlight: Flight,
        recoveredRecording: FlightRecording,
        detectorPolicy: PhysicalFlightDetectionPolicy = .production,
        detectorPolicySnapshot: PhysicalFlightDetectionPolicySnapshot? = nil,
        storageDegradations: Set<RecordingStorageDegradation> = [],
        recoveredCockpitContext: RecordingCockpitContext? = nil
    ) {
        self.store = store
        flight = recoveredFlight
        flightPlanSnapshot = recoveredRecording.flightPlanSnapshot
        recording = recoveredRecording
        cockpitContext = recoveredCockpitContext
        self.storageDegradations = storageDegradations
        let restoredPolicy = detectorPolicySnapshot
            ?? PhysicalFlightDetectionPolicySnapshot(policy: detectorPolicy)
        self.detectorPolicySnapshot = restoredPolicy
        detector = PhysicalFlightDetector(policy: restoredPolicy.policy)
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
        await acquireMutation()
        defer { releaseMutation() }
        guard isArmed else { return .none }
        let routeWriteUnresolved = unresolvedRouteWrite != nil
        switch event {
        case .sample(let sourceSample, _):
            guard let baseSample = RecordedTrackSample(sourceSample) else { return .none }
            let sample = associateSupplemental(with: baseSample)
            guard !deliveredSamples.contains(sample) else { return .none }
            deliveredSamples.append(sample)
            if routeWriteUnresolved {
                guard let recording, !storageDegradations.contains(.lowStorage) else {
                    return .trackPersistenceFailed
                }
                do {
                    try await appendTrackSample(sample, recordingID: recording.id)
                } catch {
                    // Keep the gap visible without appending journal events while its
                    // route transaction is uncertain.
                    segmentNeedsReopening = true
                    return .trackPersistenceFailed
                }
                return .none
            }
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
                    var promotion = FlightRecording.promoteAutomatically(
                        id: UUID(),
                        flightID: flight.id,
                        flightPlanSnapshot: flightPlanSnapshot,
                        startedAt: rollingBuffer.first?.observedAt ?? sourceSample.observedAt,
                        promotedAt: sourceSample.observedAt,
                        partial: partial,
                        eventID: UUID()
                    )
                    let currentFlight = flight
                    promotion.recording.sourceSchemaVersion = 3
                    promotion.recording.recordedProgression = await MainActor.run {
                        currentFlight.progressionPolicy == .automaticNextLeg ? .automatic : .manual
                    }
                    let initialContext = cockpitContext ?? RecordingCockpitContext(flightID: flight.id, checklists: [:], areDriftLinesVisible: true)
                    promotion.events[0].cockpitContext = initialContext
                    let segmentID = UUID()
                    activeSegmentID = segmentID
                    do {
                        try await store.create(FlightRecordingSeed(
                            recording: promotion.recording,
                            events: promotion.events,
                            trackSegments: [RecordedTrackSegment(id: segmentID, samples: rollingBuffer)],
                            detectorPolicy: detectorPolicySnapshot
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
                        if storageDegradations.contains(.lowStorage) {
                            segmentNeedsReopening = false
                        }
                    }
                }
                if !storageDegradations.contains(.lowStorage) {
                    try? await appendTrackSample(sample, recordingID: currentRecording.id)
                }
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
            if routeWriteUnresolved {
                segmentNeedsReopening = true
                return .none
            }
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

    private func appendTrackSample(_ sample: RecordedTrackSample, recordingID: UUID) async throws {
        let segmentID = segmentNeedsReopening ? UUID() : activeSegmentID ?? UUID()
        activeSegmentID = segmentID
        segmentNeedsReopening = false
        try await store.appendTrackBatch(.init(recordingID: recordingID, segmentID: segmentID, samples: [sample]))
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
        eventIDs: [UUID],
        context: RecordingCockpitContext? = nil,
        checklistSelection: StartChecklistSelection = .tzeKivun
    ) async throws -> CommittedNavigationTransition {
        try await commit(
            .startLeg(at: timestamp, recordingID: recordingID, eventIDs: eventIDs),
            context: context, checklistSelection: checklistSelection
        )
    }

    func commit(
        _ command: RecordedNavigationCommand,
        context: RecordingCockpitContext? = nil,
        checklistSelection: StartChecklistSelection = .tzeKivun
    ) async throws -> CommittedNavigationTransition {
        await acquireMutation()
        defer { releaseMutation() }
        if unresolvedRouteWrite != nil {
            switch command {
            case .confirmPendingAmendment, .managePendingAmendment: break
            default: throw EngineError.routeOutcomeUncertain
            }
        }
        switch command {
        case .confirmPendingAmendment(let amendment, let plan, let timestamp, let elapsed):
            return try await confirmPendingAmendment(amendment, plan: plan, at: timestamp, elapsed: elapsed, context: context)
        case .managePendingAmendment(let change, let plan, let timestamp, let elapsed, let eventID):
            return try await commitPendingAmendmentChange(
                change, in: plan, at: timestamp, elapsed: elapsed, eventID: eventID, context: context,
                checklistSelection: checklistSelection
            )
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
                var event = try candidateRecording.startLeg(
                    legID: legID,
                    at: timestamp,
                    elapsed: elapsed,
                    eventID: eventIDs[0]
                )
                event.cockpitContext = await transitionContext(context, flight: candidateFlight, payload: event.payload, selection: checklistSelection)
                try await store.appendEvent(event, recordingID: candidateRecording.id, synchronize: true)
                cockpitContext = event.cockpitContext
                flight = candidateFlight
                recording = candidateRecording
                return CommittedNavigationTransition(
                    flight: candidateFlight,
                    recording: candidateRecording,
                    eventIDs: [event.id], cockpitContext: event.cockpitContext
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

            promotion.recording.sourceSchemaVersion = 3
            promotion.recording.recordedProgression = await MainActor.run {
                candidateFlight.progressionPolicy == .automaticNextLeg ? .automatic : .manual
            }
            let startedContext = await transitionContext(context, flight: candidateFlight,
                                                         payload: .legStarted(legID: legID), selection: checklistSelection)
            for index in promotion.events.indices {
                promotion.events[index].cockpitContext = startedContext
            }
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
                trackSegments: bufferedSegment,
                detectorPolicy: detectorPolicySnapshot
            ))
            cockpitContext = startedContext
            flight = candidateFlight
            recording = promotion.recording
            return CommittedNavigationTransition(
                flight: candidateFlight,
                recording: promotion.recording,
                eventIDs: promotion.events.map(\.id), cockpitContext: startedContext
            )
        case .identifyDestination(let timestamp, let elapsed, let eventID, let targetID):
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: [eventID], context: context, selection: checklistSelection) { candidate in
                let legID = candidate.legIDs[candidate.activeLegIndex]
                if let departure = candidate.activePartwayDeparture?.departureStop {
                    guard targetID == departure.id else { throw PendingRouteAmendment.Validation.unavailableDeparture }
                    try candidate.identifyDestination(at: timestamp)
                    return ([(.pilot, .amendmentDepartureIdentified(legID: legID, targetID: departure.id))], nil)
                }
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
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: [eventID], context: context, selection: checklistSelection) { candidate in
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
        case .reachCurrentWaypoint(let orderedKeys, let timestamp, let elapsed, let eventIDs, let expectedLegID):
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: eventIDs, context: context, selection: checklistSelection) { candidate in
                let departingLegID = candidate.legIDs[candidate.activeLegIndex]
                guard expectedLegID == nil || expectedLegID == departingLegID else {
                    throw PendingRouteAmendment.Validation.unavailableDeparture
                }
                try candidate.reachCurrentWaypoint(orderedActiveLegPointKeys: orderedKeys, at: timestamp)
                return Self.waypointReachEvents(from: departingLegID, after: candidate)
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
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: [eventID], context: context, selection: checklistSelection) { candidate in
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
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: [eventID], context: context, selection: checklistSelection) { candidate in
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
            return try await commitExistingRecording(at: timestamp, elapsed: elapsed, eventIDs: [eventID], context: context, selection: checklistSelection) { candidate in
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
        case .undoReach(let originalEventID, let restoredFlight, let timestamp, let elapsed, let eventID):
            let pendingRouteChanged = flight.pendingRouteAmendment != restoredFlight.pendingRouteAmendment
            if pendingRouteChanged {
                try await validateUndoOfOriginalDestinationReach(originalEventID, restoring: restoredFlight)
            }
            guard restoredFlight.id == flight.id,
                  restoredFlight.flightPlanID == flight.flightPlanID,
                  restoredFlight.legIDs == flight.legIDs else {
                throw Flight.TransitionError.legNotActive
            }
            var restoredContext = context
            restoredContext?.navigationGeneration = UUID()
            let transition = try await appendOperationalEvent(
                .reachUndone(originalEventID: originalEventID),
                origin: .pilot,
                at: timestamp,
                elapsed: elapsed,
                eventID: eventID, context: restoredContext, navigationState: .active
            )
            flight = restoredFlight
            return CommittedNavigationTransition(
                flight: restoredFlight,
                recording: transition.recording,
                eventIDs: transition.eventIDs, cockpitContext: restoredContext
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

    private func confirmPendingAmendment(
        _ amendment: PendingRouteAmendment,
        plan: FlightPlan,
        at timestamp: Date,
        elapsed: Duration,
        context: RecordingCockpitContext?
    ) async throws -> CommittedNavigationTransition {
        if let outstanding = unresolvedRouteWrite {
            guard outstanding.transaction.event.payload == .pendingRouteAmendmentConfirmed(amendment) else {
                throw EngineError.routeOutcomeUncertain
            }
            if try await reconcileRouteWrite(outstanding.transaction) {
                return publishRouteWrite(outstanding.transition)
            }
            unresolvedRouteWrite = nil
        }
        if flight.pendingRouteAmendment == amendment, let recording {
            return .init(flight: flight, recording: recording, eventIDs: [amendment.id], cockpitContext: cockpitContext)
        }
        guard var candidate = recording else { throw FlightRecording.TransitionError.recordingAlreadyClosed }
        let expectedSequence = candidate.nextEventSequence
        let current = flight
        let changedFlight = try await MainActor.run {
            var next = current
            try next.installPendingAmendment(amendment, in: plan)
            return next
        }
        var capturedContext = context?.navigationGeneration == cockpitContext?.navigationGeneration ? context : nil
        capturedContext = capturedContext ?? cockpitContext
        guard var capturedContext else {
            throw FlightRecordingStoreError.operationFailed(id: candidate.id)
        }
        try capturedContext.validate(flightID: current.id, legIDs: flightPlanSnapshot.legIDs)
        capturedContext.navigationGeneration = amendment.id
        var event = try candidate.confirmPendingAmendment(amendment, at: timestamp, elapsed: elapsed)
        event.cockpitContext = capturedContext
        if candidate.sourceSchemaVersion < 3 {
            candidate.cockpitContextStartSequence = expectedSequence
        }
        candidate.sourceSchemaVersion = 4
        let transaction = FlightRouteTransaction(recordingID: candidate.id, expectedSequence: expectedSequence, event: event)
        let transition = CommittedNavigationTransition(
            flight: changedFlight, recording: candidate, eventIDs: [event.id], cockpitContext: capturedContext
        )
        return try await commitRouteWrite(transaction, transition: transition)
    }

    private func commitPendingAmendmentChange(
        _ change: PendingAmendmentChange,
        in plan: FlightPlan,
        at timestamp: Date,
        elapsed: Duration,
        eventID: UUID,
        context: RecordingCockpitContext?,
        checklistSelection: StartChecklistSelection
    ) async throws -> CommittedNavigationTransition {
        let payload = change.eventPayload
        if let outstanding = unresolvedRouteWrite {
            guard outstanding.transaction.event.id == eventID,
                  outstanding.transaction.event.payload == payload else { throw EngineError.routeOutcomeUncertain }
            if try await reconcileRouteWrite(outstanding.transaction) {
                return publishRouteWrite(outstanding.transition)
            }
            unresolvedRouteWrite = nil
        }
        guard var candidate = recording else { throw FlightRecording.TransitionError.recordingAlreadyClosed }
        if flight.pendingRouteAmendment?.id != change.expectedPendingID {
            // A caller may repeat the operation after publication. A matching journal tail
            // establishes the same result without applying any route or reach effect again.
            let saved = try await store.readSnapshot(id: candidate.id)
            if let index = saved.events.firstIndex(where: { $0.id == eventID && $0.payload == payload }) {
                let tail = saved.events[index...]
                if tail.map(\.id) == Array(change.eventIDs(startingWith: eventID).prefix(tail.count)) {
                    return .init(flight: flight, recording: candidate, eventIDs: tail.map(\.id), cockpitContext: cockpitContext)
                }
            }
            throw PendingRouteAmendment.Validation.stalePendingAmendment
        }
        let current = flight
        let result = try await MainActor.run {
            var next = current
            var entries: [(RecordedFlightEvent.Origin, RecordedFlightEventPayload)] = [(.pilot, payload)]
            var navigationState: RecordedNavigationState?
            switch change {
            case .replace(let pendingID, let amendment):
                try next.installPendingAmendment(amendment, in: plan, replacing: pendingID)
            case .cancel(let pendingID):
                try next.cancelPendingAmendment(id: pendingID)
            case .reportOriginalDestination(let report, _, _):
                try next.cancelForOriginalDestination(report, in: plan)
                let keys = plan.identificationPoints.lazy.filter { $0.legID == report.legID }
                    .map { IdentificationPointKey(legID: $0.legID, identificationPointID: $0.id) }
                try next.reachCurrentWaypoint(orderedActiveLegPointKeys: Array(keys), at: timestamp)
                let reach = Self.waypointReachEvents(from: report.legID, after: next)
                entries += reach.entries
                navigationState = reach.navigationState
            }
            return (flight: next, entries: entries, navigationState: navigationState)
        }
        let expectedSequence = candidate.nextEventSequence
        var events = try candidate.recordNavigationEvents(
            at: timestamp, elapsed: elapsed, entries: result.entries,
            eventIDs: Array(change.eventIDs(startingWith: eventID).prefix(result.entries.count)),
            navigationState: result.navigationState
        )
        let supplied = context?.navigationGeneration == cockpitContext?.navigationGeneration ? context : nil
        var captured = supplied ?? cockpitContext
        if case .reportOriginalDestination(let report, _, _) = change {
            captured = await transitionContext(supplied, flight: result.flight,
                                               payload: .waypointReached(legID: report.legID), selection: checklistSelection)
        }
        guard var captured else { throw FlightRecordingStoreError.operationFailed(id: candidate.id) }
        try captured.validate(flightID: current.id, legIDs: current.legIDs)
        captured.navigationGeneration = eventID
        for index in events.indices { events[index].cockpitContext = captured }
        if candidate.sourceSchemaVersion < 3 { candidate.cockpitContextStartSequence = expectedSequence }
        candidate.sourceSchemaVersion = 4
        let transaction = FlightRouteTransaction(recordingID: candidate.id, expectedSequence: expectedSequence, events: events)
        let transition = CommittedNavigationTransition(
            flight: result.flight, recording: candidate, eventIDs: events.map(\.id), cockpitContext: captured
        )
        return try await commitRouteWrite(transaction, transition: transition)
    }

    @MainActor
    private static func waypointReachEvents(from departingLegID: UUID, after candidate: Flight) -> (
        entries: [(RecordedFlightEvent.Origin, RecordedFlightEventPayload)], navigationState: RecordedNavigationState?
    ) {
        let reach: (RecordedFlightEvent.Origin, RecordedFlightEventPayload) = (.pilot, .waypointReached(legID: departingLegID))
        switch candidate.legState {
        case .completed:
            return ([reach, (.automatic, .finalWaypointReached(legID: departingLegID))], .reachedFinalWaypoint)
        case .ready:
            return ([reach], .ready)
        case .active:
            let nextLegID = candidate.legIDs[candidate.activeLegIndex]
            return ([reach, (.automatic, .automaticNextLegTransition(fromLegID: departingLegID, toLegID: nextLegID))], nil)
        }
    }

    private func validateUndoOfOriginalDestinationReach(_ reachEventID: UUID, restoring restored: Flight) async throws {
        let restoredIsActive = await MainActor.run { restored.legState == .active }
        guard let recording, let pendingID = restored.pendingRouteAmendment?.id,
              flight.pendingRouteAmendment == nil, restoredIsActive else {
            throw PendingRouteAmendment.Validation.stalePendingAmendment
        }
        let history = try await store.readSnapshot(id: recording.id).events
        guard let cancellationIndex = history.lastIndex(where: {
            switch $0.payload {
            case .pendingRouteAmendmentCancelled, .pendingRouteAmendmentReplaced, .pendingRouteAmendmentConfirmed: true
            default: false
            }
        }), case .pendingRouteAmendmentCancelled(let cancelledID, let destination?, let linkedReachID) = history[cancellationIndex].payload,
              cancelledID == pendingID, linkedReachID == reachEventID,
              restored.legIDs[restored.activeLegIndex] == destination.legID,
              let reach = history.dropFirst(cancellationIndex + 1).first,
              reach.id == reachEventID, reach.payload == .waypointReached(legID: destination.legID),
              !history.dropFirst(cancellationIndex + 2).contains(where: {
                  switch $0.payload {
                  case .waypointReached, .identificationPointReached, .reachUndone, .legStarted, .navigationCompleted: true
                  default: false
                  }
              }) else {
            throw PendingRouteAmendment.Validation.stalePendingAmendment
        }
    }

    private func commitRouteWrite(
        _ transaction: FlightRouteTransaction,
        transition: CommittedNavigationTransition
    ) async throws -> CommittedNavigationTransition {
        unresolvedRouteWrite = (transaction, transition)
        do {
            try await store.commitRouteTransaction(transaction)
        } catch {
            // Leave the write fenced if durable state itself cannot be read.
            if try await reconcileRouteWrite(transaction) {
                return publishRouteWrite(transition)
            }
            unresolvedRouteWrite = nil
            throw error
        }
        return publishRouteWrite(transition)
    }

    private func reconcileRouteWrite(_ transaction: FlightRouteTransaction) async throws -> Bool {
        do { return try await store.routeTransactionIsCommitted(transaction) }
        catch { throw EngineError.routeOutcomeUncertain }
    }

    private func publishRouteWrite(_ transition: CommittedNavigationTransition) -> CommittedNavigationTransition {
        flight = transition.flight
        recording = transition.recording
        cockpitContext = transition.cockpitContext
        unresolvedRouteWrite = nil
        return transition
    }

    private func requireResolvedRouteWrite() throws {
        if let unresolvedRouteWrite {
            throw FlightRecordingStoreError.operationFailed(id: unresolvedRouteWrite.transaction.recordingID)
        }
    }

    func checkpoint(recordingID: UUID, at timestamp: Date) async throws {
        await acquireMutation()
        defer { releaseMutation() }
        try requireResolvedRouteWrite()
        guard recording?.id == recordingID, recording?.closure == nil else { return }
        try await store.updateRecoveryCheckpoint(recordingID: recordingID, at: timestamp)
        recording = recording?.restoringRecoveryCheckpoint(at: timestamp)
    }

    func expireRecoveryCheckpoint(recordingID: UUID, at timestamp: Date) async throws -> FlightRecording? {
        await acquireMutation()
        defer { releaseMutation() }
        try requireResolvedRouteWrite()
        guard var candidate = recording, candidate.id == recordingID, candidate.closure == nil else { return nil }
        let snapshot = try await store.readSnapshot(id: recordingID)
        let lastActivity = snapshot.latestDurableEvidenceAt
        guard snapshot.recording.closure == nil,
              timestamp.timeIntervalSince(lastActivity) >= candidate.recoveryWindowSeconds else { return nil }
        let event = try candidate.closeDuringRecovery(
            at: lastActivity, elapsed: .seconds(max(0, lastActivity.timeIntervalSince(candidate.startedAt))),
            cause: .recoveryExpired, eventID: UUID()
        )
        try await store.appendEvent(event, recordingID: recordingID, synchronize: true)
        guard let closure = candidate.closure else { return nil }
        try await store.close(id: recordingID, closure: closure)
        recording = candidate
        return candidate
    }

    private func commitExistingRecording(
        at timestamp: Date,
        elapsed: Duration,
        eventIDs: [UUID],
        context: RecordingCockpitContext?,
        selection: StartChecklistSelection,
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
        var events = try candidateRecording.recordNavigationEvents(
            at: timestamp,
            elapsed: elapsed,
            entries: result.1.entries,
            eventIDs: eventIDs,
            navigationState: result.1.navigationState
        )
        let capturedContext = await transitionContext(context, flight: result.0,
                                                       payload: events[0].payload, selection: selection)
        for index in events.indices { events[index].cockpitContext = capturedContext }
        for (index, event) in events.enumerated() {
            try await store.appendEvent(
                event,
                recordingID: candidateRecording.id,
                synchronize: index == events.indices.last
            )
        }
        cockpitContext = capturedContext
        flight = result.0
        recording = candidateRecording
        return CommittedNavigationTransition(
            flight: result.0,
            recording: candidateRecording,
            eventIDs: events.map(\.id), cockpitContext: capturedContext
        )
    }

    private func acquireMutation() async {
        if mutationInProgress {
            await withCheckedContinuation { mutationWaiters.append($0) }
        } else { mutationInProgress = true }
    }

    private func releaseMutation() {
        if mutationWaiters.isEmpty { mutationInProgress = false }
        else { mutationWaiters.removeFirst().resume() }
    }

    private func transitionContext(
        _ supplied: RecordingCockpitContext?, flight: Flight,
        payload: RecordedFlightEventPayload, selection: StartChecklistSelection
    ) async -> RecordingCockpitContext {
        let prior = supplied ?? cockpitContext
        return await MainActor.run {
            var result = prior ?? RecordingCockpitContext(flightID: flight.id, checklists: [:], areDriftLinesVisible: true)
            switch payload {
            case .destinationIdentified(let legID), .amendmentDepartureIdentified(let legID, _), .waypointReached(let legID):
                result.checklists[legID]?.phaseState = .hiddenForPhase
            default: break
            }
            if flight.legState == .active {
                result = result.starting(legID: flight.legIDs[flight.activeLegIndex], selection: selection)
            }
            result.navigationGeneration = UUID()
            return result
        }
    }

    @discardableResult
    func recordPresentation(_ context: RecordingCockpitContext, at timestamp: Date) async throws -> Bool {
        await acquireMutation()
        defer { releaseMutation() }
        try requireResolvedRouteWrite()
        try context.validate(flightID: flight.id, legIDs: flightPlanSnapshot.legIDs)
        // Check after acquiring the gate: navigation may have committed while this
        // snapshot was queued, including an undo back to otherwise identical values.
        guard context.navigationGeneration == cockpitContext?.navigationGeneration else { return false }
        guard var candidate = recording else {
            cockpitContext = context
            return true
        }
        guard context != cockpitContext else { return true }
        let elapsed = Duration.seconds(max(0, timestamp.timeIntervalSince(candidate.startedAt)))
        var events = try candidate.recordNavigationEvents(at: timestamp, elapsed: elapsed,
                                                          entries: [(.pilot, .cockpitPresentationChanged)], eventIDs: [UUID()])
        events[0].cockpitContext = context
        try await store.appendEvent(events[0], recordingID: candidate.id, synchronize: true)
        recording = candidate
        cockpitContext = context
        return true
    }

    private func appendOperationalEvent(
        _ payload: RecordedFlightEventPayload,
        origin: RecordedFlightEvent.Origin,
        at timestamp: Date,
        elapsed: Duration,
        eventID: UUID,
        context: RecordingCockpitContext? = nil,
        navigationState: RecordedNavigationState? = nil
    ) async throws -> CommittedNavigationTransition {
        guard var candidateRecording = recording else {
            throw FlightRecording.TransitionError.recordingAlreadyClosed
        }
        var events = try candidateRecording.recordNavigationEvents(
            at: timestamp,
            elapsed: elapsed,
            entries: [(origin, payload)],
            eventIDs: [eventID],
            navigationState: navigationState
        )
        events[0].cockpitContext = context
        try await store.appendEvent(events[0], recordingID: candidateRecording.id, synchronize: true)
        if let context { cockpitContext = context }
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
        await acquireMutation()
        defer { releaseMutation() }
        try requireResolvedRouteWrite()
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
        await acquireMutation()
        defer { releaseMutation() }
        try requireResolvedRouteWrite()
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
