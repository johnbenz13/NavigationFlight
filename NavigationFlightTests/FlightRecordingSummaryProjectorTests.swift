import Foundation
import Testing
@testable import NavigationFlight

@Suite("Flight recording summary projector")
struct FlightRecordingSummaryProjectorTests {
    @Test("Distance sums consecutive samples without bridging segment gaps")
    func distanceDoesNotBridgeSegments() throws {
        let firstSegment = RecordedTrackSegment(
            id: UUID(),
            samples: [
                sample(latitude: 0, longitude: 0, observedAt: 0),
                sample(latitude: 0, longitude: 0.01, observedAt: 60),
            ]
        )
        let secondSegment = RecordedTrackSegment(
            id: UUID(),
            samples: [
                sample(latitude: 10, longitude: 10, observedAt: 120),
                sample(latitude: 10, longitude: 10.01, observedAt: 180),
            ]
        )

        let summary = FlightRecordingSummaryProjector().project(
            trackSegments: [firstSegment, secondSegment],
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 180),
            knownGapIntervals: []
        )

        let distance = try #require(summary.distanceMeters)
        #expect(abs(distance - 2_207) < 2)
    }

    @Test("Duration uses the physical recording interval")
    func durationUsesRecordingInterval() {
        let summary = FlightRecordingSummaryProjector().project(
            trackSegments: [],
            startedAt: Date(timeIntervalSince1970: 1_000),
            endedAt: Date(timeIntervalSince1970: 4_600),
            knownGapIntervals: []
        )

        #expect(summary.duration == .seconds(3_600))
    }

    @Test("Maximum altitude ignores invalid stored measurements")
    func maximumAltitudeUsesValidEvidence() {
        let segment = RecordedTrackSegment(
            id: UUID(),
            samples: [
                sample(latitude: 0, longitude: 0, observedAt: 0, altitudeMeters: 100),
                sample(latitude: 0, longitude: 0.01, observedAt: 60, altitudeMeters: .nan),
                sample(latitude: 0, longitude: 0.02, observedAt: 120, altitudeMeters: 250),
            ]
        )

        let summary = FlightRecordingSummaryProjector().project(
            trackSegments: [segment],
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 120),
            knownGapIntervals: []
        )

        #expect(summary.maximumAltitudeMeters == 250)
    }

    @Test("Coverage uses known recording time and does not double-count overlapping gaps")
    func coverageUsesKnownTimeAndGaps() {
        let summary = FlightRecordingSummaryProjector().project(
            trackSegments: [],
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 100),
            knownGapIntervals: [
                Date(timeIntervalSince1970: 20)..<Date(timeIntervalSince1970: 40),
                Date(timeIntervalSince1970: 30)..<Date(timeIntervalSince1970: 50),
            ]
        )

        #expect(summary.gpsCoverageFraction == 0.7)
    }

    @Test("Missing measurement evidence remains unavailable rather than zero")
    func missingEvidenceIsUnavailable() {
        let summary = FlightRecordingSummaryProjector().project(
            trackSegments: [],
            startedAt: Date(timeIntervalSince1970: 0),
            endedAt: Date(timeIntervalSince1970: 100),
            knownGapIntervals: []
        )

        #expect(summary.distanceMeters == nil)
        #expect(summary.maximumAltitudeMeters == nil)
        #expect(summary.gpsCoverageFraction == nil)
    }

    private func sample(
        latitude: Double,
        longitude: Double,
        observedAt: TimeInterval,
        altitudeMeters: Double? = nil
    ) -> RecordedTrackSample {
        RecordedTrackSample(
            coordinate: WGS84Coordinate(
                latitudeDegrees: latitude,
                longitudeDegrees: longitude
            ),
            observedAt: Date(timeIntervalSince1970: observedAt),
            horizontalAccuracyMeters: 5,
            altitudeMeters: altitudeMeters,
            verticalAccuracyMeters: nil,
            groundSpeedMetersPerSecond: nil,
            speedAccuracyMetersPerSecond: nil,
            courseDegrees: nil,
            courseAccuracyDegrees: nil
        )
    }
}
