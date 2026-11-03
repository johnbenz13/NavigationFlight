import Foundation

struct FlightPlanInspectionPresentation: Equatable, Sendable {
    enum Action: Equatable, Sendable {
        case loadInCockpit
        case returnToCockpit
        case loadUpdatedPlan
        case restartFlight

        var label: String {
            switch self {
            case .loadInCockpit: "Load in Cockpit"
            case .returnToCockpit: "Return to Cockpit"
            case .loadUpdatedPlan: "Load Updated Plan"
            case .restartFlight: "Restart Flight"
            }
        }
    }

    let primaryAction: Action
    let secondaryActions: [Action]

    init(inspected: LibraryFlightPlan, loadedFlightPlan: FlightPlan?) {
        if let loadedFlightPlan, inspected.id == loadedFlightPlan.id {
            primaryAction = .returnToCockpit
            secondaryActions = inspected.flightPlan.modifiedAt == loadedFlightPlan.modifiedAt
                ? [.restartFlight]
                : [.loadUpdatedPlan, .restartFlight]
        } else {
            primaryAction = .loadInCockpit
            secondaryActions = []
        }
    }
}
