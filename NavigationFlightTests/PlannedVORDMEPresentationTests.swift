import Foundation
import Testing
@testable import NavigationFlight

@Suite("Planned VOR DME presentation")
struct PlannedVORDMEPresentationTests {
    @Test("Reference formats compact and complete planned-provenance copy")
    func formattedCopy() throws {
        let reference = AviationMapVORDMEReference(
            id: try #require(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")),
            waypointID: try #require(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")),
            waypointCoordinate: AviationMapCoordinate(latitude: 32.5, longitude: 35.2),
            stationIdentifier: "NAT",
            frequencyMHz: 112.4,
            magneticRadialFromDegrees: 33,
            slantRangeNauticalMiles: 18.2
        )

        #expect(reference.compactLabel == "NAT · R-033°M · 18.2 NM")
        #expect(reference.serviceAndFrequencyLabel == "VOR/DME · 112.400 MHz")
        #expect(reference.radialAndDistanceLabel == "R-033°M · 18.2 NM")
        #expect(reference.provenanceLabel == "Imported planning reference—not live avionics data.")
    }
}
