import Foundation

#if DEBUG
nonisolated struct FixtureAircraftLocationSource: AircraftLocationSource {
    let event: LocationSourceEvent

    func updates() -> AsyncThrowingStream<LocationSourceEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(event)
        }
    }

    func requestWhenInUseAuthorization() async {}

    static func make(state: String) -> FixtureAircraftLocationSource {
        let now = Date.now
        switch state {
        case "ready", "recovery-available", "on-track", "position-only", "no-sensible-intercept", "extreme-displacement":
            let values: (latitude: Double, longitude: Double, speed: Double?) = switch state {
            case "recovery-available": (0.008, 0.006, 50)
            case "on-track": (0.008, 0.001, 50)
            case "position-only": (0.008, 0.006, nil)
            case "no-sensible-intercept": (0.02, 0.001, 50)
            case "extreme-displacement": (0.008, 0.25, 50)
            default: (32, 34.8, 20)
            }
            return FixtureAircraftLocationSource(event: .sample(
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
            ))
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
