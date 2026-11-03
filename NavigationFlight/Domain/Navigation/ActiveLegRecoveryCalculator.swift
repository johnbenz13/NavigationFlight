import Foundation

nonisolated enum RecoveryUnavailabilityReason: Equatable, Sendable {
    case insufficientPositionQuality
    case insufficientMovementQuality
    case noActiveLeg
    case activeLegPassed
    case insufficientRemainingLeg
    case extremeDisplacement
}

nonisolated struct RecoveryGuidance: Equatable, Sendable {
    let magneticCourseDegrees: Double
    let rejoinTimeSeconds: Double
    let distanceNauticalMiles: Double
    let interceptCoordinate: WGS84Coordinate
    let interceptAngleDegrees: Double
}

nonisolated enum ActiveLegRecoveryOutcome: Equatable, Sendable {
    case onTrack
    case guidance(RecoveryGuidance)
    case unavailable(RecoveryUnavailabilityReason)
}

nonisolated struct PositionCheckRecoveryPolicy: Equatable, Sendable {
    let minimumCorridorNauticalMiles: Double
    let accuracyMultiplier: Double
    let shallowInterceptDegrees: Double
    let maximumInterceptDegrees: Double
    let shallowInterceptTimeSeconds: Double
    let maximumInterceptTimeSeconds: Double
    let minimumGroundSpeedMetersPerSecond: Double
    let extremeDisplacementNauticalMiles: Double

    init(
        minimumCorridorNauticalMiles: Double = 0.2,
        accuracyMultiplier: Double = 2,
        shallowInterceptDegrees: Double = 20,
        maximumInterceptDegrees: Double = 45,
        shallowInterceptTimeSeconds: Double = 30,
        maximumInterceptTimeSeconds: Double = 120,
        minimumGroundSpeedMetersPerSecond: Double = 5,
        extremeDisplacementNauticalMiles: Double = 10
    ) {
        self.minimumCorridorNauticalMiles = minimumCorridorNauticalMiles
        self.accuracyMultiplier = accuracyMultiplier
        self.shallowInterceptDegrees = shallowInterceptDegrees
        self.maximumInterceptDegrees = maximumInterceptDegrees
        self.shallowInterceptTimeSeconds = shallowInterceptTimeSeconds
        self.maximumInterceptTimeSeconds = maximumInterceptTimeSeconds
        self.minimumGroundSpeedMetersPerSecond = minimumGroundSpeedMetersPerSecond
        self.extremeDisplacementNauticalMiles = extremeDisplacementNauticalMiles
    }
}

