import Foundation
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Flight recording application coordination")
struct FlightRecordingCoordinatorTests {
    @Test("Loaded Flight arms capture and publishes prepared without creating a package")
    func loadedFlightArmsCapture() async {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let coordinator = FlightRecordingCoordinator(store: store)

        await coordinator.arm(flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)

        #expect(coordinator.status == .prepared)
        #expect(await store.packages().isEmpty)
    }

    @Test("Ground movement remains hidden and timeout leaves no incomplete package")
    func provisionalMovementRemainsHidden() async {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let clock = ManualMonotonicClock()
        let coordinator = FlightRecordingCoordinator(store: store, detectorPolicy: .fixture, monotonicNow: clock.now)
        await coordinator.arm(flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)

        await coordinator.handleLocationEvent(.sample(sample(speed: 4, altitude: 30, at: fixture.startedAt), receivedAt: fixture.startedAt))
        clock.advance(by: .seconds(5))
        await coordinator.handleLocationEvent(.sample(sample(speed: 4, altitude: 30, at: fixture.startedAt.addingTimeInterval(5)), receivedAt: fixture.startedAt.addingTimeInterval(5)))

        #expect(coordinator.status == .prepared)
        #expect(await store.packages().isEmpty)
        #expect(coordinator.snapshot.flight == fixture.flight)

        clock.advance(by: .seconds(30))
        await coordinator.handleLocationEvent(.sample(sample(speed: 0, altitude: 30, at: fixture.startedAt.addingTimeInterval(35)), receivedAt: fixture.startedAt.addingTimeInterval(35)))
        #expect(await store.packages().isEmpty)
        #expect(coordinator.snapshot.recording == nil)
    }

    @Test("Credible takeoff promotes the complete buffer without changing navigation")
    func takeoffPromotesBufferedRecording() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let clock = ManualMonotonicClock()
        let coordinator = FlightRecordingCoordinator(store: store, detectorPolicy: .fixture, monotonicNow: clock.now)
        await coordinator.arm(flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)

        await coordinator.handleLocationEvent(.sample(sample(speed: 4, altitude: 30, at: fixture.startedAt), receivedAt: fixture.startedAt))
        clock.advance(by: .seconds(5))
        await coordinator.handleLocationEvent(.sample(sample(speed: 4, altitude: 30, at: fixture.startedAt.addingTimeInterval(5)), receivedAt: fixture.startedAt.addingTimeInterval(5)))
        clock.advance(by: .seconds(1))
        await coordinator.handleLocationEvent(.sample(sample(speed: 24, altitude: 55, at: fixture.startedAt.addingTimeInterval(6)), receivedAt: fixture.startedAt.addingTimeInterval(6)))
        clock.advance(by: .seconds(5))
        await coordinator.handleLocationEvent(.sample(sample(speed: 24, altitude: 60, at: fixture.startedAt.addingTimeInterval(11)), receivedAt: fixture.startedAt.addingTimeInterval(11)))

