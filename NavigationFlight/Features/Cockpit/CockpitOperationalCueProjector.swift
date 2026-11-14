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
    let dueAltitude: AltitudeCue?
    let dueEvents: Set<DueEvent>
}

struct CockpitConsoleCuePresentation: Equatable, Sendable {
    let immediateFrequencyCues: [CockpitOperationalCueState.FrequencyCue]
    let isAltitudeEmphasized: Bool

    init(
        cues: CockpitOperationalCueState,
        emphasizedEvents: Set<CockpitOperationalCueState.DueEvent>
    ) {
        immediateFrequencyCues = [
            cues.frequencies.first(where: { $0.status == .current }),
            cues.frequencies.first(where: { $0.status == .next })
        ].compactMap { $0 }
        isAltitudeEmphasized = emphasizedEvents.contains { event in
            if case .altitude = event { true } else { false }
        }
    }
}

extension CockpitOperationalCueState.FrequencyCue {
    var statusLabel: String? {
        switch status {
        case .current: "CURRENT"
        case .next: "NEXT"
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
        let legIndexByID = Dictionary(uniqueKeysWithValues: flight.legIDs.enumerated().map { ($1, $0) })
        let orderedFrequencyChanges = flightPlan.frequencyChanges.enumerated()
            .compactMap { sourceIndex, change -> (change: FrequencyChange, legIndex: Int, time: Int, sourceIndex: Int)? in
                guard let changeLegIndex = legIndexByID[change.legID],
                      changeLegIndex <= flight.activeLegIndex,
                      let annotation = plannedNavigation.annotations.first(where: { $0.entityID == change.id }),
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
        if plannedNavigation.legs.indices.contains(flight.activeLegIndex + 1) {
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
        let currentAltitude = currentAltitudeChange?.change.targetAltitude
            ?? AltitudeFeet(value: presentation.initialAltitudeFeetMsl)
        let nextAltitude: CockpitOperationalCueState.AltitudeCue?
        if let nextAltitudeChange {
            nextAltitude = CockpitOperationalCueState.AltitudeCue(
                target: nextAltitudeChange.change.targetAltitude,
                direction: nextAltitudeChange.change.symbolDirection
            )
        } else if plannedNavigation.legs.indices.contains(flight.activeLegIndex + 1) {
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
