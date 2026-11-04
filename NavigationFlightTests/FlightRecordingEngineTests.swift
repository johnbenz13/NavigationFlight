import Foundation
import Testing
@testable import NavigationFlight

@Suite("Flight recording engine")
struct FlightRecordingEngineTests {
    @Test("Start Leg is not published until the durable package is synchronized")
    func publicationWaitsForDurability() async throws {
        let fixture = makeFixture()
        let store = ControlledFlightRecordingStore()
        let engine = FlightRecordingEngine(
            store: store,
            flight: fixture.flight,
            flightPlanSnapshot: fixture.snapshot
        )
        let task = Task {
            try await engine.promoteForStartLeg(
                at: fixture.startedAt,
                recordingID: UUID(),
                eventIDs: [UUID(), UUID()]
            )
        }

        await store.waitForCreateStart()
        let pending = await engine.snapshot()
        #expect(pending.flight.legState == .ready)
        #expect(pending.recording == nil)

        await store.releaseCreate()
        _ = try await task.value
        let committed = await engine.snapshot()
        #expect(committed.flight.legState == .active)
        #expect(committed.recording?.navigationState == .active)
        #expect(committed.recording?.gpsCoverage == .unavailable)
    }

    @Test("Persistence failure leaves the published Flight and recording unchanged")
    func persistenceFailurePreservesPublishedState() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore(failure: .create)
        let engine = FlightRecordingEngine(
            store: store,
            flight: fixture.flight,
            flightPlanSnapshot: fixture.snapshot
        )

        await #expect(throws: FlightRecordingStoreError.operationFailed(id: nil)) {
            try await engine.promoteForStartLeg(
                at: fixture.startedAt,
                recordingID: UUID(),
                eventIDs: [UUID(), UUID()]
            )
        }
        let snapshot = await engine.snapshot()
        #expect(snapshot.flight == fixture.flight)
        #expect(snapshot.recording == nil)
    }

    @Test("Navigation Complete is synchronized before the completed recording state is published")
    func navigationCompletionIsDurable() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(
            store: store,
            flight: fixture.flight,
            flightPlanSnapshot: fixture.snapshot
        )
        let started = try await engine.promoteForStartLeg(
            at: fixture.startedAt,
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )
        let completedFlight = try await MainActor.run {
            var flight = started.flight
            try flight.reachCurrentWaypoint(at: fixture.startedAt.addingTimeInterval(60))
            return flight
        }

        let completed = try await engine.completeNavigation(
            flight: completedFlight,
            at: fixture.startedAt.addingTimeInterval(61),
            elapsed: .seconds(61),
            eventID: UUID()
        )

        #expect(completed.flight.legState == .completed)
        #expect(completed.recording?.navigationState == .complete)
        let recordingID = try #require(completed.recording?.id)
        let persisted = try await store.readSnapshot(id: recordingID)
        #expect(persisted.events.last?.payload == .navigationCompleted)
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

private actor ControlledFlightRecordingStore: FlightRecordingStore {
    private var createStarted = false
    private var createWaiters: [CheckedContinuation<Void, Never>] = []
    private var createRelease: CheckedContinuation<Void, Never>?

    func create(_ seed: FlightRecordingSeed) async throws {
        createStarted = true
        createWaiters.forEach { $0.resume() }
        createWaiters.removeAll()
        await withCheckedContinuation { continuation in
            createRelease = continuation
        }
    }

    func waitForCreateStart() async {
        guard !createStarted else { return }
        await withCheckedContinuation { continuation in
            createWaiters.append(continuation)
        }
    }

    func releaseCreate() {
        createRelease?.resume()
        createRelease = nil
    }

    func appendEvent(
        _ event: RecordedFlightEvent,
        recordingID: UUID,
        synchronize: Bool
    ) async throws {}

    func packages() async -> [FlightRecordingPackageResult] { [] }

    func readSnapshot(id: UUID) async throws -> FlightRecordingReadSnapshot {
        throw FlightRecordingStoreError.corruptPackage(id: id)
    }

    func close(id: UUID, closure: FlightRecordingClosure) async throws {}
}
