import Foundation

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

    func transition(_ intent: PositionCheckIntent, now: Duration) -> PositionCheckTransition {
        switch intent {
        case .holdCompleted(let availability, let restoration),
             .restartHoldCompleted(let availability, let restoration):
            return start(availability: availability, restoration: restoration, now: now)
        case .cancel:
            guard case .acquiring = self else { return .unchanged(self) }
            return PositionCheckTransition(state: .idle, effect: .cancelDeadline)
        case .locationAvailabilityChanged(.ready(let sample)):
            switch self {
            case .acquiring(let request):
                return activate(sample: sample, restoration: request.restoration, now: now)
            case .active(let session):
                let updated = Session(
                    generation: session.generation,
                    deadline: session.deadline,
                    projection: PositionCheckProjection(sample: sample),
                    restoration: session.restoration
                )
                return PositionCheckTransition(state: .active(updated), effect: .none)
            default:
                return .unchanged(self)
            }
        case .locationAvailabilityChanged:
            return .unchanged(self)
        case .deadlineReached(let generation):
            switch self {
            case .acquiring(let request) where request.generation == generation:
                return PositionCheckTransition(state: .transientFailure(.acquisitionTimedOut), effect: .cancelDeadline)
            case .active(let session) where session.generation == generation:
                return PositionCheckTransition(state: .idle, effect: .endDisclosure(restoration: session.restoration))
            default:
                return .unchanged(self)
            }
        case .activeLegChanged, .sceneBecameInactive, .cockpitDismissed:
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
        now: Duration
    ) -> PositionCheckTransition {
        switch availability {
        case .ready(let sample):
            return activate(sample: sample, restoration: restoration, now: now)
        case .acquiring, .unavailable:
            let request = Request(
                generation: Generation(),
                deadline: now + .seconds(10),
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
        now: Duration
    ) -> PositionCheckTransition {
        let session = Session(
            generation: Generation(),
            deadline: now + .seconds(10),
            projection: PositionCheckProjection(sample: sample),
            restoration: restoration
        )
        return PositionCheckTransition(
            state: .active(session),
            effect: .scheduleDeadline(generation: session.generation, deadline: session.deadline)
        )
    }
}

nonisolated enum PositionCheckIntent: Equatable, Sendable {
    case holdCompleted(availability: LocationAvailability, restoration: CockpitRestoration)
    case cancel
    case restartHoldCompleted(availability: LocationAvailability, restoration: CockpitRestoration)
    case locationAvailabilityChanged(LocationAvailability)
    case deadlineReached(PositionCheckState.Generation)
    case activeLegChanged
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
