import Foundation

nonisolated struct PositionCheckTiming: Equatable, Sendable {
    static let standard = PositionCheckTiming(
        acquisitionDuration: .seconds(10),
        disclosureDuration: .seconds(10)
    )

    let acquisitionDuration: Duration
    let disclosureDuration: Duration
}

nonisolated struct PositionCheckProjection: Equatable, Sendable {
    let coordinate: WGS84Coordinate
    let horizontalAccuracyMeters: Double
    let trueCourseDegrees: Double?

    init(sample: AircraftLocationSample) {
        coordinate = sample.coordinate
        horizontalAccuracyMeters = sample.horizontalAccuracyMeters
        trueCourseDegrees = PositionCheckQualityPolicy().classify(
            sample,
            receivedAt: sample.observedAt,
            lastAcceptedObservation: nil
        ).guidance == .eligible ? sample.trueCourseDegrees : nil
    }
}

nonisolated enum PositionCheckState: Equatable, Sendable {
    struct Generation: Hashable, Sendable {
        fileprivate let value: UUID

        fileprivate init() {
            value = UUID()
        }
    }

    struct Request: Equatable, Sendable {
        let generation: Generation
        let deadline: Duration
        let restoration: CockpitRestoration
    }

    struct Session: Equatable, Sendable {
        let generation: Generation
        let deadline: Duration
        let projection: PositionCheckProjection
        let restoration: CockpitRestoration
    }

    enum Failure: Equatable, Sendable {
        case acquisitionTimedOut
        case signalLost
        case servicesDisabled
        case staleFix
        case poorAccuracy
        case sourceFailure
        case permissionRevoked(LocationPermissionReason)
    }

    case idle
    case acquiring(Request)
    case active(Session)
    case transientFailure(Failure)

    var acquisitionRequest: Request? {
        guard case .acquiring(let request) = self else { return nil }
        return request
    }

    var activeSession: Session? {
        guard case .active(let session) = self else { return nil }
        return session
    }

    func transition(
        _ intent: PositionCheckIntent,
        now: Duration,
        timing: PositionCheckTiming = .standard
    ) -> PositionCheckTransition {
        switch intent {
        case .holdCompleted(let availability, let restoration),
             .restartHoldCompleted(let availability, let restoration):
            return start(availability: availability, restoration: restoration, now: now, timing: timing)
        case .cancel:
            guard case .acquiring = self else { return .unchanged(self) }
            return PositionCheckTransition(state: .idle, effect: .cancelDeadline)
        case .dismissFailure:
            guard case .transientFailure = self else { return .unchanged(self) }
            return PositionCheckTransition(state: .idle, effect: .none)
        case .locationAvailabilityChanged(let availability):
            switch self {
            case .acquiring(let request):
                switch availability {
                case .ready(let sample):
                    return activate(
                        sample: sample,
                        restoration: request.restoration,
                        now: now,
                        timing: timing
                    )
                case .acquiring:
                    return .unchanged(self)
                case .unavailable, .permissionRequired:
                    return PositionCheckTransition(
                        state: .transientFailure(Self.failure(for: availability)),
                        effect: .cancelDeadline
                    )
                }
            case .active(let session):
                if case .ready(let sample) = availability {
                    let updated = Session(
                        generation: session.generation,
                        deadline: session.deadline,
                        projection: PositionCheckProjection(sample: sample),
                        restoration: session.restoration
                    )
                    return PositionCheckTransition(state: .active(updated), effect: .none)
                }
                return PositionCheckTransition(
                    state: .transientFailure(Self.failure(for: availability)),
                    effect: .endDisclosure(restoration: session.restoration)
                )
            default:
                return .unchanged(self)
            }
        case .deadlineReached(let generation):
            switch self {
            case .acquiring(let request) where request.generation == generation:
                return PositionCheckTransition(state: .transientFailure(.acquisitionTimedOut), effect: .cancelDeadline)
            case .active(let session) where session.generation == generation:
                return PositionCheckTransition(state: .idle, effect: .endDisclosure(restoration: session.restoration))
            default:
                return .unchanged(self)
            }
        case .activeLegChanged, .activeFlightLost, .sceneBecameInactive, .cockpitDismissed:
            switch self {
            case .active(let session):
                return PositionCheckTransition(state: .idle, effect: .endDisclosure(restoration: session.restoration))
            case .acquiring:
                return PositionCheckTransition(state: .idle, effect: .cancelDeadline)
            case .idle, .transientFailure:
                return .unchanged(self)
            }
        case .end:
            guard case .active(let session) = self else { return .unchanged(self) }
            return PositionCheckTransition(state: .idle, effect: .endDisclosure(restoration: session.restoration))
        }
    }

    private func start(
        availability: LocationAvailability,
        restoration: CockpitRestoration,
        now: Duration,
        timing: PositionCheckTiming
    ) -> PositionCheckTransition {
        switch availability {
        case .ready(let sample):
            return activate(sample: sample, restoration: restoration, now: now, timing: timing)
        case .acquiring, .unavailable:
            let request = Request(
                generation: Generation(),
                deadline: now + timing.acquisitionDuration,
                restoration: restoration
            )
            return PositionCheckTransition(
                state: .acquiring(request),
                effect: .scheduleDeadline(generation: request.generation, deadline: request.deadline)
            )
        case .permissionRequired:
            return .unchanged(self)
        }
    }

    private func activate(
        sample: AircraftLocationSample,
        restoration: CockpitRestoration,
        now: Duration,
        timing: PositionCheckTiming
    ) -> PositionCheckTransition {
        let session = Session(
            generation: Generation(),
            deadline: now + timing.disclosureDuration,
            projection: PositionCheckProjection(sample: sample),
            restoration: restoration
        )
        return PositionCheckTransition(
            state: .active(session),
            effect: .scheduleDeadline(generation: session.generation, deadline: session.deadline)
        )
    }

    private static func failure(for availability: LocationAvailability) -> Failure {
        switch availability {
        case .ready:
            preconditionFailure("A ready sample is not a failure")
        case .acquiring, .unavailable(.signalLost):
            return .signalLost
        case .unavailable(.servicesDisabled):
            return .servicesDisabled
        case .unavailable(.stale), .unavailable(.outOfOrder):
            return .staleFix
        case .unavailable(.invalidAccuracy), .unavailable(.insufficientAccuracy):
            return .poorAccuracy
        case .unavailable(.sourceFailure):
            return .sourceFailure
        case .permissionRequired(let reason):
            return .permissionRevoked(reason)
        }
    }
}

nonisolated enum PositionCheckIntent: Equatable, Sendable {
    case holdCompleted(availability: LocationAvailability, restoration: CockpitRestoration)
    case cancel
    case dismissFailure
    case restartHoldCompleted(availability: LocationAvailability, restoration: CockpitRestoration)
    case locationAvailabilityChanged(LocationAvailability)
    case deadlineReached(PositionCheckState.Generation)
    case activeLegChanged
    case activeFlightLost
    case sceneBecameInactive
    case cockpitDismissed
    case end
}

nonisolated struct PositionCheckTransition: Equatable, Sendable {
    let state: PositionCheckState
    let effect: PositionCheckEffect

    static func unchanged(_ state: PositionCheckState) -> PositionCheckTransition {
        PositionCheckTransition(state: state, effect: .none)
    }
}

nonisolated enum PositionCheckEffect: Equatable, Sendable {
    case none
    case scheduleDeadline(generation: PositionCheckState.Generation, deadline: Duration)
    case cancelDeadline
    case endDisclosure(restoration: CockpitRestoration)
}
