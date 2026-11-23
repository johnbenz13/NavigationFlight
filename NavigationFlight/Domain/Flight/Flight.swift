import Foundation

struct IdentificationPointKey: Hashable, Sendable {
    let legID: UUID
    let identificationPointID: UUID
}
struct NavigationTimingTargetKey: Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case identificationPoint
        case destination
    }

    let legID: UUID
    let kind: Kind
    let targetID: UUID
}

struct Flight: Equatable, Sendable {
    enum ProgressionPolicy: Equatable, Sendable {
        case automaticNextLeg
        case manualNextLeg
    }

    enum LegState: Equatable, Sendable {
        case ready
        case active
        case completed
    }

    enum TransitionError: Error, Equatable, Sendable, LocalizedError {
        case invalidLegIndex(Int)
        case legNotReady
        case legNotActive
        case legAlreadyStarted(Int)
        case destinationAlreadyIdentified(Int)
        case waypointAlreadyReached(Int)
        case identificationPointAlreadyReached(UUID)
        case identificationPointPassedWithoutReport(UUID)
        case identificationPointWrongLeg(UUID)
        case invalidIdentificationPointOrder
        case timestampPrecedesStart
        case finalLegCompleted
        case amendmentRejoinUnavailable

        var errorDescription: String? {
            switch self {
            case .invalidLegIndex:
                "The selected leg is not part of this flight."
            case .legNotReady:
                "This leg is not ready to start."
            case .legNotActive:
                "This leg is not active."
            case .legAlreadyStarted:
                "This leg has already been started."
            case .destinationAlreadyIdentified:
                "This waypoint has already been identified."
            case .waypointAlreadyReached:
                "This waypoint has already been reached."
            case .identificationPointAlreadyReached:
                "This identification point has already been reached."
            case .identificationPointPassedWithoutReport:
                "This identification point was passed without report and can no longer be reached."
            case .identificationPointWrongLeg:
                "This identification point is not part of the active leg."
            case .invalidIdentificationPointOrder:
                "The active leg’s identification-point order is unavailable."
            case .timestampPrecedesStart:
                "The reported time cannot be earlier than the leg start."
            case .finalLegCompleted:
                "Navigation has already been completed."
            case .amendmentRejoinUnavailable:
                "Return to the retained route is unavailable in this version."
            }
        }
    }

    struct LegTiming: Equatable, Sendable {
        let legID: UUID
        let legIndex: Int
        let startedAt: Date
        let destinationIdentifiedAt: Date?
        let reachedAt: Date?
        var amendmentDepartureAt: Date? = nil
        var recordedDepartureElapsed: TimeInterval? = nil

        var actualElapsedDuration: TimeInterval? {
            recordedDepartureElapsed ?? (reachedAt ?? amendmentDepartureAt).map { $0.timeIntervalSince(startedAt) }
        }
    }

    struct IdentificationPointTiming: Equatable, Sendable {
        enum Outcome: Equatable, Sendable {
            case reached(Date)
            case passedWithoutReport
        }

        let key: IdentificationPointKey
        let legIndex: Int
        let outcome: Outcome

        var identificationPointID: UUID { key.identificationPointID }
        var legID: UUID { key.legID }
        var reachedAt: Date? {
            guard case .reached(let timestamp) = outcome else { return nil }
            return timestamp
        }

        func actualLegElapsedDuration(startedAt: Date) -> TimeInterval? {
            reachedAt?.timeIntervalSince(startedAt)
        }
    }

    enum IdentificationPointState: Equatable, Sendable {
        case future
        case reached(Date)
        case passedWithoutReport

        var isReached: Bool {
            if case .reached = self { return true }
            return false
        }
    }

    struct PilotETAState: Equatable, Sendable {
        struct Commit: Equatable, Sendable {
            let seconds: Int
        }

        struct CheckDisclosure: Equatable, Sendable {
            let observationKey: IdentificationPointKey
            let referenceSeconds: Int
        }

        var draftSeconds: Int
        var commits: [Commit]
        var isEditing: Bool
        var isCheckResultVisible: Bool
        var validationError: PilotETAError?
        var checkDisclosures: [CheckDisclosure]

        var committedSeconds: Int? { commits.last?.seconds }
        var latestCheckDisclosure: CheckDisclosure? { checkDisclosures.last }
    }

