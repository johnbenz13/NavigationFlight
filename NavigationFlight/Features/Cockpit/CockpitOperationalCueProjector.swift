import Foundation

struct CockpitOperationalCueState: Equatable, Sendable {
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
    let currentAltitude: AltitudeFeet
    let nextAltitude: AltitudeCue?
    let dueEvents: Set<DueEvent>
}

struct CockpitOperationalCueProjector: Sendable {
    private let presentationAdapter = CockpitPresentationAdapter()

    func project(
        flightPlan: FlightPlan,
        flight: Flight,
        at timestamp: Date
    ) throws -> CockpitOperationalCueState {
        let presentation = try presentationAdapter.makePresentation(
            flightPlan: flightPlan,
            legIndex: flight.activeLegIndex,
            mode: flight.executionMode
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
        let orderedFrequencyChanges = flightPlan.frequencyChanges.enumerated()
            .compactMap { sourceIndex, change -> (change: FrequencyChange, time: Int, sourceIndex: Int)? in
                guard change.legID == legID,
                      let annotation = annotationsByID[change.id],
                      let time = time(for: annotation, mode: flight.executionMode) else { return nil }
                return (change, time, sourceIndex)
            }
            .sorted { lhs, rhs in
                lhs.time == rhs.time ? lhs.sourceIndex < rhs.sourceIndex : lhs.time < rhs.time
            }
        var distinctFrequencyChanges: [(change: FrequencyChange, time: Int, sourceIndex: Int)] = []
        for candidate in orderedFrequencyChanges {
            guard distinctFrequencyChanges.last.map({
                sameFrequency($0.change, candidate.change)
            }) != true else { continue }
            distinctFrequencyChanges.append(candidate)
        }
        let initialFrequencyID = presentation.displayFrequencies.first?.id
        let currentFrequencyChange = elapsedSeconds.flatMap { elapsed in
            distinctFrequencyChanges.last { $0.time <= elapsed }
        }
        let matchedCurrentFrequencyID = currentFrequencyChange.flatMap {
            displayFrequencyID(for: $0.change, in: presentation.displayFrequencies)
        }
        let currentFrequencyID = matchedCurrentFrequencyID ?? initialFrequencyID
        let nextFrequencyID = distinctFrequencyChanges
            .filter { candidate in
                guard let elapsedSeconds else { return true }
                return candidate.time > elapsedSeconds
            }
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

        let orderedAltitudeChanges = flightPlan.altitudeChanges.enumerated()
            .compactMap { sourceIndex, change -> (change: AltitudeChange, time: Int, sourceIndex: Int)? in
                guard change.legID == legID,
                      let annotation = annotationsByID[change.id],
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
        let nextAltitude = nextAltitudeChange.map {
                CockpitOperationalCueState.AltitudeCue(
                    target: $0.change.targetAltitude,
                    direction: $0.change.symbolDirection
                )
            }

        var dueEvents: Set<CockpitOperationalCueState.DueEvent> = []
        if let currentFrequencyChange {
            dueEvents.insert(.frequency(currentFrequencyChange.change.id))
        }
        if let currentAltitudeChange {
            dueEvents.insert(.altitude(currentAltitudeChange.change.id))
        }

        return CockpitOperationalCueState(
            frequencies: frequencies,
            currentAltitude: currentAltitudeChange?.change.targetAltitude
                ?? AltitudeFeet(value: presentation.initialAltitudeFeetMsl),
            nextAltitude: nextAltitude,
            dueEvents: dueEvents
        )
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
