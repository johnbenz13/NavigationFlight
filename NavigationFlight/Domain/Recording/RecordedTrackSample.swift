import Foundation

nonisolated struct RecordedTrackSample: Equatable, Sendable {
    let coordinate: WGS84Coordinate
    let observedAt: Date
    let horizontalAccuracyMeters: Double
    let altitudeMeters: Double?
    let verticalAccuracyMeters: Double?
    let groundSpeedMetersPerSecond: Double?
    let speedAccuracyMetersPerSecond: Double?
    let courseDegrees: Double?
    let courseAccuracyDegrees: Double?
    let barometricAltitudeMeters: Double?
    let deviceHeadingDegrees: Double?
    let deviceHeadingAccuracyDegrees: Double?

    init?(_ sample: AircraftLocationSample) {
        let latitude = sample.coordinate.latitudeDegrees
        let longitude = sample.coordinate.longitudeDegrees
        guard latitude.isFinite, (-90...90).contains(latitude),
              longitude.isFinite, (-180...180).contains(longitude),
              sample.observedAt.timeIntervalSinceReferenceDate.isFinite,
              sample.horizontalAccuracyMeters.isFinite,
              sample.horizontalAccuracyMeters >= 0 else { return nil }
        coordinate = sample.coordinate
        observedAt = sample.observedAt
        horizontalAccuracyMeters = sample.horizontalAccuracyMeters
        altitudeMeters = sample.altitudeMeters
        verticalAccuracyMeters = sample.verticalAccuracyMeters
        groundSpeedMetersPerSecond = sample.groundSpeedMetersPerSecond
        speedAccuracyMetersPerSecond = sample.speedAccuracyMetersPerSecond
        courseDegrees = sample.trueCourseDegrees
        courseAccuracyDegrees = sample.courseAccuracyDegrees
        barometricAltitudeMeters = nil
        deviceHeadingDegrees = nil
        deviceHeadingAccuracyDegrees = nil
    }

    init(
        coordinate: WGS84Coordinate,
        observedAt: Date,
        horizontalAccuracyMeters: Double,
        altitudeMeters: Double?,
        verticalAccuracyMeters: Double?,
        groundSpeedMetersPerSecond: Double?,
        speedAccuracyMetersPerSecond: Double?,
        courseDegrees: Double?,
        courseAccuracyDegrees: Double?,
        barometricAltitudeMeters: Double? = nil,
        deviceHeadingDegrees: Double? = nil,
        deviceHeadingAccuracyDegrees: Double? = nil
    ) {
        self.coordinate = coordinate
        self.observedAt = observedAt
        self.horizontalAccuracyMeters = horizontalAccuracyMeters
        self.altitudeMeters = altitudeMeters
        self.verticalAccuracyMeters = verticalAccuracyMeters
        self.groundSpeedMetersPerSecond = groundSpeedMetersPerSecond
        self.speedAccuracyMetersPerSecond = speedAccuracyMetersPerSecond
        self.courseDegrees = courseDegrees
        self.courseAccuracyDegrees = courseAccuracyDegrees
        self.barometricAltitudeMeters = barometricAltitudeMeters
        self.deviceHeadingDegrees = deviceHeadingDegrees
        self.deviceHeadingAccuracyDegrees = deviceHeadingAccuracyDegrees
    }

    func addingSupplemental(
        barometricAltitudeMeters: Double?,
        deviceHeadingDegrees: Double?,
        deviceHeadingAccuracyDegrees: Double?
    ) -> Self {
        Self(
            coordinate: coordinate,
            observedAt: observedAt,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            altitudeMeters: altitudeMeters,
            verticalAccuracyMeters: verticalAccuracyMeters,
            groundSpeedMetersPerSecond: groundSpeedMetersPerSecond,
            speedAccuracyMetersPerSecond: speedAccuracyMetersPerSecond,
            courseDegrees: courseDegrees,
            courseAccuracyDegrees: courseAccuracyDegrees,
            barometricAltitudeMeters: barometricAltitudeMeters,
            deviceHeadingDegrees: deviceHeadingDegrees,
            deviceHeadingAccuracyDegrees: deviceHeadingAccuracyDegrees
        )
    }
}

nonisolated struct RecordedTrackSegment: Equatable, Sendable, Identifiable {
    let id: UUID
    var samples: [RecordedTrackSample]
}

nonisolated struct RecordedTrackBatch: Equatable, Sendable {
    let recordingID: UUID
    let segmentID: UUID
    let samples: [RecordedTrackSample]
}
