import Foundation

struct AviationMapCoordinate: Equatable, Sendable {
    let latitude: Double
    let longitude: Double
}

struct AviationMapCameraState: Equatable, Sendable {
    let center: AviationMapCoordinate
    let zoomLevel: Double
    let direction: Double
    let pitch: Double
}

nonisolated struct GPSDisclosureOverlay: Equatable, Sendable {
    enum Marker: Equatable, Sendable {
        case neutral
        case directional(trueCourseDegrees: Double)
    }

    let coordinate: AviationMapCoordinate
    let accuracyRadiusMeters: Double
    let marker: Marker

    init(projection: PositionCheckProjection) {
        coordinate = AviationMapCoordinate(
            latitude: projection.coordinate.latitudeDegrees,
            longitude: projection.coordinate.longitudeDegrees
        )
        accuracyRadiusMeters = projection.horizontalAccuracyMeters
        marker = projection.trueCourseDegrees.map(Marker.directional) ?? .neutral
    }
}

nonisolated enum GPSDisclosureMapContract {
    static let accuracySourceID = "position-check-accuracy-source"
    static let accuracyLayerID = "position-check-accuracy-layer"
    static let markerSourceID = "position-check-marker-source"
    static let markerLayerID = "position-check-marker-layer"

    static func accuracyRing(
        for overlay: GPSDisclosureOverlay,
        vertexCount: Int = 48
    ) -> [AviationMapCoordinate] {
        guard overlay.accuracyRadiusMeters > 0, vertexCount >= 3 else { return [] }
        let earthRadius = 6_371_000.0
        let latitude = overlay.coordinate.latitude * .pi / 180
        let longitude = overlay.coordinate.longitude * .pi / 180
        let angularDistance = overlay.accuracyRadiusMeters / earthRadius
        return (0...vertexCount).map { index in
            let bearing = 2 * Double.pi * Double(index) / Double(vertexCount)
            let ringLatitude = asin(
                sin(latitude) * cos(angularDistance)
                    + cos(latitude) * sin(angularDistance) * cos(bearing)
            )
            let ringLongitude = longitude + atan2(
                sin(bearing) * sin(angularDistance) * cos(latitude),
                cos(angularDistance) - sin(latitude) * sin(ringLatitude)
            )
            return AviationMapCoordinate(
                latitude: ringLatitude * 180 / .pi,
                longitude: ringLongitude * 180 / .pi
            )
        }
    }
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

struct AviationMapDriftReferenceArm: Equatable, Sendable {
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

struct AviationMapMinuteMarker: Equatable, Sendable {
    let minute: Int
    let fraction: Double
    let coordinate: AviationMapCoordinate
    let level: AviationMapMinuteMarkLevel

    var showsLabel: Bool { level == .even }
}

struct AviationMapIdentificationPoint: Identifiable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case future
        case reached
        case passedWithoutReport
    }

    let id: IdentificationPointKey
    let name: String
    let coordinate: AviationMapCoordinate
    let plannedElapsedSeconds: Int
    let status: Status
    let committedETASeconds: Int?

    var isReached: Bool { status == .reached }

    init(
        id: IdentificationPointKey,
        name: String,
        coordinate: AviationMapCoordinate,
        plannedElapsedSeconds: Int,
        status: Status,
        committedETASeconds: Int?
    ) {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.plannedElapsedSeconds = plannedElapsedSeconds
        self.status = status
        self.committedETASeconds = committedETASeconds
    }

    init(
        id: IdentificationPointKey,
        name: String,
        coordinate: AviationMapCoordinate,
        plannedElapsedSeconds: Int,
        isReached: Bool,
        committedETASeconds: Int?
    ) {
        self.init(
            id: id,
            name: name,
            coordinate: coordinate,
            plannedElapsedSeconds: plannedElapsedSeconds,
            status: isReached ? .reached : .future,
            committedETASeconds: committedETASeconds
        )
    }

    var operationalState: AviationMapIdentificationPointOperationalState {
        AviationMapIdentificationPointOperationalState(
            status: status,
            plannedElapsedSeconds: plannedElapsedSeconds,
            committedETASeconds: committedETASeconds
        )
    }
}

struct AviationMapIdentificationPointOperationalState: Equatable, Sendable {
    let status: AviationMapIdentificationPoint.Status
    let plannedElapsedSeconds: Int
    let committedETASeconds: Int?

