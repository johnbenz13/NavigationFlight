import Foundation

struct PendingAmendmentManagement: Equatable {
    struct OriginalDestination: Equatable {
        let report: PendingAmendmentOriginalDestination
        let name: String
    }

    enum Confirmation: Equatable {
        case cancel(UUID)
        case reportOriginalDestination(OriginalDestination)
    }

    enum Intent {
        case replace(UUID)
        case confirm(Confirmation, CockpitRestoration)
        case retry
        case dismissFailedSave
    }

    let id: UUID
    let departureName: String
    let legNumber: Int
    let originalDestination: OriginalDestination?
}
