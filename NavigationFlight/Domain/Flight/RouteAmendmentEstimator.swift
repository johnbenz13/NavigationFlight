import Foundation

nonisolated enum RouteAmendmentEstimator {
    struct Inputs: Equatable, Sendable {
        let mode: NavigationMode
        let magneticVariationEast: Degrees
        let planningAirspeed: Knots
        let defaultWind: Wind?
    }

    enum Result: Codable, Equatable, Sendable {
        enum Provenance: Codable, Equatable, Sendable {
            case noWind
            case plannedWind(Wind)
        }

        case available(direction: Degrees, durationSeconds: Int, provenance: Provenance)
        case unavailable
    }

    static func estimate(
        from departure: WGS84Coordinate,
        to arrival: WGS84Coordinate,
        inputs: Inputs
    ) -> Result {
        let airspeed = inputs.planningAirspeed.value
        let variation = inputs.magneticVariationEast.value
        guard airspeed.isFinite, airspeed > 0, (-180...180).contains(variation),
              valid(departure), valid(arrival) else { return .unavailable }

        let longitudeDelta = RouteAmendmentRoute.longitudeDelta(
            departure.longitudeDegrees, arrival.longitudeDegrees
        ) * .pi / 180
        let projectedLatitudeDelta = RouteAmendmentRoute.mercatorY(arrival.latitudeDegrees)
            - RouteAmendmentRoute.mercatorY(departure.latitudeDegrees)
        guard longitudeDelta != 0 || projectedLatitudeDelta != 0 else { return .unavailable }
        let course = atan2(longitudeDelta, projectedLatitudeDelta)
        let startLatitude = departure.latitudeDegrees * .pi / 180
        let endLatitude = arrival.latitudeDegrees * .pi / 180
        let haversine = pow(sin((endLatitude - startLatitude) / 2), 2)
            + cos(startLatitude) * cos(endLatitude) * pow(sin(longitudeDelta / 2), 2)
        let distanceNM = 2 * 6_371_008.8 * asin(sqrt(min(1, max(0, haversine)))) / 1_852

        let heading: Double
        let groundSpeed: Double
        let provenance: Result.Provenance
        switch inputs.mode {
        case .noWind:
            heading = course
            groundSpeed = airspeed
            provenance = .noWind
        case .wind:
            guard let wind = inputs.defaultWind,
                  (0..<360).contains(wind.directionFromTrue.value),
                  wind.speed.value.isFinite, wind.speed.value >= 0 else { return .unavailable }
            let relativeWind = (wind.directionFromTrue.value + 180) * .pi / 180 - course
            let crosswindRatio = sin(relativeWind) * wind.speed.value / airspeed
            guard abs(crosswindRatio) < 1 else { return .unavailable }
            heading = course - asin(crosswindRatio)
            groundSpeed = airspeed * sqrt(1 - crosswindRatio * crosswindRatio)
                + cos(relativeWind) * wind.speed.value
            provenance = .plannedWind(wind)
        }
        guard groundSpeed.isFinite, groundSpeed > 0,
              let duration = Int(exactly: (distanceNM / groundSpeed * 3_600).rounded()),
              duration > 0 else { return .unavailable }
        let magneticDirection = (heading * 180 / .pi - variation + 720)
            .truncatingRemainder(dividingBy: 360)
        return .available(direction: Degrees(value: magneticDirection), durationSeconds: duration, provenance: provenance)
    }

    private static func valid(_ point: WGS84Coordinate) -> Bool {
        (-90...90).contains(point.latitudeDegrees) && (-180...180).contains(point.longitudeDegrees)
    }
}
