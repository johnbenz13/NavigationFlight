import Foundation

struct CockpitPresentationData: Equatable, Sendable {
    struct PlannedReference: Identifiable, Equatable, Sendable {
        let id: UUID
        let endpointName: String
        let station: String
        let frequencyMHz: Double
        let magneticRadialFromDegrees: Double
        let slantRangeNauticalMiles: Double
        let source: VORDMEExecutionSource
    }

    struct Frequency: Identifiable, Equatable, Sendable {
        let id: String
        let phase: FlightPhase
        let role: String?
        let service: String
        let frequencyMHz: Double
        let source: ExecutionFrequencySource
    }

    struct RouteEvent: Identifiable, Equatable, Sendable {
        let id: UUID
        let kind: ExecutionAnnotationKind
        let normalizedX: Double
        let normalizedY: Double
        let position: WGS84Coordinate
        let timeFromLegStartSeconds: Int
        let title: String
        let detail: String
    }

    let planTitle: String
    let legPosition: String
    let origin: String
    let destination: String
    let originNormalizedX: Double
    let originNormalizedY: Double
    let destinationNormalizedX: Double
    let destinationNormalizedY: Double
    let originCrossingAltitudeFeet: Double
    let destinationCrossingAltitudeFeet: Double
    let magneticCourseDegrees: Double
    let magneticHeadingDegrees: Double?
    let distanceNauticalMiles: Double
    let groundSpeedKnots: Double
    let legDurationSeconds: Int
    let cumulativeDurationSeconds: Int
    let initialAltitudeFeetMsl: Double
    let mode: NavigationMode
    let supportsWindMode: Bool
    let references: [PlannedReference]
    let frequencies: [FlightPhase: [Frequency]]
    let routeEvents: [RouteEvent]
}

enum CockpitPresentationError: Error, Equatable, Sendable {
    case unavailableExecution
    case invalidLegIndex(Int)
    case unavailableWindMode
    case missingSourceLeg(UUID)
}

