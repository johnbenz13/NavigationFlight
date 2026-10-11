import Foundation

enum FPLNavMappingError: Error, Equatable, Sendable {
    case unexpectedFormat(String, version: Int)
    case duplicateWaypoint(UUID)
    case missingWaypointInOrder(UUID)
    case waypointNotInOrder(UUID)
    case duplicateLeg(UUID)
    case duplicateIdentificationPoint(UUID)
    case missingLegEndpoint(legID: UUID, waypointID: UUID)
    case legDoesNotConnectOrderedWaypoints(legID: UUID)
    case unknownLegReference(entity: String, entityID: UUID, legID: UUID)
    case invalidAltitudeAnchor(changeID: UUID)
    case unknownAltitudeChangeDirection(changeID: UUID, direction: String)
    case waypointAnchorIsNotLegEndpoint(changeID: UUID, waypointID: UUID)
    case unknownIdentificationPoint(changeID: UUID, identificationPointID: UUID)
    case identificationPointIsOnDifferentLeg(changeID: UUID, identificationPointID: UUID)
    case unknownFlightPhase(String)
    case unknownVORDMECalculation(referenceID: UUID)
    case unknownVORDMEWaypoint(referenceID: UUID, waypointID: UUID)
}

struct FPLNavV5Mapper {
    func map(_ source: FPLNavV5DTO) throws -> NavigationFlight {
        guard source.format == "fpl-navigation-project", source.formatVersion == 5 else {
            throw FPLNavMappingError.unexpectedFormat(source.format, version: source.formatVersion)
        }

        let waypointPairs = source.navigation.route.waypoints.map { ($0.id, mapWaypoint($0)) }
        var waypointsByID: [UUID: RouteWaypoint] = [:]
        for (id, waypoint) in waypointPairs {
            guard waypointsByID.updateValue(waypoint, forKey: id) == nil else {
                throw FPLNavMappingError.duplicateWaypoint(id)
            }
        }

        let orderedWaypoints = try source.navigation.route.waypointOrder.map { id in
            guard let waypoint = waypointsByID[id] else {
                throw FPLNavMappingError.missingWaypointInOrder(id)
            }
            return waypoint
        }
        let orderedIDs = Set(source.navigation.route.waypointOrder)
        if let unlistedID = waypointsByID.keys.first(where: { !orderedIDs.contains($0) }) {
            throw FPLNavMappingError.waypointNotInOrder(unlistedID)
        }

        let legs = try source.navigation.route.legs.enumerated().map { index, leg in
            guard let departure = waypointsByID[leg.departureWaypointId] else {
                throw FPLNavMappingError.missingLegEndpoint(legID: leg.id, waypointID: leg.departureWaypointId)
            }
            guard let arrival = waypointsByID[leg.arrivalWaypointId] else {
                throw FPLNavMappingError.missingLegEndpoint(legID: leg.id, waypointID: leg.arrivalWaypointId)
            }
            guard index + 1 < orderedWaypoints.count,
                  orderedWaypoints[index].id == departure.id,
                  orderedWaypoints[index + 1].id == arrival.id else {
                throw FPLNavMappingError.legDoesNotConnectOrderedWaypoints(legID: leg.id)
            }
            return NavigationLeg(
                id: leg.id,
                departure: departure,
                arrival: arrival,
                windOverride: leg.windOverride.map(mapWind),
                remark: leg.remark
            )
        }

        var legsByID: [UUID: NavigationLeg] = [:]
        for leg in legs {
            guard legsByID.updateValue(leg, forKey: leg.id) == nil else {
                throw FPLNavMappingError.duplicateLeg(leg.id)
            }
        }
        let identificationPoints = try source.navigation.identificationPoints.map { point in
            guard legsByID[point.legId] != nil else {
                throw FPLNavMappingError.unknownLegReference(entity: "identification point", entityID: point.id, legID: point.legId)
            }
            return IdentificationPoint(
                id: point.id,
                legID: point.legId,
                progress: LegProgress(fraction: point.legProgress),
                lateralOffset: Metres(value: point.lateralOffsetMetres),
                timeLabelArrangement: mapArrangement(point.timeLabelArrangement)
            )
        }
        var pointsByID: [UUID: IdentificationPoint] = [:]
        for point in identificationPoints {
            guard pointsByID.updateValue(point, forKey: point.id) == nil else {
                throw FPLNavMappingError.duplicateIdentificationPoint(point.id)
            }
        }

        let altitudeChanges = try source.navigation.altitudeChanges.map { change in
            guard let leg = legsByID[change.legId] else {
                throw FPLNavMappingError.unknownLegReference(entity: "altitude change", entityID: change.id, legID: change.legId)
            }
            let anchor: AltitudeChangeAnchor
            switch change.anchor.kind {
            case "leg-progress":
                guard let progress = change.anchor.legProgress else {
                    throw FPLNavMappingError.invalidAltitudeAnchor(changeID: change.id)
                }
                anchor = .legProgress(LegProgress(fraction: progress))
            case "waypoint":
                guard let waypointID = change.anchor.waypointId else {
                    throw FPLNavMappingError.invalidAltitudeAnchor(changeID: change.id)
                }
                guard waypointID == leg.departure.id || waypointID == leg.arrival.id else {
                    throw FPLNavMappingError.waypointAnchorIsNotLegEndpoint(changeID: change.id, waypointID: waypointID)
                }
                anchor = .waypoint(waypointID)
            case "identification-point":
                guard let pointID = change.anchor.identificationPointId else {
                    throw FPLNavMappingError.invalidAltitudeAnchor(changeID: change.id)
                }
                guard let point = pointsByID[pointID] else {
                    throw FPLNavMappingError.unknownIdentificationPoint(changeID: change.id, identificationPointID: pointID)
                }
                guard point.legID == change.legId else {
                    throw FPLNavMappingError.identificationPointIsOnDifferentLeg(changeID: change.id, identificationPointID: pointID)
                }
                anchor = .identificationPoint(pointID)
            default:
                throw FPLNavMappingError.invalidAltitudeAnchor(changeID: change.id)
            }

            guard let direction = AltitudeChangeDirection(rawValue: change.symbolDirection) else {
                throw FPLNavMappingError.unknownAltitudeChangeDirection(
                    changeID: change.id,
                    direction: change.symbolDirection
                )
            }
            return AltitudeChange(
                id: change.id,
                legID: change.legId,
                anchor: anchor,
                targetAltitude: AltitudeFeet(value: change.targetAltitudeFeet),
                symbolDirection: direction,
                showsAnchorMark: change.showAnchorMark,
                arrangement: mapArrangement(change.arrangement)
            )
        }

        let frequencyChanges = try source.navigation.radioFrequencyChanges.map { change in
            guard legsByID[change.legId] != nil else {
                throw FPLNavMappingError.unknownLegReference(entity: "frequency change", entityID: change.id, legID: change.legId)
            }
            return FrequencyChange(
                id: change.id,
                legID: change.legId,
                progress: LegProgress(fraction: change.legProgress),
                service: RadioService(catalogID: change.service.catalogId, name: change.service.name),
                frequency: FrequencyMHz(value: change.frequencyMhz),
                isFlippedHorizontally: change.flippedHorizontally,
                arrangement: mapArrangement(change.arrangement)
            )
        }

        let vorDmeReferences = try source.navigation.vorDmeReferences.map { reference in
            guard waypointsByID[reference.waypointId] != nil else {
                throw FPLNavMappingError.unknownVORDMEWaypoint(referenceID: reference.id, waypointID: reference.waypointId)
            }
            let calculation: VORDMECalculation
            switch reference.calculation.mode {
            case "automatic":
                calculation = .automatic
            case "manual":
                guard let radial = reference.calculation.radialDegrees,
                      let distance = reference.calculation.distanceNm else {
                    throw FPLNavMappingError.unknownVORDMECalculation(referenceID: reference.id)
                }
                calculation = .manual(radial: Degrees(value: radial), distance: NauticalMiles(value: distance))
            default:
                throw FPLNavMappingError.unknownVORDMECalculation(referenceID: reference.id)
            }
            return VORDMEReference(
                id: reference.id,
                waypointID: reference.waypointId,
                calculation: calculation,
                navigationAid: NavigationAidReference(
                    catalogID: reference.navigationAid.catalogId,
                    identifier: reference.navigationAid.snapshot.identifier,
                    name: reference.navigationAid.snapshot.name,
                    position: mapCoordinate(reference.navigationAid.snapshot.position)
                )
            )
        }

        return NavigationFlight(
            id: source.project.id,
            title: source.project.title,
            createdAt: source.project.createdAt,
            modifiedAt: source.project.modifiedAt,
            parameters: NavigationParameters(
                magneticVariationEast: Degrees(value: source.navigation.parameters.magneticVariationEastDegrees),
                defaultAltitude: AltitudeFeet(value: source.navigation.parameters.defaultAltitudeFeet),
                driftAngle: Degrees(value: source.navigation.parameters.driftAngleDegrees),
                planningAirspeed: Knots(value: source.navigation.parameters.planningAirspeedKnots)
            ),
            waypoints: orderedWaypoints,
            legs: legs,
            identificationPoints: identificationPoints,
            altitudeChanges: altitudeChanges,
            frequencyChanges: frequencyChanges,
            vorDmeReferences: vorDmeReferences,
            operationalContext: try mapOperationalContext(source.navigation.operationalContext),
            execution: .unavailableLegacyFormat(version: 5)
        )
    }

