import Foundation

enum IdentificationPointTimingCalculator {
    nonisolated static func roundToNearestFiveSeconds(_ seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        return Int((Double(seconds) / 5).rounded(.toNearestOrAwayFromZero)) * 5
    }

    nonisolated static func roundUpToFiveSeconds(_ seconds: Int) -> Int {
        guard seconds > 0 else { return 0 }
        return ((seconds + 4) / 5) * 5
    }

    nonisolated static func referenceTargetElapsed(
        plannedReachedElapsed: TimeInterval?,
        actualReachedElapsed: TimeInterval?,
        plannedTargetElapsed: TimeInterval?
    ) -> TimeInterval? {
        guard let plannedReachedElapsed,
              let actualReachedElapsed,
              let plannedTargetElapsed,
              plannedReachedElapsed > 0,
              actualReachedElapsed >= 0,
              plannedTargetElapsed >= 0 else { return nil }
        return plannedTargetElapsed * actualReachedElapsed / plannedReachedElapsed
    }

    nonisolated static func displaySeconds(_ elapsed: TimeInterval) -> Int {
        max(0, Int(elapsed.rounded(.toNearestOrAwayFromZero)))
    }
}
