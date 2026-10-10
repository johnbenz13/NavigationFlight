import Foundation

struct NavigationFlight: Equatable, Sendable {
    let id: UUID
    let title: String
    let createdAt: Date
    let modifiedAt: Date
    let parameters: NavigationParameters
    /// Waypoints in the authoritative route order.
    let waypoints: [RouteWaypoint]
    /// Legs in the authoritative serialized order, with resolved endpoints.
    let legs: [NavigationLeg]
    let identificationPoints: [IdentificationPoint]
    let altitudeChanges: [AltitudeChange]
    let frequencyChanges: [FrequencyChange]
    let vorDmeReferences: [VORDMEReference]
    let operationalContext: OperationalContext
}
