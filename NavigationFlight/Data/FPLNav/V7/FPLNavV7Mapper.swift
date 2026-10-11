import Foundation

struct FPLNavV7ValidationError: Error, Equatable, Sendable {
    let path: String
    let reason: String
}

struct FPLNavV7Mapper {
    func map(_ source: FPLNavV7DTO) throws -> NavigationFlight {
        guard source.format == "fpl-navigation-project", source.formatVersion == 7 else {
            throw FPLNavMappingError.unexpectedFormat(source.format, version: source.formatVersion)
        }

        let legacy = FPLNavV5DTO(
            format: source.format,
            formatVersion: 5,
            project: source.project,
            navigation: .init(
                parameters: source.navigation.parameters,
                route: source.navigation.route,
                identificationPoints: source.navigation.identificationPoints,
                altitudeChanges: source.navigation.altitudeChanges,
                radioFrequencyChanges: source.navigation.radioFrequencyChanges,
                operationalContext: source.navigation.operationalContext,
                vorDmeReferences: source.navigation.vorDmeReferences
            )
        )
        let base = try FPLNavV5Mapper().map(legacy)
        let execution = try mapExecution(source, base: base)
        return NavigationFlight(
            id: base.id,
            title: base.title,
            createdAt: base.createdAt,
            modifiedAt: base.modifiedAt,
            parameters: base.parameters,
            waypoints: base.waypoints,
            legs: base.legs,
            identificationPoints: base.identificationPoints,
            altitudeChanges: base.altitudeChanges,
            frequencyChanges: base.frequencyChanges,
            vorDmeReferences: base.vorDmeReferences,
            operationalContext: base.operationalContext,
            execution: execution.legs.isEmpty ? .emptyPlan(execution) : .eligible(execution)
        )
    }

