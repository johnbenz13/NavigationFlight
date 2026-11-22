import Foundation

nonisolated enum PreferenceChange: Equatable, Sendable {
    case startChecklist(StartChecklistSelection)
    case showDriftLines(Bool)
    case progression(AppPreferences.Progression)
    case recoveryWindow(AppPreferences.RecoveryWindow)
    case routeAmendmentMode(RouteAmendmentMode)

    var key: String {
        switch self {
        case .startChecklist: "cockpit.startChecklist"
        case .showDriftLines: "cockpit.showDriftLines"
        case .progression: "cockpit.progression"
        case .recoveryWindow: "recording.recoveryWindowSeconds"
        case .routeAmendmentMode: "cockpit.routeAmendmentMode"
        }
    }
}
