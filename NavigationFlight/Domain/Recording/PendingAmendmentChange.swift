import Foundation

nonisolated enum PendingAmendmentChange: Equatable, Sendable {
    case replace(expectedPendingID: UUID, amendment: PendingRouteAmendment)
    case cancel(expectedPendingID: UUID)
    case reportOriginalDestination(PendingAmendmentOriginalDestination, reachEventID: UUID, automaticEventID: UUID)

    var expectedPendingID: UUID {
        switch self {
        case .replace(let id, _), .cancel(let id): id
        case .reportOriginalDestination(let report, _, _): report.amendmentID
        }
    }

    var eventPayload: RecordedFlightEventPayload {
        switch self {
        case .replace(let id, let amendment): .pendingRouteAmendmentReplaced(previousID: id, amendment: amendment)
        case .cancel(let id): .pendingRouteAmendmentCancelled(amendmentID: id, originalDestination: nil, linkedReachEventID: nil)
        case .reportOriginalDestination(let destination, let reachID, _):
            .pendingRouteAmendmentCancelled(
                amendmentID: destination.amendmentID, originalDestination: destination, linkedReachEventID: reachID
            )
        }
    }

    func eventIDs(startingWith operationID: UUID) -> [UUID] {
        switch self {
        case .replace, .cancel: [operationID]
        case .reportOriginalDestination(_, let reachID, let automaticID): [operationID, reachID, automaticID]
        }
    }
}