    struct PilotHeadingState: Equatable, Sendable {
        struct Commit: Equatable, Sendable {
            let degrees: Int
        }

        let baselineDegrees: Int
        var draftDegrees: Int
        var commits: [Commit]
        var isEditing: Bool

        var committedDegrees: Int? { commits.last?.degrees }
        var operationalDegrees: Int { committedDegrees ?? baselineDegrees }
    }

    enum PilotETAError: Error, Equatable, Sendable {
        case staleDraft(minimumSeconds: Int)
    }

    let id: UUID
    let flightPlanID: UUID
    let sourceLegIDs: [UUID]
    let progressionPolicy: ProgressionPolicy
    private(set) var activeLegIndex: Int
    private(set) var executionMode: NavigationMode
    private(set) var pendingRouteAmendment: PendingRouteAmendment?
    private(set) var activatedRouteAmendment: ActivatedRouteAmendment?

    var legIDs: [UUID] {
        guard let activatedRouteAmendment else { return sourceLegIDs }
        return Array(sourceLegIDs.prefix(activatedRouteAmendment.replacementStartIndex)) +
            activatedRouteAmendment.amendment.replacementLegs.map(\.id)
    }

    var activeLegID: UUID { legIDs[activeLegIndex] }

    var amendmentLegIndex: Int? {
        activatedRouteAmendment.map { activeLegIndex - $0.replacementStartIndex }
    }

    var amendmentLeg: PendingRouteAmendment.Leg? {
        guard let activatedRouteAmendment, let amendmentLegIndex else { return nil }
        return activatedRouteAmendment.amendment.replacementLegs[amendmentLegIndex]
    }

    var awaitsAmendmentRejoin: Bool {
        activatedRouteAmendment != nil && activeLegIndex == legIDs.count - 1
    }
    private var pendingDepartureIdentifiedAt: Date?

    var activePartwayDeparture: PendingRouteAmendment? {
        guard let pendingRouteAmendment, pendingRouteAmendment.departureIsPartway,
              pendingRouteAmendment.departure.legIndex == activeLegIndex else { return nil }
        return pendingRouteAmendment
    }

    func operationalArrival(for leg: NavigationLeg) -> RouteWaypoint {
        guard let pendingRouteAmendment, pendingRouteAmendment.departureIsPartway,
              pendingRouteAmendment.departure.legID == leg.id,
              let stop = pendingRouteAmendment.departureStop else { return leg.arrival }
        return RouteWaypoint(
            id: stop.id, name: stop.name, position: stop.position,
            plannedAltitude: leg.departure.plannedAltitude,
            generatedNumber: leg.arrival.generatedNumber, reportingPointReference: nil
        )
    }

    mutating func installPendingAmendment(
        _ amendment: PendingRouteAmendment, in plan: FlightPlan, replacing pendingID: UUID? = nil
    ) throws {
        guard pendingRouteAmendment?.id == pendingID else {
            throw PendingRouteAmendment.Validation.stalePendingAmendment
        }
        guard let route = routeForAmendment(in: plan) else {
            throw PendingRouteAmendment.Validation.unavailableDeparture
        }
        try amendment.validate(flight: self, route: route, replacing: pendingID)
        if let pendingID { try cancelPendingAmendment(id: pendingID) }
        pendingRouteAmendment = amendment
    }

    mutating func cancelPendingAmendment(id: UUID) throws {
        guard let pendingRouteAmendment, pendingRouteAmendment.id == id else {
            throw PendingRouteAmendment.Validation.stalePendingAmendment
        }
        if pendingRouteAmendment.departureIsPartway, let stop = pendingRouteAmendment.departureStop {
            pilotETAStatesByTargetKey.removeValue(forKey: .init(
                legID: pendingRouteAmendment.departure.legID, kind: .destination, targetID: stop.id
            ))
        }
        self.pendingRouteAmendment = nil
        pendingDepartureIdentifiedAt = nil
    }

