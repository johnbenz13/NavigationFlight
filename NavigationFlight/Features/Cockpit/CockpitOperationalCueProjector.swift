import Foundation

struct CockpitOperationalCueState: Equatable, Sendable {
    struct NavigationAidPlan: Equatable, Sendable {
        struct Station: Identifiable, Equatable, Sendable {
            let id: UUID
            let identifier: String
            let frequencyMHz: Double
            let associations: [Association]
        }

        struct Association: Identifiable, Equatable, Sendable {
            enum State: Equatable, Sendable {
                case firstFlownLeg
                case upcomingLeg
                case current
                case later
                case history
            }

            let id: UUID
            let state: State
            let arrivalWaypoint: String
            let routeIndex: Int
        }

        let stations: [Station]
    }

    struct CommunicationPlan: Equatable, Sendable {
        struct Entry: Identifiable, Equatable, Sendable {
            enum State: Equatable, Sendable {
                case departurePlan
                case atStart
                case current
                case next
                case later
                case past
                case arrival
            }

            let id: String
            let phase: FlightPhase
            let role: String?
            let service: String
            let frequencyMHz: Double
            let state: State
            let dueContext: String
        }

        let entries: [Entry]
        let compactEntries: [Entry]
    }

    struct FrequencyCue: Identifiable, Equatable, Sendable {
        enum Status: Equatable, Sendable {
            case current
            case next
            case other
        }

        var id: String { frequency.id }
        let frequency: CockpitPresentationData.DisplayFrequency
        let status: Status
    }

    struct AltitudeCue: Equatable, Sendable {
        let target: AltitudeFeet
        let direction: AltitudeChangeDirection
    }

    enum DueEvent: Hashable, Sendable {
        case frequency(UUID)
        case altitude(UUID)
    }

    let frequencies: [FrequencyCue]
    let communicationPlan: CommunicationPlan
    let navigationAidPlan: NavigationAidPlan
    let currentAltitude: AltitudeFeet
    let nextAltitude: AltitudeCue?
    let dueAltitude: AltitudeCue?
    let dueEvents: Set<DueEvent>

    init(
        frequencies: [FrequencyCue],
        communicationPlan: CommunicationPlan = .init(entries: [], compactEntries: []),
        navigationAidPlan: NavigationAidPlan = .init(stations: []),
        currentAltitude: AltitudeFeet,
        nextAltitude: AltitudeCue?,
        dueAltitude: AltitudeCue?,
        dueEvents: Set<DueEvent>
    ) {
        self.frequencies = frequencies
        self.communicationPlan = communicationPlan
        self.navigationAidPlan = navigationAidPlan
        self.currentAltitude = currentAltitude
        self.nextAltitude = nextAltitude
        self.dueAltitude = dueAltitude
        self.dueEvents = dueEvents
    }
}

struct CockpitConsoleCuePresentation: Equatable, Sendable {
    let immediateFrequencyCues: [CockpitOperationalCueState.FrequencyCue]
    let isAltitudeEmphasized: Bool

    init(
        cues: CockpitOperationalCueState,
        emphasizedEvents: Set<CockpitOperationalCueState.DueEvent>
    ) {
        if cues.communicationPlan.compactEntries.isEmpty {
            immediateFrequencyCues = [
                cues.frequencies.first(where: { $0.status == .current }),
                cues.frequencies.first(where: { $0.status == .next })
            ].compactMap { $0 }
        } else {
            immediateFrequencyCues = cues.communicationPlan.compactEntries.prefix(2).map { entry in
                let status: CockpitOperationalCueState.FrequencyCue.Status = switch entry.state {
                case .current, .departurePlan: .current
                case .next: .next
                case .atStart, .later, .past, .arrival: .other
                }
                return CockpitOperationalCueState.FrequencyCue(
                    frequency: .init(
                        id: entry.id,
                        phases: [entry.phase],
                        service: entry.service,
                        serviceType: entry.role ?? entry.phase.rawValue,
                        frequencyMHz: entry.frequencyMHz,
                        source: .route
                    ),
                    status: status
                )
            }
        }
        isAltitudeEmphasized = emphasizedEvents.contains { event in
            if case .altitude = event { true } else { false }
        }
    }
}

extension CockpitOperationalCueState.FrequencyCue {
    var statusLabel: String? {
        switch status {
        case .current: "PLANNED NOW"
        case .next: "PLANNED NEXT"
        case .other: nil
        }
    }

