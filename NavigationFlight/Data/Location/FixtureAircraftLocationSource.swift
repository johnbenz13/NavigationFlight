import Foundation

#if DEBUG
nonisolated struct FixtureAircraftLocationSource: AircraftLocationSource {
    let event: LocationSourceEvent
    let delayedEvent: LocationSourceEvent?

    init(event: LocationSourceEvent, delayedEvent: LocationSourceEvent? = nil) {
        self.event = event
        self.delayedEvent = delayedEvent
    }

    func updates() -> AsyncThrowingStream<LocationSourceEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(event)
            guard let delayedEvent else { return }
            Task {
                try? await Task.sleep(for: .seconds(6))
                guard !Task.isCancelled else { return }
                continuation.yield(delayedEvent)
                for _ in 0..<5 {
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    continuation.yield(event)
                    try? await Task.sleep(for: .seconds(3))
                    guard !Task.isCancelled else { return }
                    continuation.yield(delayedEvent)
                }
            }
        }
    }

    func requestWhenInUseAuthorization() async {}

    static func make(state: String) -> FixtureAircraftLocationSource {
        let now = Date.now
        switch state {
        case "ready", "recovery-available", "on-track", "position-only", "no-sensible-intercept", "extreme-displacement", "signal-loss", "permission-revoked":
            let values: (latitude: Double, longitude: Double, speed: Double?) = switch state {
            case "recovery-available", "signal-loss", "permission-revoked": (0.008, 0.006, 50)
            case "on-track": (0.008, 0.001, 50)
            case "position-only": (0.008, 0.006, nil)
            case "no-sensible-intercept": (0.02, 0.001, 50)
            case "extreme-displacement": (0.008, 0.25, 50)
            default: (32, 34.8, 20)
            }
            let sample = LocationSourceEvent.sample(
                AircraftLocationSample(
                    coordinate: WGS84Coordinate(latitudeDegrees: values.latitude, longitudeDegrees: values.longitude),
                    observedAt: now,
                    horizontalAccuracyMeters: 50,
                    trueCourseDegrees: 90,
                    courseAccuracyDegrees: 10,
                    groundSpeedMetersPerSecond: values.speed,
                    speedAccuracyMetersPerSecond: 1
                ),
                receivedAt: now
            )
            let delayedEvent: LocationSourceEvent? = switch state {
                case "signal-loss": .signalLost
                case "permission-revoked": .authorization(.denied)
                default: nil
            }
            return FixtureAircraftLocationSource(event: sample, delayedEvent: delayedEvent)
        case "unavailable":
            return FixtureAircraftLocationSource(event: .signalLost)
        case "permission-required":
            return FixtureAircraftLocationSource(event: .authorization(.denied))
        default:
            return FixtureAircraftLocationSource(event: .authorization(.whenInUse))
        }
    }
}
#endif
