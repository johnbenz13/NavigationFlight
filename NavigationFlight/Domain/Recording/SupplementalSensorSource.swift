import Foundation

nonisolated enum SupplementalSensorEvent: Equatable, Sendable {
    case relativeBarometricAltitude(meters: Double, observedAt: Date)
    case deviceHeading(degrees: Double, accuracyDegrees: Double?, observedAt: Date)
}

@MainActor
protocol SupplementalSensorSource: AnyObject {
    func updates() -> AsyncThrowingStream<SupplementalSensorEvent, Error>
}