nonisolated struct ActiveLegRecoveryCalculator: Sendable {
    private let policy: PositionCheckRecoveryPolicy

    init(policy: PositionCheckRecoveryPolicy = PositionCheckRecoveryPolicy()) {
        self.policy = policy
    }

    func calculate(
        sample: AircraftLocationSample,
        legStart: WGS84Coordinate,
        legEnd: WGS84Coordinate,
        importedMagneticCourseDegrees: Double
    ) -> ActiveLegRecoveryOutcome {
        guard sample.horizontalAccuracyMeters.isFinite, sample.horizontalAccuracyMeters >= 0 else {
            return .unavailable(.insufficientPositionQuality)
        }

        let start = Coordinate(legStart)
        let end = Coordinate(legEnd)
        let aircraft = Coordinate(sample.coordinate)
        let legDistance = distance(from: start, to: end)
        guard legDistance > 0, importedMagneticCourseDegrees.isFinite else {
            return .unavailable(.noActiveLeg)
        }

        let legBearing = bearing(from: start, to: end)
        let aircraftDistance = angularDistance(from: start, to: aircraft)
        let bearingToAircraft = bearing(from: start, to: aircraft)
        let bearingDifference = normalizedSigned(bearingToAircraft - legBearing) * .pi / 180
        let crossTrack = asin(clamp(sin(aircraftDistance) * sin(bearingDifference), -1, 1)) * Self.earthRadiusNauticalMiles
        let alongTrack = atan2(
            sin(aircraftDistance) * cos(bearingDifference),
            cos(aircraftDistance)
        ) * Self.earthRadiusNauticalMiles
        let corridor = max(
            policy.minimumCorridorNauticalMiles,
            policy.accuracyMultiplier * sample.horizontalAccuracyMeters / 1_852
        )

        if alongTrack > legDistance + corridor {
            return .unavailable(.activeLegPassed)
        }
        let absoluteCrossTrack = abs(crossTrack)
        if absoluteCrossTrack > max(policy.extremeDisplacementNauticalMiles, legDistance) {
            return .unavailable(.extremeDisplacement)
        }
        if absoluteCrossTrack <= corridor {
            return .onTrack
        }
        guard let groundSpeed = sample.groundSpeedMetersPerSecond,
              groundSpeed.isFinite,
              groundSpeed >= policy.minimumGroundSpeedMetersPerSecond,
              sample.trueCourseDegrees != nil else {
            return .unavailable(.insufficientMovementQuality)
        }

        let crossTrackTime = absoluteCrossTrack * 1_852 / groundSpeed
        let interceptAngle = selectedInterceptAngle(crossTrackTime: crossTrackTime)
        let lookAhead = absoluteCrossTrack / tan(interceptAngle * .pi / 180)
        let requestedAlongTrack = max(0, alongTrack) + lookAhead
        let interceptAlongTrack = min(requestedAlongTrack, legDistance)
        guard interceptAlongTrack > max(0, alongTrack) else {
            return .unavailable(.insufficientRemainingLeg)
        }

        let intercept = destination(from: start, bearingDegrees: legBearing, distanceNauticalMiles: interceptAlongTrack)
        let recoveryBearing = bearing(from: aircraft, to: intercept)
        let actualInterceptAngle = abs(normalizedSigned(recoveryBearing - legBearing))
        guard actualInterceptAngle <= policy.maximumInterceptDegrees + 0.001 else {
            return .unavailable(.insufficientRemainingLeg)
        }

        let recoveryDistance = distance(from: aircraft, to: intercept)
        let trueToMagneticCorrection = normalizedSigned(legBearing - importedMagneticCourseDegrees)
        let magneticRecoveryCourse = normalized360(recoveryBearing - trueToMagneticCorrection)
        return .guidance(
            RecoveryGuidance(
                magneticCourseDegrees: magneticRecoveryCourse,
                rejoinTimeSeconds: recoveryDistance * 1_852 / groundSpeed,
                distanceNauticalMiles: recoveryDistance,
                interceptCoordinate: intercept.wgs84,
                interceptAngleDegrees: actualInterceptAngle
            )
        )
    }

    private func selectedInterceptAngle(crossTrackTime: Double) -> Double {
        guard crossTrackTime > policy.shallowInterceptTimeSeconds else {
            return policy.shallowInterceptDegrees
        }
        guard crossTrackTime < policy.maximumInterceptTimeSeconds else {
            return policy.maximumInterceptDegrees
        }
        let fraction = (crossTrackTime - policy.shallowInterceptTimeSeconds)
            / (policy.maximumInterceptTimeSeconds - policy.shallowInterceptTimeSeconds)
        return policy.shallowInterceptDegrees
            + fraction * (policy.maximumInterceptDegrees - policy.shallowInterceptDegrees)
    }

    private struct Coordinate {
        let latitudeRadians: Double
        let longitudeRadians: Double

        init(_ value: WGS84Coordinate) {
            latitudeRadians = value.latitudeDegrees * .pi / 180
            longitudeRadians = value.longitudeDegrees * .pi / 180
        }

        init(latitudeRadians: Double, longitudeRadians: Double) {
            self.latitudeRadians = latitudeRadians
            self.longitudeRadians = longitudeRadians
        }

        var wgs84: WGS84Coordinate {
            WGS84Coordinate(
                latitudeDegrees: latitudeRadians * 180 / .pi,
                longitudeDegrees: longitudeRadians * 180 / .pi
            )
        }
    }

    private static let earthRadiusNauticalMiles = 3_440.065

    private func angularDistance(from: Coordinate, to: Coordinate) -> Double {
        let latitudeDelta = to.latitudeRadians - from.latitudeRadians
        let longitudeDelta = to.longitudeRadians - from.longitudeRadians
        let haversine = pow(sin(latitudeDelta / 2), 2)
            + cos(from.latitudeRadians) * cos(to.latitudeRadians) * pow(sin(longitudeDelta / 2), 2)
        return 2 * atan2(sqrt(haversine), sqrt(max(0, 1 - haversine)))
    }

    private func distance(from: Coordinate, to: Coordinate) -> Double {
        angularDistance(from: from, to: to) * Self.earthRadiusNauticalMiles
    }

    private func bearing(from: Coordinate, to: Coordinate) -> Double {
        let longitudeDelta = to.longitudeRadians - from.longitudeRadians
        let y = sin(longitudeDelta) * cos(to.latitudeRadians)
        let x = cos(from.latitudeRadians) * sin(to.latitudeRadians)
            - sin(from.latitudeRadians) * cos(to.latitudeRadians) * cos(longitudeDelta)
        return normalized360(atan2(y, x) * 180 / .pi)
    }

    private func destination(
        from: Coordinate,
        bearingDegrees: Double,
        distanceNauticalMiles: Double
    ) -> Coordinate {
        let angularDistance = distanceNauticalMiles / Self.earthRadiusNauticalMiles
        let bearing = bearingDegrees * .pi / 180
        let latitude = asin(
            sin(from.latitudeRadians) * cos(angularDistance)
                + cos(from.latitudeRadians) * sin(angularDistance) * cos(bearing)
        )
        let longitude = from.longitudeRadians + atan2(
            sin(bearing) * sin(angularDistance) * cos(from.latitudeRadians),
            cos(angularDistance) - sin(from.latitudeRadians) * sin(latitude)
        )
        return Coordinate(latitudeRadians: latitude, longitudeRadians: longitude)
    }

    private func normalized360(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }

    private func normalizedSigned(_ degrees: Double) -> Double {
        let value = normalized360(degrees)
        return value > 180 ? value - 360 : value
    }

    private func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }
}