    var accessibilityDescription: String {
        let frequencyValue = frequency.frequencyMHz.formatted(.number.precision(.fractionLength(2...3)))
        let stateDescription = statusLabel.map { ", \($0.lowercased())" } ?? ""
        return "\(frequency.service), \(frequencyValue) megahertz\(stateDescription)"
    }
}

extension CockpitOperationalCueState {
    var altitudeAccessibilityDescription: String {
        let current = currentAltitude.value.formatted(.number.precision(.fractionLength(0)))
        guard let nextAltitude else {
            return "Target altitude \(current) feet MSL"
        }
        let next = nextAltitude.target.value.formatted(.number.precision(.fractionLength(0)))
        let direction = nextAltitude.direction == .up ? "climb" : "descent"
        return "Target altitude \(current) feet MSL, next target \(next) feet, \(direction)"
    }
}

struct CockpitDueEmphasis: Equatable, Sendable {
    private var observedEvents: Set<CockpitOperationalCueState.DueEvent>?
    private var contextID: String?
    private var wasVisible = false
    private var deadlines: [CockpitOperationalCueState.DueEvent: Date] = [:]

    mutating func observe(
        _ events: Set<CockpitOperationalCueState.DueEvent>,
        contextID: String,
        isVisible: Bool,
        at timestamp: Date
    ) {
        deadlines = deadlines.filter { $0.value > timestamp }

        guard isVisible else {
            observedEvents = events
            self.contextID = contextID
            wasVisible = false
            deadlines.removeAll()
            return
        }

        guard wasVisible, let observedEvents else {
            self.observedEvents = events
            self.contextID = contextID
            wasVisible = true
            deadlines.removeAll()
            return
        }

        if self.contextID != contextID {
            deadlines.removeAll()
            for event in events {
                deadlines[event] = timestamp.addingTimeInterval(5)
            }
            self.observedEvents = events
            self.contextID = contextID
            return
        }

        for event in events.subtracting(observedEvents) {
            deadlines[event] = timestamp.addingTimeInterval(5)
        }
        self.observedEvents = events
    }

    func activeEvents(at timestamp: Date) -> Set<CockpitOperationalCueState.DueEvent> {
        Set(deadlines.compactMap { event, deadline in deadline > timestamp ? event : nil })
    }
}

struct CockpitOperationalCueProjector: Sendable {
    private let presentationAdapter = CockpitPresentationAdapter()