    private func mapExecution(_ source: FPLNavV7DTO, base: NavigationFlight) throws -> NavigationExecution {
        try validateConsumedSource(source)
        let execution = source.execution
        try require(!execution.calculationVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    "execution.calculationVersion", "must be nonempty")
        try require(execution.altitudeReference == "MSL", "execution.altitudeReference", "must be MSL")
        try require(execution.legs.count == source.navigation.route.legs.count,
                    "execution.legs", "must contain every source leg exactly once")

        var legIDs = Set<UUID>()
        var mappedLegs: [LegExecution] = []
        for (index, leg) in execution.legs.enumerated() {
            let path = "execution.legs[\(index)]"
            try require(legIDs.insert(leg.legId).inserted, path + ".legId", "is duplicated")
            try require(source.navigation.route.legs[index].id == leg.legId, path + ".legId", "must match source route order")
            try degrees(leg.trueCourseDegrees, path + ".trueCourseDegrees")
            try degrees(leg.magneticCourseDegrees, path + ".magneticCourseDegrees")
            try positive(leg.distanceNauticalMiles, path + ".distanceNauticalMiles")
            try nonnegative(leg.initialAltitudeFeetMsl, path + ".initialAltitudeFeetMsl")
            try timing(leg.noWind, path + ".noWind")
            try require(leg.noWind.plannedGroundSpeedKnots == source.navigation.parameters.planningAirspeedKnots,
                        path + ".noWind.plannedGroundSpeedKnots", "must equal planning airspeed")
            let windEnabled = source.navigation.presentation.navigationLog.windEnabled
            try require(windEnabled == (leg.withWind != nil), path + ".withWind",
                        "must be present exactly when wind planning is enabled")
            let mappedWind: WindExecution?
            if let wind = leg.withWind {
                try timing(.init(plannedDurationSeconds: wind.plannedDurationSeconds,
                                 plannedGroundSpeedKnots: wind.plannedGroundSpeedKnots), path + ".withWind")
                try windValue(wind.effectiveWind, path + ".withWind.effectiveWind")
                try degrees(wind.trueHeadingDegrees, path + ".withWind.trueHeadingDegrees")
                try degrees(wind.magneticHeadingDegrees, path + ".withWind.magneticHeadingDegrees")
                try finiteRange(wind.windCorrectionDegrees, -180...180, path + ".withWind.windCorrectionDegrees")
                let sourceLeg = source.navigation.route.legs[index]
                guard let expected = sourceLeg.windOverride ?? source.navigation.operationalContext.defaultWind else {
                    throw error(path + ".withWind", "wind-enabled leg requires explicit override or project wind")
                }
                try require(expected.directionFromTrueDegrees == wind.effectiveWind.directionFromTrueDegrees &&
                            expected.speedKnots == wind.effectiveWind.speedKnots,
                            path + ".withWind.effectiveWind", "must match leg override or project default")
                mappedWind = WindExecution(
                    timing: .init(durationSeconds: wind.plannedDurationSeconds,
                                  groundSpeed: .init(value: wind.plannedGroundSpeedKnots)),
                    effectiveWind: mapWind(wind.effectiveWind),
                    trueHeading: .init(value: wind.trueHeadingDegrees),
                    magneticHeading: .init(value: wind.magneticHeadingDegrees),
                    windCorrection: .init(value: wind.windCorrectionDegrees)
                )
            } else {
                mappedWind = nil
            }
            mappedLegs.append(.init(
                legID: leg.legId,
                trueCourse: .init(value: leg.trueCourseDegrees),
                magneticCourse: .init(value: leg.magneticCourseDegrees),
                groundDistance: .init(value: leg.distanceNauticalMiles),
                initialAltitudeMsl: .init(value: leg.initialAltitudeFeetMsl),
                noWind: .init(durationSeconds: leg.noWind.plannedDurationSeconds,
                              groundSpeed: .init(value: leg.noWind.plannedGroundSpeedKnots)),
                withWind: mappedWind
            ))
        }

        var sourceAnnotations: [UUID: (ExecutionAnnotationKind, UUID)] = [:]
        for item in source.navigation.identificationPoints.map({ ($0.id, ExecutionAnnotationKind.identificationPoint, $0.legId) }) +
            source.navigation.altitudeChanges.map({ ($0.id, ExecutionAnnotationKind.altitudeChange, $0.legId) }) +
            source.navigation.radioFrequencyChanges.map({ ($0.id, ExecutionAnnotationKind.radioFrequencyChange, $0.legId) }) {
            try require(sourceAnnotations.updateValue((item.1, item.2), forKey: item.0) == nil,
                        "navigation annotations", "source entity IDs must be unique across annotation kinds")
        }
        try require(execution.annotations.count == sourceAnnotations.count,
                    "execution.annotations", "must contain every source annotation exactly once")
        var annotationIDs = Set<UUID>()
        let legsByID = Dictionary(uniqueKeysWithValues: mappedLegs.map { ($0.legID, $0) })
        let annotations = try execution.annotations.enumerated().map { index, annotation in
            let path = "execution.annotations[\(index)]"
            try require(annotationIDs.insert(annotation.entityId).inserted, path + ".entityId", "is duplicated")
            guard let kind = ExecutionAnnotationKind(rawValue: annotation.kind),
                  let expected = sourceAnnotations[annotation.entityId],
                  expected.0 == kind, expected.1 == annotation.legId else {
                throw error(path + ".entityId", "must match a source entity, kind, and leg")
            }
            guard let leg = legsByID[annotation.legId] else { throw error(path + ".legId", "references an unknown execution leg") }
            try coordinate(annotation.position, path + ".position")
            try boundedTime(annotation.noWindTimeFromLegStartSeconds, maximum: leg.noWind.durationSeconds,
                            path: path + ".noWindTimeFromLegStartSeconds")
            try require(source.navigation.presentation.navigationLog.windEnabled == (annotation.withWindTimeFromLegStartSeconds != nil),
                        path + ".withWindTimeFromLegStartSeconds", "must be present exactly when wind planning is enabled")
            if let time = annotation.withWindTimeFromLegStartSeconds, let wind = leg.withWind {
                try boundedTime(time, maximum: wind.timing.durationSeconds, path: path + ".withWindTimeFromLegStartSeconds")
            }
            return AnnotationExecution(entityID: annotation.entityId, kind: kind, legID: annotation.legId,
                                       position: mapCoordinate(annotation.position),
                                       noWindTimeFromLegStartSeconds: annotation.noWindTimeFromLegStartSeconds,
                                       withWindTimeFromLegStartSeconds: annotation.withWindTimeFromLegStartSeconds)
        }

        let sourceReferences = Dictionary(uniqueKeysWithValues: source.navigation.vorDmeReferences.map { ($0.id, $0) })
        try require(execution.vorDmeReferences.count == sourceReferences.count,
                    "execution.vorDmeReferences", "must contain every accepted source reference exactly once")
        var referenceIDs = Set<UUID>()
        let references = try execution.vorDmeReferences.enumerated().map { index, reference in
            let path = "execution.vorDmeReferences[\(index)]"
            try require(referenceIDs.insert(reference.referenceId).inserted, path + ".referenceId", "is duplicated")
            guard let sourceReference = sourceReferences[reference.referenceId],
                  let mode = VORDMEExecutionSource(rawValue: reference.source),
                  sourceReference.calculation.mode == reference.source else {
                throw error(path + ".referenceId", "must match an accepted reference and calculation mode")
            }
            try positiveMaximum(reference.frequencyMhz, maximum: 999.999, path + ".frequencyMhz")
            try degrees(reference.magneticRadialFromDegrees, path + ".magneticRadialFromDegrees")
            try nonnegative(reference.slantRangeNauticalMiles, path + ".slantRangeNauticalMiles")
            if let elevation = reference.stationElevationFeetMsl { try finite(elevation, path + ".stationElevationFeetMsl") }
            if mode == .automatic {
                try require(reference.stationElevationFeetMsl != nil, path + ".stationElevationFeetMsl", "is required for automatic references")
            } else {
                try require(sourceReference.calculation.radialDegrees == reference.magneticRadialFromDegrees &&
                            sourceReference.calculation.distanceNm == reference.slantRangeNauticalMiles,
                            path, "manual radial and pilot-provided slant range must remain unchanged")
            }
            return VORDMEExecution(referenceID: reference.referenceId,
                                   frequency: .init(value: reference.frequencyMhz),
                                   stationElevationMsl: reference.stationElevationFeetMsl.map(AltitudeFeet.init),
                                   magneticRadialFrom: .init(value: reference.magneticRadialFromDegrees),
                                   slantRange: .init(value: reference.slantRangeNauticalMiles), source: mode)
        }

        let phaseSources: [(FlightPhase, [FPLNavV7DTO.Frequency])] = [
            (.departure, execution.frequenciesByPhase.departure),
            (.enRoute, execution.frequenciesByPhase.enRoute),
            (.arrival, execution.frequenciesByPhase.arrival)
        ]
        let frequencies: [FlightPhase: [ExecutionFrequency]] = try phaseSources.reduce(into: [:]) { result, pair in
            var ids = Set<String>()
            result[pair.0] = try pair.1.enumerated().map { index, frequency in
                let path = "execution.frequenciesByPhase.\(pair.0.rawValue)[\(index)]"
                try require(!frequency.id.isEmpty && ids.insert(frequency.id).inserted, path + ".id", "must be nonempty and unique in its phase")
                try require(!frequency.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && frequency.name.count <= 100,
                            path + ".name", "must contain 1...100 non-whitespace characters")
                if let role = frequency.role { try require(!role.isEmpty, path + ".role", "must be nonempty") }
                try positiveMaximum(frequency.frequencyMhz, maximum: 999.999, path + ".frequencyMhz")
                guard let source = ExecutionFrequencySource(rawValue: frequency.source) else { throw error(path + ".source", "is unsupported") }
                return .init(id: frequency.id, name: frequency.name, role: frequency.role,
                             frequency: .init(value: frequency.frequencyMhz), source: source)
            }
        }
        try validateRequiredFrequencies(source, frequencies: frequencies)

        return NavigationExecution(calculationVersion: execution.calculationVersion, altitudeReference: .msl,
                                   legs: mappedLegs, annotations: annotations, vorDmeReferences: references,
                                   frequenciesByPhase: frequencies,
                                   defaultMode: source.navigation.presentation.navigationLog.windEnabled ? .wind : .noWind)
    }

