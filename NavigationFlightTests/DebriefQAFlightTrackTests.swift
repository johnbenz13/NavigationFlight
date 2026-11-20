import Foundation
import Testing
@testable import NavigationFlight

@Suite("Debrief QA real flight tracks")
struct DebriefQAFlightTrackTests {
    @Test("LLHZ to LLMZ fixture pairs its supplied plan with its recorded execution")
    func llhzLLMZFixtureUsesMatchingPlanAndTrack() throws {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repository = sourceFile.deletingLastPathComponent().deletingLastPathComponent()
        let planData = try Data(contentsOf: repository.appending(
            path: "fixtures/FlightRecords/llhz-llmz/flight-plan.fplnav"
        ))
        let plan = try FPLNavDecoder().decode(planData)
        let track = try #require(DebriefQAFlightTrack.samples(
            startedAt: Date(timeIntervalSince1970: 1_000),
            planTitle: plan.title
        ))

        #expect(plan.title == "LLHZ - LLMZ")
        #expect(plan.waypoints.count == 20)
        #expect(plan.waypoints.first?.name == "שפיים")
        #expect(plan.waypoints.last?.name == "עין גדי")
        #expect(track.first?.coordinate == WGS84Coordinate(
            latitudeDegrees: 32.181228,
            longitudeDegrees: 34.828135
        ))
        #expect(track.last?.coordinate == WGS84Coordinate(
            latitudeDegrees: 31.328694,
            longitudeDegrees: 35.387494
        ))
    }

    @Test("Plan titles select their corresponding recorded execution")
    func selectsMatchingExecution() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let llib = try #require(DebriefQAFlightTrack.samples(
            startedAt: startedAt,
            planTitle: "LLHZ - LLIB via Jerusalem"
        ))
        let llmz = try #require(DebriefQAFlightTrack.samples(
            startedAt: startedAt,
            planTitle: "LLHZ - LLMZ"
        ))

        #expect(llib.count == 55)
        #expect(DebriefQAFlightTrack.duration(for: "LLHZ - LLIB via Jerusalem") == 6_676.92)
        #expect(llib.first?.coordinate == WGS84Coordinate(
            latitudeDegrees: 32.181418,
            longitudeDegrees: 34.828641
        ))
        #expect(llib.last?.coordinate == WGS84Coordinate(
            latitudeDegrees: 32.977308,
            longitudeDegrees: 35.573419
        ))

        #expect(llmz.count == 42)
        #expect(DebriefQAFlightTrack.duration(for: "LLHZ - LLMZ") == 5_186.41)
        #expect(llmz.first?.coordinate == WGS84Coordinate(
            latitudeDegrees: 32.181228,
            longitudeDegrees: 34.828135
        ))
        #expect(llmz.last?.coordinate == WGS84Coordinate(
            latitudeDegrees: 31.328694,
            longitudeDegrees: 35.387494
        ))
    }

    @Test("Unknown plans do not receive unrelated real flight evidence")
    func unknownPlanFailsClosed() {
        #expect(DebriefQAFlightTrack.duration(for: "Unknown") == nil)
        #expect(DebriefQAFlightTrack.samples(startedAt: .now, planTitle: "Unknown") == nil)
    }
}
