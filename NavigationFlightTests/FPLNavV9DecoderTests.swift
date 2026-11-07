import Foundation
import Testing
@testable import NavigationFlight

private final class V9FixtureLocator {}

struct FPLNavV9DecoderTests {
    @Test func chartTextDoesNotChangeOperationalFlightPlan() throws {
        let data = try fixtureData("representative-v9")
        var withoutNotes = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        withoutNotes["formatVersion"] = 8
        var navigation = try #require(withoutNotes["navigation"] as? [String: Any])
        navigation.removeValue(forKey: "chartTexts")
        var presentation = try #require(navigation["presentation"] as? [String: Any])
        var globalStyles = try #require(presentation["globalStyleOverrides"] as? [String: Any])
        globalStyles.removeValue(forKey: "chartText")
        presentation["globalStyleOverrides"] = globalStyles
        var entityStyles = try #require(presentation["entityStyleOverrides"] as? [[String: Any]])
        entityStyles.removeAll { ($0["target"] as? [String: Any])?["kind"] as? String == "chart-text" }
        presentation["entityStyleOverrides"] = entityStyles
        navigation["presentation"] = presentation
        withoutNotes["navigation"] = navigation

        let baseline = try FPLNavDecoder().decode(JSONSerialization.data(withJSONObject: withoutNotes))
        let withChartText = try FPLNavDecoder().decode(data)
        #expect(withChartText == baseline)
    }

    @Test(arguments: ["blank-text", "duplicate-id", "unknown-style-target"])
    func sharedInvalidGoldenFilesAreRejected(_ name: String) throws {
        let data = try fixtureData(name)
        do {
            _ = try FPLNavDecoder().decode(data)
            Issue.record("Expected shared invalid V9 fixture to be rejected: \(name)")
        } catch FPLNavDecoderError.invalidV9Document(_) {
            // The shared fixture's chart-text violation was detected before projection.
        }
    }

    @Test(arguments: ["missing", "whitespace", "too-long", "duplicate-id", "invalid-coordinate",
                      "invalid-rotation", "unknown-field", "invalid-style", "dangling-style-target",
                      "cross-target-style", "duplicate-style-target"])
    func invalidChartTextCandidatesAreRejected(_ mutation: String) throws {
        var root = try fixtureObject("representative-v9")
        var navigation = try #require(root["navigation"] as? [String: Any])
        var notes = try #require(navigation["chartTexts"] as? [[String: Any]])
        var presentation = try #require(navigation["presentation"] as? [String: Any])
        var styles = try #require(presentation["globalStyleOverrides"] as? [String: Any])
        var entities = try #require(presentation["entityStyleOverrides"] as? [[String: Any]])

        switch mutation {
        case "missing": navigation.removeValue(forKey: "chartTexts")
        case "whitespace": notes[0]["text"] = " \n\t "
        case "too-long": notes[0]["text"] = String(repeating: "א", count: 501)
        case "duplicate-id":
            let route = try #require(navigation["route"] as? [String: Any])
            let waypoints = try #require(route["waypoints"] as? [[String: Any]])
            notes[0]["id"] = waypoints[0]["id"]
        case "invalid-coordinate": notes[0]["position"] = ["latitude": 91, "longitude": 35]
        case "invalid-rotation": notes[0]["rotationDegrees"] = 181
        case "unknown-field": notes[0]["legId"] = "00000000-0000-4000-8000-000000000004"
        case "invalid-style": styles["chartText"] = ["fontColor": "red"]
        case "dangling-style-target":
            entities[0]["target"] = ["kind": "chart-text", "id": "00000000-0000-4000-8000-000000000099"]
        case "cross-target-style":
            entities[0]["target"] = ["kind": "waypoint", "id": "00000000-0000-4000-8000-000000000002"]
        case "duplicate-style-target": entities.append(entities[0])
        default: Issue.record("Unknown test mutation: \(mutation)")
        }

        if mutation != "missing" { navigation["chartTexts"] = notes }
        presentation["globalStyleOverrides"] = styles
        presentation["entityStyleOverrides"] = entities
        navigation["presentation"] = presentation
        root["navigation"] = navigation
        do {
            _ = try FPLNavDecoder().decode(JSONSerialization.data(withJSONObject: root))
            Issue.record("Expected invalid V9 chart text to be rejected: \(mutation)")
        } catch FPLNavDecoderError.invalidV9Document(_) {
            // V9 source/presentation errors must be recognized before projection.
        }
    }

    @Test func futureVersionIsRejectedBeforeChartTextCanBeDiscarded() throws {
        var root = try fixtureObject("representative-v9")
        root["formatVersion"] = 10
        #expect(throws: FPLNavDecoderError.unsupportedFormatVersion(10)) {
            try FPLNavDecoder().decode(JSONSerialization.data(withJSONObject: root))
        }
    }

    private func fixtureObject(_ name: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: fixtureData(name)) as? [String: Any])
    }

    private func fixtureData(_ name: String) throws -> Data {
        let bundle = Bundle(for: V9FixtureLocator.self)
        let url = try #require(bundle.url(forResource: name, withExtension: "fplnav",
                                         subdirectory: "Fixtures/FPLNav/V9")
                               ?? bundle.url(forResource: name, withExtension: "fplnav"))
        return try Data(contentsOf: url)
    }
}
