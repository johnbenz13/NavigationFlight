import Foundation

#if DEBUG
nonisolated enum PositionCheckFixtureScenario: String, CaseIterable, Sendable {
    case ready
    case acquiring
    case permissionRequired = "permission-required"
    case unavailable
    case recoveryAvailable = "recovery-available"
    case onTrack = "on-track"
    case positionOnly = "position-only"
    case noSensibleIntercept = "no-sensible-intercept"
    case extremeDisplacement = "extreme-displacement"
    case signalLoss = "signal-loss"
    case permissionRevoked = "permission-revoked"
}

nonisolated struct PositionCheckFixtureSource: AircraftLocationSource {
    typealias Sleep = @Sendable (Duration) async -> Void

    let scenario: PositionCheckFixtureScenario
    let observedAt: Date
    let followUpDelay: Duration
    private let sleep: Sleep

    init(
        scenario: PositionCheckFixtureScenario,
        observedAt: Date = .now,
        followUpDelay: Duration = .seconds(6),
        sleep: @escaping Sleep = { duration in try? await Task.sleep(for: duration) }
    ) {
        self.scenario = scenario
        self.observedAt = observedAt
        self.followUpDelay = followUpDelay
        self.sleep = sleep
    }

    func updates() -> AsyncThrowingStream<LocationSourceEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                continuation.yield(initialEvent)
                guard let followUpEvent else {
                    continuation.finish()
                    return
                }
                await sleep(followUpDelay)
                guard !Task.isCancelled else { return }
                continuation.yield(followUpEvent)
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func requestWhenInUseAuthorization() async {}

    private var initialEvent: LocationSourceEvent {
        switch scenario {
        case .acquiring:
            .authorization(.whenInUse)
        case .permissionRequired:
            .authorization(.denied)
        case .unavailable:
            .signalLost
        case .ready, .recoveryAvailable, .onTrack, .positionOnly,
             .noSensibleIntercept, .extremeDisplacement, .signalLoss,
             .permissionRevoked:
            sampleEvent
        }
    }

    private var followUpEvent: LocationSourceEvent? {
        switch scenario {
        case .signalLoss:
            .signalLost
        case .permissionRevoked:
            .authorization(.denied)
        default:
            nil
        }
    }

    private var sampleEvent: LocationSourceEvent {
        let values: (latitude: Double, longitude: Double, speed: Double?) = switch scenario {
        case .recoveryAvailable, .signalLoss, .permissionRevoked:
            (0.008, 0.006, 50)
        case .onTrack:
            (0.008, 0.001, 50)
        case .positionOnly:
            (0.008, 0.006, nil)
        case .noSensibleIntercept:
            (0.02, 0.001, 50)
        case .extremeDisplacement:
            (0.008, 0.25, 50)
        default:
            (32, 34.8, 20)
        }
        return .sample(
            AircraftLocationSample(
                coordinate: WGS84Coordinate(
                    latitudeDegrees: values.latitude,
                    longitudeDegrees: values.longitude
                ),
                observedAt: observedAt,
                horizontalAccuracyMeters: 50,
                trueCourseDegrees: 90,
                courseAccuracyDegrees: 10,
                groundSpeedMetersPerSecond: values.speed,
                speedAccuracyMetersPerSecond: 1
            ),
            receivedAt: observedAt
        )
    }
}
#endif
