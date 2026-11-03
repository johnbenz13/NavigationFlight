import Foundation
import Testing
@testable import NavigationFlight

struct PositionCheckRecoveryPresentationTests {
    private let adapter = CockpitPresentationAdapter()

    @Test("Guidance uses magnetic-course terminology and pilot-friendly rounding")
    func guidanceFormatting() {
        let recovery = adapter.makeRecoveryPresentation(.guidance(guidance(course: 4.6, seconds: 79, distance: 1.24)))
        #expect(recovery == .guidance(course: "005°M", time: "~1:20", distance: "1.2 NM"))
    }

    @Test("Every unavailable reason maps to an approved structured display state")
    func unavailableExplanations() {
        #expect(adapter.makeRecoveryPresentation(.unavailable(.insufficientMovementQuality)) == .positionOnly)
        #expect(adapter.makeRecoveryPresentation(.unavailable(.activeLegPassed)) == .noSensibleIntercept("Active leg passed — review flight plan"))
        #expect(adapter.makeRecoveryPresentation(.unavailable(.insufficientRemainingLeg)) == .noSensibleIntercept("No sensible forward intercept remains"))
        #expect(adapter.makeRecoveryPresentation(.unavailable(.extremeDisplacement)) == .extremeDisplacement)
        #expect(adapter.makeRecoveryPresentation(.onTrack) == .onTrack)
    }

    @Test("Only guidance creates recovery map geometry")
    func mapGeometryEligibility() {
        let projection = PositionCheckProjection(sample: sample())
        let guidanceOverlay = GPSDisclosureOverlay(projection: projection, recoveryOutcome: .guidance(guidance(course: 64, seconds: 80, distance: 1.1)))
        let positionOnlyOverlay = GPSDisclosureOverlay(projection: projection, recoveryOutcome: .unavailable(.insufficientMovementQuality))
        #expect(guidanceOverlay.recoverySegment != nil)
        #expect(guidanceOverlay.interceptCoordinate != nil)
        #expect(positionOnlyOverlay.recoverySegment == nil)
        #expect(positionOnlyOverlay.interceptCoordinate == nil)
    }

    @Test("An unusable fix clears an active disclosure without ending its timer")
    func unusableFixClearsDisclosure() {
        let active = PositionCheckState.idle.transition(
            .holdCompleted(availability: .ready(sample()), restoration: .empty),
            now: .zero
        ).state

        let presentation = adapter.makePositionCheckPresentation(
            for: .unavailable(.signalLost),
            state: active,
            remainingSeconds: 7,
            recoveryOutcome: .guidance(guidance(course: 64, seconds: 80, distance: 1.1))
        )

        #expect(presentation.disclosedPosition == nil)
        #expect(presentation.recovery == nil)
        #expect(presentation.explanation == "GPS signal lost; stale overlays were cleared.")
    }

    private func guidance(course: Double, seconds: Double, distance: Double) -> RecoveryGuidance {
        RecoveryGuidance(magneticCourseDegrees: course, rejoinTimeSeconds: seconds, distanceNauticalMiles: distance, interceptCoordinate: WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.9), interceptAngleDegrees: 20)
    }

    private func sample() -> AircraftLocationSample {
        AircraftLocationSample(coordinate: WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.8), observedAt: Date(timeIntervalSince1970: 1_000), horizontalAccuracyMeters: 20, trueCourseDegrees: 72, courseAccuracyDegrees: 5, groundSpeedMetersPerSecond: 50, speedAccuracyMetersPerSecond: 1)
    }
}
