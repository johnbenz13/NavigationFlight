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

    enum TransitionError: Error, Equatable, Sendable {
        case invalidLegIndex(Int)
        case legNotReady
        case legNotActive
        case legAlreadyStarted(Int)
        case destinationAlreadyIdentified(Int)
        case waypointAlreadyReached(Int)
        case identificationPointAlreadyReached(UUID)
        case timestampPrecedesStart
        case finalLegCompleted
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
        let key: IdentificationPointKey
        let legIndex: Int
        let reachedAt: Date

        var identificationPointID: UUID { key.identificationPointID }
        var legID: UUID { key.legID }

        func actualLegElapsedDuration(startedAt: Date) -> TimeInterval {
            reachedAt.timeIntervalSince(startedAt)
        }
    }

    struct PilotETAState: Equatable, Sendable {
        var draftSeconds: Int
        var committedSeconds: Int?
        var isEditing: Bool
        var isCheckResultVisible: Bool
        let timingObservationKey: IdentificationPointKey?
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

    mutating func reachIdentificationPoint(key: IdentificationPointKey, at timestamp: Date) throws {
        guard legState == .active, let startedAt = legStartedAt else {
            throw TransitionError.legNotActive
        }
        guard key.legID == legIDs[activeLegIndex] else { throw TransitionError.legNotActive }
        guard identificationPointTimings.allSatisfy({ $0.key != key }) else {
            throw TransitionError.identificationPointAlreadyReached(key.identificationPointID)
        }
        guard timestamp >= startedAt else { throw TransitionError.timestampPrecedesStart }
        identificationPointTimings.append(
            IdentificationPointTiming(
                key: key,
                legIndex: activeLegIndex,
                reachedAt: timestamp
            )
        )
    }

    func identificationPointTiming(for key: IdentificationPointKey) -> IdentificationPointTiming? {
        identificationPointTimings.first { $0.key == key }
    }

    func actualLegElapsedDuration(atIdentificationPoint key: IdentificationPointKey) -> TimeInterval? {
        guard let record = identificationPointTiming(for: key),
              let legTiming = legTimings.first(where: { $0.legID == record.legID }) else { return nil }
        return record.actualLegElapsedDuration(startedAt: legTiming.startedAt)
    }

    mutating func initializePilotETA(
        targetKey: NavigationTimingTargetKey,
        plannedElapsedSeconds: Int,
        timingObservationKey: IdentificationPointKey? = nil
    ) {
        guard plannedElapsedSeconds >= 0, pilotETAStatesByTargetKey[targetKey] == nil else { return }
        pilotETAStatesByTargetKey[targetKey] = PilotETAState(
            draftSeconds: IdentificationPointTimingCalculator.roundToNearestFiveSeconds(plannedElapsedSeconds),
            committedSeconds: nil,
            isEditing: true,
            isCheckResultVisible: false,
            timingObservationKey: timingObservationKey
        )
    }

    mutating func adjustPilotETA(targetKey: NavigationTimingTargetKey, by deltaSeconds: Int) {
        guard var state = pilotETAStatesByTargetKey[targetKey], state.isEditing else { return }
        state.draftSeconds = max(0, state.draftSeconds + deltaSeconds)
        pilotETAStatesByTargetKey[targetKey] = state
    }

    mutating func commitPilotETA(targetKey: NavigationTimingTargetKey) {
        guard var state = pilotETAStatesByTargetKey[targetKey] else { return }
        state.committedSeconds = state.draftSeconds
        state.isEditing = false
        state.isCheckResultVisible = false
        pilotETAStatesByTargetKey[targetKey] = state
    }

    mutating func beginEditingPilotETA(targetKey: NavigationTimingTargetKey) {
        guard var state = pilotETAStatesByTargetKey[targetKey],
              let committed = state.committedSeconds else { return }
        state.draftSeconds = committed
        state.isEditing = true
        state.isCheckResultVisible = false
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

    mutating func reachCurrentWaypoint(at timestamp: Date) throws {
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

        legTimings[timingIndex] = LegTiming(
            legID: current.legID,
            legIndex: current.legIndex,
            startedAt: current.startedAt,
            destinationIdentifiedAt: current.destinationIdentifiedAt,
            reachedAt: timestamp
        )

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

    func elapsedTime(at now: Date) -> TimeInterval? {
        guard legState == .active, let legStartedAt else { return nil }
        return max(0, now.timeIntervalSince(legStartedAt))
    }
}
