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

    struct DisplayFrequency: Identifiable, Equatable, Sendable {
        let id: String
        let phases: [FlightPhase]
        let service: String
        let serviceType: String
        let frequencyMHz: Double
        let source: ExecutionFrequencySource
    }

    struct RouteEvent: Identifiable, Equatable, Sendable {
        let id: UUID
        let entityIDs: [UUID]
        let kinds: [ExecutionAnnotationKind]
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
    let displayFrequencies: [DisplayFrequency]
    let routeEvents: [RouteEvent]
}

enum CockpitPresentationError: Error, Equatable, Sendable {
    case unavailableExecution
    case invalidLegIndex(Int)
    case unavailableWindMode
    case missingSourceLeg(UUID)
}

struct NextLegPreparation: Equatable, Sendable {
    enum Direction: Equatable, Sendable {
        case heading(Double)
        case course(Double)
    }

    struct FrequencyChange: Equatable, Sendable {
        let service: String
        let frequencyMHz: Double
    }

    let legIndex: Int
    let direction: Direction
    let initialAltitudeFeetMsl: Double
    let immediateAltitudeFeetMsl: Double?
    let immediateFrequencyChange: FrequencyChange?
}

struct PreviousLegSummary: Equatable, Sendable {
    struct VORDME: Equatable, Sendable {
        let station: String
        let magneticRadialFromDegrees: Double
        let slantRangeNauticalMiles: Double
    }

    let legIndex: Int
    let origin: String
    let destination: String
    let plannedDurationSeconds: Int
    let actualDurationSeconds: Int
    let deltaSeconds: Int
    let magneticHeadingDegrees: Double?
    let magneticCourseDegrees: Double
    let vorDme: VORDME?
}

struct LegStartChecklistTemplate: Equatable, Sendable {
    struct Section: Identifiable, Equatable, Sendable {
        let id: String
        let title: String?
        let items: [Item]
    }

    struct Item: Identifiable, Equatable, Sendable {
        enum Kind: String, Equatable, Sendable {
            case timer
            case direction
            case altitude
            case speedAndEngine
            case reporting
        }

        var id: String { kind.rawValue }
        let kind: Kind
        let title: String
        let instruction: String?
        let staticLines: [String]
    }

    let id: String
    let featureTitle: String
    let displayName: String
    let collapsedTitle: String
    let sections: [Section]

    static let tzeKivun = LegStartChecklistTemplate(
        id: "tze-kivun-gamad",
        featureTitle: "LEG START CHECKLIST",
        displayName: "צא כיוון",
        collapsedTitle: "צא כיוון · גמ״ד",
        sections: [
            Section(
                id: "leg-start",
                title: nil,
                items: [
                    Item(kind: .timer, title: "TIMER", instruction: nil, staticLines: []),
                    Item(
                        kind: .direction,
                        title: "HEADING",
                        instruction: "Check magnetic compass",
                        staticLines: []
                    )
                ]
            ),
            Section(
                id: "gamad",
                title: "גמ״ד",
                items: [
                    Item(kind: .altitude, title: "גובה", instruction: nil, staticLines: []),
                    Item(
                        kind: .speedAndEngine,
                        title: "מהירות ומנוע",
                        instruction: nil,
                        staticLines: [
                            "Oil pressure",
                            "Oil temperature",
                            "Amperage · Suction · Fuel"
                        ]
                    ),
                    Item(
                        kind: .reporting,
                        title: "דיווח",
                        instruction: "מה הדיווח הבא?",
                        staticLines: []
                    )
                ]
            )
        ]
    )

    func item(_ kind: Item.Kind) -> Item? {
        sections.lazy.flatMap(\.items).first { $0.kind == kind }
    }

    var gamadSection: Section? {
        sections.first { $0.id == "gamad" }
    }
}

struct LegStartChecklistPresentation: Equatable, Sendable {
    enum Direction: Equatable, Sendable {
        case heading(Double)
        case course(Double)
    }

    let legID: UUID
    let template: LegStartChecklistTemplate
    let direction: Direction
    let plannedAltitudeFeetMsl: Double
    /// The current v7 contract does not identify any saved value as planned IAS.
    let plannedIndicatedAirspeedKnots: Double?
}

