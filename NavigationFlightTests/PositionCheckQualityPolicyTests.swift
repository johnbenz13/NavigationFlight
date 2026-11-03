import Foundation
import Testing
@testable import NavigationFlight

@Suite("Position Check quality policy")
struct PositionCheckQualityPolicyTests {
    @Test("A fix exactly five seconds old remains position eligible")
    func exactAgeBoundaryIsEligible() {
        let now = Date(timeIntervalSince1970: 1_000)
        let sample = AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32.0, longitudeDegrees: 34.8),
            observedAt: now.addingTimeInterval(-5),
            horizontalAccuracyMeters: 100,
            trueCourseDegrees: 90,
            courseAccuracyDegrees: 20,
            groundSpeedMetersPerSecond: 5,
            speedAccuracyMetersPerSecond: 0
        )

        let result = PositionCheckQualityPolicy().classify(
            sample,
            receivedAt: now,
            lastAcceptedObservation: nil
        )

        #expect(result.position == .eligible)
    }

    @Test("A fix older than five seconds is stale")
    func olderFixIsStale() {
        let now = Date(timeIntervalSince1970: 1_000)
        let sample = sample(observedAt: now.addingTimeInterval(-5.001))

        let result = PositionCheckQualityPolicy().classify(
            sample,
            receivedAt: now,
            lastAcceptedObservation: nil
        )

        #expect(result.position == .ineligible(.stale))
    }

    @Test("Horizontal accuracy must be positive and no greater than 100 metres", arguments: [
        (-1.0, PositionCheckQuality.PositionEligibility.ineligible(.invalidAccuracy)),
        (0.0, .ineligible(.invalidAccuracy)),
        (0.001, .eligible),
        (100.0, .eligible),
        (100.001, .ineligible(.insufficientAccuracy))
    ])
    func horizontalAccuracyBoundary(
        accuracy: Double,
        expected: PositionCheckQuality.PositionEligibility
    ) {
        let now = Date(timeIntervalSince1970: 1_000)
        let result = PositionCheckQualityPolicy().classify(
            sample(observedAt: now, horizontalAccuracyMeters: accuracy),
            receivedAt: now,
            lastAcceptedObservation: nil
        )

        #expect(result.position == expected)
    }

    @Test("A fix older than the last accepted observation is rejected as out of order")
    func outOfOrderFixIsRejected() {
        let now = Date(timeIntervalSince1970: 1_000)
        let result = PositionCheckQualityPolicy().classify(
            sample(observedAt: now.addingTimeInterval(-1)),
            receivedAt: now,
            lastAcceptedObservation: now
        )

        #expect(result.position == .ineligible(.outOfOrder))
    }

    @Test("Position eligibility is independent from movement guidance")
    func positionCanBeEligibleWithoutGuidance() {
        let now = Date(timeIntervalSince1970: 1_000)
        let result = PositionCheckQualityPolicy().classify(
            sample(
                observedAt: now,
                trueCourseDegrees: -1,
                courseAccuracyDegrees: 21,
                groundSpeedMetersPerSecond: 4.999,
                speedAccuracyMetersPerSecond: -1
            ),
            receivedAt: now,
            lastAcceptedObservation: nil
        )

        #expect(result.position == .eligible)
        #expect(result.guidance == .ineligible)
    }

    private func sample(
        observedAt: Date,
        horizontalAccuracyMeters: Double = 100,
        trueCourseDegrees: Double? = 90,
        courseAccuracyDegrees: Double? = 20,
        groundSpeedMetersPerSecond: Double? = 5,
        speedAccuracyMetersPerSecond: Double? = 0
    ) -> AircraftLocationSample {
        AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32.0, longitudeDegrees: 34.8),
            observedAt: observedAt,
            horizontalAccuracyMeters: horizontalAccuracyMeters,
            trueCourseDegrees: trueCourseDegrees,
            courseAccuracyDegrees: courseAccuracyDegrees,
            groundSpeedMetersPerSecond: groundSpeedMetersPerSecond,
            speedAccuracyMetersPerSecond: speedAccuracyMetersPerSecond
        )
    }
}
