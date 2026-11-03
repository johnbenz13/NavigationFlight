import Foundation
import Testing
@testable import NavigationFlight

@Suite("Position Check readiness presentation")
struct PositionCheckReadinessPresentationTests {
    @Test("Ready presentation is hold eligible and uses text plus a symbol")
    func readyPresentation() {
        let sample = AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32, longitudeDegrees: 34.8),
            observedAt: Date(timeIntervalSince1970: 1_000),
            horizontalAccuracyMeters: 50,
            trueCourseDegrees: nil,
            courseAccuracyDegrees: nil,
            groundSpeedMetersPerSecond: nil,
            speedAccuracyMetersPerSecond: nil
        )

        let presentation = CockpitPresentationAdapter().makePositionCheckPresentation(for: .ready(sample))

        #expect(presentation.status == .ready)
        #expect(presentation.statusLabel == "READY")
        #expect(presentation.detail == "GPS Ready · Hold 1 sec")
        #expect(presentation.isHoldEligible)
        #expect(!presentation.systemImage.isEmpty)
    }

    @Test("Structured unavailable causes retain a specific explanation", arguments: [
        (LocationUnavailabilityReason.servicesDisabled, "Location Services are disabled"),
        (.signalLost, "GPS signal is temporarily unavailable"),
        (.stale, "The latest GPS position is stale"),
        (.invalidAccuracy, "GPS reported invalid accuracy"),
        (.insufficientAccuracy, "GPS accuracy is insufficient"),
        (.outOfOrder, "An older GPS position was ignored"),
        (.sourceFailure, "GPS is unavailable")
    ])
    func unavailableReasons(reason: LocationUnavailabilityReason, explanation: String) {
        let presentation = CockpitPresentationAdapter().makePositionCheckPresentation(
            for: .unavailable(reason)
        )

        #expect(presentation.status == .unavailable)
        #expect(presentation.explanation == explanation)
        #expect(presentation.remedy == "Try again")
        #expect(!presentation.isHoldEligible)
    }

    @Test("Permission presentation distinguishes denied from restricted")
    func permissionReasons() {
        let denied = CockpitPresentationAdapter().makePositionCheckPresentation(
            for: .permissionRequired(.denied)
        )
        let restricted = CockpitPresentationAdapter().makePositionCheckPresentation(
            for: .permissionRequired(.restricted)
        )

        #expect(denied.statusLabel == "PERMISSION REQUIRED")
        #expect(denied.remedy == "Open Settings")
        #expect(denied.explanation != restricted.explanation)
        #expect(denied.detail.contains("manual navigation remains available"))
    }

    @Test("Signal loss presentation contains no disclosed values and offers dismissal")
    func signalLossPresentation() {
        let presentation = CockpitPresentationAdapter().makePositionCheckPresentation(
            for: .unavailable(.signalLost),
            state: .transientFailure(.signalLost),
            remainingSeconds: nil
        )

        #expect(presentation.status == .signalLost)
        #expect(presentation.statusLabel == "GPS LOST")
        #expect(presentation.title == "GPS signal lost")
        #expect(presentation.detail == "Position and guidance cleared; cockpit context restored")
        #expect(presentation.remedy == "Dismiss")
        #expect(presentation.disclosedPosition == nil)
        #expect(presentation.recovery == nil)
    }
}