struct CockpitPresentationAdapter: Sendable {
    func makeLegStartChecklist(
        flight: NavigationFlight,
        session: FlightSession
    ) throws -> LegStartChecklistPresentation? {
        guard session.legState == .active,
              flight.legs.indices.contains(session.activeLegIndex),
              case .eligible(let execution) = flight.execution,
              execution.legs.indices.contains(session.activeLegIndex) else { return nil }

        let resolvedLeg = execution.legs[session.activeLegIndex]
        let direction: LegStartChecklistPresentation.Direction
        switch session.executionMode {
        case .wind:
            guard let wind = resolvedLeg.withWind else {
                throw CockpitPresentationError.unavailableWindMode
            }
            direction = .heading(wind.magneticHeading.value)
        case .noWind:
            direction = .course(resolvedLeg.magneticCourse.value)
        }

        return LegStartChecklistPresentation(
            legID: flight.legs[session.activeLegIndex].id,
            template: .tzeKivun,
            direction: direction,
            plannedAltitudeFeetMsl: resolvedLeg.initialAltitudeMsl.value,
            plannedIndicatedAirspeedKnots: nil
        )
    }

    func makeNextLegPreparation(
        flight: NavigationFlight,
        session: FlightSession
    ) throws -> NextLegPreparation? {
        let nextIndex = session.activeLegIndex + 1
        guard flight.legs.indices.contains(nextIndex) else { return nil }
        guard case .eligible(let execution) = flight.execution,
              execution.legs.indices.contains(nextIndex) else {
            throw CockpitPresentationError.unavailableExecution
        }

        let sourceLeg = flight.legs[nextIndex]
        let resolvedLeg = execution.legs[nextIndex]
        let direction: NextLegPreparation.Direction
        switch session.executionMode {
        case .wind:
            guard let wind = resolvedLeg.withWind else {
                throw CockpitPresentationError.unavailableWindMode
            }
            direction = .heading(wind.magneticHeading.value)
        case .noWind:
            direction = .course(resolvedLeg.magneticCourse.value)
        }

        let immediateAltitude = flight.altitudeChanges.first { change in
            guard change.legID == sourceLeg.id else { return false }
            return switch change.anchor {
            case .waypoint(let waypointID): waypointID == sourceLeg.departure.id
            case .legProgress(let progress): progress.fraction == 0
            case .identificationPoint: false
            }
        }?.targetAltitude.value
        let immediateFrequency = flight.frequencyChanges.first {
            $0.legID == sourceLeg.id && $0.progress.fraction == 0
        }.map {
            NextLegPreparation.FrequencyChange(
                service: $0.service.name,
                frequencyMHz: $0.frequency.value
            )
        }

        return NextLegPreparation(
            legIndex: nextIndex,
            direction: direction,
            initialAltitudeFeetMsl: resolvedLeg.initialAltitudeMsl.value,
            immediateAltitudeFeetMsl: immediateAltitude,
            immediateFrequencyChange: immediateFrequency
        )
    }

    func makePreviousLegSummary(
        flight: NavigationFlight,
        session: FlightSession
    ) throws -> PreviousLegSummary? {
        guard let timing = session.legTimings.last(where: { $0.reachedAt != nil }),
              let reachedAt = timing.reachedAt,
              flight.legs.indices.contains(timing.legIndex),
              case .eligible(let execution) = flight.execution,
              execution.legs.indices.contains(timing.legIndex) else {
            return nil
        }
        let sourceLeg = flight.legs[timing.legIndex]
        let resolvedLeg = execution.legs[timing.legIndex]
        let plannedDuration: Int
        let heading: Double?
        switch session.executionMode {
        case .noWind:
            plannedDuration = resolvedLeg.noWind.durationSeconds
            heading = nil
        case .wind:
            guard let wind = resolvedLeg.withWind else {
                throw CockpitPresentationError.unavailableWindMode
            }
            plannedDuration = wind.timing.durationSeconds
            heading = wind.magneticHeading.value
        }
        let actualDuration = max(0, Int(reachedAt.timeIntervalSince(timing.startedAt).rounded()))

        let acceptedReferences = Dictionary(
            uniqueKeysWithValues: execution.vorDmeReferences.map { ($0.referenceID, $0) }
        )
        let sourceReference = flight.vorDmeReferences.first {
            $0.waypointID == sourceLeg.arrival.id && acceptedReferences[$0.id] != nil
        }
        let vorDme = sourceReference.flatMap { source -> PreviousLegSummary.VORDME? in
            guard let accepted = acceptedReferences[source.id] else { return nil }
            return PreviousLegSummary.VORDME(
                station: source.navigationAid.identifier,
                magneticRadialFromDegrees: accepted.magneticRadialFrom.value,
                slantRangeNauticalMiles: accepted.slantRange.value
            )
        }

        return PreviousLegSummary(
            legIndex: timing.legIndex,
            origin: sourceLeg.departure.name,
            destination: sourceLeg.arrival.name,
            plannedDurationSeconds: plannedDuration,
            actualDurationSeconds: actualDuration,
            deltaSeconds: actualDuration - plannedDuration,
            magneticHeadingDegrees: heading,
            magneticCourseDegrees: resolvedLeg.magneticCourse.value,
            vorDme: vorDme
        )
    }

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

