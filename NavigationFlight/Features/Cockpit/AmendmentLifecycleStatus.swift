import Foundation

/// A presentation of existing Flight facts, independent of workspace visibility.
enum AmendmentLifecycleStatus: String, Equatable, Sendable {
    case none, incomplete, ready, armed, awaitingStartLeg, flying

    static func project(flight: Flight?, draft: RouteAmendmentDraft?, route: RouteAmendmentRoute?) -> Self {
        if let flight, let activation = flight.activatedRouteAmendment {
            let firstID = activation.amendment.replacementLegs.first?.id
            return flight.legTimings.contains(where: { $0.legID == firstID }) ? .flying : .awaitingStartLeg
        }
        if flight?.pendingRouteAmendment != nil { return .armed }
        guard let draft, draft.hasContent else { return .none }
        if let editor = draft.editor, editor.entry.values == nil { return .incomplete }
        guard let route, let departure = draft.departure, let rejoin = draft.rejoin,
              route.contains(departure), route.contains(rejoin), route.precedes(departure, rejoin) else {
            return .incomplete
        }
        let legs = draft.reviewLegs(on: route)
        return !legs.isEmpty && legs.allSatisfy({ $0.values != nil }) ? .ready : .incomplete
    }

    var title: String {
        switch self {
        case .none: ""
        case .incomplete: "Incomplete draft"
        case .ready: "Ready · not armed"
        case .armed: "Armed · awaiting departure"
        case .awaitingStartLeg: "Armed · awaiting Start leg"
        case .flying: "Flying · read-only"
        }
    }

    var badgeSymbol: String? {
        switch self {
        case .none: nil
        case .incomplete: "circle.fill"
        case .ready: "pause.fill"
        case .armed, .awaitingStartLeg, .flying: "play.fill"
        }
    }
}