struct CockpitPresentationAdapter: Sendable {
    func makePresentation(
        flight: NavigationFlight,
        legIndex: Int,
        mode: NavigationMode
    ) throws -> CockpitPresentationData {
        guard case .eligible(let execution) = flight.execution else {
            throw CockpitPresentationError.unavailableExecution
        }
        guard execution.legs.indices.contains(legIndex), flight.legs.indices.contains(legIndex) else {
            throw CockpitPresentationError.invalidLegIndex(legIndex)
        }

        let leg = execution.legs[legIndex]
        let sourceLeg = flight.legs[legIndex]
        let timing: PlannedTiming
        let heading: Double?
        switch mode {
        case .noWind:
            timing = leg.noWind
            heading = nil
        case .wind:
            guard let wind = leg.withWind else { throw CockpitPresentationError.unavailableWindMode }
            timing = wind.timing
            heading = wind.magneticHeading.value
        }

        let cumulative = try execution.legs.prefix(through: legIndex).reduce(0) { total, candidate in
            switch mode {
            case .noWind:
                return total + candidate.noWind.durationSeconds
            case .wind:
                guard let wind = candidate.withWind else { throw CockpitPresentationError.unavailableWindMode }
                return total + wind.timing.durationSeconds
            }
        }

        let sourceReferences = Dictionary(uniqueKeysWithValues: flight.vorDmeReferences.map { ($0.id, $0) })
        let endpointIDs = [sourceLeg.departure.id: sourceLeg.departure.name, sourceLeg.arrival.id: sourceLeg.arrival.name]
        let references = execution.vorDmeReferences.compactMap { resolved -> CockpitPresentationData.PlannedReference? in
            guard let source = sourceReferences[resolved.referenceID],
                  let endpointName = endpointIDs[source.waypointID] else { return nil }
            return CockpitPresentationData.PlannedReference(
                id: resolved.referenceID,
                endpointName: endpointName,
                station: source.navigationAid.identifier,
                frequencyMHz: resolved.frequency.value,
                magneticRadialFromDegrees: resolved.magneticRadialFrom.value,
                slantRangeNauticalMiles: resolved.slantRange.value,
                source: resolved.source
            )
        }

        let frequencies = Dictionary(uniqueKeysWithValues: FlightPhase.allCases.map { phase in
            (phase, (execution.frequenciesByPhase[phase] ?? []).map {
                CockpitPresentationData.Frequency(
                    id: $0.id,
                    phase: phase,
                    role: $0.role,
                    service: $0.name,
                    frequencyMHz: $0.frequency.value,
                    source: $0.source
                )
            })
        })

        let sourcePoints = Dictionary(uniqueKeysWithValues: flight.identificationPoints.map { ($0.id, $0) })
        let altitudeChanges = Dictionary(uniqueKeysWithValues: flight.altitudeChanges.map { ($0.id, $0) })
        let frequencyChanges = Dictionary(uniqueKeysWithValues: flight.frequencyChanges.map { ($0.id, $0) })
        let annotations = execution.annotations.filter { $0.legID == leg.legID }
        let positions = [sourceLeg.departure.position, sourceLeg.arrival.position] + annotations.map(\.position)
        let projected = project(
            positions: positions,
            origin: sourceLeg.departure.position,
            destination: sourceLeg.arrival.position
        )
        let routeEvents = try annotations.enumerated().map { index, annotation in
            let time: Int
            switch mode {
            case .noWind:
                time = annotation.noWindTimeFromLegStartSeconds
            case .wind:
                guard let windTime = annotation.withWindTimeFromLegStartSeconds else {
                    throw CockpitPresentationError.unavailableWindMode
                }
                time = windTime
            }
            let label: (String, String)
            switch annotation.kind {
            case .identificationPoint:
                guard sourcePoints[annotation.entityID] != nil else { throw CockpitPresentationError.missingSourceLeg(annotation.entityID) }
                label = ("Identification point", "Passive planned marker")
            case .altitudeChange:
                guard let change = altitudeChanges[annotation.entityID] else { throw CockpitPresentationError.missingSourceLeg(annotation.entityID) }
                label = ("Altitude change", "After passing anchor: \(formatFeet(change.targetAltitude.value)) MSL")
            case .radioFrequencyChange:
                guard let change = frequencyChanges[annotation.entityID] else { throw CockpitPresentationError.missingSourceLeg(annotation.entityID) }
                label = ("Frequency change", "\(change.service.name) · \(formatFrequency(change.frequency.value)) MHz")
            }
            return CockpitPresentationData.RouteEvent(
                id: annotation.entityID,
                kind: annotation.kind,
                normalizedX: projected[index + 2].0,
                normalizedY: projected[index + 2].1,
                position: annotation.position,
                timeFromLegStartSeconds: time,
                title: label.0,
                detail: label.1
            )
        }

        return .init(
            planTitle: flight.title,
            legPosition: "Leg \(legIndex + 1) of \(execution.legs.count)",
            origin: sourceLeg.departure.name,
            destination: sourceLeg.arrival.name,
            originNormalizedX: projected[0].0,
            originNormalizedY: projected[0].1,
            destinationNormalizedX: projected[1].0,
            destinationNormalizedY: projected[1].1,
            originCrossingAltitudeFeet: sourceLeg.departure.plannedAltitude.value,
            destinationCrossingAltitudeFeet: sourceLeg.arrival.plannedAltitude.value,
            magneticCourseDegrees: leg.magneticCourse.value,
            magneticHeadingDegrees: heading,
            distanceNauticalMiles: leg.groundDistance.value,
            groundSpeedKnots: timing.groundSpeed.value,
            legDurationSeconds: timing.durationSeconds,
            cumulativeDurationSeconds: cumulative,
            initialAltitudeFeetMsl: leg.initialAltitudeMsl.value,
            mode: mode,
            supportsWindMode: execution.legs.allSatisfy { $0.withWind != nil },
            references: references,
            frequencies: frequencies,
            routeEvents: routeEvents
        )
    }

    private func project(
        positions: [WGS84Coordinate],
        origin: WGS84Coordinate,
        destination: WGS84Coordinate
    ) -> [(Double, Double)] {
        let all = [origin, destination] + positions
        let latitudes = all.map(\.latitudeDegrees)
        let longitudes = all.map(\.longitudeDegrees)
        let latitudeSpan = max((latitudes.max() ?? 0) - (latitudes.min() ?? 0), 0.000_001)
        let longitudeSpan = max((longitudes.max() ?? 0) - (longitudes.min() ?? 0), 0.000_001)
        let minimumLatitude = latitudes.min() ?? 0
        let minimumLongitude = longitudes.min() ?? 0
        return positions.map {
            let x = 0.14 + (($0.longitudeDegrees - minimumLongitude) / longitudeSpan) * 0.72
            let y = 0.86 - (($0.latitudeDegrees - minimumLatitude) / latitudeSpan) * 0.72
            return (x, y)
        }
    }

    private func formatFeet(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private func formatFrequency(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2...3))) }
}
