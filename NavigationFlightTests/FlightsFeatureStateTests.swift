import Foundation
import Testing
@testable import NavigationFlight

@Suite("Flights feature state")
struct FlightsFeatureStateTests {
    @Test("Stale loading completion cannot replace the last successful rows")
    func staleLoadingCompletion() throws {
        let firstRequest = try #require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        let secondRequest = try #require(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let row = summary(id: try #require(UUID(uuidString: "55555555-5555-5555-5555-555555555555")))
        var state = FlightsFeatureState()

        state.beginLoading(requestID: firstRequest)
        state.beginLoading(requestID: secondRequest)

        let staleCompletion = state.completeLoading(requestID: firstRequest, rows: [row])
        #expect(staleCompletion == false)
        #expect(state.rows.isEmpty)
        let acceptedCompletion = state.completeLoading(requestID: secondRequest, rows: [row])
        #expect(acceptedCompletion)
        #expect(state.rows == [row])
        #expect(state.isLoading == false)
    }

    private func summary(id: UUID) -> FlightRecordingSummary {
        FlightRecordingSummary(
            id: id,
            flightPlanTitle: "Coastal Navigation",
            route: "LLHZ → LLHZ",
            startedAt: Date(timeIntervalSince1970: 1_000),
            duration: .seconds(600),
            status: .complete,
            gpsCoverage: .available,
            approximateSizeBytes: 1_000,
            canContinue: false,
            canDelete: true
        )
    }
}
