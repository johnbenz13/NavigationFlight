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

struct FlightSession: Equatable, Sendable {
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
            }
        }
    }

    struct LegTiming: Equatable, Sendable {
        let legID: UUID
        let legIndex: Int
        let startedAt: Date
        let destinationIdentifiedAt: Date?
        let reachedAt: Date?

        var actualElapsedDuration: TimeInterval? {
            reachedAt.map { $0.timeIntervalSince(startedAt) }
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
    }

    struct PilotETAState: Equatable, Sendable {
        struct Commit: Equatable, Sendable {
            let seconds: Int
        }

        var draftSeconds: Int
        var commits: [Commit]
        var isEditing: Bool
        var isCheckResultVisible: Bool
        var validationError: PilotETAError?
        let timingObservationKey: IdentificationPointKey?

        var committedSeconds: Int? { commits.last?.seconds }
    }

    enum PilotETAError: Error, Equatable, Sendable {
        case staleDraft(minimumSeconds: Int)
    }

    let flightID: UUID
    let legIDs: [UUID]
    let progressionPolicy: ProgressionPolicy
    private(set) var activeLegIndex: Int
    private(set) var executionMode: NavigationMode
    private(set) var legState: LegState
    private(set) var legTimings: [LegTiming]
    private(set) var identificationPointTimings: [IdentificationPointTiming]
    private(set) var pilotETAStatesByTargetKey: [NavigationTimingTargetKey: PilotETAState]

    var legStartedAt: Date? {
        legTimings.first { $0.legIndex == activeLegIndex }?.startedAt
    }

    var destinationIdentifiedAt: Date? {
        legTimings.first { $0.legIndex == activeLegIndex }?.destinationIdentifiedAt
    }

    init(
        flightID: UUID,
        legIDs: [UUID],
        activeLegIndex: Int,
        executionMode: NavigationMode,
        progressionPolicy: ProgressionPolicy = .automaticNextLeg
    ) {
        precondition(legIDs.indices.contains(activeLegIndex), "Active leg index must be in the plan")
        self.flightID = flightID
        self.legIDs = legIDs
        self.activeLegIndex = activeLegIndex
        self.executionMode = executionMode
        self.progressionPolicy = progressionPolicy
        self.legState = .ready
        self.legTimings = []
        self.identificationPointTimings = []
        self.pilotETAStatesByTargetKey = [:]
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

    mutating func initializePilotETA(
        targetKey: NavigationTimingTargetKey,
        plannedElapsedSeconds: Int,
        currentElapsedSeconds: Int = 0,
        timingObservationKey: IdentificationPointKey? = nil
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
            timingObservationKey: timingObservationKey
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

    mutating func showPilotETACheck(targetKey: NavigationTimingTargetKey) {
        guard var state = pilotETAStatesByTargetKey[targetKey], state.committedSeconds != nil else { return }
        state.isCheckResultVisible = true
        pilotETAStatesByTargetKey[targetKey] = state
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

    private func canRevisePilotETA(targetKey: NavigationTimingTargetKey) -> Bool {
        guard targetKey.kind == .identificationPoint else {
            return legTimings.first(where: { $0.legID == targetKey.legID })?.reachedAt == nil
        }
        return identificationPointState(for: IdentificationPointKey(
            legID: targetKey.legID,
            identificationPointID: targetKey.targetID
        )) == .future
    }

    mutating func reachCurrentWaypoint(
        orderedActiveLegPointKeys: [IdentificationPointKey] = [],
        at timestamp: Date
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
            reachedAt: timestamp
        )
        identificationPointTimings = nextIdentificationPointTimings
        pilotETAStatesByTargetKey = nextETAStates

        guard activeLegIndex + 1 < legIDs.count else {
            legState = .completed
            return
        }

        activeLegIndex += 1
        switch progressionPolicy {
        case .automaticNextLeg:
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
        case .manualNextLeg:
            legState = .ready
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

    func elapsedTime(at now: Date) -> TimeInterval? {
        guard legState == .active, let legStartedAt else { return nil }
        return max(0, now.timeIntervalSince(legStartedAt))
    }
}
