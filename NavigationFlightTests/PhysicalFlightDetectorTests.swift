import Foundation
import Testing
@testable import NavigationFlight

@Suite("Physical flight detection")
struct PhysicalFlightDetectorTests {
    @Test("Ground movement requires a sustained candidate window")
    func sustainedGroundMovementStartsProvisionalCapture() {
        var detector = PhysicalFlightDetector(policy: .fixture)

        #expect(detector.process(sample(speed: 4, at: 0), monotonicTime: .seconds(0)).isEmpty)
        #expect(detector.process(sample(speed: 4, at: 4), monotonicTime: .seconds(4)).isEmpty)
        #expect(detector.process(sample(speed: 4, at: 5), monotonicTime: .seconds(5)) == [.groundMovementBegan])
        #expect(detector.state == .groundMovement)
    }

    @Test("Interrupted movement and poor accuracy cancel the candidate")
    func movementCandidateCancellation() {
        var detector = PhysicalFlightDetector(policy: .fixture)

        #expect(detector.process(sample(speed: 4, at: 0), monotonicTime: .seconds(0)).isEmpty)
        #expect(detector.process(sample(speed: 0, at: 3), monotonicTime: .seconds(3)).isEmpty)
        #expect(detector.process(sample(speed: 4, at: 6), monotonicTime: .seconds(6)).isEmpty)
        #expect(detector.process(sample(speed: 4, at: 10, horizontalAccuracy: 100), monotonicTime: .seconds(10)).isEmpty)
        #expect(detector.process(sample(speed: 4, at: 15), monotonicTime: .seconds(15)).isEmpty)
        #expect(detector.state == .preparing)
    }

    @Test("A brief interruption inside hysteresis does not restart movement evidence")
    func briefTaxiStopUsesHysteresis() {
        var detector = PhysicalFlightDetector(policy: .fixture)

        #expect(detector.process(sample(speed: 4, at: 0), monotonicTime: .seconds(0)).isEmpty)
        #expect(detector.process(sample(speed: 0, at: 1), monotonicTime: .seconds(1)).isEmpty)
        #expect(detector.process(sample(speed: 4, at: 5), monotonicTime: .seconds(5)) == [.groundMovementBegan])
    }

    @Test("Holding short, drift, and noisy altitude do not promote")
    func representativeNegativeFixtures() {
        var detector = detectorWithGroundMovement()

        #expect(detector.process(sample(speed: 0, altitude: 30, at: 10), monotonicTime: .seconds(10)).isEmpty)
        #expect(detector.process(sample(speed: 1, altitude: 100, at: 20), monotonicTime: .seconds(20)).isEmpty)
        #expect(detector.process(sample(speed: 24, altitude: 100, at: 21, horizontalAccuracy: 100), monotonicTime: .seconds(21)).isEmpty)
        #expect(detector.state == .groundMovement)
    }

    @Test("A single takeoff-speed spike never promotes a recording")
    func takeoffSpikeIsRejected() {
        var detector = detectorWithGroundMovement()

        #expect(detector.process(sample(speed: 24, altitude: 55, at: 6), monotonicTime: .seconds(6)).isEmpty)
        #expect(detector.process(sample(speed: 4, altitude: 31, at: 7), monotonicTime: .seconds(7)).isEmpty)
        #expect(detector.state == .groundMovement)
    }

    @Test("Sustained speed and altitude gain detect takeoff")
    func sustainedTakeoffPromotes() {
        var detector = detectorWithGroundMovement()

        #expect(detector.process(sample(speed: 24, altitude: 55, at: 6), monotonicTime: .seconds(6)).isEmpty)
        #expect(detector.process(sample(speed: 24, altitude: 60, at: 11), monotonicTime: .seconds(11)) == [.takeoffDetected])
        #expect(detector.state == .airborne)
    }

    @Test("Contradictory sustained evidence emits a correction without erasing takeoff")
    func contradictionEmitsCorrection() {
        var detector = detectorWithGroundMovement()
        _ = detector.process(sample(speed: 24, altitude: 55, at: 6), monotonicTime: .seconds(6))
        _ = detector.process(sample(speed: 24, altitude: 60, at: 11), monotonicTime: .seconds(11))

        #expect(detector.process(sample(speed: 0, altitude: 30, at: 12), monotonicTime: .seconds(12)).isEmpty)
        #expect(detector.process(sample(speed: 0, altitude: 30, at: 17), monotonicTime: .seconds(17)) == [
            .correction(previous: .airborne, corrected: .groundMovement)
        ])
        #expect(detector.state == .groundMovement)
    }

    @Test("Stationary provisional capture is discarded only after its conservative timeout")
    func provisionalTimeout() {
        var detector = detectorWithGroundMovement()

        #expect(detector.process(sample(speed: 0, at: 34), monotonicTime: .seconds(34)).isEmpty)
        #expect(detector.process(sample(speed: 0, at: 35), monotonicTime: .seconds(35)) == [.provisionalTimedOut])
        #expect(detector.state == .preparing)
    }

    @Test("Sustained airborne evidence at launch creates an explicit partial start")
    func airborneLaunchCreatesPartialStart() {
        var detector = PhysicalFlightDetector(policy: .fixture)

        #expect(detector.process(sample(speed: 24, altitude: 500, at: 0), monotonicTime: .seconds(0)).isEmpty)
        #expect(detector.process(sample(speed: 25, altitude: 505, at: 8), monotonicTime: .seconds(8)) == [.partialStartDetected])
        #expect(detector.state == .airborne)
    }

    private func detectorWithGroundMovement() -> PhysicalFlightDetector {
        var detector = PhysicalFlightDetector(policy: .fixture)
        _ = detector.process(sample(speed: 4, at: 0), monotonicTime: .seconds(0))
        _ = detector.process(sample(speed: 4, at: 5), monotonicTime: .seconds(5))
        return detector
    }

    private func sample(
        speed: Double,
        altitude: Double = 30,
        at seconds: TimeInterval,
        horizontalAccuracy: Double = 10
    ) -> AircraftLocationSample {
        AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32, longitudeDegrees: 34.8),
            observedAt: Date(timeIntervalSince1970: seconds),
            horizontalAccuracyMeters: horizontalAccuracy,
            altitudeMeters: altitude,
            verticalAccuracyMeters: 5,
            trueCourseDegrees: 90,
            courseAccuracyDegrees: 5,
            groundSpeedMetersPerSecond: speed,
            speedAccuracyMetersPerSecond: 0.5
        )
    }
}

private extension PhysicalFlightDetectionPolicy {
    static let fixture = PhysicalFlightDetectionPolicy(
        maximumHorizontalAccuracyMeters: 50,
        maximumSpeedAccuracyMetersPerSecond: 2,
        groundMovementSpeedMetersPerSecond: 3,
        groundMovementWindow: .seconds(5),
        candidateInterruptionTolerance: .seconds(1),
        takeoffSpeedMetersPerSecond: 20,
        takeoffAltitudeGainMeters: 20,
        takeoffWindow: .seconds(5),
        provisionalTimeout: .seconds(30),
        airborneLaunchWindow: .seconds(8)
    )
}
