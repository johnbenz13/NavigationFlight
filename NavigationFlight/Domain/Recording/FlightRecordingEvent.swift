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
    var cockpitContext: RecordingCockpitContext? = nil
}

nonisolated enum RecordedFlightEventPayload: Equatable, Sendable {
    struct RouteActivationFact {
        let origin: RecordedFlightEvent.Origin
        let payload: RecordedFlightEventPayload
    }

    static func routeActivationCompanions(
        _ departure: ActivatedRouteAmendment.Departure, immediate: Bool
    ) -> [RouteActivationFact] {
        var facts: [RouteActivationFact] = []
        if departure.recordedOriginalArrival {
            facts.append(.init(origin: .pilot, payload: .waypointReached(legID: departure.sourceLegID)))
        }
        if departure.startsReplacement {
            if immediate {
                facts.append(.init(origin: .pilot, payload: .legStarted(legID: departure.firstReplacementLegID)))
            } else {
                facts.append(.init(origin: .automatic, payload: .automaticNextLegTransition(
                    fromLegID: departure.sourceLegID, toLegID: departure.firstReplacementLegID
                )))
            }
        }
        return facts
    }

    static func rejoinCompanions(_ rejoin: ActivatedRouteAmendment.Rejoin) -> [RouteActivationFact] {
        var facts: [RouteActivationFact] = [.init(origin: .pilot, payload: .waypointReached(legID: rejoin.replacementLegID))]
        if let retained = rejoin.retainedLegID {
            if rejoin.startsRetainedLeg {
                facts.append(.init(origin: .automatic, payload: .automaticNextLegTransition(
                    fromLegID: rejoin.replacementLegID, toLegID: retained
                )))
            }
        } else {
            facts.append(.init(origin: .automatic, payload: .finalWaypointReached(legID: rejoin.replacementLegID)))
        }
        return facts
    }

    enum RecordingStartCause: Equatable, Sendable {
        case startLegWithoutLocation
        case automaticTakeoff
        case partialStart
    }

    case recordingStarted(cause: RecordingStartCause)
    case legStarted(legID: UUID)
    case destinationIdentified(legID: UUID)
    case amendmentDepartureIdentified(legID: UUID, targetID: UUID)
    case identificationPointReached(key: IdentificationPointKey)
    case waypointReached(legID: UUID)
    case pendingRouteAmendmentConfirmed(PendingRouteAmendment)
    case routeAmendmentActivated(ActivatedRouteAmendment.Departure)
    case routeAmendmentRejoined(ActivatedRouteAmendment.Rejoin)
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
    case cockpitPresentationChanged
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
    case recoveryContinued
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

nonisolated extension ActivatedRouteAmendment.Rejoin {
    var navigationState: RecordedNavigationState {
        guard retainedLegID != nil else { return .reachedFinalWaypoint }
        return startsRetainedLeg ? .active : .ready
    }
}
