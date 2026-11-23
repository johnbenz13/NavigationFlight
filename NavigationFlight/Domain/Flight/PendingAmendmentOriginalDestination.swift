import Foundation

nonisolated struct PendingAmendmentOriginalDestination: Codable, Equatable, Sendable {
    let amendmentID: UUID
    let legID: UUID
    let targetID: UUID
}