    func project(
        flightPlan: FlightPlan,
        flight: Flight,
        at timestamp: Date
    ) throws -> CockpitOperationalCueState {
        if flight.activatedRouteAmendment != nil {
            return try projectAmendment(flightPlan: flightPlan, flight: flight)
        }
        let presentation = try presentationAdapter.makePresentation(
            flightPlan: flightPlan,
            legIndex: flight.activeLegIndex,
            mode: flight.executionMode, flight: flight
        )
        guard case .eligible(let plannedNavigation) = flightPlan.plannedNavigation else {
            throw CockpitPresentationError.unavailablePlannedNavigation
        }
        let legID = flight.legIDs[flight.activeLegIndex]
        let annotationsByID = Dictionary(
            uniqueKeysWithValues: plannedNavigation.annotations
                .filter { $0.legID == legID }
                .map { ($0.entityID, $0) }
        )

        let elapsedSeconds = flight.elapsedTime(at: timestamp).map {
            IdentificationPointTimingCalculator.displaySeconds($0)
        }
        let legIndexByID = Dictionary(uniqueKeysWithValues: flight.legIDs.enumerated().map { ($1, $0) })
        let orderedFrequencyChanges = flightPlan.frequencyChanges.enumerated()
            .compactMap { sourceIndex, change -> (change: FrequencyChange, legIndex: Int, time: Int, sourceIndex: Int)? in
                guard let changeLegIndex = legIndexByID[change.legID],
                      changeLegIndex <= flight.activeLegIndex,
                      let annotation = plannedNavigation.annotations.first(where: { $0.entityID == change.id }),
                      flight.pendingRouteAmendment?.includes(annotation, in: flightPlan) != false,
                      let time = time(for: annotation, mode: flight.executionMode) else { return nil }
                return (change, changeLegIndex, time, sourceIndex)
            }
            .sorted { lhs, rhs in
                if lhs.legIndex != rhs.legIndex { return lhs.legIndex < rhs.legIndex }
                return lhs.time == rhs.time ? lhs.sourceIndex < rhs.sourceIndex : lhs.time < rhs.time
            }
        var distinctFrequencyChanges: [(
            change: FrequencyChange,
            legIndex: Int,
            time: Int,
            sourceIndex: Int
        )] = []
        for candidate in orderedFrequencyChanges {
            guard distinctFrequencyChanges.last.map({
                sameFrequency($0.change, candidate.change)
            }) != true else { continue }
            distinctFrequencyChanges.append(candidate)
        }
        let initialFrequencyID = presentation.displayFrequencies.first?.id
        let currentFrequencyChange = distinctFrequencyChanges.last { candidate in
            if candidate.legIndex < flight.activeLegIndex { return true }
            guard let elapsedSeconds else { return false }
            return candidate.legIndex == flight.activeLegIndex && candidate.time <= elapsedSeconds
        }
        let matchedCurrentFrequencyID = currentFrequencyChange.flatMap {
            displayFrequencyID(for: $0.change, in: presentation.displayFrequencies)
        }
        let currentFrequencyID = matchedCurrentFrequencyID ?? initialFrequencyID
        var pendingFrequencyChanges = distinctFrequencyChanges
            .filter { candidate in
                guard let elapsedSeconds else {
                    return candidate.legIndex == flight.activeLegIndex
                }
                return candidate.legIndex == flight.activeLegIndex && candidate.time > elapsedSeconds
            }
        if flight.pendingRouteAmendment?.blocksArrival(at: flight.activeLegIndex) != true,
           plannedNavigation.legs.indices.contains(flight.activeLegIndex + 1) {
            let nextLegID = plannedNavigation.legs[flight.activeLegIndex + 1].legID
            let nextLegTimeZeroChanges = flightPlan.frequencyChanges.enumerated().compactMap {
                sourceIndex, change -> (change: FrequencyChange, legIndex: Int, time: Int, sourceIndex: Int)? in
                guard change.legID == nextLegID,
                      let annotation = plannedNavigation.annotations.first(where: { $0.entityID == change.id }),
                      time(for: annotation, mode: flight.executionMode) == 0 else { return nil }
                return (change, flight.activeLegIndex + 1, 0, sourceIndex)
            }
            pendingFrequencyChanges.append(contentsOf: nextLegTimeZeroChanges)
        }
        let nextFrequencyID = pendingFrequencyChanges
            .compactMap { candidate in
                displayFrequencyID(for: candidate.change, in: presentation.displayFrequencies)
            }
            .first { $0 != currentFrequencyID }
        let hasRepresentableCurrentFrequency = currentFrequencyChange == nil || matchedCurrentFrequencyID != nil
        let frequencies = presentation.displayFrequencies.map { frequency in
            let status: CockpitOperationalCueState.FrequencyCue.Status
            if hasRepresentableCurrentFrequency == false {
                status = .other
            } else if frequency.id == currentFrequencyID {
                status = .current
            } else if frequency.id == nextFrequencyID {
                status = .next
            } else {
                status = .other
            }
            return CockpitOperationalCueState.FrequencyCue(
                frequency: frequency,
                status: status
            )
        }

        let communicationPlan = makeCommunicationPlan(
            flightPlan: flightPlan,
            plannedNavigation: plannedNavigation,
            presentation: presentation,
            flight: flight,
            elapsedSeconds: elapsedSeconds
        )
        let navigationAidPlan = makeNavigationAidPlan(
            flightPlan: flightPlan,
            plannedNavigation: plannedNavigation,
            flight: flight
        )

        let orderedAltitudeChanges = flightPlan.altitudeChanges.enumerated()
            .compactMap { sourceIndex, change -> (change: AltitudeChange, time: Int, sourceIndex: Int)? in
                guard change.legID == legID,
                      let annotation = annotationsByID[change.id],
                      flight.pendingRouteAmendment?.includes(annotation, in: flightPlan) != false,
                      let time = time(for: annotation, mode: flight.executionMode) else { return nil }
                return (change, time, sourceIndex)
            }
            .sorted { lhs, rhs in
                lhs.time == rhs.time ? lhs.sourceIndex < rhs.sourceIndex : lhs.time < rhs.time
            }
        let currentAltitudeChange = elapsedSeconds.flatMap { elapsed in
            orderedAltitudeChanges.last { $0.time <= elapsed }
        }
        let nextAltitudeChange = orderedAltitudeChanges.first { candidate in
            guard let elapsedSeconds else { return true }
            return candidate.time > elapsedSeconds
        }
        let currentAltitude = currentAltitudeChange?.change.targetAltitude
            ?? AltitudeFeet(value: presentation.initialAltitudeFeetMsl)
        let nextAltitude: CockpitOperationalCueState.AltitudeCue?
        if let nextAltitudeChange {
            nextAltitude = CockpitOperationalCueState.AltitudeCue(
                target: nextAltitudeChange.change.targetAltitude,
                direction: nextAltitudeChange.change.symbolDirection
            )
        } else if flight.pendingRouteAmendment?.blocksArrival(at: flight.activeLegIndex) != true,
                  plannedNavigation.legs.indices.contains(flight.activeLegIndex + 1) {
            nextAltitude = beginningAltitudeCue(
                legIndex: flight.activeLegIndex + 1,
                currentAltitude: currentAltitude,
                flightPlan: flightPlan,
                plannedNavigation: plannedNavigation,
                mode: flight.executionMode
            )
        } else {
            nextAltitude = nil
        }

        let initialAltitudeDue = currentAltitudeChange == nil
            ? beginningAltitudeCueForCurrentLeg(
                legIndex: flight.activeLegIndex,
                flightPlan: flightPlan,
                plannedNavigation: plannedNavigation,
                mode: flight.executionMode
            )
            : nil

        var dueEvents: Set<CockpitOperationalCueState.DueEvent> = []
        if let currentFrequencyChange {
            dueEvents.insert(.frequency(currentFrequencyChange.change.id))
        }
        if let currentAltitudeChange {
            dueEvents.insert(.altitude(currentAltitudeChange.change.id))
        } else if initialAltitudeDue != nil {
            dueEvents.insert(.altitude(legID))
        }

        return CockpitOperationalCueState(
            frequencies: frequencies,
            communicationPlan: communicationPlan,
            navigationAidPlan: navigationAidPlan,
            currentAltitude: currentAltitude,
            nextAltitude: nextAltitude,
            dueAltitude: currentAltitudeChange.map {
                CockpitOperationalCueState.AltitudeCue(
                    target: $0.change.targetAltitude,
                    direction: $0.change.symbolDirection
                )
            } ?? initialAltitudeDue,
            dueEvents: dueEvents
        )
    }