        let displayFrequencies = makeDisplayFrequencies(from: frequencies)

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
        let individualEvents = try annotations.enumerated().map { index, annotation in
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
                entityIDs: [annotation.entityID],
                kinds: [annotation.kind],
                normalizedX: projected[index + 2].0,
                normalizedY: projected[index + 2].1,
                position: annotation.position,
                timeFromLegStartSeconds: time,
                title: label.0,
                detail: label.1
            )
        }
        let routeEvents = groupCoincidentEvents(individualEvents)

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
            displayFrequencies: displayFrequencies,
            routeEvents: routeEvents
        )
    }

    func makeDisplayFrequencies(
        from frequencies: [FlightPhase: [CockpitPresentationData.Frequency]]
    ) -> [CockpitPresentationData.DisplayFrequency] {
        FlightPhase.allCases
            .flatMap { frequencies[$0] ?? [] }
            .reduce(into: []) { groups, frequency in
                if let index = groups.firstIndex(where: {
                    $0.service == frequency.service &&
                    $0.serviceType == serviceTypeLabel(for: frequency) &&
                    $0.frequencyMHz == frequency.frequencyMHz &&
                    $0.source == frequency.source
                }) {
                    let existing = groups[index]
                    groups[index] = .init(
                        id: existing.id,
                        phases: existing.phases.contains(frequency.phase)
                            ? existing.phases
                            : existing.phases + [frequency.phase],
                        service: existing.service,
                        serviceType: existing.serviceType,
                        frequencyMHz: existing.frequencyMHz,
                        source: existing.source
                    )
                } else {
                    groups.append(.init(
                        id: frequency.id,
                        phases: [frequency.phase],
                        service: frequency.service,
                        serviceType: serviceTypeLabel(for: frequency),
                        frequencyMHz: frequency.frequencyMHz,
                        source: frequency.source
                    ))
                }
            }
    }

    private func serviceTypeLabel(for frequency: CockpitPresentationData.Frequency) -> String {
        if let role = frequency.role, !role.isEmpty {
            return role
        }
        return switch frequency.source {
        case .departure: "Departure"
        case .route: "Route"
        case .arrival: "Arrival"
        case .vorDme: "VOR/DME"
        case .user: "User"
        }
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
            let x = 0.18 + (($0.longitudeDegrees - minimumLongitude) / longitudeSpan) * 0.58
            let y = 0.78 - (($0.latitudeDegrees - minimumLatitude) / latitudeSpan) * 0.50
            return (x, y)
        }
    }

    private func groupCoincidentEvents(
        _ events: [CockpitPresentationData.RouteEvent]
    ) -> [CockpitPresentationData.RouteEvent] {
        events.reduce(into: []) { grouped, event in
            if let index = grouped.firstIndex(where: {
                $0.position == event.position && $0.timeFromLegStartSeconds == event.timeFromLegStartSeconds
            }) {
                let existing = grouped[index]
                grouped[index] = .init(
                    id: existing.id,
                    entityIDs: existing.entityIDs + event.entityIDs,
                    kinds: existing.kinds + event.kinds,
                    normalizedX: existing.normalizedX,
                    normalizedY: existing.normalizedY,
                    position: existing.position,
                    timeFromLegStartSeconds: existing.timeFromLegStartSeconds,
                    title: "Combined planned events",
                    detail: "\(existing.detail) · \(event.detail)"
                )
            } else {
                grouped.append(event)
            }
        }
    }

    private func formatFeet(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(0))) }
    private func formatFrequency(_ value: Double) -> String { value.formatted(.number.precision(.fractionLength(2...3))) }
}

enum CockpitPresentationFormatter {
    static func aviationDegrees(_ value: Double) -> String {
        let roundedDegrees = Int(value.rounded())
        let normalizedDegrees = ((roundedDegrees % 360) + 360) % 360
        return String(format: "%03d°", normalizedDegrees)
    }

    static func signedDuration(_ seconds: Int) -> String {
        let sign = seconds >= 0 ? "+" : "-"
        let absolute = abs(seconds)
        return String(format: "%@%02d:%02d", sign, absolute / 60, absolute % 60)
    }
}
