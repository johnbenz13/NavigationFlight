import Foundation
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Flight recording application coordination")
struct FlightRecordingCoordinatorTests {
    @Test("Successful Start Leg commit publishes the committed transition and recording status")
    func successfulStartLegCommit() async throws {
        let fixture = makeFixture()
        let coordinator = FlightRecordingCoordinator(store: InMemoryFlightRecordingStore())

        let transition = try await coordinator.startLeg(
            flight: fixture.flight,
            flightPlanSnapshot: fixture.snapshot,
            at: fixture.startedAt,
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )

        #expect(transition.flight.legState == .active)
        #expect(coordinator.snapshot.recording == transition.recording)
        #expect(coordinator.status == .recordingGPSUnavailable)
        #expect(coordinator.lastError == nil)
    }

    @Test("Failed Start Leg commit preserves the ready Flight and exposes a restrained error")
    func failedStartLegCommit() async throws {
        let fixture = makeFixture()
        let coordinator = FlightRecordingCoordinator(
            store: InMemoryFlightRecordingStore(failure: .create)
        )

        await #expect(throws: FlightRecordingStoreError.operationFailed(id: nil)) {
            try await coordinator.startLeg(
                flight: fixture.flight,
                flightPlanSnapshot: fixture.snapshot,
                at: fixture.startedAt,
                recordingID: UUID(),
                eventIDs: [UUID(), UUID()]
            )
        }

        #expect(coordinator.snapshot.flight == fixture.flight)
        #expect(coordinator.snapshot.recording == nil)
        #expect(coordinator.status == .ready)
        #expect(coordinator.lastError == .startLegPersistenceFailed)
    }

    @Test("Replacing an ended Flight resets recording state and allows a fresh recording")
    func endedFlightCanRestartRecording() async throws {
        let fixture = makeFixture()
        let coordinator = FlightRecordingCoordinator(store: InMemoryFlightRecordingStore())
        _ = try await coordinator.startLeg(
            flight: fixture.flight,
            flightPlanSnapshot: fixture.snapshot,
            at: fixture.startedAt,
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )
        try await coordinator.endManually(
            at: fixture.startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            eventIDs: [UUID(), UUID()]
        )

        try await coordinator.prepareForFlightReplacement(
            at: fixture.startedAt.addingTimeInterval(61),
            eventIDs: [UUID(), UUID()]
        )
        let restartedFlight = Flight(
            id: UUID(),
            flightPlanID: fixture.flight.flightPlanID,
            legIDs: fixture.flight.legIDs,
            activeLegIndex: 0,
            executionMode: .noWind
        )
        let transition = try await coordinator.startLeg(
            flight: restartedFlight,
            flightPlanSnapshot: fixture.snapshot,
            at: fixture.startedAt.addingTimeInterval(120),
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )

        #expect(coordinator.status == .recordingGPSUnavailable)
        #expect(transition.recording.flightID == restartedFlight.id)
        #expect(transition.recording.closure == nil)
    }

    @Test("Storage degradation projects a warning without disabling navigation commits")
    func storageDegradationWarnsWithoutBlockingNavigation() async throws {
        let fixture = makeFixture()
        let coordinator = FlightRecordingCoordinator(store: InMemoryFlightRecordingStore())
        _ = try await coordinator.startLeg(
            flight: fixture.flight,
            flightPlanSnapshot: fixture.snapshot,
            at: fixture.startedAt,
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )
        try await coordinator.recordStorageDegradation(
            .trackWriteFailed,
            at: fixture.startedAt.addingTimeInterval(5),
            elapsed: .seconds(5),
            eventID: UUID()
        )

        #expect(coordinator.status == .recordingDegraded)
        #expect(coordinator.snapshot.storageDegradations == [.trackWriteFailed])
        let transition = try await coordinator.commitNavigation(.identifyDestination(
            at: fixture.startedAt.addingTimeInterval(6),
            elapsed: .seconds(6),
            eventID: UUID()
        ))
        #expect(transition.flight.destinationIdentifiedAt != nil)
        let presentation = RecordingStatusPresentation(status: coordinator.status)
        #expect(presentation.compactTitle == "REC · WARNING")
        #expect(presentation.showsEndRecordingAction)
    }

    private func makeFixture() -> (flight: Flight, snapshot: RecordedFlightPlanSnapshot, startedAt: Date) {
        let planID = UUID()
        let legID = UUID()
        return (
            Flight(
                flightPlanID: planID,
                legIDs: [legID],
                activeLegIndex: 0,
                executionMode: .noWind
            ),
            RecordedFlightPlanSnapshot(id: planID, title: "Training flight", legIDs: [legID]),
            Date(timeIntervalSince1970: 1_000)
        )
    }
}