    func originalDestinationReport(in plan: FlightPlan) -> PendingAmendmentOriginalDestination? {
        guard legState == .active, let pending = activePartwayDeparture, plan.id == flightPlanID,
              plan.legs.indices.contains(activeLegIndex) else { return nil }
        let leg = plan.legs[activeLegIndex]
        // The current, strictly partway anchor precedes fraction 1 of the same stable leg.
        guard leg.id == legIDs[activeLegIndex], leg.id == pending.departure.legID else { return nil }
        return .init(amendmentID: pending.id, legID: leg.id, targetID: leg.arrival.id)
    }

    mutating func cancelForOriginalDestination(
        _ report: PendingAmendmentOriginalDestination, in plan: FlightPlan
    ) throws {
        guard originalDestinationReport(in: plan) == report else {
            throw PendingRouteAmendment.Validation.stalePendingAmendment
        }
        try cancelPendingAmendment(id: report.amendmentID)
    }

    private(set) var legState: LegState
    private(set) var legTimings: [LegTiming]
    private(set) var identificationPointTimings: [IdentificationPointTiming]
    private(set) var pilotETAStatesByTargetKey: [NavigationTimingTargetKey: PilotETAState]
    private(set) var pilotHeadingStatesByLegID: [UUID: PilotHeadingState]

    var legStartedAt: Date? {
        legTimings.first { $0.legIndex == activeLegIndex }?.startedAt
    }

    var destinationIdentifiedAt: Date? {
        if activePartwayDeparture != nil { return pendingDepartureIdentifiedAt }
        return legTimings.first { $0.legIndex == activeLegIndex }?.destinationIdentifiedAt
    }

    init(
        id: UUID = UUID(),
        flightPlanID: UUID,
        legIDs: [UUID],
        activeLegIndex: Int,
        executionMode: NavigationMode,
        progressionPolicy: ProgressionPolicy = .automaticNextLeg
    ) {
        precondition(legIDs.indices.contains(activeLegIndex), "Active leg index must be in the plan")
        self.id = id
        self.flightPlanID = flightPlanID
        self.sourceLegIDs = legIDs
        self.activeLegIndex = activeLegIndex
        self.executionMode = executionMode
        self.progressionPolicy = progressionPolicy
        self.legState = .ready
        self.legTimings = []
        self.identificationPointTimings = []
        self.pilotETAStatesByTargetKey = [:]
        self.pilotHeadingStatesByLegID = [:]
    }

    mutating func selectReadyLeg(index: Int, mode: NavigationMode) throws {
        guard legState == .ready else { throw TransitionError.legNotReady }
        guard legIDs.indices.contains(index) else { throw TransitionError.invalidLegIndex(index) }
        guard legTimings.allSatisfy({ $0.legIndex != index }) else {
            throw TransitionError.legAlreadyStarted(index)
        }
        activeLegIndex = index
        executionMode = mode
    }

    mutating func startLeg(at timestamp: Date) throws {
        guard legState == .ready else {
            if legState == .active { throw TransitionError.legAlreadyStarted(activeLegIndex) }
            throw TransitionError.finalLegCompleted
        }
        guard legTimings.allSatisfy({ $0.legIndex != activeLegIndex }) else {
            throw TransitionError.legAlreadyStarted(activeLegIndex)
        }
        legTimings.append(
            LegTiming(
                legID: legIDs[activeLegIndex],
                legIndex: activeLegIndex,
                startedAt: timestamp,
                destinationIdentifiedAt: nil,
                reachedAt: nil
            )
        )
        legState = .active
    }

    mutating func identifyDestination(at timestamp: Date) throws {
        guard legState == .active,
              let timingIndex = legTimings.firstIndex(where: { $0.legIndex == activeLegIndex }) else {
            throw TransitionError.legNotActive
        }
        let current = legTimings[timingIndex]
        if activePartwayDeparture != nil {
            guard pendingDepartureIdentifiedAt == nil else {
                throw TransitionError.destinationAlreadyIdentified(activeLegIndex)
            }
            guard timestamp >= current.startedAt else { throw TransitionError.timestampPrecedesStart }
            pendingDepartureIdentifiedAt = timestamp
            return
        }
        guard current.destinationIdentifiedAt == nil else {
            throw TransitionError.destinationAlreadyIdentified(activeLegIndex)
        }
        guard timestamp >= current.startedAt else { throw TransitionError.timestampPrecedesStart }
        legTimings[timingIndex] = LegTiming(
            legID: current.legID,
            legIndex: current.legIndex,
            startedAt: current.startedAt,
            destinationIdentifiedAt: timestamp,
            reachedAt: current.reachedAt
        )
    }

