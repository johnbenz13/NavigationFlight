import Foundation

struct FlightPlanInspectionPresentation: Equatable, Sendable {
    struct PresentedAction: Equatable, Sendable {
        enum Role: Equatable, Sendable {
            case standard
            case destructive
        }

        let action: Action
        let label: String
        let consequence: String?
        let role: Role
    }

    enum Action: Hashable, Sendable {
        case loadInCockpit
        case returnToCockpit
        case loadUpdatedPlan
        case restartFlight
    }

    let primaryAction: PresentedAction
    let updateActions: [PresentedAction]
    let flightActionsTitle = "Flight Actions"
    let flightActions: [PresentedAction]

    init(inspected: LibraryFlightPlan, loadedFlightPlan: FlightPlan?) {
        if let loadedFlightPlan, inspected.id == loadedFlightPlan.id {
            primaryAction = PresentedAction(
                action: .returnToCockpit,
                label: "Continue to Cockpit",
                consequence: "Keeps the current Flight and returns to the cockpit without changing timing or progress.",
                role: .standard
            )
            updateActions = inspected.flightPlan.modifiedAt == loadedFlightPlan.modifiedAt
                ? []
                : [PresentedAction(
                    action: .loadUpdatedPlan,
                    label: "Load Updated Plan",
                    consequence: nil,
                    role: .standard
                )]
            flightActions = [PresentedAction(
                action: .restartFlight,
                label: "Restart Flight…",
                consequence: "Creates a new ready Flight from this Flight Plan. Existing progress or edits require confirmation.",
                role: .destructive
            )]
        } else {
            primaryAction = PresentedAction(
                action: .loadInCockpit,
                label: "Load in Cockpit",
                consequence: nil,
                role: .standard
            )
            updateActions = []
            flightActions = []
        }
    }
}
