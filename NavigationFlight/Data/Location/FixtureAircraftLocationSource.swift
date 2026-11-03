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
        case "ready":
            return FixtureAircraftLocationSource(event: .sample(
                AircraftLocationSample(
                    coordinate: WGS84Coordinate(latitudeDegrees: 32, longitudeDegrees: 34.8),
                    observedAt: now,
                    horizontalAccuracyMeters: 50,
                    trueCourseDegrees: 90,
                    courseAccuracyDegrees: 10,
                    groundSpeedMetersPerSecond: 20,
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
