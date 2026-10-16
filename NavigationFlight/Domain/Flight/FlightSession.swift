import Foundation

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

    let flightID: UUID
    let legIDs: [UUID]
    let progressionPolicy: ProgressionPolicy
    private(set) var activeLegIndex: Int
    private(set) var executionMode: NavigationMode
    private(set) var legState: LegState
    private(set) var legTimings: [LegTiming]

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
