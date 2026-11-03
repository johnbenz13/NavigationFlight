import Foundation
import Testing
@testable import NavigationFlight

struct ActiveLegRecoveryCalculatorTests {
    @Test("Position inside the uncertainty corridor is on track")
    func uncertaintyCorridorReturnsOnTrack() {
        let outcome = ActiveLegRecoveryCalculator().calculate(
            sample: sample(latitude: 32.0, longitude: 34.8, accuracyMeters: 200),
            legStart: WGS84Coordinate(latitudeDegrees: 32.0, longitudeDegrees: 34.7),
            legEnd: WGS84Coordinate(latitudeDegrees: 32.0, longitudeDegrees: 35.0),
            importedMagneticCourseDegrees: 90
        )

        #expect(outcome == .onTrack)
    }

    @Test("Accuracy expands the practical on-track corridor")
    func accuracyExpandsCorridor() {
        let legStart = WGS84Coordinate(latitudeDegrees: 0, longitudeDegrees: 0)
        let legEnd = WGS84Coordinate(latitudeDegrees: 0, longitudeDegrees: 0.2)
        let fixed = ActiveLegRecoveryCalculator().calculate(
            sample: sample(latitude: 0.00355, longitude: 0.05, accuracyMeters: 5),
            legStart: legStart, legEnd: legEnd, importedMagneticCourseDegrees: 90
        )
        let expanded = ActiveLegRecoveryCalculator().calculate(
            sample: sample(latitude: 0.00355, longitude: 0.05, accuracyMeters: 200),
            legStart: legStart, legEnd: legEnd, importedMagneticCourseDegrees: 90
        )
        #expect(expanded == .onTrack)
        if case .guidance = fixed {} else { Issue.record("Expected guidance outside the fixed corridor") }
    }

    @Test("Left and right deviations receive shallow forward intercepts")
    func shallowForwardInterceptsOnBothSides() {
        for latitude in [-0.01, 0.01] {
            let guidance = guidance(latitude: latitude, longitude: 0.05, speed: 100)
            #expect(abs(guidance.interceptAngleDegrees - 20) < 0.5)
            #expect(guidance.interceptCoordinate.longitudeDegrees > 0.05)
            #expect(guidance.interceptAngleDegrees < 45.01)
        }
    }

    @Test("Cross-track time selects interpolated and maximum intercept angles")
    func interceptAngleSelection() {
        let interpolated = guidance(latitude: 0.01, longitude: 0.05, speed: 15)
        let maximum = guidance(latitude: 0.01, longitude: 0.05, speed: 5)
        #expect(interpolated.interceptAngleDegrees > 20)
        #expect(interpolated.interceptAngleDegrees < 45)
        #expect(abs(maximum.interceptAngleDegrees - 45) < 0.5)
    }

    @Test("Endpoint is used only as a bounded forward intercept")
    func endpointFallbackAndRejection() {
        let fallback = guidance(latitude: 0.005, longitude: 0.19, speed: 50)
        #expect(abs(fallback.interceptCoordinate.longitudeDegrees - 0.2) < 0.001)
        let rejected = outcome(latitude: 0.02, longitude: 0.19, speed: 50)
        #expect(rejected == .unavailable(.insufficientRemainingLeg))
    }

    @Test("Passed legs and extreme displacement never invent guidance")
    func passedAndExtremeOutcomes() {
        #expect(outcome(latitude: 0.01, longitude: 0.25, speed: 50) == .unavailable(.activeLegPassed))
        #expect(outcome(latitude: 0.25, longitude: 0.05, speed: 50) == .unavailable(.extremeDisplacement))
    }

    @Test("Magnetic conversion normalizes across north and rejoin time uses current groundspeed")
    func magneticNormalizationAndTime() {
        let outcome = ActiveLegRecoveryCalculator().calculate(
            sample: sample(latitude: -0.01, longitude: 0.05, accuracyMeters: 5, groundSpeedMetersPerSecond: 50),
            legStart: WGS84Coordinate(latitudeDegrees: 0, longitudeDegrees: 0),
            legEnd: WGS84Coordinate(latitudeDegrees: 0, longitudeDegrees: 0.2),
            importedMagneticCourseDegrees: 350
        )
        guard case .guidance(let guidance) = outcome else {
            Issue.record("Expected guidance")
            return
        }
        #expect(guidance.magneticCourseDegrees >= 0 && guidance.magneticCourseDegrees < 360)
        #expect(abs(guidance.rejoinTimeSeconds - guidance.distanceNauticalMiles * 1_852 / 50) < 0.01)
    }

    @Test("Insufficient movement suppresses guidance without suppressing position eligibility")
    func insufficientMovementSuppressesGuidance() {
        #expect(outcome(latitude: 0.01, longitude: 0.05, speed: nil) == .unavailable(.insufficientMovementQuality))
    }

    private func outcome(latitude: Double, longitude: Double, speed: Double?) -> ActiveLegRecoveryOutcome {
        ActiveLegRecoveryCalculator().calculate(
            sample: sample(latitude: latitude, longitude: longitude, accuracyMeters: 5, groundSpeedMetersPerSecond: speed),
            legStart: WGS84Coordinate(latitudeDegrees: 0, longitudeDegrees: 0),
            legEnd: WGS84Coordinate(latitudeDegrees: 0, longitudeDegrees: 0.2),
            importedMagneticCourseDegrees: 90
        )
    }

    private func guidance(latitude: Double, longitude: Double, speed: Double) -> RecoveryGuidance {
        let result = outcome(latitude: latitude, longitude: longitude, speed: speed)
        guard case .guidance(let guidance) = result else {
            Issue.record("Expected recovery guidance, got \(result)")
            return RecoveryGuidance(
                magneticCourseDegrees: 0, rejoinTimeSeconds: 0, distanceNauticalMiles: 0,
                interceptCoordinate: WGS84Coordinate(latitudeDegrees: 0, longitudeDegrees: 0),
                interceptAngleDegrees: 0
            )
        }
        return guidance
    }

    private func sample(
        latitude: Double,
        longitude: Double,
        accuracyMeters: Double,
        trueCourseDegrees: Double? = 90,
        groundSpeedMetersPerSecond: Double? = 50
    ) -> AircraftLocationSample {
        AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: latitude, longitudeDegrees: longitude),
            observedAt: Date(timeIntervalSince1970: 1_000),
            horizontalAccuracyMeters: accuracyMeters,
            trueCourseDegrees: trueCourseDegrees,
            courseAccuracyDegrees: 5,
            groundSpeedMetersPerSecond: groundSpeedMetersPerSecond,
            speedAccuracyMetersPerSecond: 1
        )
    }
}