    func projectAmendment(flightPlan: FlightPlan, flight: Flight) throws -> CockpitOperationalCueState {
        guard let activation = flight.activatedRouteAmendment, let legIndex = flight.amendmentLegIndex,
              case .eligible(let planned) = flightPlan.plannedNavigation,
              planned.legs.indices.contains(activation.amendment.departure.legIndex) else {
            throw CockpitPresentationError.unavailablePlannedNavigation
        }
        let amendment = activation.amendment
        let sourceIndex = amendment.departure.legIndex
        let source = planned.legs[sourceIndex]
        let originalIDs = flight.sourceLegIDs
        let annotationByID = Dictionary(uniqueKeysWithValues: planned.annotations.map { ($0.entityID, $0) })
        let elapsed = flight.legTimings.first { $0.legID == source.legID }?.actualElapsedDuration
        func eligibleTime(for id: UUID, legID: UUID) -> (Int, Int)? {
            guard let index = originalIDs.firstIndex(of: legID), index <= sourceIndex,
                  let annotation = annotationByID[id], amendment.includes(annotation, in: flightPlan),
                  let plannedTime = time(for: annotation, mode: flight.executionMode) else { return nil }
            if index == sourceIndex {
                guard let elapsed, Double(plannedTime) <= elapsed else { return nil }
            }
            return (index, plannedTime)
        }
        let priorAltitude = flightPlan.altitudeChanges.compactMap { change -> (Int, AltitudeFeet)? in
            guard change.legID == source.legID, let order = eligibleTime(for: change.id, legID: change.legID) else { return nil }
            return (order.1, change.targetAltitude)
        }.sorted { $0.0 < $1.0 }.last?.1 ?? source.initialAltitudeMsl
        let priorFrequency = flightPlan.frequencyChanges.compactMap { change -> ((Int, Int), FrequencyMHz)? in
            guard let order = eligibleTime(for: change.id, legID: change.legID) else { return nil }
            return (order, change.frequency)
        }.sorted { $0.0 < $1.0 }.last?.1 ?? FlightPhase.allCases.lazy.compactMap {
            planned.frequenciesByPhase[$0]?.first?.frequency
        }.first

        let active = flight.legState == .active
        let startedLegs = amendment.replacementLegs.prefix(legIndex + (active ? 1 : 0))
        let altitude = startedLegs.reversed().compactMap(\.altitudeFeet).first.map(AltitudeFeet.init) ?? priorAltitude
        let frequency = startedLegs.reversed().compactMap(\.frequencyMHz).first ?? priorFrequency?.value
        let cueLeg = amendment.replacementLegs[legIndex]
        let next = active && amendment.replacementLegs.indices.contains(legIndex + 1)
            ? amendment.replacementLegs[legIndex + 1] : (active ? nil : cueLeg)
        var frequencies: [CockpitOperationalCueState.FrequencyCue] = []
        func cue(_ value: Double, label: String, status: CockpitOperationalCueState.FrequencyCue.Status) -> CockpitOperationalCueState.FrequencyCue {
            .init(frequency: .init(id: "\(status)-\(value)", phases: [.enRoute], service: label,
                                  serviceType: String(localized: "Advisory"), frequencyMHz: value, source: .user), status: status)
        }
        if let frequency {
            frequencies.append(cue(frequency, label: String(localized: "Planned frequency"), status: .current))
        }
        if let upcoming = next?.frequencyMHz, upcoming != frequency {
            frequencies.append(cue(upcoming, label: String(localized: "Next leg frequency"), status: .next))
        }
        func altitudeCue(_ feet: Double) -> CockpitOperationalCueState.AltitudeCue {
            .init(target: .init(value: feet), direction: feet < altitude.value ? .down : .up)
        }
        var due: Set<CockpitOperationalCueState.DueEvent> = []
        if active && cueLeg.frequencyMHz != nil { due.insert(.frequency(cueLeg.id)) }
        if active && cueLeg.altitudeFeet != nil { due.insert(.altitude(cueLeg.id)) }
        return .init(
            frequencies: frequencies, currentAltitude: altitude, nextAltitude: next?.altitudeFeet.map(altitudeCue),
            dueAltitude: active ? cueLeg.altitudeFeet.map(altitudeCue) : nil, dueEvents: due
        )
    }

