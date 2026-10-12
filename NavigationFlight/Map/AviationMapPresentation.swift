import Foundation

struct AviationMapCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct AviationMapCameraState: Equatable, Sendable {
    let center: AviationMapCoordinate
    let zoomLevel: Double
    let direction: Double
}

struct AviationMapWaypoint: Identifiable, Equatable, Sendable {
    enum Role: String, Equatable, Sendable {
        case route
        case from
        case to
    }

    let id: UUID
    let name: String
    let coordinate: AviationMapCoordinate
    let role: Role
}

struct AviationMapLeg: Identifiable, Equatable, Sendable {
    let id: UUID
    let index: Int
    let from: AviationMapCoordinate
    let to: AviationMapCoordinate
}

struct AviationMapVORDMEReference: Identifiable, Equatable, Sendable {
    let id: UUID
    let waypointID: UUID
    let waypointCoordinate: AviationMapCoordinate
    let stationIdentifier: String
    let frequencyMHz: Double
    let magneticRadialFromDegrees: Double
    let slantRangeNauticalMiles: Double
}

struct AviationMapPresentation: Equatable, Sendable {
    let waypoints: [AviationMapWaypoint]
    let legs: [AviationMapLeg]
    let activeLegIndex: Int
    let nextLegPreview: AviationMapLeg?
    let endpointReferences: [AviationMapVORDMEReference]

    var activeLeg: AviationMapLeg? {
        legs.first { $0.index == activeLegIndex }
    }

    var readyFocusTarget: AviationMapCoordinate? {
        activeLeg?.from
    }

    var activeFocusTarget: AviationMapCoordinate? {
        activeLeg?.to
    }
}

enum AviationMapPresentationError: Error, Equatable {
    case invalidActiveLegIndex(Int)
    case missingExecutionReference(UUID)
}

struct AviationMapPresentationFactory {
    func makePresentation(
        flight: NavigationFlight,
        session: FlightSession
    ) throws -> AviationMapPresentation {
        guard flight.legs.indices.contains(session.activeLegIndex) else {
            throw AviationMapPresentationError.invalidActiveLegIndex(session.activeLegIndex)
        }

        let activeSourceLeg = flight.legs[session.activeLegIndex]
        let waypoints = flight.waypoints.map { waypoint in
            AviationMapWaypoint(
                id: waypoint.id,
                name: waypoint.name,
                coordinate: coordinate(waypoint.position),
                role: role(
                    for: waypoint.id,
                    departureID: activeSourceLeg.departure.id,
                    arrivalID: activeSourceLeg.arrival.id
                )
            )
        }
        let legs = flight.legs.enumerated().map { index, leg in
            AviationMapLeg(
                id: leg.id,
                index: index,
                from: coordinate(leg.departure.position),
                to: coordinate(leg.arrival.position)
            )
        }

        let executionReferences = Dictionary(
            uniqueKeysWithValues: (flight.execution.execution?.vorDmeReferences ?? []).map {
                ($0.referenceID, $0)
            }
        )
        let endpointIDs = Set([activeSourceLeg.departure.id, activeSourceLeg.arrival.id])
        let endpointReferences = try flight.vorDmeReferences
            .filter { endpointIDs.contains($0.waypointID) }
            .map { reference in
                guard let execution = executionReferences[reference.id] else {
                    throw AviationMapPresentationError.missingExecutionReference(reference.id)
                }
                guard let waypoint = flight.waypoints.first(where: { $0.id == reference.waypointID }) else {
                    throw AviationMapPresentationError.missingExecutionReference(reference.id)
                }
                return AviationMapVORDMEReference(
                    id: reference.id,
                    waypointID: reference.waypointID,
                    waypointCoordinate: coordinate(waypoint.position),
                    stationIdentifier: reference.navigationAid.identifier,
                    frequencyMHz: execution.frequency.value,
                    magneticRadialFromDegrees: execution.magneticRadialFrom.value,
                    slantRangeNauticalMiles: execution.slantRange.value
                )
            }

        return AviationMapPresentation(
            waypoints: waypoints,
            legs: legs,
            activeLegIndex: session.activeLegIndex,
            nextLegPreview: legs.first { $0.index == session.activeLegIndex + 1 },
            endpointReferences: endpointReferences
        )
    }

    private func role(
        for waypointID: UUID,
        departureID: UUID,
        arrivalID: UUID
    ) -> AviationMapWaypoint.Role {
        if waypointID == departureID { return .from }
        if waypointID == arrivalID { return .to }
        return .route
    }

    private func coordinate(_ value: WGS84Coordinate) -> AviationMapCoordinate {
        AviationMapCoordinate(
            latitude: value.latitudeDegrees,
            longitude: value.longitudeDegrees
        )
    }
}

enum AviationMapGeometry {
    static func bearing(
        from: AviationMapCoordinate,
        to: AviationMapCoordinate
    ) -> Double {
        let latitude1 = from.latitude * .pi / 180
        let latitude2 = to.latitude * .pi / 180
        let longitudeDelta = (to.longitude - from.longitude) * .pi / 180
        let y = sin(longitudeDelta) * cos(latitude2)
        let x = cos(latitude1) * sin(latitude2)
            - sin(latitude1) * cos(latitude2) * cos(longitudeDelta)
        return (atan2(y, x) * 180 / .pi + 360).truncatingRemainder(dividingBy: 360)
    }

    static func interpolate(
        from: AviationMapCoordinate,
        to: AviationMapCoordinate,
        fraction: Double
    ) -> AviationMapCoordinate {
        AviationMapCoordinate(
            latitude: from.latitude + (to.latitude - from.latitude) * fraction,
            longitude: from.longitude + (to.longitude - from.longitude) * fraction
        )
    }
}