    private func mapWaypoint(_ source: FPLNavV5DTO.Waypoint) -> RouteWaypoint {
        RouteWaypoint(
            id: source.id,
            name: source.name,
            position: mapCoordinate(source.position),
            plannedAltitude: AltitudeFeet(value: source.altitudeFeet),
            generatedNumber: source.generatedNumber,
            reportingPointReference: source.reportingPointReference.map {
                ReportingPointReference(
                    catalogID: $0.catalogId,
                    name: $0.snapshot.name,
                    position: mapCoordinate($0.snapshot.position)
                )
            }
        )
    }

    private func mapOperationalContext(_ source: FPLNavV5DTO.OperationalContext) throws -> OperationalContext {
        let entries = try source.frequencyEntries.map { entry in
            guard let phase = FlightPhase(rawValue: entry.phase) else {
                throw FPLNavMappingError.unknownFlightPhase(entry.phase)
            }
            return FrequencyEntry(
                id: entry.id,
                phase: phase,
                name: entry.name,
                frequency: FrequencyMHz(value: entry.frequencyMhz),
                replaces: entry.replaces.map {
                    ReplacedFrequency(name: $0.name, role: $0.role, frequency: FrequencyMHz(value: $0.frequencyMhz))
                }
            )
        }
        return OperationalContext(
            defaultWind: source.defaultWind.map(mapWind),
            departureAerodrome: source.departureAerodromeReference.map(mapAerodrome),
            arrivalAerodrome: source.arrivalAerodromeReference.map(mapAerodrome),
            frequencyEntries: entries,
            frequencyOrderByPhase: [
                .departure: source.frequencyOrderByPhase.departure,
                .enRoute: source.frequencyOrderByPhase.enRoute,
                .arrival: source.frequencyOrderByPhase.arrival
            ]
        )
    }

    private func mapCoordinate(_ source: FPLNavV5DTO.Coordinate) -> WGS84Coordinate {
        WGS84Coordinate(latitudeDegrees: source.latitude, longitudeDegrees: source.longitude)
    }

    private func mapWind(_ source: FPLNavV5DTO.Wind) -> Wind {
        Wind(directionFromTrue: Degrees(value: source.directionFromTrueDegrees), speed: Knots(value: source.speedKnots))
    }

    private func mapArrangement(_ source: FPLNavV5DTO.Arrangement) -> AnnotationArrangement {
        AnnotationArrangement(
            longitudinalOffset: Metres(value: source.longitudinalMetres),
            lateralOffset: Metres(value: source.lateralMetres),
            rotation: Degrees(value: source.rotationDegrees)
        )
    }

    private func mapAerodrome(_ source: FPLNavV5DTO.AerodromeReference) -> AerodromeReference {
        AerodromeReference(
            catalogID: source.catalogId,
            name: source.snapshot.name,
            position: mapCoordinate(source.snapshot.position),
            icao: source.snapshot.icao,
            localCode: source.snapshot.localCode
        )
    }
}
