import Foundation

nonisolated struct ActivatedRouteAmendment: Equatable, Sendable {
    struct Departure: Codable, Equatable, Sendable {
        let amendmentID: UUID
        let sourceLegID: UUID
        let targetID: UUID
        let firstReplacementLegID: UUID
        let startsReplacement: Bool
        let sourceElapsedSeconds: TimeInterval?
        let recordedOriginalArrival: Bool

        func matches(_ recorded: Self) -> Bool {
            guard amendmentID == recorded.amendmentID, sourceLegID == recorded.sourceLegID,
                  targetID == recorded.targetID, firstReplacementLegID == recorded.firstReplacementLegID,
                  startsReplacement == recorded.startsReplacement,
                  recordedOriginalArrival == recorded.recordedOriginalArrival else { return false }
            if let actual = sourceElapsedSeconds, let saved = recorded.sourceElapsedSeconds {
                // The journal stores wall-clock dates at whole-second precision.
                return saved.isFinite && saved >= 0 && abs(actual - saved) < 1
            }
            return sourceElapsedSeconds == recorded.sourceElapsedSeconds
        }
    }

    let amendment: PendingRouteAmendment
    let departure: Departure
    let departedAt: Date
    let replacementStartIndex: Int
}
