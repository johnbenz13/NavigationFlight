import Foundation

struct FlightSession: Equatable, Sendable {
    enum LegState: Equatable, Sendable {
        case ready
        case active
    }

    let flightID: UUID
    private(set) var activeLegIndex: Int
    private(set) var executionMode: NavigationMode
    private(set) var legState: LegState
    private(set) var legStartedAt: Date?

    init(
        flightID: UUID,
        activeLegIndex: Int,
        executionMode: NavigationMode
    ) {
        self.flightID = flightID
        self.activeLegIndex = activeLegIndex
        self.executionMode = executionMode
        self.legState = .ready
        self.legStartedAt = nil
    }

    mutating func selectReadyLeg(index: Int, mode: NavigationMode) {
        guard legState == .ready else { return }
        activeLegIndex = index
        executionMode = mode
    }

    @discardableResult
    mutating func startLeg(at timestamp: Date) -> Bool {
        guard legState == .ready, legStartedAt == nil else { return false }
        legStartedAt = timestamp
        legState = .active
        return true
    }

    func elapsedTime(at now: Date) -> TimeInterval? {
        guard let legStartedAt else { return nil }
        return max(0, now.timeIntervalSince(legStartedAt))
    }
}