    mutating func reachIdentificationPoint(
        key: IdentificationPointKey,
        orderedActiveLegPointKeys: [IdentificationPointKey],
        at timestamp: Date
    ) throws {
        guard legState == .active, let startedAt = legStartedAt else {
            throw TransitionError.legNotActive
        }
        let activeLegID = legIDs[activeLegIndex]
        guard key.legID == activeLegID else {
            throw TransitionError.identificationPointWrongLeg(key.identificationPointID)
        }
        if let departure = activePartwayDeparture,
           orderedActiveLegPointKeys.map(\.identificationPointID) != departure.retainedDeparturePointIDs {
            throw TransitionError.invalidIdentificationPointOrder
        }
        guard !orderedActiveLegPointKeys.isEmpty,
              orderedActiveLegPointKeys.allSatisfy({ $0.legID == activeLegID }),
              Set(orderedActiveLegPointKeys).count == orderedActiveLegPointKeys.count,
              let selectedIndex = orderedActiveLegPointKeys.firstIndex(of: key) else {
            throw TransitionError.invalidIdentificationPointOrder
        }
        switch identificationPointState(for: key) {
        case .reached:
            throw TransitionError.identificationPointAlreadyReached(key.identificationPointID)
        case .passedWithoutReport:
            throw TransitionError.identificationPointPassedWithoutReport(key.identificationPointID)
        case .future:
            break
        }
        guard timestamp >= startedAt else { throw TransitionError.timestampPrecedesStart }

        var nextTimings = identificationPointTimings
        for earlierKey in orderedActiveLegPointKeys[..<selectedIndex]
        where identificationPointState(for: earlierKey) == .future {
            nextTimings.append(
                IdentificationPointTiming(
                    key: earlierKey,
                    legIndex: activeLegIndex,
                    outcome: .passedWithoutReport
                )
            )
        }
        nextTimings.append(
            IdentificationPointTiming(
                key: key,
                legIndex: activeLegIndex,
                outcome: .reached(timestamp)
            )
        )

        var nextETAStates = pilotETAStatesByTargetKey
        let selectedTargetKey = NavigationTimingTargetKey(
            legID: key.legID,
            kind: .identificationPoint,
            targetID: key.identificationPointID
        )
        if var selectedETAState = nextETAStates[selectedTargetKey] {
            if let committedSeconds = selectedETAState.committedSeconds {
                selectedETAState.draftSeconds = committedSeconds
                selectedETAState.isEditing = false
                selectedETAState.isCheckResultVisible = false
                nextETAStates[selectedTargetKey] = selectedETAState
            } else {
                nextETAStates.removeValue(forKey: selectedTargetKey)
            }
        }

        identificationPointTimings = nextTimings
        pilotETAStatesByTargetKey = nextETAStates
    }

    func identificationPointTiming(for key: IdentificationPointKey) -> IdentificationPointTiming? {
        identificationPointTimings.first { $0.key == key }
    }

    func identificationPointState(for key: IdentificationPointKey) -> IdentificationPointState {
        guard let timing = identificationPointTiming(for: key) else { return .future }
        switch timing.outcome {
        case .reached(let timestamp):
            return .reached(timestamp)
        case .passedWithoutReport:
            return .passedWithoutReport
        }
    }

    func actualLegElapsedDuration(atIdentificationPoint key: IdentificationPointKey) -> TimeInterval? {
        guard let record = identificationPointTiming(for: key),
              let legTiming = legTimings.first(where: { $0.legID == record.legID }) else { return nil }
        return record.actualLegElapsedDuration(startedAt: legTiming.startedAt)
    }

    func latestEligibleTimingObservation(
        before targetKey: NavigationTimingTargetKey,
        orderedPointKeys: [IdentificationPointKey]
    ) -> IdentificationPointKey? {
        let endIndex: Int
        switch targetKey.kind {
        case .destination:
            endIndex = orderedPointKeys.endIndex
        case .identificationPoint:
            guard let index = orderedPointKeys.firstIndex(where: {
                $0.legID == targetKey.legID && $0.identificationPointID == targetKey.targetID
            }) else { return nil }
            endIndex = index
        }
        return orderedPointKeys[..<endIndex].last(where: {
            $0.legID == targetKey.legID && identificationPointState(for: $0).isReached
        })
    }

