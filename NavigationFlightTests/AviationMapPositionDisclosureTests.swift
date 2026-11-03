import Foundation
import Testing
@testable import NavigationFlight

@Suite("Aviation map Position Check disclosure")
struct AviationMapPositionDisclosureTests {
    @Test("Overlay projects a directional marker only from trustworthy course")
    func directionalAndNeutralMarkers() {
        let directional = GPSDisclosureOverlay(projection: projection(course: 72))
        let neutral = GPSDisclosureOverlay(projection: projection(course: nil))

        #expect(directional.marker == .directional(trueCourseDegrees: 72))
        #expect(neutral.marker == .neutral)
        #expect(directional.accuracyRadiusMeters == 35)
    }

    @Test("Accuracy geometry is a closed ring around the disclosed position")
    func accuracyGeometry() throws {
        let overlay = GPSDisclosureOverlay(projection: projection(course: nil))
        let ring = GPSDisclosureMapContract.accuracyRing(for: overlay)

        #expect(ring.count == 49)
        #expect(try #require(ring.first) == ring.last)
        #expect(ring.allSatisfy { $0 != overlay.coordinate })
    }

    @Test("Position Check map sources and layers have stable distinct identifiers")
    func stableIdentifiers() {
        let identifiers = [
            GPSDisclosureMapContract.accuracySourceID,
            GPSDisclosureMapContract.accuracyLayerID,
            GPSDisclosureMapContract.markerSourceID,
            GPSDisclosureMapContract.markerLayerID,
            GPSDisclosureMapContract.recoverySourceID,
            GPSDisclosureMapContract.recoveryLayerID,
            GPSDisclosureMapContract.interceptSourceID,
            GPSDisclosureMapContract.interceptLayerID
        ]
        #expect(Set(identifiers).count == identifiers.count)
        #expect(identifiers.allSatisfy { $0.hasPrefix("position-check-") })
    }

    @Test("Recovery camera requests retain both aircraft and intercept coordinates")
    func recoveryCameraRequest() {
        let aircraft = AviationMapCoordinate(latitude: 32.1, longitude: 34.8)
        let intercept = AviationMapCoordinate(latitude: 32.2, longitude: 34.9)
        let request = AviationMapFocusRequest(mode: .positionCheck(aircraft: aircraft, intercept: intercept))

        #expect(request.mode == .positionCheck(aircraft: aircraft, intercept: intercept))
    }

    private func projection(course: Double?) -> PositionCheckProjection {
        PositionCheckProjection(
            sample: AircraftLocationSample(
                coordinate: WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.8),
                observedAt: Date(timeIntervalSince1970: 1_000),
                horizontalAccuracyMeters: 35,
                trueCourseDegrees: course,
                courseAccuracyDegrees: course == nil ? nil : 5,
                groundSpeedMetersPerSecond: course == nil ? nil : 40,
                speedAccuracyMetersPerSecond: course == nil ? nil : 1
            )
        )
    }
}