    private func makeNavigationAidPlan(
        flightPlan: FlightPlan,
        plannedNavigation: PlannedNavigation,
        flight: Flight
    ) -> CockpitOperationalCueState.NavigationAidPlan {
        let resolvedByID = Dictionary(
            uniqueKeysWithValues: plannedNavigation.vorDmeReferences.map { ($0.referenceID, $0) }
        )
        let waypointNames = Dictionary(uniqueKeysWithValues: flightPlan.waypoints.map { ($0.id, $0.name) })
        let arrivalLegIndexByWaypointID = Dictionary(
            uniqueKeysWithValues: flightPlan.legs.enumerated().map { ($1.arrival.id, $0) }
        )

        struct ResolvedAssociation {
            let station: String
            let frequencyMHz: Double
            let association: CockpitOperationalCueState.NavigationAidPlan.Association
        }

        let associations = flightPlan.vorDmeReferences.compactMap { reference -> ResolvedAssociation? in
            guard let resolved = resolvedByID[reference.id],
                  let arrivalWaypoint = waypointNames[reference.waypointID] else { return nil }

            let referenceLegIndex = arrivalLegIndexByWaypointID[reference.waypointID]
            let state: CockpitOperationalCueState.NavigationAidPlan.Association.State
            switch flight.legState {
            case .completed:
                state = .history
            case .active:
                if referenceLegIndex == flight.activeLegIndex {
                    state = .current
                } else if let referenceLegIndex, referenceLegIndex < flight.activeLegIndex {
                    state = .history
                } else {
                    state = .later
                }
            case .ready:
                if referenceLegIndex == flight.activeLegIndex {
                    state = flight.hasNavigationProgress ? .upcomingLeg : .firstFlownLeg
                } else if let referenceLegIndex, referenceLegIndex < flight.activeLegIndex {
                    state = .history
                } else {
                    state = .later
                }
            }

            return ResolvedAssociation(
                station: reference.navigationAid.identifier,
                frequencyMHz: resolved.frequency.value,
                association: .init(
                    id: reference.id,
                    state: state,
                    arrivalWaypoint: arrivalWaypoint,
                    routeIndex: referenceLegIndex ?? .max
                )
            )
        }

        var stations: [CockpitOperationalCueState.NavigationAidPlan.Station] = []
        for item in associations {
            if let index = stations.firstIndex(where: {
                $0.identifier == item.station && $0.frequencyMHz == item.frequencyMHz
            }) {
                let station = stations[index]
                stations[index] = .init(
                    id: station.id,
                    identifier: station.identifier,
                    frequencyMHz: station.frequencyMHz,
                    associations: station.associations + [item.association]
                )
            } else {
                stations.append(.init(
                    id: item.association.id,
                    identifier: item.station,
                    frequencyMHz: item.frequencyMHz,
                    associations: [item.association]
                ))
            }
        }

        stations = stations.map { station in
            let orderedAssociations = station.associations.enumerated().sorted { lhs, rhs in
                if lhs.element.routeIndex != rhs.element.routeIndex {
                    return lhs.element.routeIndex < rhs.element.routeIndex
                }
                return lhs.offset < rhs.offset
            }.map(\.element)
            return .init(
                id: station.id,
                identifier: station.identifier,
                frequencyMHz: station.frequencyMHz,
                associations: orderedAssociations
            )
        }

        let orderedStations = stations.enumerated().sorted { lhs, rhs in
            let lhsRemaining = lhs.element.associations.filter { $0.state != .history }
            let rhsRemaining = rhs.element.associations.filter { $0.state != .history }

            switch (lhsRemaining.first, rhsRemaining.first) {
            case let (lhsNext?, rhsNext?):
                if lhsNext.routeIndex != rhsNext.routeIndex {
                    return lhsNext.routeIndex < rhsNext.routeIndex
                }
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            case (nil, nil):
                let lhsLast = lhs.element.associations.last?.routeIndex ?? .min
                let rhsLast = rhs.element.associations.last?.routeIndex ?? .min
                if lhsLast != rhsLast { return lhsLast > rhsLast }
            }
            return lhs.offset < rhs.offset
        }.map(\.element)

        return .init(stations: orderedStations)
    }