    mutating func initializePilotETA(
        targetKey: NavigationTimingTargetKey,
        plannedElapsedSeconds: Int,
        currentElapsedSeconds: Int = 0
    ) {
        guard plannedElapsedSeconds >= 0,
              canRevisePilotETA(targetKey: targetKey),
              pilotETAStatesByTargetKey[targetKey] == nil else { return }
        let floor = Self.pilotETAMinimumSeconds(currentElapsedSeconds: currentElapsedSeconds)
        pilotETAStatesByTargetKey[targetKey] = PilotETAState(
            draftSeconds: max(
                IdentificationPointTimingCalculator.roundToNearestFiveSeconds(plannedElapsedSeconds),
                floor
            ),
            commits: [],
            isEditing: true,
            isCheckResultVisible: false,
            validationError: nil,
            checkDisclosures: []
        )
    }

    mutating func adjustPilotETA(
        targetKey: NavigationTimingTargetKey,
        by deltaSeconds: Int,
        currentElapsedSeconds: Int = 0
    ) {
        guard canRevisePilotETA(targetKey: targetKey),
              var state = pilotETAStatesByTargetKey[targetKey], state.isEditing else { return }
        let floor = Self.pilotETAMinimumSeconds(currentElapsedSeconds: currentElapsedSeconds)
        state.draftSeconds = max(floor, state.draftSeconds + deltaSeconds)
        state.validationError = state.draftSeconds < floor ? .staleDraft(minimumSeconds: floor) : nil
        pilotETAStatesByTargetKey[targetKey] = state
    }

    @discardableResult
    mutating func commitPilotETA(
        targetKey: NavigationTimingTargetKey,
        currentElapsedSeconds: Int = 0
    ) -> PilotETAError? {
        guard canRevisePilotETA(targetKey: targetKey),
              var state = pilotETAStatesByTargetKey[targetKey], state.isEditing else { return nil }
        let floor = Self.pilotETAMinimumSeconds(currentElapsedSeconds: currentElapsedSeconds)
        guard state.draftSeconds >= floor else {
            let error = PilotETAError.staleDraft(minimumSeconds: floor)
            state.validationError = error
            pilotETAStatesByTargetKey[targetKey] = state
            return error
        }
        state.commits.append(.init(seconds: state.draftSeconds))
        state.isEditing = false
        state.isCheckResultVisible = false
        state.validationError = nil
        pilotETAStatesByTargetKey[targetKey] = state
        return nil
    }

    mutating func beginEditingPilotETA(
        targetKey: NavigationTimingTargetKey,
        currentElapsedSeconds: Int = 0
    ) {
        guard canRevisePilotETA(targetKey: targetKey),
              var state = pilotETAStatesByTargetKey[targetKey],
              let committed = state.committedSeconds else { return }
        state.draftSeconds = max(
            committed,
            Self.pilotETAMinimumSeconds(currentElapsedSeconds: currentElapsedSeconds)
        )
        state.isEditing = true
        state.isCheckResultVisible = false
        state.validationError = nil
        pilotETAStatesByTargetKey[targetKey] = state
    }

    mutating func cancelPilotETAEditing(targetKey: NavigationTimingTargetKey) {
        guard var state = pilotETAStatesByTargetKey[targetKey], state.isEditing else { return }
        guard let committed = state.committedSeconds else {
            pilotETAStatesByTargetKey.removeValue(forKey: targetKey)
            return
        }
        state.draftSeconds = committed
        state.isEditing = false
        state.validationError = nil
        pilotETAStatesByTargetKey[targetKey] = state
    }