    private func validateRequiredFrequencies(_ source: FPLNavV7DTO, frequencies: [FlightPhase: [ExecutionFrequency]]) throws {
        let enRoute = frequencies[.enRoute] ?? []
        for change in source.navigation.radioFrequencyChanges {
            try require(enRoute.contains { $0.id == "route:\(change.id.uuidString.lowercased())" && $0.source == .route &&
                $0.name == change.service.name && $0.frequency.value == change.frequencyMhz },
                "execution.frequenciesByPhase.en-route", "must include route frequency \(change.id)")
        }
        for entry in source.navigation.operationalContext.frequencyEntries {
            guard let phase = FlightPhase(rawValue: entry.phase) else { throw error("navigation.operationalContext.frequencyEntries", "contains unsupported phase") }
            try require((frequencies[phase] ?? []).contains { $0.id == "user:\(entry.id)" && $0.source == .user &&
                $0.name == entry.name && $0.frequency.value == entry.frequencyMhz },
                "execution.frequenciesByPhase.\(phase.rawValue)", "must include user frequency \(entry.id)")
        }
    }

    private func validateConsumedSource(_ source: FPLNavV7DTO) throws {
        let parameters = source.navigation.parameters
        try finiteRange(parameters.magneticVariationEastDegrees, -180...180, "navigation.parameters.magneticVariationEastDegrees")
        try nonnegative(parameters.defaultAltitudeFeet, "navigation.parameters.defaultAltitudeFeet")
        try require(parameters.driftAngleDegrees.isFinite && parameters.driftAngleDegrees >= 0 && parameters.driftAngleDegrees < 90,
                    "navigation.parameters.driftAngleDegrees", "must be finite in [0, 90)")
        try positive(parameters.planningAirspeedKnots, "navigation.parameters.planningAirspeedKnots")
        let waypoints = Dictionary(uniqueKeysWithValues: source.navigation.route.waypoints.map { ($0.id, $0) })
        for (index, waypoint) in source.navigation.route.waypoints.enumerated() {
            try coordinate(waypoint.position, "navigation.route.waypoints[\(index)].position")
            try nonnegative(waypoint.altitudeFeet, "navigation.route.waypoints[\(index)].altitudeFeet")
        }
        for (index, leg) in source.navigation.route.legs.enumerated() {
            if let wind = leg.windOverride { try windValue(wind, "navigation.route.legs[\(index)].windOverride") }
            if let departure = waypoints[leg.departureWaypointId], let arrival = waypoints[leg.arrivalWaypointId] {
                try require(departure.position.latitude != arrival.position.latitude || departure.position.longitude != arrival.position.longitude,
                            "navigation.route.legs[\(index)]", "cannot have identical endpoint positions")
            }
        }
        for (index, point) in source.navigation.identificationPoints.enumerated() {
            try finiteRange(point.legProgress, 0...1, "navigation.identificationPoints[\(index)].legProgress")
            try finite(point.lateralOffsetMetres, "navigation.identificationPoints[\(index)].lateralOffsetMetres")
        }
        for (index, change) in source.navigation.altitudeChanges.enumerated() {
            try nonnegative(change.targetAltitudeFeet, "navigation.altitudeChanges[\(index)].targetAltitudeFeet")
            if let progress = change.anchor.legProgress { try finiteRange(progress, 0...1, "navigation.altitudeChanges[\(index)].anchor.legProgress") }
        }
        for (index, change) in source.navigation.radioFrequencyChanges.enumerated() {
            try finiteRange(change.legProgress, 0...1, "navigation.radioFrequencyChanges[\(index)].legProgress")
            try positiveMaximum(change.frequencyMhz, maximum: 999.999, "navigation.radioFrequencyChanges[\(index)].frequencyMhz")
        }
        if let wind = source.navigation.operationalContext.defaultWind { try windValue(wind, "navigation.operationalContext.defaultWind") }
        for (index, entry) in source.navigation.operationalContext.frequencyEntries.enumerated() {
            try positiveMaximum(entry.frequencyMhz, maximum: 999.999, "navigation.operationalContext.frequencyEntries[\(index)].frequencyMhz")
        }
        for (index, reference) in source.navigation.vorDmeReferences.enumerated() where reference.calculation.mode == "manual" {
            guard let radial = reference.calculation.radialDegrees, let distance = reference.calculation.distanceNm else {
                throw error("navigation.vorDmeReferences[\(index)].calculation", "manual calculation requires radial and distance")
            }
            try degrees(radial, "navigation.vorDmeReferences[\(index)].calculation.radialDegrees")
            try nonnegative(distance, "navigation.vorDmeReferences[\(index)].calculation.distanceNm")
        }
    }