    private func time(
        for annotation: PlannedNavigationAnnotation,
        mode: NavigationMode
    ) -> Int? {
        switch mode {
        case .noWind:
            annotation.noWindTimeFromLegStartSeconds
        case .wind:
            annotation.withWindTimeFromLegStartSeconds
        }
    }

    private struct CommunicationEvent {
        let entry: CockpitPresentationData.Frequency
        let legIndex: Int?
        let time: Int?
        let dueContext: String
    }

    private func makeCommunicationPlan(
        flightPlan: FlightPlan,
        plannedNavigation: PlannedNavigation,
        presentation: CockpitPresentationData,
        flight: Flight,
        elapsedSeconds: Int?
    ) -> CockpitOperationalCueState.CommunicationPlan {
        let legIndexByID = Dictionary(uniqueKeysWithValues: flight.legIDs.enumerated().map { ($1, $0) })
        let changeByPlannedID = Dictionary(uniqueKeysWithValues: flightPlan.frequencyChanges.map {
            ("route:\($0.id.uuidString.lowercased())", $0)
        })
        let annotationByID = Dictionary(uniqueKeysWithValues: plannedNavigation.annotations.map { ($0.entityID, $0) })

        let events = FlightPhase.allCases.flatMap { phase in
            (presentation.frequencies[phase] ?? []).filter { entry in
                entry.source != .vorDme && entry.frequencyMHz >= 118
            }.compactMap { entry -> CommunicationEvent? in
                guard let change = changeByPlannedID[entry.id],
                      let legIndex = legIndexByID[change.legID],
                      let annotation = annotationByID[change.id],
                      let eventTime = time(for: annotation, mode: flight.executionMode) else {
                    let context = phase == .departure ? "Before navigation" : "After navigation"
                    return CommunicationEvent(entry: entry, legIndex: nil, time: nil, dueContext: context)
                }
                guard flight.pendingRouteAmendment?.includes(annotation, in: flightPlan) != false else { return nil }
                return CommunicationEvent(
                    entry: entry,
                    legIndex: legIndex,
                    time: eventTime,
                    dueContext: dueContext(
                        for: change,
                        legIndex: legIndex,
                        time: eventTime,
                        flightPlan: flightPlan
                    )
                )
            }
        }

        let orderedRouteEvents = events.filter { $0.legIndex != nil }.sorted {
            if $0.legIndex != $1.legIndex { return ($0.legIndex ?? 0) < ($1.legIndex ?? 0) }
            return ($0.time ?? 0) < ($1.time ?? 0)
        }
        let routeCurrentIndex: Int? = {
            guard flight.legState != .ready, let elapsedSeconds else { return nil }
            return orderedRouteEvents.lastIndex {
                guard let legIndex = $0.legIndex, let eventTime = $0.time else { return false }
                return legIndex < flight.activeLegIndex
                    || (legIndex == flight.activeLegIndex && eventTime <= elapsedSeconds)
            }
        }()
        let routeNextIndex: Int? = {
            let start = (routeCurrentIndex ?? -1) + 1
            guard orderedRouteEvents.indices.contains(start) else { return nil }
            if let current = routeCurrentIndex {
                let currentEvent = orderedRouteEvents[current]
                return orderedRouteEvents.indices.dropFirst(start).first {
                    !sameCommunication(orderedRouteEvents[$0].entry, currentEvent.entry)
                }
            }
            return start
        }()

        let fullEntries = events.map { event -> CockpitOperationalCueState.CommunicationPlan.Entry in
            let state: CockpitOperationalCueState.CommunicationPlan.Entry.State
            if event.entry.phase == .departure {
                if flight.legState == .ready && flight.activeLegIndex == 0 {
                    state = .departurePlan
                } else if flight.legState == .active,
                          routeCurrentIndex == nil,
                          events.first(where: { $0.entry.phase == .departure })?.entry.id == event.entry.id {
                    state = .current
                } else {
                    state = .past
                }
            } else if event.entry.phase == .arrival {
                if flight.legState == .active,
                   routeNextIndex == nil,
                   events.first(where: { $0.entry.phase == .arrival })?.entry.id == event.entry.id {
                    state = .next
                } else {
                    state = .arrival
                }
            } else if let index = orderedRouteEvents.firstIndex(where: { $0.entry.id == event.entry.id }) {
                if flight.legState == .ready,
                   event.legIndex == flight.activeLegIndex,
                   event.time == 0 { state = .atStart }
                else if flight.legState == .completed { state = .past }
                else if index == routeCurrentIndex { state = .current }
                else if index == routeNextIndex { state = .next }
                else if routeCurrentIndex.map({ index < $0 }) == true { state = .past }
                else { state = .later }
            } else {
                state = .later
            }
            return .init(
                id: event.entry.id,
                phase: event.entry.phase,
                role: event.entry.role,
                service: event.entry.service,
                frequencyMHz: event.entry.frequencyMHz,
                state: state,
                dueContext: event.dueContext
            )
        }

        let compactCandidates: [CockpitOperationalCueState.CommunicationPlan.Entry]
        switch flight.legState {
        case .ready:
            let currentLegRoute = fullEntries.filter { entry in
                guard let change = changeByPlannedID[entry.id] else { return false }
                return legIndexByID[change.legID] == flight.activeLegIndex
            }
            compactCandidates = (flight.activeLegIndex == 0
                ? Array(fullEntries.filter { $0.phase == .departure }.prefix(1))
                : []) + currentLegRoute
        case .active:
            compactCandidates = fullEntries.filter { $0.state == .current || $0.state == .next }
        case .completed:
            compactCandidates = Array(fullEntries.filter { $0.phase == .arrival }.prefix(1))
        }
        var compactEntries: [CockpitOperationalCueState.CommunicationPlan.Entry] = []
        for entry in compactCandidates where compactEntries.count < (flight.legState == .ready ? 3 : 2) {
            guard compactEntries.last.map({ !sameCommunication($0, entry) }) ?? true else { continue }
            compactEntries.append(entry)
        }

        return .init(entries: fullEntries, compactEntries: compactEntries)
    }

