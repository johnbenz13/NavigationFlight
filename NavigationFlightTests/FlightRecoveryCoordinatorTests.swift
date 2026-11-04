import Foundation
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Flight recovery coordination")
struct FlightRecoveryCoordinatorTests {
    @Test("Bootstrap presents every recoverable package without selecting one")
    func bootstrapPresentsRecoverablePackagesWithoutSelection() async throws {
        let first = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")),
            startedAt: Date(timeIntervalSince1970: 2_000)
        )
        let second = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")),
            startedAt: Date(timeIntervalSince1970: 1_000)
        )
        let unsupportedID = try #require(UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000003"))
        let store = InMemoryFlightRecordingStore(packageResults: [
            .available(second),
            .corrupt(id: nil),
            .unsupported(id: unsupportedID, schemaVersion: 99),
            .available(first)
        ])
        let coordinator = FlightRecoveryCoordinator(store: store)

        await coordinator.bootstrap()

        #expect(coordinator.state == .selectionRequired([
            RecoveryCandidate(
                recordingID: first.recording.id,
                flightPlanTitle: first.recording.flightPlanSnapshot.title,
                startedAt: first.recording.startedAt
            ),
            RecoveryCandidate(
                recordingID: second.recording.id,
                flightPlanTitle: second.recording.flightPlanSnapshot.title,
                startedAt: second.recording.startedAt
            )
        ]))
        #expect(coordinator.unavailablePackages == [
            .unsupported(id: unsupportedID, schemaVersion: 99),
            .corrupt(id: nil)
        ])
        #expect(coordinator.selectedRecordingID == nil)
    }

    @Test("Bootstrap does not offer Continue for a package without an immutable Flight Plan")
    func bootstrapRejectsPackageWithoutImmutableFlightPlan() async throws {
        let snapshot = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "ACACACAC-0000-0000-0000-000000000008")),
            startedAt: Date(timeIntervalSince1970: 2_000),
            includesSourceData: false
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(store: store)

        await coordinator.bootstrap()

        #expect(coordinator.state == .failure(.corrupt(id: snapshot.recording.id)))
        #expect(coordinator.unavailablePackages == [.corrupt(id: snapshot.recording.id)])
    }

    @Test("Ending a recovery appends its incomplete closure before removing the launch gate")
    func endAsIncompleteIsDurable() async throws {
        let snapshot = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "DDDDDDDD-0000-0000-0000-000000000004")),
            startedAt: Date(timeIntervalSince1970: 1_000)
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(store: store)
        await coordinator.bootstrap()

        try await coordinator.endAsIncomplete(
            id: snapshot.recording.id,
            at: Date(timeIntervalSince1970: 1_120),
            elapsed: .seconds(120),
            eventIDs: [
                #require(UUID(uuidString: "EEEEEEEE-0000-0000-0000-000000000005")),
                #require(UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000006"))
            ]
        )

        let stored = try await store.readSnapshot(id: snapshot.recording.id)
        #expect(stored.events.suffix(2).map(\.payload) == [
            .manualEnd,
            .recordingClosed(outcome: .incomplete, cause: .manual)
        ])
        #expect(stored.recording.closure?.outcome == .incomplete)
        #expect(coordinator.state == .none)
    }

    @Test("Recovery elapsed time rebases from persisted monotonic time, not wall clock")
    func elapsedTimeUsesPersistedMonotonicBasis() async throws {
        let snapshot = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "ABABABAB-0000-0000-0000-000000000007")),
            startedAt: Date(timeIntervalSince1970: 50_000)
        )
        let uptime = MutableUptime(value: 10)
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            monotonicUptime: { uptime.value }
        )

        await coordinator.bootstrap()
        uptime.value = 17.5

        #expect(coordinator.rebasedElapsed(for: snapshot.recording.id) == .seconds(7.5))
    }

    @Test("Continue restores the captured Flight Plan and active leg before opening Cockpit")
    func continueRestoresCapturedPlanAndActiveLeg() async throws {
        let sourceData = try fixtureData()
        let plan = try FPLNavDecoder().decode(sourceData)
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let flight = Flight(
            id: UUID(),
            flightPlanID: plan.id,
            legIDs: plan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: try #require(plan.plannedNavigation.plannedNavigation?.defaultMode)
        )
        let promotion = try FlightRecording.promoteForStartLeg(
            id: UUID(),
            flightID: flight.id,
            flightPlanSnapshot: RecordedFlightPlanSnapshot(
                id: plan.id,
                title: plan.title,
                legIDs: plan.legs.map(\.id),
                sourceData: sourceData
            ),
            legID: plan.legs[0].id,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()]
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(
            FlightRecordingReadSnapshot(recording: promotion.recording, events: promotion.events)
        )])
        let coordinator = FlightRecoveryCoordinator(store: store)
        await coordinator.bootstrap()

        let recovered = try await coordinator.continueFlight(
            id: promotion.recording.id,
            at: startedAt.addingTimeInterval(120),
            elapsed: .seconds(120),
            eventID: UUID()
        )

        #expect(recovered.flightPlan == plan)
        #expect(recovered.flight.id == flight.id)
        #expect(recovered.flight.activeLegIndex == 0)
        #expect(recovered.flight.legState == .active)
        #expect(recovered.flight.legStartedAt == startedAt)
        var appState = AppFeatureState(selectedAppSection: .settings)
        appState.restoreRecoveredFlight(recovered, sourceData: sourceData)
        #expect(appState.selectedAppSection == .cockpit)
        #expect(appState.cockpit.flight == recovered.flight)
        #expect(appState.cockpit.flightPlan == plan)
        #expect(appState.cockpit.pendingReachUndo == nil)
        #expect(appState.positionCheckPermissionEducation == .completed)
        let runtimeCoordinator = FlightRecordingCoordinator(store: store)
        await runtimeCoordinator.restore(recovered)
        #expect(runtimeCoordinator.snapshot.flight == recovered.flight)
        #expect(runtimeCoordinator.snapshot.recording == recovered.recording)
        #expect(runtimeCoordinator.status == .recordingGPSUnavailable)
        let stored = try await store.readSnapshot(id: promotion.recording.id)
        #expect(stored.events.last?.payload == .recoveryContinued)
        #expect(coordinator.state == .none)
    }

    @Test("Replay restores committed navigation facts and excludes transient editors and undo")
    func replayRestoresCommittedNavigationFacts() async throws {
        let sourceData = try fixtureData()
        let plan = try FPLNavDecoder().decode(sourceData)
        let planned = try #require(plan.plannedNavigation.plannedNavigation)
        let startedAt = Date(timeIntervalSince1970: 2_000)
        let finalLegIndex = plan.legs.index(before: plan.legs.endIndex)
        let flight = Flight(
            id: UUID(),
            flightPlanID: plan.id,
            legIDs: plan.legs.map(\.id),
            activeLegIndex: finalLegIndex,
            executionMode: planned.defaultMode
        )
        let snapshot = RecordedFlightPlanSnapshot(
            id: plan.id,
            title: plan.title,
            legIDs: plan.legs.map(\.id),
            sourceData: sourceData
        )
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(
            store: store,
            flight: flight,
            flightPlanSnapshot: snapshot
        )
        var committed = try await engine.promoteForStartLeg(
            at: startedAt,
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )
        committed = try await engine.commit(.identifyDestination(
            at: startedAt.addingTimeInterval(10),
            elapsed: .seconds(10),
            eventID: UUID()
        ))
        let legID = plan.legs[finalLegIndex].id
        let destinationTarget = NavigationTimingTargetKey(
            legID: legID,
            kind: .destination,
            targetID: plan.legs[finalLegIndex].arrival.id
        )
        committed = try await engine.commit(.reviseETA(
            target: destinationTarget,
            plannedElapsedSeconds: 600,
            committedSeconds: 720,
            at: startedAt.addingTimeInterval(20),
            elapsed: .seconds(20),
            eventID: UUID()
        ))
        committed = try await engine.commit(.reviseHeading(
            legID: legID,
            baselineDegrees: 90,
            committedDegrees: 105,
            at: startedAt.addingTimeInterval(30),
            elapsed: .seconds(30),
            eventID: UUID()
        ))
        let pointKeys = plan.identificationPoints
            .filter { $0.legID == legID }
            .map { IdentificationPointKey(legID: legID, identificationPointID: $0.id) }
        for (index, key) in pointKeys.enumerated() {
            committed = try await engine.commit(.reachIdentificationPoint(
                key: key,
                orderedActiveLegPointKeys: pointKeys,
                at: startedAt.addingTimeInterval(TimeInterval(40 + index)),
                elapsed: .seconds(40 + index),
                eventID: UUID(),
                nextETATarget: nil,
                nextETAPlannedElapsedSeconds: nil
            ))
        }
        committed = try await engine.commit(.reachCurrentWaypoint(
            orderedActiveLegPointKeys: pointKeys,
            at: startedAt.addingTimeInterval(100),
            elapsed: .seconds(100),
            eventIDs: [UUID(), UUID()]
        ))
        committed = try await engine.commit(.completeNavigation(
            at: startedAt.addingTimeInterval(110),
            elapsed: .seconds(110),
            eventID: UUID()
        ))
        let persisted = try await store.readSnapshot(id: committed.recording.id)
        let recovery = FlightRecoveryCoordinator(store: store)
        await recovery.bootstrap()

        let recovered = try await recovery.continueFlight(
            id: committed.recording.id,
            at: startedAt.addingTimeInterval(120),
            elapsed: .seconds(120),
            eventID: UUID()
        )

        #expect(recovered.flight == committed.flight)
        #expect(recovered.recording.physicalState == persisted.recording.physicalState)
        #expect(recovered.recording.navigationState == .complete)
        #expect(recovered.flight.pilotETAState(targetKey: destinationTarget)?.isEditing == false)
        #expect(recovered.flight.pilotHeadingState(for: legID)?.isEditing == false)
        let runtime = FlightRecordingCoordinator(store: store)
        await runtime.restore(recovered)
        try await runtime.prepareForFlightReplacement(
            at: startedAt.addingTimeInterval(130),
            eventIDs: [UUID(), UUID()]
        )
        let displaced = try await store.readSnapshot(id: recovered.recording.id)
        #expect(displaced.recording.closure?.outcome == .incomplete)
    }

    private func recoveryFixture(
        recordingID: UUID,
        startedAt: Date,
        includesSourceData: Bool = true
    ) throws -> FlightRecordingReadSnapshot {
        let sourceData = try fixtureData()
        let plan = try FPLNavDecoder().decode(sourceData)
        let flightID = UUID()
        let snapshot = RecordedFlightPlanSnapshot(
            id: plan.id,
            title: plan.title,
            legIDs: plan.legs.map(\.id),
            sourceData: includesSourceData ? sourceData : nil
        )
        let promotion = try FlightRecording.promoteForStartLeg(
            id: recordingID,
            flightID: flightID,
            flightPlanSnapshot: snapshot,
            legID: plan.legs[0].id,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()]
        )
        return FlightRecordingReadSnapshot(
            recording: promotion.recording,
            events: promotion.events
        )
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: FlightRecoveryFixtureLocator.self)
        let nested = bundle.url(
            forResource: "representative-v7",
            withExtension: "fplnav",
            subdirectory: "Fixtures/FPLNav/V7/Official"
        )
        return try Data(contentsOf: #require(
            nested ?? bundle.url(forResource: "representative-v7", withExtension: "fplnav")
        ))
    }
}

private final class FlightRecoveryFixtureLocator {}

@MainActor
private final class MutableUptime {
    var value: TimeInterval

    init(value: TimeInterval) {
        self.value = value
    }
}
