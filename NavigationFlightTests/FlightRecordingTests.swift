import Foundation
import Testing
@testable import NavigationFlight

@Suite("Flight recording domain")
struct FlightRecordingTests {
    @Test("Start Leg without location promotes one action-only recording with ordered events")
    func actionOnlyPromotion() throws {
        let recordingID = UUID()
        let flightID = UUID()
        let planID = UUID()
        let legID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_000)

        let promotion = try FlightRecording.promoteForStartLeg(
            id: recordingID,
            flightID: flightID,
            flightPlanSnapshot: RecordedFlightPlanSnapshot(
                id: planID,
                title: "LCLK to EGLL",
                legIDs: [legID]
            ),
            legID: legID,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()]
        )

        #expect(promotion.recording.id == recordingID)
        #expect(promotion.recording.physicalState == .unavailable)
        #expect(promotion.recording.navigationState == .active)
        #expect(promotion.recording.gpsCoverage == .unavailable)
        #expect(promotion.recording.closure == nil)
        #expect(promotion.events.map(\.sequence) == [0, 1])
        #expect(promotion.events.map(\.payload) == [
            .recordingStarted(cause: .startLegWithoutLocation),
            .legStarted(legID: legID)
        ])
    }

    @Test("Manual end closes an action-only recording incomplete in deterministic order")
    func manualIncompleteClosure() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let endedAt = startedAt.addingTimeInterval(300)
        var promotion = try makePromotion(startedAt: startedAt)

        let events = try promotion.recording.endManually(
            at: endedAt,
            elapsed: .seconds(300),
            eventIDs: [UUID(), UUID()]
        )

        #expect(events.map(\.sequence) == [2, 3])
        #expect(events.map(\.payload) == [
            .manualEnd,
            .recordingClosed(outcome: .incomplete, cause: .manual)
        ])
        #expect(promotion.recording.closure == FlightRecordingClosure(
            outcome: .incomplete,
            cause: .manual,
            closedAt: endedAt,
            elapsed: .seconds(300),
            landingEvidenceAvailable: false
        ))
    }

    @Test("Navigation completion makes a later manual action-only closure complete")
    func navigationCompletionThenManualClosure() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let completedAt = startedAt.addingTimeInterval(240)
        let endedAt = startedAt.addingTimeInterval(300)
        var promotion = try makePromotion(startedAt: startedAt)

        let navigationCompleted = try promotion.recording.completeNavigation(
            at: completedAt,
            elapsed: .seconds(240),
            eventID: UUID()
        )
        let closingEvents = try promotion.recording.endManually(
            at: endedAt,
            elapsed: .seconds(300),
            eventIDs: [UUID(), UUID()]
        )

        #expect(navigationCompleted.sequence == 2)
        #expect(navigationCompleted.payload == .navigationCompleted)
        #expect(closingEvents.map(\.sequence) == [3, 4])
        #expect(closingEvents.map(\.payload) == [
            .manualEnd,
            .recordingClosed(outcome: .complete, cause: .manual)
        ])
        #expect(promotion.recording.navigationState == .complete)
        #expect(promotion.recording.closure?.outcome == .complete)
    }

    @Test("Manual physical closure is complete only after navigation and landing evidence")
    func manualPhysicalClosureMatrix() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var promotion = try makePromotion(startedAt: startedAt)
        _ = try promotion.recording.recordPhysicalTransition(
            to: .landedAwaitingStop,
            at: startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            eventID: UUID()
        )
        _ = try promotion.recording.completeNavigation(
            at: startedAt.addingTimeInterval(90),
            elapsed: .seconds(90),
            eventID: UUID()
        )

        let events = try promotion.recording.endManually(
            at: startedAt.addingTimeInterval(120),
            elapsed: .seconds(120),
            eventIDs: [UUID(), UUID()]
        )

        #expect(events.last?.payload == .recordingClosed(outcome: .complete, cause: .manual))
        #expect(promotion.recording.closure?.landingEvidenceAvailable == true)
    }

    @Test("Automatic stop closure reflects navigation completion", arguments: [false, true])
    func automaticStopClosure(navigationCompleted: Bool) throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var promotion = try makePromotion(startedAt: startedAt)
        _ = try promotion.recording.recordPhysicalTransition(
            to: .stopped,
            at: startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            eventID: UUID()
        )
        if navigationCompleted {
            _ = try promotion.recording.completeNavigation(
                at: startedAt.addingTimeInterval(90),
                elapsed: .seconds(90),
                eventID: UUID()
            )
        }

        let event = try promotion.recording.closeAutomatically(
            at: startedAt.addingTimeInterval(120),
            elapsed: .seconds(120),
            eventID: UUID()
        )
        let expected: FlightRecordingClosure.Outcome = navigationCompleted ? .complete : .incomplete

        #expect(event.payload == .recordingClosed(outcome: expected, cause: .automatic))
        #expect(promotion.recording.closure?.outcome == expected)
        #expect(promotion.recording.closure?.landingEvidenceAvailable == true)
    }

    @Test("Navigation completion before physical stop also closes Complete")
    func navigationFirstAutomaticClosure() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var promotion = try makePromotion(startedAt: startedAt)
        _ = try promotion.recording.completeNavigation(
            at: startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            eventID: UUID()
        )
        _ = try promotion.recording.recordPhysicalTransition(
            to: .stopped,
            at: startedAt.addingTimeInterval(90),
            elapsed: .seconds(90),
            eventID: UUID()
        )

        _ = try promotion.recording.closeAutomatically(
            at: startedAt.addingTimeInterval(90),
            elapsed: .seconds(90),
            eventID: UUID()
        )

        #expect(promotion.recording.closure?.outcome == .complete)
    }

    @Test("Duplicate Start Leg and duplicate manual end are rejected without advancing sequence")
    func duplicateCommandsAreRejected() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var promotion = try makePromotion(startedAt: startedAt)

        #expect(throws: FlightRecording.TransitionError.navigationAlreadyActive) {
            try promotion.recording.startLeg(
                legID: UUID(),
                at: startedAt,
                elapsed: .zero,
                eventID: UUID()
            )
        }

        _ = try promotion.recording.endManually(
            at: startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            eventIDs: [UUID(), UUID()]
        )
        #expect(throws: FlightRecording.TransitionError.recordingAlreadyClosed) {
            try promotion.recording.endManually(
                at: startedAt.addingTimeInterval(120),
                elapsed: .seconds(120),
                eventIDs: [UUID(), UUID()]
            )
        }
        #expect(promotion.recording.nextEventSequence == 4)
    }

    private func makePromotion(startedAt: Date) throws -> FlightRecordingPromotion {
        let legID = UUID()
        return try FlightRecording.promoteForStartLeg(
            id: UUID(),
            flightID: UUID(),
            flightPlanSnapshot: RecordedFlightPlanSnapshot(
                id: UUID(),
                title: "Training flight",
                legIDs: [legID]
            ),
            legID: legID,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()]
        )
    }
}
