import Foundation
import Testing
@testable import NavigationFlight

private final class V8FixtureLocator {}

struct FPLNavV8DecoderTests {
    @Test func sharedGoldenPreservesSavedPerLegSpeedsAndDurations() throws {
        let plan = try FPLNavDecoder().decode(fixtureData("representative-v8"))
        guard case .eligible(let navigation) = plan.plannedNavigation else {
            Issue.record("Expected execution-eligible V8 plan")
            return
        }
        #expect(navigation.legs.map(\.legID) == plan.legs.map(\.id))
        #expect(navigation.legs.map(\.noWind.groundSpeed.value) == [90, 60])
        #expect(navigation.legs.map(\.noWind.durationSeconds) == [40, 60])
        #expect(navigation.legs.map { $0.withWind?.timing.durationSeconds } == [40, 60])
    }

    @Test(arguments: ["nonpositive-override", "mismatched-speed", "missing-wind-solution"])
    func sharedInvalidCandidatesAreRejected(_ name: String) throws {
        let data = try fixtureData("v8-" + name)
        #expect(throws: (any Error).self) { try FPLNavDecoder().decode(data) }
    }

    @Test(arguments: ["null", "true", "\"60\"", "0", "-1", "1e999", "\"NaN\""])
    func presentInvalidOverrideDoesNotInherit(_ value: String) throws {
        let source = try #require(String(data: fixtureData("representative-v8"), encoding: .utf8))
        let mutated = source.replacingOccurrences(of: "\"planningAirspeedOverrideKnots\": 60",
                                                   with: "\"planningAirspeedOverrideKnots\": " + value)
        #expect(mutated != source)
        #expect(throws: (any Error).self) { try FPLNavDecoder().decode(Data(mutated.utf8)) }
    }

    @Test(arguments: [6, 9])
    func unsupportedVersionsAreRejected(_ version: Int) throws {
        var object = try fixtureObject("representative-v8")
        object["formatVersion"] = version
        let data = try JSONSerialization.data(withJSONObject: object)
        #expect(throws: FPLNavDecoderError.unsupportedFormatVersion(version)) {
            try FPLNavDecoder().decode(data)
        }
    }

    @Test func savedDurationsAreNotRecalculated() throws {
        var object = try fixtureObject("representative-v8")
        var execution = try #require(object["execution"] as? [String: Any])
        var legs = try #require(execution["legs"] as? [[String: Any]])
        var timing = try #require(legs[1]["noWind"] as? [String: Any])
        timing["plannedDurationSeconds"] = 83
        legs[1]["noWind"] = timing
        execution["legs"] = legs
        object["execution"] = execution
        let plan = try FPLNavDecoder().decode(JSONSerialization.data(withJSONObject: object))
        guard case .eligible(let navigation) = plan.plannedNavigation else {
            Issue.record("Expected execution-eligible V8 plan")
            return
        }
        #expect(navigation.legs[1].noWind.durationSeconds == 83)
        #expect(navigation.legs[1].noWind.groundSpeed.value == 60)
    }

    @Test(arguments: V7Mutation.allCases)
    func v8RetainsExecutionInvariants(_ mutation: V7Mutation) throws {
        var object = try fixtureObject("representative-v7")
        object["formatVersion"] = 8
        try mutation.apply(to: &object)
        #expect(throws: (any Error).self) {
            try FPLNavDecoder().decode(JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test func v7DoesNotConsumeV8Override() throws {
        var object = try fixtureObject("representative-v7")
        var navigation = try #require(object["navigation"] as? [String: Any])
        var route = try #require(navigation["route"] as? [String: Any])
        var legs = try #require(route["legs"] as? [[String: Any]])
        legs[0]["planningAirspeedOverrideKnots"] = "ignored V8 property"
        route["legs"] = legs
        navigation["route"] = route
        object["navigation"] = navigation
        let original = try FPLNavDecoder().decode(fixtureData("representative-v7"))
        #expect(try FPLNavDecoder().decode(JSONSerialization.data(withJSONObject: object)) == original)
    }

    private func fixtureObject(_ name: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: fixtureData(name)) as? [String: Any])
    }

    private func fixtureData(_ name: String) throws -> Data {
        let bundle = Bundle(for: V8FixtureLocator.self)
        let url = try #require(bundle.url(forResource: name, withExtension: "fplnav",
                                         subdirectory: "Fixtures/FPLNav/V8")
                               ?? bundle.url(forResource: name, withExtension: "fplnav"))
        return try Data(contentsOf: url)
    }
}