    @discardableResult
    mutating func showPilotETACheck(
        targetKey: NavigationTimingTargetKey,
        observationKey: IdentificationPointKey,
        plannedObservationElapsed: TimeInterval,
        actualObservationElapsed: TimeInterval,
        plannedTargetElapsed: TimeInterval
    ) -> Bool {
        guard var state = pilotETAStatesByTargetKey[targetKey],
              state.committedSeconds != nil,
              let exactReference = IdentificationPointTimingCalculator.referenceTargetElapsed(
                plannedReachedElapsed: plannedObservationElapsed,
                actualReachedElapsed: actualObservationElapsed,
                plannedTargetElapsed: plannedTargetElapsed
              ) else { return false }
        state.checkDisclosures.append(.init(
            observationKey: observationKey,
            referenceSeconds: IdentificationPointTimingCalculator.displaySeconds(exactReference)
        ))
        state.isCheckResultVisible = true
        pilotETAStatesByTargetKey[targetKey] = state
        return true
    }

    mutating func hidePilotETACheck(targetKey: NavigationTimingTargetKey) {
        guard var state = pilotETAStatesByTargetKey[targetKey] else { return }
        state.isCheckResultVisible = false
        pilotETAStatesByTargetKey[targetKey] = state
    }

    func pilotETAState(targetKey: NavigationTimingTargetKey) -> PilotETAState? {
        pilotETAStatesByTargetKey[targetKey]
    }

    func committedPilotETA(targetKey: NavigationTimingTargetKey) -> Int? {
        pilotETAStatesByTargetKey[targetKey]?.committedSeconds
    }

    func pilotETACommitHistory(targetKey: NavigationTimingTargetKey) -> [PilotETAState.Commit] {
        pilotETAStatesByTargetKey[targetKey]?.commits ?? []
    }

    static func pilotETAMinimumSeconds(currentElapsedSeconds: Int) -> Int {
        IdentificationPointTimingCalculator.roundUpToFiveSeconds(max(0, currentElapsedSeconds))
    }

    static func normalizedHeading(_ degrees: Int) -> Int {
        let remainder = degrees % 360
        return remainder > 0 ? remainder : remainder + 360
    }

    mutating func openPilotHeadingEditor(baselineDegrees: Int) {
        guard legState == .active else { return }
        let legID = legIDs[activeLegIndex]
        if var state = pilotHeadingStatesByLegID[legID] {
            state.draftDegrees = state.operationalDegrees
            state.isEditing = true
            pilotHeadingStatesByLegID[legID] = state
        } else {
            let baseline = Self.normalizedHeading(baselineDegrees)
            pilotHeadingStatesByLegID[legID] = PilotHeadingState(
                baselineDegrees: baseline,
                draftDegrees: baseline,
                commits: [],
                isEditing: true
            )
        }
    }

    mutating func adjustPilotHeading(by deltaDegrees: Int) {
        guard legState == .active else { return }
        let legID = legIDs[activeLegIndex]
        guard var state = pilotHeadingStatesByLegID[legID], state.isEditing else { return }
        state.draftDegrees = Self.normalizedHeading(state.draftDegrees + deltaDegrees)
        pilotHeadingStatesByLegID[legID] = state
    }

    mutating func commitPilotHeading() {
        guard legState == .active else { return }
        let legID = legIDs[activeLegIndex]
        guard var state = pilotHeadingStatesByLegID[legID], state.isEditing else { return }
        state.commits.append(.init(degrees: state.draftDegrees))
        state.isEditing = false
        pilotHeadingStatesByLegID[legID] = state
    }

    mutating func cancelPilotHeadingEditing() {
        guard legState == .active else { return }
        let legID = legIDs[activeLegIndex]
        guard var state = pilotHeadingStatesByLegID[legID], state.isEditing else { return }
        if state.commits.isEmpty {
            pilotHeadingStatesByLegID.removeValue(forKey: legID)
        } else {
            state.draftDegrees = state.operationalDegrees
            state.isEditing = false
            pilotHeadingStatesByLegID[legID] = state
        }
    }

    func pilotHeadingState(for legID: UUID) -> PilotHeadingState? {
        pilotHeadingStatesByLegID[legID]
    }

    private func canRevisePilotETA(targetKey: NavigationTimingTargetKey) -> Bool {
        if let departure = activePartwayDeparture, targetKey.legID == departure.departure.legID {
            switch targetKey.kind {
            case .destination:
                guard targetKey.targetID == departure.departureStop?.id else { return false }
            case .identificationPoint:
                guard departure.retainedDeparturePointIDs.contains(targetKey.targetID) else { return false }
            }
        }
        guard targetKey.kind == .identificationPoint else {
            return legTimings.first(where: { $0.legID == targetKey.legID })?.actualElapsedDuration == nil
        }
        return identificationPointState(for: IdentificationPointKey(
            legID: targetKey.legID,
            identificationPointID: targetKey.targetID
        )) == .future
    }