    private func dueContext(
        for change: FrequencyChange,
        legIndex: Int,
        time: Int,
        flightPlan: FlightPlan
    ) -> String {
        guard flightPlan.legs.indices.contains(legIndex) else { return "Planned in route" }
        let leg = flightPlan.legs[legIndex]
        let route = "\(leg.departure.name) → \(leg.arrival.name)"
        if time == 0 { return "\(route) · at start" }
        let points = flightPlan.identificationPoints.filter { $0.legID == change.legID }
        if let pointIndex = points.firstIndex(where: { abs($0.progress.fraction - change.progress.fraction) < 0.000_001 }) {
            return "\(route) · at IP \(pointIndex + 1)"
        }
        return "\(route) · later this leg"
    }

    private func sameCommunication(
        _ lhs: CockpitPresentationData.Frequency,
        _ rhs: CockpitPresentationData.Frequency
    ) -> Bool {
        lhs.service == rhs.service && lhs.frequencyMHz == rhs.frequencyMHz
    }

    private func sameCommunication(
        _ lhs: CockpitOperationalCueState.CommunicationPlan.Entry,
        _ rhs: CockpitOperationalCueState.CommunicationPlan.Entry
    ) -> Bool {
        lhs.service == rhs.service && lhs.frequencyMHz == rhs.frequencyMHz
    }