        let package = try #require(await store.packages().first)
        guard case .available(let snapshot) = package else {
            Issue.record("Expected an available promoted package")
            return
        }
        #expect(snapshot.trackSegments.flatMap(\.samples).count == 4)
        #expect(snapshot.recording.navigationState == .ready)
        #expect(snapshot.recording.physicalState == .airborne)
        #expect(coordinator.snapshot.flight == fixture.flight)
        #expect(coordinator.status == .recording)
    }

    @Test("Already-airborne launch publishes an explicit partial recording")
    func airborneLaunchPublishesPartialStatus() async {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let clock = ManualMonotonicClock()
        let coordinator = FlightRecordingCoordinator(store: store, detectorPolicy: .fixture, monotonicNow: clock.now)
        await coordinator.arm(flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)

        await coordinator.handleLocationEvent(.sample(sample(speed: 24, altitude: 500, at: fixture.startedAt), receivedAt: fixture.startedAt))
        clock.advance(by: .seconds(8))
        await coordinator.handleLocationEvent(.sample(sample(speed: 25, altitude: 505, at: fixture.startedAt.addingTimeInterval(8)), receivedAt: fixture.startedAt.addingTimeInterval(8)))

        #expect(coordinator.status == .partialRecording)
        #expect(await store.packages().count == 1)
        #expect(coordinator.snapshot.flight == fixture.flight)
    }

    @Test("Start Leg after automatic promotion uses the existing recording")
    func startLegAfterAutomaticPromotion() async throws {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore()
        let clock = ManualMonotonicClock()
        let coordinator = FlightRecordingCoordinator(store: store, detectorPolicy: .fixture, monotonicNow: clock.now)
        await coordinator.arm(flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        await coordinator.handleLocationEvent(.sample(sample(speed: 4, altitude: 30, at: fixture.startedAt), receivedAt: fixture.startedAt))
        clock.advance(by: .seconds(5))
        await coordinator.handleLocationEvent(.sample(sample(speed: 4, altitude: 30, at: fixture.startedAt.addingTimeInterval(5)), receivedAt: fixture.startedAt.addingTimeInterval(5)))
        clock.advance(by: .seconds(1))
        await coordinator.handleLocationEvent(.sample(sample(speed: 24, altitude: 55, at: fixture.startedAt.addingTimeInterval(6)), receivedAt: fixture.startedAt.addingTimeInterval(6)))
        clock.advance(by: .seconds(5))
        await coordinator.handleLocationEvent(.sample(sample(speed: 24, altitude: 60, at: fixture.startedAt.addingTimeInterval(11)), receivedAt: fixture.startedAt.addingTimeInterval(11)))
        let recordingID = try #require(coordinator.snapshot.recording?.id)

        let transition = try await coordinator.startLeg(
            flight: fixture.flight,
            flightPlanSnapshot: fixture.snapshot,
            at: fixture.startedAt.addingTimeInterval(12),
            recordingID: UUID(),
            eventIDs: [UUID()]
        )

        #expect(transition.recording.id == recordingID)
        #expect(transition.flight.legState == .active)
        #expect(await store.packages().count == 1)
    }

    @Test("Failed automatic promotion never publishes a non-durable recording")
    func automaticPromotionFailureRemainsPrepared() async {
        let fixture = makeFixture()
        let store = InMemoryFlightRecordingStore(failure: .create)
        let clock = ManualMonotonicClock()
        let coordinator = FlightRecordingCoordinator(store: store, detectorPolicy: .fixture, monotonicNow: clock.now)
        await coordinator.arm(flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        await coordinator.handleLocationEvent(.sample(sample(speed: 4, altitude: 30, at: fixture.startedAt), receivedAt: fixture.startedAt))
        clock.advance(by: .seconds(5))
        await coordinator.handleLocationEvent(.sample(sample(speed: 4, altitude: 30, at: fixture.startedAt.addingTimeInterval(5)), receivedAt: fixture.startedAt.addingTimeInterval(5)))
        clock.advance(by: .seconds(1))
        await coordinator.handleLocationEvent(.sample(sample(speed: 24, altitude: 55, at: fixture.startedAt.addingTimeInterval(6)), receivedAt: fixture.startedAt.addingTimeInterval(6)))
        clock.advance(by: .seconds(5))
        await coordinator.handleLocationEvent(.sample(sample(speed: 24, altitude: 60, at: fixture.startedAt.addingTimeInterval(11)), receivedAt: fixture.startedAt.addingTimeInterval(11)))

        #expect(coordinator.snapshot.recording == nil)
        #expect(coordinator.status == .prepared)
        #expect(coordinator.lastError == .automaticPromotionPersistenceFailed)
        #expect(await store.packages().isEmpty)
    }

    @Test("Buffered GPS, gap, and resumed delivery publish distinct recording states")
    func gpsLifecyclePresentation() async throws {
        let fixture = makeFixture()
        let coordinator = FlightRecordingCoordinator(store: InMemoryFlightRecordingStore())
        let first = sample(at: fixture.startedAt)
        let resumed = sample(at: fixture.startedAt.addingTimeInterval(10))
        await coordinator.arm(flight: fixture.flight, flightPlanSnapshot: fixture.snapshot)
        await coordinator.handleLocationEvent(.sample(first, receivedAt: first.observedAt))
        _ = try await coordinator.startLeg(
            flight: fixture.flight,
            flightPlanSnapshot: fixture.snapshot,
            at: fixture.startedAt,
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )
        #expect(coordinator.status == .recording)
        await coordinator.handleLocationEvent(.signalLost)
        #expect(coordinator.status == .gpsGap)
        await coordinator.handleLocationEvent(.sample(resumed, receivedAt: resumed.observedAt))
        #expect(coordinator.status == .gpsResumed)
    }
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

    private func sample(at date: Date) -> AircraftLocationSample {
        sample(speed: 10, altitude: nil, at: date)
    }

    private func sample(speed: Double, altitude: Double?, at date: Date) -> AircraftLocationSample {
        AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32, longitudeDegrees: 34.8),
            observedAt: date,
            horizontalAccuracyMeters: 10,
            altitudeMeters: altitude,
            verticalAccuracyMeters: altitude == nil ? nil : 5,
            trueCourseDegrees: 90,
            courseAccuracyDegrees: 5,
            groundSpeedMetersPerSecond: speed,
            speedAccuracyMetersPerSecond: 0.5
        )
    }
}

@MainActor
private final class ManualMonotonicClock {
    private var value = Duration.zero

    var now: @MainActor @Sendable () -> Duration {
        { [weak self] in self?.value ?? .zero }
    }

    func advance(by duration: Duration) {
        value += duration
    }
}

private extension PhysicalFlightDetectionPolicy {
    static let fixture = PhysicalFlightDetectionPolicy(
        maximumHorizontalAccuracyMeters: 50,
        maximumSpeedAccuracyMetersPerSecond: 2,
        groundMovementSpeedMetersPerSecond: 3,
        groundMovementWindow: .seconds(5),
        candidateInterruptionTolerance: .seconds(1),
        takeoffSpeedMetersPerSecond: 20,
        takeoffAltitudeGainMeters: 20,
        takeoffWindow: .seconds(5),
        provisionalTimeout: .seconds(30),
        airborneLaunchWindow: .seconds(8)
    )
}