    mutating func activateAmendment(
        id: UUID, expectedLegID: UUID, targetID: UUID, at timestamp: Date,
        replaying recorded: ActivatedRouteAmendment.Departure? = nil
    ) throws -> ActivatedRouteAmendment.Departure {
        guard let amendment = pendingRouteAmendment, amendment.id == id,
              let firstLeg = amendment.replacementLegs.first, firstLeg.from.id == targetID,
              activeLegID == expectedLegID else {
            throw PendingRouteAmendment.Validation.unavailableDeparture
        }
        let immediate = amendment.startsImmediately == true
        let recordsArrival = !immediate && !amendment.departureIsPartway
        let sourceElapsed: TimeInterval?
        if legState == .active {
            let departureOnActiveLeg = amendment.departure.legID == activeLegID
            guard departureOnActiveLeg || immediate else {
                throw PendingRouteAmendment.Validation.unavailableDeparture
            }
            let retainedKeys = departureOnActiveLeg ? amendment.retainedDeparturePointIDs.map {
                IdentificationPointKey(legID: expectedLegID, identificationPointID: $0)
            } : []
            try finishActiveLeg(orderedActiveLegPointKeys: retainedKeys, at: timestamp, recordsArrival: recordsArrival)
            sourceElapsed = legTimings.last?.actualElapsedDuration
        } else if legState == .ready, immediate {
            sourceElapsed = nil
        } else {
            throw TransitionError.legNotActive
        }
        let firstReplacement = activeLegIndex + (legState == .active ? 1 : 0)
        let startsReplacement = immediate || progressionPolicy == .automaticNextLeg
        var departure = ActivatedRouteAmendment.Departure(
            amendmentID: amendment.id, sourceLegID: expectedLegID, targetID: targetID,
            firstReplacementLegID: firstLeg.id, startsReplacement: startsReplacement,
            sourceElapsedSeconds: sourceElapsed, recordedOriginalArrival: recordsArrival
        )
        if let recorded {
            guard departure.matches(recorded) else { throw PendingRouteAmendment.Validation.invalidGeometry }
            departure = recorded
            if let elapsed = recorded.sourceElapsedSeconds,
               let index = legTimings.lastIndex(where: { $0.legID == expectedLegID }) {
                legTimings[index].recordedDepartureElapsed = elapsed
            }
        } else if let sourceElapsed, let index = legTimings.lastIndex(where: { $0.legID == expectedLegID }) {
            legTimings[index].recordedDepartureElapsed = sourceElapsed
        }
        activatedRouteAmendment = .init(
            amendment: amendment, departure: departure, departedAt: timestamp,
            replacementStartIndex: firstReplacement
        )
        pendingRouteAmendment = nil
        pendingDepartureIdentifiedAt = nil
        activeLegIndex = firstReplacement
        legState = .ready
        if startsReplacement { try startLeg(at: timestamp) }
        return departure
    }

    mutating func reachCurrentWaypoint(
        orderedActiveLegPointKeys: [IdentificationPointKey] = [],
        at timestamp: Date
    ) throws {
        if pendingRouteAmendment?.blocksArrival(at: activeLegIndex) == true {
            throw PendingRouteAmendment.Validation.departureRequiresAmendmentActivation
        }
        if awaitsAmendmentRejoin { throw TransitionError.amendmentRejoinUnavailable }
        try finishActiveLeg(orderedActiveLegPointKeys: orderedActiveLegPointKeys, at: timestamp, recordsArrival: true)
        guard activeLegIndex + 1 < legIDs.count else {
            legState = .completed
            return
        }
        activeLegIndex += 1
        legState = .ready
        if progressionPolicy == .automaticNextLeg { try startLeg(at: timestamp) }
    }

