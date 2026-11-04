import Foundation

nonisolated struct AircraftLocationSample: Equatable, Sendable {
    let coordinate: WGS84Coordinate
    let observedAt: Date
    let horizontalAccuracyMeters: Double
    let altitudeMeters: Double?
    let verticalAccuracyMeters: Double?
    let trueCourseDegrees: Double?
    let courseAccuracyDegrees: Double?
    let groundSpeedMetersPerSecond: Double?
    let speedAccuracyMetersPerSecond: Double?

    init(
        coordinate: WGS84Coordinate,
        observedAt: Date,
        horizontalAccuracyMeters: Double,
        altitudeMeters: Double? = nil,
        verticalAccuracyMeters: Double? = nil,
        trueCourseDegrees: Double?,
        courseAccuracyDegrees: Double?,
        groundSpeedMetersPerSecond: Double?,
        speedAccuracyMetersPerSecond: Double?
    ) {
        self.coordinate = coordinate
        self.observedAt = observedAt
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.altitudeMeters = altitudeMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.trueCourseDegrees = trueCourseDegrees
        self.courseAccuracyDegrees = courseAccuracyDegrees
        self.groundSpeedMetersPerSecond = groundSpeedMetersPerSecond
        self.speedAccuracyMetersPerSecond = speedAccuracyMetersPerSecond
    }
}

nonisolated enum LocationAuthorization: Equatable, Sendable {
    case notDetermined
    case whenInUse
    case denied
    case restricted
}

nonisolated enum LocationPermissionReason: Equatable, Sendable {
    case notDetermined
    case denied
    case restricted
}

nonisolated enum LocationUnavailabilityReason: Equatable, Sendable {
    case servicesDisabled
    case signalLost
    case stale
    case invalidAccuracy
    case insufficientAccuracy
    case outOfOrder
    case sourceFailure
}

nonisolated enum LocationSourceEvent: Equatable, Sendable {
    case authorization(LocationAuthorization)
    case servicesDisabled
    case signalLost
    case sample(AircraftLocationSample, receivedAt: Date)
}

nonisolated enum LocationAvailability: Equatable, Sendable {
    case ready(AircraftLocationSample)
    case acquiring
    case unavailable(LocationUnavailabilityReason)
    case permissionRequired(LocationPermissionReason)
}

nonisolated protocol AircraftLocationSource: Sendable {
    func updates() -> AsyncThrowingStream<LocationSourceEvent, Error>
    func requestWhenInUseAuthorization() async
    func beginRecordingActivity() async
    func endRecordingActivity() async
}

nonisolated extension AircraftLocationSource {
    func beginRecordingActivity() async {}
    func endRecordingActivity() async {}
}
