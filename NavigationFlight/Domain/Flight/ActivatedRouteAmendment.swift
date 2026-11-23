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

    struct Rejoin: Codable, Equatable, Sendable {
        let amendmentID: UUID
        let replacementLegID: UUID
        let targetID: UUID
        let retainedLegID: UUID?
        let startsRetainedLeg: Bool
    }

    var retainedStartIndex: Int { replacementStartIndex + amendment.replacementLegs.count }
    var retainedSourceStartIndex: Int { amendment.rejoin.legIndex + (amendment.rejoin.fraction == 1 ? 1 : 0) }

    // The confirmation ID is reserved as the new timing identity for an interior split.
    var splitLegID: UUID? {
        (0 < amendment.rejoin.fraction && amendment.rejoin.fraction < 1) ? amendment.id : nil
    }

    func retainedLegIDs(in sourceLegIDs: [UUID]) -> [UUID] {
        var ids = Array(sourceLegIDs.dropFirst(retainedSourceStartIndex))
        if let splitLegID, !ids.isEmpty { ids[0] = splitLegID }
        return ids
    }

    let amendment: PendingRouteAmendment
    let departure: Departure
    let departedAt: Date
    let replacementStartIndex: Int
}