    var isReached: Bool { status == .reached }
    var isPassedWithoutReport: Bool { status == .passedWithoutReport }
    var canMarkReached: Bool { status == .future }
    var canEditETA: Bool { status == .future }
    var operationalETASeconds: Int { committedETASeconds ?? plannedElapsedSeconds }
}

struct AviationMapETATarget: Identifiable, Equatable, Sendable {
    let id: NavigationTimingTargetKey
    let name: String
    let plannedElapsedSeconds: Int
    var kind: NavigationTimingTargetKey.Kind { id.kind }
    let committedETASeconds: Int?
}

struct AviationMapIdentificationContext: Equatable, Sendable {
    let pointID: IdentificationPointKey
    let actualElapsedSeconds: Int?
    let nextTarget: AviationMapETATarget?
    let reportError: Flight.TransitionError?

    init(
        pointID: IdentificationPointKey,
        actualElapsedSeconds: Int?,
        nextTarget: AviationMapETATarget?,
        reportError: Flight.TransitionError? = nil
    ) {
        self.pointID = pointID
        self.actualElapsedSeconds = actualElapsedSeconds
        self.nextTarget = nextTarget
        self.reportError = reportError
    }
}

struct AviationMapTimingTargetContext: Equatable, Sendable {
    let target: AviationMapETATarget
    let targetIdentifier: String
    let pilotETAState: Flight.PilotETAState
    let timingReferenceSeconds: Int?
    let observationBasis: String?
    let canCheck: Bool
    let minimumETASeconds: Int

    var canCommit: Bool { pilotETAState.draftSeconds >= minimumETASeconds }
}

struct AviationMapPresentation: Equatable, Sendable {
    var gpsDisclosureOverlay: GPSDisclosureOverlay? = nil
    let waypoints: [AviationMapWaypoint]
    let legs: [AviationMapLeg]
    let activeLegIndex: Int
    let nextLegPreview: AviationMapLeg?
    let endpointReferences: [AviationMapVORDMEReference]
    let plannedDurationSeconds: Int
    let minuteMarkers: [AviationMapMinuteMarker]
    let identificationPoints: [AviationMapIdentificationPoint]
    let destinationTarget: AviationMapETATarget
    let driftReferenceArms: [AviationMapDriftReferenceArm]

    var activeLeg: AviationMapLeg? {
        legs.first { $0.index == activeLegIndex }
    }

    var readyFocusTarget: AviationMapCoordinate? {
        activeLeg?.from
    }

    var activeFocusTarget: AviationMapCoordinate? {
        activeLeg?.to
    }

    var plannedDurationText: String {
        AviationMapSymbology.formatDuration(plannedDurationSeconds)
    }

    func nextETATarget(after identificationPointID: IdentificationPointKey) -> AviationMapETATarget? {
        guard let reachedIndex = identificationPoints.firstIndex(where: { $0.id == identificationPointID }) else {
            return nil
        }
        if let next = identificationPoints[(reachedIndex + 1)...].first(where: { $0.status == .future }) {
            return AviationMapETATarget(
                id: NavigationTimingTargetKey(
                    legID: next.id.legID,
                    kind: .identificationPoint,
                    targetID: next.id.identificationPointID
                ),
                name: next.name,
                plannedElapsedSeconds: next.plannedElapsedSeconds,
                committedETASeconds: next.committedETASeconds
            )
        }
        return destinationTarget
    }

    var currentETATarget: AviationMapETATarget {
        if let next = identificationPoints.first(where: { $0.status == .future }) {
            return AviationMapETATarget(
                id: NavigationTimingTargetKey(
                    legID: next.id.legID,
                    kind: .identificationPoint,
                    targetID: next.id.identificationPointID
                ),
                name: next.name,
                plannedElapsedSeconds: next.plannedElapsedSeconds,
                committedETASeconds: next.committedETASeconds
            )
        }
        return destinationTarget
    }

    func timingTarget(for key: NavigationTimingTargetKey) -> AviationMapETATarget? {
        if destinationTarget.id == key { return destinationTarget }
        guard key.kind == .identificationPoint,
              let point = identificationPoints.first(where: {
                  $0.id.legID == key.legID && $0.id.identificationPointID == key.targetID
              }) else { return nil }
        return AviationMapETATarget(
            id: key,
            name: point.name,
            plannedElapsedSeconds: point.plannedElapsedSeconds,
            committedETASeconds: point.committedETASeconds
        )
    }
}