    private func timing(_ value: FPLNavV7DTO.Timing, _ path: String) throws {
        try require(value.plannedDurationSeconds > 0, path + ".plannedDurationSeconds", "must be a positive integer")
        try positive(value.plannedGroundSpeedKnots, path + ".plannedGroundSpeedKnots")
    }
    private func windValue(_ value: FPLNavV5DTO.Wind, _ path: String) throws {
        try degrees(value.directionFromTrueDegrees, path + ".directionFromTrueDegrees")
        try nonnegative(value.speedKnots, path + ".speedKnots")
    }
    private func coordinate(_ value: FPLNavV5DTO.Coordinate, _ path: String) throws {
        try finiteRange(value.latitude, -90...90, path + ".latitude")
        try finiteRange(value.longitude, -180...180, path + ".longitude")
    }
    private func degrees(_ value: Double, _ path: String) throws { try require(value.isFinite && value >= 0 && value < 360, path, "must be finite in [0, 360)") }
    private func finite(_ value: Double, _ path: String) throws { try require(value.isFinite, path, "must be finite") }
    private func positive(_ value: Double, _ path: String) throws { try require(value.isFinite && value > 0, path, "must be finite and positive") }
    private func nonnegative(_ value: Double, _ path: String) throws { try require(value.isFinite && value >= 0, path, "must be finite and nonnegative") }
    private func positiveMaximum(_ value: Double, maximum: Double, _ path: String) throws { try require(value.isFinite && value > 0 && value <= maximum, path, "must be in (0, \(maximum)]") }
    private func finiteRange(_ value: Double, _ range: ClosedRange<Double>, _ path: String) throws { try require(value.isFinite && range.contains(value), path, "must be finite in \(range)") }
    private func boundedTime(_ value: Int, maximum: Int, path: String) throws { try require(value >= 0 && value <= maximum, path, "must be an integer from zero through leg duration") }
    private func require(_ condition: @autoclosure () -> Bool, _ path: String, _ reason: String) throws { if !condition() { throw error(path, reason) } }
    private func error(_ path: String, _ reason: String) -> FPLNavV7ValidationError { .init(path: path, reason: reason) }
    private func mapCoordinate(_ value: FPLNavV5DTO.Coordinate) -> WGS84Coordinate { .init(latitudeDegrees: value.latitude, longitudeDegrees: value.longitude) }
    private func mapWind(_ value: FPLNavV5DTO.Wind) -> Wind { .init(directionFromTrue: .init(value: value.directionFromTrueDegrees), speed: .init(value: value.speedKnots)) }
}
