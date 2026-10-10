//
//  NavigationFlightTests.swift
//  NavigationFlightTests
//
//  Created by Jonathan Bensaid on 10/10/2026.
//

import Foundation
import Testing
@testable import NavigationFlight

private final class FixtureLocator {}

struct NavigationFlightTests {
    @Test func representativeV5MapsIntoDomain() throws {
        let flight = try FPLNavDecoder().decode(try representativeData())

        #expect(flight.title == "Coastal training navigation")
        #expect(flight.waypoints.map(\.name) == ["BAZRA", "Visual checkpoint"])
        #expect(flight.legs.count == 1)
        #expect(flight.legs[0].departure.id == flight.waypoints[0].id)
        #expect(flight.legs[0].arrival.id == flight.waypoints[1].id)
        #expect(flight.waypoints[0].position == WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.5))
        #expect(flight.waypoints[1].plannedAltitude == AltitudeFeet(value: 3500))

        // V5 explicitly distinguishes east-positive magnetic variation and true wind direction.
        #expect(flight.parameters.magneticVariationEast == Degrees(value: 5))
        #expect(flight.operationalContext.defaultWind?.directionFromTrue == Degrees(value: 270))

        #expect(flight.identificationPoints[0].progress == LegProgress(fraction: 0.4))
        #expect(flight.altitudeChanges.map(\.targetAltitude.value) == [4000, 2500, 3200])
        #expect(flight.frequencyChanges[0].service.name == "Tel Aviv Control")
        #expect(flight.frequencyChanges[0].frequency == FrequencyMHz(value: 120.5))
        #expect(flight.vorDmeReferences.count == 2)
        #expect(flight.vorDmeReferences[0].calculation == .automatic)
        #expect(
            flight.vorDmeReferences[1].calculation
                == .manual(radial: Degrees(value: 270), distance: NauticalMiles(value: 12.4))
        )
        #expect(flight.operationalContext.departureAerodrome?.icao == "LLHZ")
        #expect(flight.operationalContext.arrivalAerodrome?.localCode == "LLMG")
    }

    @Test func documentMetadataIdentifiesV5() throws {
        let object = try representativeJSONObject()
        #expect(object["formatVersion"] as? Int == 5)
        #expect(object["format"] as? String == "fpl-navigation-project")
    }

    @Test func editorOnlyAndUnknownPropertiesAreIgnored() throws {
        var object = try representativeJSONObject()
        object["futureEditorState"] = ["selection": "ignored"]
        var navigation = try #require(object["navigation"] as? [String: Any])
        navigation["futureEditorTool"] = true
        object["navigation"] = navigation

        let flight = try FPLNavDecoder().decode(try JSONSerialization.data(withJSONObject: object))
        #expect(flight.waypoints.count == 2)
    }

    @Test func unsupportedVersionIsTyped() throws {
        var object = try representativeJSONObject()
        object["formatVersion"] = 6

        #expect(throws: FPLNavDecoderError.unsupportedFormatVersion(6)) {
            try FPLNavDecoder().decode(try JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test func brokenWaypointRelationshipIsTyped() throws {
        var object = try representativeJSONObject()
        var navigation = try #require(object["navigation"] as? [String: Any])
        var route = try #require(navigation["route"] as? [String: Any])
        var order = try #require(route["waypointOrder"] as? [String])
        order[0] = "00000000-0000-4000-8000-000000000099"
        route["waypointOrder"] = order
        navigation["route"] = route
        object["navigation"] = navigation

        let expectedID = try #require(UUID(uuidString: order[0]))
        #expect(throws: FPLNavDecoderError.mapping(.missingWaypointInOrder(expectedID))) {
            try FPLNavDecoder().decode(try JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test func samePositionEventsRemainIndependentAndRepresentable() throws {
        var object = try representativeJSONObject()
        var navigation = try #require(object["navigation"] as? [String: Any])
        var frequencyChanges = try #require(navigation["radioFrequencyChanges"] as? [[String: Any]])
        frequencyChanges[0]["legProgress"] = 0.25
        navigation["radioFrequencyChanges"] = frequencyChanges
        object["navigation"] = navigation

        let flight = try FPLNavDecoder().decode(try JSONSerialization.data(withJSONObject: object))
        #expect(flight.altitudeChanges[0].anchor == .legProgress(LegProgress(fraction: 0.25)))
        #expect(flight.frequencyChanges[0].progress == LegProgress(fraction: 0.25))
    }

    private func representativeData() throws -> Data {
        let bundle = Bundle(for: FixtureLocator.self)
        let nestedURL = bundle.url(
            forResource: "representative",
            withExtension: "fplnav",
            subdirectory: "Fixtures/FPLNav/V5"
        )
        let url = nestedURL ?? bundle.url(forResource: "representative", withExtension: "fplnav")
        return try Data(contentsOf: #require(url))
    }

    private func representativeJSONObject() throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: representativeData()) as? [String: Any])
    }
}