    private mutating func finishActiveLeg(
        orderedActiveLegPointKeys: [IdentificationPointKey], at timestamp: Date, recordsArrival: Bool
    ) throws {
        guard legState == .active else {
            if legTimings.first(where: { $0.legIndex == activeLegIndex })?.reachedAt != nil {
                throw TransitionError.waypointAlreadyReached(activeLegIndex)
            }
            throw TransitionError.legNotActive
        }
        guard let timingIndex = legTimings.firstIndex(where: { $0.legIndex == activeLegIndex }) else {
            throw TransitionError.legNotActive
        }
        let current = legTimings[timingIndex]
        guard current.reachedAt == nil else {
            throw TransitionError.waypointAlreadyReached(activeLegIndex)
        }
        guard timestamp >= current.startedAt else { throw TransitionError.timestampPrecedesStart }

        let activeLegID = legIDs[activeLegIndex]
        guard orderedActiveLegPointKeys.allSatisfy({ $0.legID == activeLegID }),
              Set(orderedActiveLegPointKeys).count == orderedActiveLegPointKeys.count else {
            throw TransitionError.invalidIdentificationPointOrder
        }

        var nextIdentificationPointTimings = identificationPointTimings
        var nextETAStates = pilotETAStatesByTargetKey
        for pointKey in orderedActiveLegPointKeys
        where identificationPointState(for: pointKey) == .future {
            nextIdentificationPointTimings.append(
                IdentificationPointTiming(
                    key: pointKey,
                    legIndex: activeLegIndex,
                    outcome: .passedWithoutReport
                )
            )
            closePilotETADraft(
                targetKey: NavigationTimingTargetKey(
                    legID: pointKey.legID,
                    kind: .identificationPoint,
                    targetID: pointKey.identificationPointID
                ),
                in: &nextETAStates
            )
        }
        for destinationTargetKey in Array(nextETAStates.keys)
        where destinationTargetKey.legID == activeLegID && destinationTargetKey.kind == .destination {
            closePilotETADraft(targetKey: destinationTargetKey, in: &nextETAStates)
        }

        legTimings[timingIndex] = LegTiming(
            legID: current.legID,
            legIndex: current.legIndex,
            startedAt: current.startedAt,
            destinationIdentifiedAt: current.destinationIdentifiedAt,
            reachedAt: recordsArrival ? timestamp : nil,
            amendmentDepartureAt: recordsArrival ? nil : timestamp
        )
        identificationPointTimings = nextIdentificationPointTimings
        pilotETAStatesByTargetKey = nextETAStates

        if var headingState = pilotHeadingStatesByLegID[activeLegID] {
            headingState.draftDegrees = headingState.operationalDegrees
            headingState.isEditing = false
            pilotHeadingStatesByLegID[activeLegID] = headingState
        }

    }

    private func closePilotETADraft(
        targetKey: NavigationTimingTargetKey,
        in states: inout [NavigationTimingTargetKey: PilotETAState]
    ) {
        guard var state = states[targetKey] else { return }
        guard let committedSeconds = state.committedSeconds else {
            states.removeValue(forKey: targetKey)
            return
        }
        state.draftSeconds = committedSeconds
        state.isEditing = false
        states[targetKey] = state
    }

    var hasRecordedLegTiming: Bool {
        !legTimings.isEmpty
    }

    var hasIdentificationPointOutcomes: Bool {
        !identificationPointTimings.isEmpty
    }

    var hasNavigationProgress: Bool {
        legState == .completed
            || legTimings.contains { $0.reachedAt != nil }
    }

    var hasCommittedPilotRevisions: Bool {
        pilotETAStatesByTargetKey.values.contains { !$0.commits.isEmpty }
            || pilotHeadingStatesByLegID.values.contains { !$0.commits.isEmpty }
    }

    var hasOpenPilotRevisionDrafts: Bool {
        pilotETAStatesByTargetKey.values.contains(where: \.isEditing)
            || pilotHeadingStatesByLegID.values.contains(where: \.isEditing)
    }

    var hasProtectedPilotWork: Bool {
        hasRecordedLegTiming
            || hasIdentificationPointOutcomes
            || hasNavigationProgress
            || hasCommittedPilotRevisions
            || hasOpenPilotRevisionDrafts
    }

    func elapsedTime(at now: Date) -> TimeInterval? {
        guard legState == .active, let legStartedAt else { return nil }
        return max(0, now.timeIntervalSince(legStartedAt))
    }
}
