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

    @Test("Deletion confirmation preserves the selected Flight until cancelled")
    func deletionConfirmationCancellation() throws {
        let row = summary(id: try #require(UUID(uuidString: "66666666-6666-6666-6666-666666666666")))
        var state = FlightsFeatureState()
        let requestID = UUID()
        state.beginLoading(requestID: requestID)
        _ = state.completeLoading(requestID: requestID, rows: [row])

        state.requestDeletion(of: row.id)

        #expect(state.pendingDeletionID == row.id)
        #expect(state.rows == [row])

        state.cancelDeletion()

        #expect(state.pendingDeletionID == nil)
        #expect(state.rows == [row])
        #expect(state.deletionFailureID == nil)
    }

    @Test("Successful deletion clears the pending identity and removes only that row")
    func successfulDeletionCleanup() throws {
        let deleted = summary(id: try #require(UUID(uuidString: "77777777-7777-7777-7777-777777777777")))
        let retained = summary(id: try #require(UUID(uuidString: "88888888-8888-8888-8888-888888888888")))
        var state = FlightsFeatureState()
        let requestID = UUID()
        state.beginLoading(requestID: requestID)
        _ = state.completeLoading(requestID: requestID, rows: [deleted, retained])
        state.requestDeletion(of: deleted.id)

        let completed = state.completeDeletion(id: deleted.id)
        #expect(completed)
        #expect(state.pendingDeletionID == nil)
        #expect(state.rows == [retained])
        #expect(state.deletionFailureID == nil)
    }

    @Test("Failed deletion preserves rows and selection for a retry")
    func failedDeletionPreservation() throws {
        let row = summary(id: try #require(UUID(uuidString: "99999999-9999-9999-9999-999999999999")))
        var state = FlightsFeatureState()
        let requestID = UUID()
        state.beginLoading(requestID: requestID)
        _ = state.completeLoading(requestID: requestID, rows: [row])
        state.requestDeletion(of: row.id)

        state.failDeletion(id: row.id)

        #expect(state.pendingDeletionID == nil)
        #expect(state.deletionFailureID == row.id)
        #expect(state.rows == [row])

        state.retryFailedDeletion()
        #expect(state.pendingDeletionID == row.id)
        #expect(state.deletionFailureID == nil)
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