    private func beginningAltitudeCue(
        legIndex: Int,
        currentAltitude: AltitudeFeet,
        flightPlan: FlightPlan,
        plannedNavigation: PlannedNavigation,
        mode: NavigationMode
    ) -> CockpitOperationalCueState.AltitudeCue? {
        let leg = plannedNavigation.legs[legIndex]
        let annotationsByID = Dictionary(
            uniqueKeysWithValues: plannedNavigation.annotations
                .filter { $0.legID == leg.legID && $0.kind == .altitudeChange }
                .map { ($0.entityID, $0) }
        )
        let timeZeroChange = flightPlan.altitudeChanges.last { change in
            guard change.legID == leg.legID,
                  let annotation = annotationsByID[change.id] else { return false }
            return time(for: annotation, mode: mode) == 0
        }
        if let timeZeroChange {
            return CockpitOperationalCueState.AltitudeCue(
                target: timeZeroChange.targetAltitude,
                direction: timeZeroChange.symbolDirection
            )
        }
        guard leg.initialAltitudeMsl != currentAltitude else { return nil }
        return CockpitOperationalCueState.AltitudeCue(
            target: leg.initialAltitudeMsl,
            direction: leg.initialAltitudeMsl.value > currentAltitude.value ? .up : .down
        )
    }

    private func beginningAltitudeCueForCurrentLeg(
        legIndex: Int,
        flightPlan: FlightPlan,
        plannedNavigation: PlannedNavigation,
        mode: NavigationMode
    ) -> CockpitOperationalCueState.AltitudeCue? {
        guard legIndex > 0 else { return nil }
        let previousLeg = plannedNavigation.legs[legIndex - 1]
        let previousAnnotationsByID = Dictionary(
            uniqueKeysWithValues: plannedNavigation.annotations
                .filter { $0.legID == previousLeg.legID && $0.kind == .altitudeChange }
                .map { ($0.entityID, $0) }
        )
        let previousAltitude = flightPlan.altitudeChanges.enumerated()
            .compactMap { sourceIndex, change -> (target: AltitudeFeet, time: Int, sourceIndex: Int)? in
                guard change.legID == previousLeg.legID,
                      let annotation = previousAnnotationsByID[change.id],
                      let time = time(for: annotation, mode: mode) else { return nil }
                return (change.targetAltitude, time, sourceIndex)
            }
            .max { lhs, rhs in
                lhs.time == rhs.time ? lhs.sourceIndex < rhs.sourceIndex : lhs.time < rhs.time
            }?
            .target ?? previousLeg.initialAltitudeMsl
        let currentAltitude = plannedNavigation.legs[legIndex].initialAltitudeMsl
        guard currentAltitude != previousAltitude else { return nil }
        return CockpitOperationalCueState.AltitudeCue(
            target: currentAltitude,
            direction: currentAltitude.value > previousAltitude.value ? .up : .down
        )
    }

    private func displayFrequencyID(
        for change: FrequencyChange,
        in frequencies: [CockpitPresentationData.DisplayFrequency]
    ) -> String? {
        let plannedID = "route:\(change.id.uuidString.lowercased())"
        return frequencies.first { $0.id == plannedID }?.id
            ?? frequencies.first {
                $0.source == .route &&
                $0.service == change.service.name &&
                $0.frequencyMHz == change.frequency.value
            }?.id
    }

    private func sameFrequency(_ lhs: FrequencyChange, _ rhs: FrequencyChange) -> Bool {
        lhs.service.name == rhs.service.name && lhs.frequency == rhs.frequency
    }
}