enum AviationMapPresentationError: Error, Equatable {
    case invalidActiveLegIndex(Int)
    case missingPlannedNavigationReference(UUID)
    case unavailablePlannedNavigation
    case unavailableWindMode
}

struct AviationMapPresentationFactory {
    func makePresentation(
        flightPlan: FlightPlan,
        flight: Flight
    ) throws -> AviationMapPresentation {
        guard flightPlan.legs.indices.contains(flight.activeLegIndex) else {
            throw AviationMapPresentationError.invalidActiveLegIndex(flight.activeLegIndex)
        }
        guard case .eligible(let plannedNavigation) = flightPlan.plannedNavigation,
              plannedNavigation.legs.indices.contains(flight.activeLegIndex) else {
            throw AviationMapPresentationError.unavailablePlannedNavigation
        }

        let activeSourceLeg = flightPlan.legs[flight.activeLegIndex]
        let resolvedLeg = plannedNavigation.legs[flight.activeLegIndex]
        let plannedDurationSeconds: Int
        switch flight.executionMode {
        case .noWind:
            plannedDurationSeconds = resolvedLeg.noWind.durationSeconds
        case .wind:
            guard let wind = resolvedLeg.withWind else {
                throw AviationMapPresentationError.unavailableWindMode
            }
            plannedDurationSeconds = wind.timing.durationSeconds
        }
        let waypoints = flightPlan.waypoints.map { waypoint in
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
        let legs = flightPlan.legs.enumerated().map { index, leg in
            AviationMapLeg(
                id: leg.id,
                index: index,
                from: coordinate(leg.departure.position),
                to: coordinate(leg.arrival.position)
            )
        }
        let annotationsByID = Dictionary(uniqueKeysWithValues: plannedNavigation.annotations.map { ($0.entityID, $0) })
        let activeIdentificationPoints = try flightPlan.identificationPoints
            .filter { $0.legID == activeSourceLeg.id }
            .enumerated()
            .map { offset, sourcePoint in
                guard let resolved = annotationsByID[sourcePoint.id],
                      resolved.kind == .identificationPoint,
                      resolved.legID == activeSourceLeg.id else {
                    throw AviationMapPresentationError.missingPlannedNavigationReference(sourcePoint.id)
                }
                let plannedElapsed: Int
                switch flight.executionMode {
                case .noWind:
                    plannedElapsed = resolved.noWindTimeFromLegStartSeconds
                case .wind:
                    guard let withWind = resolved.withWindTimeFromLegStartSeconds else {
                        throw AviationMapPresentationError.unavailableWindMode
                    }
                    plannedElapsed = withWind
                }
                let pointKey = IdentificationPointKey(
                    legID: activeSourceLeg.id,
                    identificationPointID: sourcePoint.id
                )
                let targetKey = NavigationTimingTargetKey(
                    legID: activeSourceLeg.id,
                    kind: .identificationPoint,
                    targetID: sourcePoint.id
                )
                let status: AviationMapIdentificationPoint.Status = switch flight.identificationPointState(for: pointKey) {
                case .future: .future
                case .reached: .reached
                case .passedWithoutReport: .passedWithoutReport
                }
                return AviationMapIdentificationPoint(
                    id: pointKey,
                    name: "IP\(offset + 1)",
                    coordinate: coordinate(resolved.position),
                    plannedElapsedSeconds: plannedElapsed,
                    status: status,
                    committedETASeconds: flight.committedPilotETA(targetKey: targetKey)
                )
            }

        let executionReferences = Dictionary(
            uniqueKeysWithValues: (flightPlan.plannedNavigation.plannedNavigation?.vorDmeReferences ?? []).map {
                ($0.referenceID, $0)
            }
        )
        let endpointIDs = Set([activeSourceLeg.departure.id, activeSourceLeg.arrival.id])
        let endpointReferences = try flightPlan.vorDmeReferences
            .filter { endpointIDs.contains($0.waypointID) }
            .map { reference in
                guard let plannedNavigation = executionReferences[reference.id] else {
                    throw AviationMapPresentationError.missingPlannedNavigationReference(reference.id)
                }
                guard let waypoint = flightPlan.waypoints.first(where: { $0.id == reference.waypointID }) else {
                    throw AviationMapPresentationError.missingPlannedNavigationReference(reference.id)
                }
                return AviationMapVORDMEReference(
                    id: reference.id,
                    waypointID: reference.waypointID,
                    waypointCoordinate: coordinate(waypoint.position),
                    stationIdentifier: reference.navigationAid.identifier,
                    frequencyMHz: plannedNavigation.frequency.value,
                    magneticRadialFromDegrees: plannedNavigation.magneticRadialFrom.value,
                    slantRangeNauticalMiles: plannedNavigation.slantRange.value
                )
            }

        return AviationMapPresentation(
            waypoints: waypoints,
            legs: legs,
            activeLegIndex: flight.activeLegIndex,
            nextLegPreview: legs.first { $0.index == flight.activeLegIndex + 1 },
            endpointReferences: endpointReferences,
            plannedDurationSeconds: plannedDurationSeconds,
            minuteMarkers: AviationMapSymbology.minuteMarkers(
                from: coordinate(activeSourceLeg.departure.position),
                to: coordinate(activeSourceLeg.arrival.position),
                plannedDurationSeconds: plannedDurationSeconds
            ),
            identificationPoints: activeIdentificationPoints,
            destinationTarget: AviationMapETATarget(
                id: NavigationTimingTargetKey(
                    legID: activeSourceLeg.id,
                    kind: .destination,
                    targetID: activeSourceLeg.arrival.id
                ),
                name: activeSourceLeg.arrival.name,
                plannedElapsedSeconds: plannedDurationSeconds,
                committedETASeconds: flight.committedPilotETA(targetKey: NavigationTimingTargetKey(
                    legID: activeSourceLeg.id,
                    kind: .destination,
                    targetID: activeSourceLeg.arrival.id
                ))
            ),
            driftReferenceArms: AviationMapGeometry.driftReferenceArms(
                from: coordinate(activeSourceLeg.departure.position),
                to: coordinate(activeSourceLeg.arrival.position),
                angleDegrees: flightPlan.parameters.driftAngle.value
            )
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

enum AviationMapSymbology {
    static let minuteLabelCadence = 2

    static func minuteMarkers(
        from: AviationMapCoordinate,
        to: AviationMapCoordinate,
        plannedDurationSeconds: Int
    ) -> [AviationMapMinuteMarker] {
        guard plannedDurationSeconds >= 60 else { return [] }

        return (1...(plannedDurationSeconds / 60)).map { minute in
            let fraction = Double(minute * 60) / Double(plannedDurationSeconds)
            return AviationMapMinuteMarker(
                minute: minute,
                fraction: fraction,
                coordinate: AviationMapGeometry.interpolate(from: from, to: to, fraction: fraction),
                level: minute.isMultiple(of: minuteLabelCadence) ? .even : .odd
            )
        }
    }

    nonisolated static func formatDuration(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

enum AviationMapGeometry {
    static func driftReferenceArms(
        from: AviationMapCoordinate,
        to: AviationMapCoordinate,
        angleDegrees: Double
    ) -> [AviationMapDriftReferenceArm] {
        guard angleDegrees.isFinite, angleDegrees >= 0, angleDegrees < 90 else { return [] }

        let midpointLatitude = (from.latitude + to.latitude) / 2
        let longitudeScale = max(cos(midpointLatitude * .pi / 180), 0.2)
        let east = (to.longitude - from.longitude) * longitudeScale
        let north = to.latitude - from.latitude
        let length = hypot(east, north)
        guard length > .leastNonzeroMagnitude else { return [] }

        let rightEast = north / length
        let rightNorth = -east / length
        let lateralOffset = length * 0.5 * tan(angleDegrees * .pi / 180)
        let departureReferenceEnd = AviationMapCoordinate(
            latitude: midpointLatitude + rightNorth * lateralOffset,
            longitude: (from.longitude + to.longitude) / 2 + rightEast * lateralOffset / longitudeScale
        )
        let arrivalReferenceEnd = AviationMapCoordinate(
            latitude: midpointLatitude - rightNorth * lateralOffset,
            longitude: (from.longitude + to.longitude) / 2 - rightEast * lateralOffset / longitudeScale
        )
        return [
            AviationMapDriftReferenceArm(from: from, to: departureReferenceEnd),
            AviationMapDriftReferenceArm(from: to, to: arrivalReferenceEnd)
        ]
    }

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
