import Foundation
import Testing
@testable import NavigationFlight

@Suite("Flight recording engine")
struct FlightRecordingEngineTests {
    @Test("Cancelled ETA drafts remain outside the recording journal")
    func cancelledETADraftAppendsNothing() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(
            at: fixture.startedAt,
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )
        let eventCount = started.recording.nextEventSequence
        let target = NavigationTimingTargetKey(
            legID: fixture.snapshot.legIDs[0],
            kind: .destination,
            targetID: UUID()
        )

        await MainActor.run {
            var draft = started.flight
            draft.initializePilotETA(targetKey: target, plannedElapsedSeconds: 300)
            draft.adjustPilotETA(targetKey: target, by: 15)
            draft.cancelPilotETAEditing(targetKey: target)
        }

        let snapshot = await engine.snapshot()
        let persisted = try await store.readSnapshot(id: started.recording.id)
        #expect(snapshot.recording?.nextEventSequence == eventCount)
        #expect(UInt64(persisted.events.count) == eventCount)
    }

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

    @Test("Destination identification is durably committed with the active leg ID")
    func destinationIdentificationIsDurable() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(
            at: fixture.startedAt,
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )

        let transition = try await engine.commit(.identifyDestination(
            at: fixture.startedAt.addingTimeInterval(30),
            elapsed: .seconds(30),
            eventID: UUID()
        ))

        let identifiedAt = await MainActor.run { transition.flight.legTimings.last?.destinationIdentifiedAt }
        #expect(identifiedAt == fixture.startedAt.addingTimeInterval(30))
        let persisted = try await store.readSnapshot(id: started.recording.id)
        #expect(persisted.events.last?.payload == .destinationIdentified(legID: fixture.snapshot.legIDs[0]))
        #expect(persisted.events.last?.origin == .pilot)
    }

    @Test("Identification-point reach records the canonical target and rejected duplicate writes nothing")
    func identificationPointReachIsDurableAndDuplicateIsNoOp() async throws {
        let fixture = makeFixture()
        let point = IdentificationPointKey(legID: fixture.snapshot.legIDs[0], identificationPointID: UUID())
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(at: fixture.startedAt, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let reachedAt = fixture.startedAt.addingTimeInterval(40)

        _ = try await engine.commit(.reachIdentificationPoint(
            key: point,
            orderedActiveLegPointKeys: [point],
            at: reachedAt,
            elapsed: .seconds(40),
            eventID: UUID(),
            nextETATarget: nil,
            nextETAPlannedElapsedSeconds: nil
        ))
        await #expect(throws: Flight.TransitionError.self) {
            try await engine.commit(.reachIdentificationPoint(
                key: point,
                orderedActiveLegPointKeys: [point],
                at: reachedAt,
                elapsed: .seconds(40),
                eventID: UUID(),
                nextETATarget: nil,
                nextETAPlannedElapsedSeconds: nil
            ))
        }

        let persisted = try await store.readSnapshot(id: started.recording.id)
        #expect(persisted.events.count == 3)
        #expect(persisted.events.last?.payload == .identificationPointReached(key: point))
    }

    @Test("Intermediate waypoint reach orders pilot reach before automatic successor start")
    func waypointReachOrdersAutomaticTransition() async throws {
        let fixture = makeFixture(legCount: 2)
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(at: fixture.startedAt, recordingID: UUID(), eventIDs: [UUID(), UUID()])

        let transition = try await engine.commit(.reachCurrentWaypoint(
            orderedActiveLegPointKeys: [],
            at: fixture.startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            eventIDs: [UUID(), UUID()]
        ))

        #expect(transition.flight.activeLegIndex == 1)
        #expect(transition.flight.legState == .active)
        let events = try await store.readSnapshot(id: started.recording.id).events
        #expect(Array(events.suffix(2).map(\.payload)) == [
            .waypointReached(legID: fixture.snapshot.legIDs[0]),
            .automaticNextLegTransition(fromLegID: fixture.snapshot.legIDs[0], toLegID: fixture.snapshot.legIDs[1])
        ])
        #expect(Array(events.suffix(2).map(\.origin)) == [.pilot, .automatic])
    }

    @Test("Final waypoint reach is durable but waits for explicit Navigation Complete")
    func finalWaypointWaitsForExplicitCompletion() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(at: fixture.startedAt, recordingID: UUID(), eventIDs: [UUID(), UUID()])

        let transition = try await engine.commit(.reachCurrentWaypoint(
            orderedActiveLegPointKeys: [],
            at: fixture.startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            eventIDs: [UUID(), UUID()]
        ))

        #expect(transition.flight.legState == .completed)
        #expect(transition.recording.navigationState == .reachedFinalWaypoint)
        #expect(transition.recording.closure == nil)
        let events = try await store.readSnapshot(id: started.recording.id).events
        #expect(Array(events.suffix(2).map(\.payload)) == [
            .waypointReached(legID: fixture.snapshot.legIDs[0]),
            .finalWaypointReached(legID: fixture.snapshot.legIDs[0])
        ])
    }

    @Test("Reach persistence failure preserves the published active Flight")
    func reachPersistenceFailurePreservesPublishedFlight() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore(failure: .append)
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(
            at: fixture.startedAt,
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )

        await #expect(throws: FlightRecordingStoreError.self) {
            try await engine.commit(.reachCurrentWaypoint(
                orderedActiveLegPointKeys: [],
                at: fixture.startedAt.addingTimeInterval(60),
                elapsed: .seconds(60),
                eventIDs: [UUID(), UUID()]
            ))
        }

        let snapshot = await engine.snapshot()
        #expect(snapshot.flight == started.flight)
        #expect(snapshot.recording == started.recording)
        let persisted = try await store.readSnapshot(id: started.recording.id)
        #expect(persisted.events.count == 2)
    }

    @Test("Automatic leg recovery is distinguished from pilot actions")
    func automaticLegRecoveryHasRecoveryOrigin() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(at: fixture.startedAt, recordingID: UUID(), eventIDs: [UUID(), UUID()])

        _ = try await engine.commit(.automaticLegRecovery(
            legID: fixture.snapshot.legIDs[0],
            at: fixture.startedAt.addingTimeInterval(10),
            elapsed: .seconds(10),
            eventID: UUID()
        ))

        let event = try #require(try await store.readSnapshot(id: started.recording.id).events.last)
        #expect(event.origin == .recovery)
        #expect(event.payload == .automaticLegRecovery(legID: fixture.snapshot.legIDs[0]))
    }

    @Test("Committed ETA revision records its canonical target and before/after values")
    func etaRevisionRecordsBeforeAndAfterValues() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(at: fixture.startedAt, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let target = NavigationTimingTargetKey(
            legID: fixture.snapshot.legIDs[0],
            kind: .destination,
            targetID: UUID()
        )

        let transition = try await engine.commit(.reviseETA(
            target: target,
            plannedElapsedSeconds: 600,
            committedSeconds: 720,
            at: fixture.startedAt.addingTimeInterval(30),
            elapsed: .seconds(30),
            eventID: UUID()
        ))

        #expect(transition.flight.committedPilotETA(targetKey: target) == 720)
        let event = try #require(try await store.readSnapshot(id: started.recording.id).events.last)
        #expect(event.payload == .etaRevised(target: target, priorSeconds: nil, committedSeconds: 720))

        await #expect(throws: Flight.TransitionError.self) {
            try await engine.commit(.reviseETA(
                target: target,
                plannedElapsedSeconds: 600,
                committedSeconds: 720,
                at: fixture.startedAt.addingTimeInterval(31),
                elapsed: .seconds(31),
                eventID: UUID()
            ))
        }
        #expect(try await store.readSnapshot(id: started.recording.id).events.count == 3)
    }

    @Test("Committed heading revision records its leg and before/after values")
    func headingRevisionRecordsBeforeAndAfterValues() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(at: fixture.startedAt, recordingID: UUID(), eventIDs: [UUID(), UUID()])

        _ = try await engine.commit(.reviseHeading(
            legID: fixture.snapshot.legIDs[0],
            baselineDegrees: 74,
            committedDegrees: 82,
            at: fixture.startedAt.addingTimeInterval(30),
            elapsed: .seconds(30),
            eventID: UUID()
        ))

        let event = try #require(try await store.readSnapshot(id: started.recording.id).events.last)
        #expect(event.payload == .headingRevised(legID: fixture.snapshot.legIDs[0], priorDegrees: 74, committedDegrees: 82))
    }

    @Test("Undo appends a linked event and preserves the original reach event")
    func undoLinksWithoutRewritingOriginal() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(at: fixture.startedAt, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let reachID = UUID()
        _ = try await engine.commit(.reachCurrentWaypoint(
            orderedActiveLegPointKeys: [],
            at: fixture.startedAt.addingTimeInterval(30),
            elapsed: .seconds(30),
            eventIDs: [reachID, UUID()]
        ))
        let undoID = UUID()

        _ = try await engine.commit(.undoReach(
            originalEventID: reachID,
            at: fixture.startedAt.addingTimeInterval(31),
            elapsed: .seconds(31),
            eventID: undoID
        ))

        let events = try await store.readSnapshot(id: started.recording.id).events
        #expect(events.contains { $0.id == reachID && $0.payload == .waypointReached(legID: fixture.snapshot.legIDs[0]) })
        #expect(events.last?.payload == .reachUndone(originalEventID: reachID))
    }

    @Test("Position Check request survives acquisition failure and successful end stores only the qualified sample")
    func positionCheckRequestAndOutcomesAreDurable() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        let started = try await engine.promoteForStartLeg(at: fixture.startedAt, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        _ = try await engine.commit(.requestPositionCheck(at: fixture.startedAt, elapsed: .zero, eventID: UUID()))
        _ = try await engine.commit(.endPositionCheck(
            outcome: .endedWithoutDisclosure,
            at: fixture.startedAt.addingTimeInterval(10),
            elapsed: .seconds(10),
            eventID: UUID()
        ))
        let sample = PositionCheckRecordedSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.8),
            observedAt: fixture.startedAt.addingTimeInterval(20),
            horizontalAccuracyMeters: 8
        )
        _ = try await engine.commit(.requestPositionCheck(at: fixture.startedAt.addingTimeInterval(20), elapsed: .seconds(20), eventID: UUID()))
        _ = try await engine.commit(.endPositionCheck(
            outcome: .disclosed(sample: sample),
            at: fixture.startedAt.addingTimeInterval(21),
            elapsed: .seconds(21),
            eventID: UUID()
        ))

        let payloads = try await store.readSnapshot(id: started.recording.id).events.map(\.payload)
        #expect(payloads.suffix(4) == [
            .positionCheckRequested,
            .positionCheckEnded(outcome: .endedWithoutDisclosure),
            .positionCheckRequested,
            .positionCheckEnded(outcome: .disclosed(sample: sample))
        ])
    }

    private func makeFixture(legCount: Int = 1) -> (flight: Flight, snapshot: RecordedFlightPlanSnapshot, startedAt: Date) {
        let planID = UUID()
        let legIDs = (0..<legCount).map { _ in UUID() }
        return (
            Flight(
                flightPlanID: planID,
                legIDs: legIDs,
                activeLegIndex: 0,
                executionMode: .noWind
            ),
            RecordedFlightPlanSnapshot(id: planID, title: "Training flight", legIDs: legIDs),
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
