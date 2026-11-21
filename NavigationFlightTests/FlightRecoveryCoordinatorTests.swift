import Foundation
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Flight recovery coordination")
struct FlightRecoveryCoordinatorTests {
    @Test("Bootstrap expires a recording whose captured recovery window elapsed")
    func bootstrapExpiresStaleRecording() async throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "10101010-0000-0000-0000-000000000001")),
            startedAt: startedAt
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(301) },
            defaultRecoveryWindow: 300
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .reconciledExpired(count: 1))
        let stored = try await store.readSnapshot(id: snapshot.recording.id)
        #expect(stored.recording.closure?.outcome == .incomplete)
        #expect(stored.recording.closure?.cause == .recoveryExpired)
        #expect(stored.recording.closure?.closedAt == startedAt)
    }

    @Test("The exact recovery cutoff is expired and cannot be continued")
    func exactCutoffIsExpired() async throws {
        let startedAt = Date(timeIntervalSince1970: 2_000)
        let snapshot = try recoveryFixture(recordingID: UUID(), startedAt: startedAt)
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(300) },
            defaultRecoveryWindow: 300
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .reconciledExpired(count: 1))
    }

    @Test("A future durable timestamp fails closed")
    func futureEvidenceFailsClosed() async throws {
        let startedAt = Date(timeIntervalSince1970: 3_000)
        let snapshot = try recoveryFixture(recordingID: UUID(), startedAt: startedAt)
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(-1) },
            defaultRecoveryWindow: 300
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .failure(.corrupt(id: snapshot.recording.id)))
    }

    @Test("Continue revalidates freshness at command time")
    func continueRevalidatesFreshness() async throws {
        let startedAt = Date(timeIntervalSince1970: 4_000)
        let snapshot = try recoveryFixture(recordingID: UUID(), startedAt: startedAt)
        let clock = MutableDate(value: startedAt.addingTimeInterval(299))
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { clock.value },
            defaultRecoveryWindow: 300
        )
        await coordinator.bootstrap()
        guard case .single = coordinator.state else {
            Issue.record("Expected a fresh recovery candidate")
            return
        }
        clock.value = startedAt.addingTimeInterval(300)

        await #expect(throws: FlightRecoveryError.recoveryExpired) {
            _ = try await coordinator.continueFlight(
                id: snapshot.recording.id,
                at: clock.value,
                elapsed: .seconds(300),
                eventID: UUID()
            )
        }
    }

    @Test("A durable checkpoint extends eligibility without relaunch refreshing it")
    func checkpointDefinesFreshness() async throws {
        let startedAt = Date(timeIntervalSince1970: 5_000)
        let original = try recoveryFixture(recordingID: UUID(), startedAt: startedAt)
        let checkpoint = startedAt.addingTimeInterval(250)
        let snapshot = FlightRecordingReadSnapshot(
            recording: original.recording.restoringRecoveryCheckpoint(at: checkpoint),
            events: original.events
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(500) }
        )

        await coordinator.bootstrap()

        guard case .single(let candidate) = coordinator.state else {
            Issue.record("Expected checkpoint-backed recovery")
            return
        }
        #expect(candidate.id == snapshot.recording.id)
    }

    @Test("Each Flight keeps the recovery window captured when recording began")
    func capturedRecoveryWindowControlsEligibility() async throws {
        let sourceData = try fixtureData()
        let plan = try FPLNavDecoder().decode(sourceData)
        let startedAt = Date(timeIntervalSince1970: 6_000)
        let promotion = try FlightRecording.promoteForStartLeg(
            id: UUID(),
            flightID: UUID(),
            flightPlanSnapshot: RecordedFlightPlanSnapshot(
                id: plan.id,
                title: plan.title,
                legIDs: plan.legs.map(\.id),
                sourceData: sourceData
            ),
            legID: plan.legs[0].id,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()],
            recoveryWindowSeconds: 60
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(
            FlightRecordingReadSnapshot(recording: promotion.recording, events: promotion.events)
        )])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(60) },
            defaultRecoveryWindow: 300
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .reconciledExpired(count: 1))
    }

    @Test("Bootstrap presents every recoverable package without selecting one")
    func bootstrapPresentsRecoverablePackagesWithoutSelection() async throws {
        let first = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")),
            startedAt: Date(timeIntervalSince1970: 2_000)
        )
        let second = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")),
            startedAt: Date(timeIntervalSince1970: 1_900)
        )
        let unsupportedID = try #require(UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000003"))
        let store = InMemoryFlightRecordingStore(packageResults: [
            .available(second),
            .corrupt(id: nil),
            .unsupported(id: unsupportedID, schemaVersion: 99),
            .available(first)
        ])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { Date(timeIntervalSince1970: 2_001) }
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .selectionRequired([
            RecoveryCandidate(
                recordingID: first.recording.id,
                flightPlanTitle: first.recording.flightPlanSnapshot.title,
                startedAt: first.recording.startedAt,
                lastActivityAt: first.recording.startedAt,
                expiresAt: first.recording.startedAt.addingTimeInterval(300)
            ),
            RecoveryCandidate(
                recordingID: second.recording.id,
                flightPlanTitle: second.recording.flightPlanSnapshot.title,
                startedAt: second.recording.startedAt,
                lastActivityAt: second.recording.startedAt,
                expiresAt: second.recording.startedAt.addingTimeInterval(300)
            )
        ]))
        #expect(coordinator.unavailablePackages == [
            .unsupported(id: unsupportedID, schemaVersion: 99),
            .corrupt(id: nil)
        ])
        #expect(coordinator.selectedRecordingID == nil)

        _ = try await coordinator.continueFlight(
            id: first.recording.id,
            at: Date(timeIntervalSince1970: 2_002),
            elapsed: .seconds(2),
            eventID: UUID()
        )
        let superseded = try await store.readSnapshot(id: second.recording.id)
        #expect(superseded.recording.closure?.cause == .supersededDuringRecovery)
    }

    @Test("Bootstrap does not offer Continue for a package without an immutable Flight Plan")
    func bootstrapRejectsPackageWithoutImmutableFlightPlan() async throws {
        let snapshot = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "ACACACAC-0000-0000-0000-000000000008")),
            startedAt: Date(timeIntervalSince1970: 2_000),
            includesSourceData: false
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { Date(timeIntervalSince1970: 2_001) }
        )

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
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { Date(timeIntervalSince1970: 1_001) }
        )
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
        #expect(stored.events.last?.payload == .recordingClosed(
            outcome: .incomplete,
            cause: .endedDuringRecovery
        ))
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
            monotonicUptime: { uptime.value },
            now: { Date(timeIntervalSince1970: 50_001) }
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
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(119) }
        )
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
        let startedAt = Date(timeIntervalSince1970: 2_000)
        let finalLegIndex = plan.legs.index(before: plan.legs.endIndex)
        let flight = Flight(
            id: UUID(),
            flightPlanID: plan.id,
            legIDs: plan.legs.map(\.id),
            activeLegIndex: finalLegIndex,
            executionMode: .noWind
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
        let recovery = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(119) }
        )
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

    @Test("Schema 3 captures checklist identity, review and explicit absence through disk recovery", arguments: StartChecklistSelection.allCases)
    func checklistDiskRecovery(_ selection: StartChecklistSelection) async throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskFlightRecordingStore(rootDirectory: directory)
        let engine = FlightRecordingEngine(store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: plan.legs.map(\.id), sourceData: source))
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(),
                                                         eventIDs: [UUID(), UUID()], checklistSelection: selection)
        var context = try #require(started.cockpitContext)
        let legID = flight.legIDs[0]
        if selection != .none { context.checklists[legID]?.reviewState = .noted }
        context.checklists[legID]?.presentationState = .collapsed
        try await engine.recordPresentation(context, at: time.addingTimeInterval(1))
        let snapshot = try await store.readSnapshot(id: started.recording.id)
        #expect(snapshot.recording.sourceSchemaVersion == 3)
        let recovery = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(2) })
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(id: started.recording.id, at: time.addingTimeInterval(2), elapsed: .seconds(2), eventID: UUID())
        #expect(recovered.cockpitContext == context)
        var cockpit = CockpitFeatureState()
        cockpit.restore(flightPlan: plan, flight: recovered.flight, sourceData: source, cockpitContext: recovered.cockpitContext)
        #expect(cockpit.legStartChecklists[legID]?.selection == selection)
        #expect((cockpit.activeLegStartChecklist == nil) == (selection == .none))
    }

    @Test("Queued presentation snapshots cannot replace arrival or undo context on disk",
          .timeLimit(.minutes(1)), arguments: StartChecklistSelection.allCases, [false, true])
    func queuedPresentationRecovery(_ selection: StartChecklistSelection, undo: Bool) async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let disk = DiskFlightRecordingStore(rootDirectory: directory)
        let store = SuspendedPresentationRecordingStore(base: disk)
        let engine = FlightRecordingEngine(store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: plan.legs.map(\.id), sourceData: source))
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(),
            eventIDs: [UUID(), UUID()], checklistSelection: selection)
        var original = try #require(started.cockpitContext)
        let firstID = flight.legIDs[0]
        if selection != .none { original.checklists[firstID]?.reviewState = .noted }
        original.checklists[firstID]?.presentationState = .collapsed
        try await engine.recordPresentation(original, at: time.addingTimeInterval(1))
        var stale = try #require(started.cockpitContext)
        stale.areDriftLinesVisible = false
        let arrival = RecordedNavigationCommand.reachCurrentWaypoint(orderedActiveLegPointKeys: [],
            at: time.addingTimeInterval(2), elapsed: .seconds(2), eventIDs: [UUID(), UUID()])
        let successor: StartChecklistSelection = selection == .none ? .establishHeading : .none
        let command: RecordedNavigationCommand
        if undo {
            let arrived = try await engine.commit(arrival, context: original, checklistSelection: successor)
            // Both the successor snapshot and a pre-arrival snapshot are stale after undo.
            stale = try #require(arrived.cockpitContext)
            stale.areDriftLinesVisible = false
            command = .undoReach(originalEventID: arrived.eventIDs[0], restoredFlight: started.flight,
                at: time.addingTimeInterval(3), elapsed: .seconds(3), eventID: UUID())
        } else {
            command = arrival
        }
        await store.suspendNextAppend()
        let navigation = Task { try await engine.commit(command, context: original, checklistSelection: successor) }
        await store.waitUntilSuspended()
        let retained = stale
        let presentation = Task { try await engine.recordPresentation(retained, at: time.addingTimeInterval(4)) }
        // Observe the actual gate waiter rather than relying on scheduling or a delay.
        while await engine.queuedMutationCount == 0 { await Task.yield() }
        await store.release()
        let committed = try await navigation.value
        #expect(try await presentation.value == false)
        let expected = try #require(committed.cockpitContext)
        #expect(expected.navigationGeneration != original.navigationGeneration)
        // Even matching pre-arrival values must not regain authority after undo (ABA).
        if undo {
            #expect(try await engine.recordPresentation(try #require(started.cockpitContext),
                at: time.addingTimeInterval(5)) == false)
        }
        let stored = try await disk.readSnapshot(id: started.recording.id)
        #expect(stored.events.last?.cockpitContext == expected)
        #expect(stored.events.last?.payload != .cockpitPresentationChanged)
        if undo {
            #expect(expected == original)
            #expect(expected.checklists[flight.legIDs[1]] == nil)
        } else {
            #expect(expected.checklists[flight.legIDs[1]]?.selection == successor)
        }
        // A current-generation UI edit still persists through the projection.
        var cockpit = CockpitFeatureState()
        cockpit.restore(flightPlan: plan, flight: committed.flight, sourceData: source, cockpitContext: expected)
        cockpit.toggleDriftLines()
        let current = try #require(cockpit.recordingCockpitContext)
        #expect(current.navigationGeneration == expected.navigationGeneration)
        #expect(try await engine.recordPresentation(current, at: time.addingTimeInterval(6)))
        let recovery = FlightRecoveryCoordinator(store: DiskFlightRecordingStore(rootDirectory: directory),
            now: { time.addingTimeInterval(7) })
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(id: started.recording.id,
            at: time.addingTimeInterval(7), elapsed: .seconds(7), eventID: UUID())
        #expect(recovered.flight.activeLegIndex == committed.flight.activeLegIndex)
        #expect(recovered.cockpitContext == current)
        #expect(recovered.cockpitContext?.checklists == expected.checklists)
    }

    @Test("Mismatched and missing required schema 3 context fail recovery", arguments: [false, true])
    func corruptChecklistContext(_ missing: Bool) async throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 20_000)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: plan.legs.map(\.id), sourceData: source))
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let snapshot = try await store.readSnapshot(id: started.recording.id)
        var events = snapshot.events
        for index in events.indices {
            events[index].cockpitContext = missing ? nil : RecordingCockpitContext(flightID: UUID(), checklists: [:], areDriftLinesVisible: true)
        }
        let corruptStore = InMemoryFlightRecordingStore(packageResults: [.available(.init(recording: snapshot.recording, events: events))])
        let recovery = FlightRecoveryCoordinator(store: corruptStore, now: { time.addingTimeInterval(1) })
        await recovery.bootstrap()
        #expect(recovery.state == .failure(.corrupt(id: snapshot.recording.id)))
    }

    @Test("Captured choices survive rerenders and never fabricate acknowledgements", arguments: StartChecklistSelection.allCases)
    func capturedStateAndAdapter(_ selection: StartChecklistSelection) throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        var cockpit = CockpitFeatureState()
        try cockpit.accept(plan)
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1000), checklistSelection: selection)
        let flight = try #require(cockpit.flight)
        let captured = try #require(cockpit.legStartChecklists[flight.legIDs[0]])
        let rendered = try CockpitPresentationAdapter().makeLegStartChecklist(flightPlan: plan, flight: flight, captured: captured)
        #expect(rendered?.template.id == (selection == .none ? nil : selection.rawValue))
        cockpit.installCommittedFlight(flight)
        #expect(cockpit.legStartChecklists[flight.legIDs[0]]?.selection == selection)
        cockpit.noteLegStartChecklist()
        if selection == .none {
            #expect(cockpit.activeLegStartChecklist == nil)
            #expect(!cockpit.hasChecklistAcknowledgements)
            #expect(cockpit.legStartChecklists[flight.legIDs[0]]?.reviewState == .pending)
        } else {
            #expect(cockpit.activeLegStartChecklist?.reviewState == .noted)
        }
        var corrupt = captured
        corrupt.definitionRevision = 2
        #expect(throws: FlightRecoveryError.invalidJournal) {
            try RecordingCockpitContext(flightID: flight.id, checklists: [captured.legID: corrupt], areDriftLinesVisible: true)
                .validate(flightID: flight.id, legIDs: flight.legIDs)
        }
    }

    @Test("A schema upgrade interrupted before its first context record preserves legacy recovery")
    func interruptedLegacyContextUpgrade() async throws {
        let time = Date(timeIntervalSince1970: 30_000)
        let fixture = try recoveryFixture(recordingID: UUID(), startedAt: time)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskFlightRecordingStore(rootDirectory: directory)
        try await store.create(.init(recording: fixture.recording, events: fixture.events))
        let manifestURL = directory.appending(path: fixture.recording.id.uuidString.lowercased()).appending(path: "manifest.json")
        var manifest = try FlightRecordingCoding.decoder.decode(FlightRecordingManifestDTO.self, from: Data(contentsOf: manifestURL))
        manifest.schemaVersion = 3
        manifest.progressionPolicy = .automatic
        manifest.cockpitContextStartSequence = UInt64(fixture.events.count)
        try FlightRecordingCoding.encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        let recovery = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(1) })
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(id: fixture.recording.id,
            at: time.addingTimeInterval(1), elapsed: .seconds(1), eventID: UUID())
        var cockpit = CockpitFeatureState()
        cockpit.restore(flightPlan: recovered.flightPlan, flight: recovered.flight,
                        sourceData: fixture.recording.flightPlanSnapshot.sourceData, cockpitContext: recovered.cockpitContext)
        #expect(cockpit.activeLegStartChecklist?.selection == .tzeKivun)
        #expect(cockpit.activeLegStartChecklist?.reviewState == .pending)
        await recovery.bootstrap()
        if case .single = recovery.state {} else { Issue.record("Legacy recovery must remain available after continuation") }
    }

    @Test("Schema 3 replays the captured Manual policy independently of defaults")
    func capturedManualPolicyRecovery() async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        #expect(plan.legs.count > 1)
        let time = Date(timeIntervalSince1970: 40_000)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0,
                            executionMode: .noWind, progressionPolicy: .manualNextLeg)
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: plan.legs.map(\.id), sourceData: source))
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()], checklistSelection: .none)
        _ = try await engine.commit(.reachCurrentWaypoint(orderedActiveLegPointKeys: [],
            at: time.addingTimeInterval(1), elapsed: .seconds(1), eventIDs: [UUID()]))
        let recovery = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(2) })
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(id: started.recording.id,
            at: time.addingTimeInterval(2), elapsed: .seconds(2), eventID: UUID())
        #expect(recovered.flight.progressionPolicy == .manualNextLeg)
        #expect(recovered.flight.legState == .ready)
        #expect(recovered.flight.activeLegIndex == 1)
        #expect(recovered.cockpitContext?.checklists[flight.legIDs[0]]?.selection == StartChecklistSelection.none)
        #expect(recovered.cockpitContext?.checklists[flight.legIDs[1]] == nil)
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

    private func twoLegFixtureData() throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        var navigation = try #require(object["navigation"] as? [String: Any])
        var route = try #require(navigation["route"] as? [String: Any])
        var waypoints = try #require(route["waypoints"] as? [[String: Any]])
        var order = try #require(route["waypointOrder"] as? [String])
        var legs = try #require(route["legs"] as? [[String: Any]])
        var waypoint = try #require(waypoints.last)
        let waypointID = UUID().uuidString
        waypoint["id"] = waypointID
        waypoint["position"] = ["latitude": 0.03, "longitude": 0.01]
        waypoints.append(waypoint)
        var leg = try #require(legs.last)
        let legID = UUID().uuidString
        leg["id"] = legID
        let departureID = try #require(order.last)
        leg["departureWaypointId"] = departureID
        leg["arrivalWaypointId"] = waypointID
        legs.append(leg)
        order.append(waypointID)
        route["waypoints"] = waypoints
        route["waypointOrder"] = order
        route["legs"] = legs
        navigation["route"] = route
        object["navigation"] = navigation
        var execution = try #require(object["execution"] as? [String: Any])
        var resolved = try #require(execution["legs"] as? [[String: Any]])
        var resolvedLeg = try #require(resolved.last)
        resolvedLeg["legId"] = legID
        resolved.append(resolvedLeg)
        execution["legs"] = resolved
        object["execution"] = execution
        return try JSONSerialization.data(withJSONObject: object)
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

@MainActor
private final class MutableDate {
    var value: Date

    init(value: Date) {
        self.value = value
    }
}

private actor SuspendedPresentationRecordingStore: FlightRecordingStore {
    let base: DiskFlightRecordingStore
    private var shouldSuspend = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(base: DiskFlightRecordingStore) { self.base = base }

    func suspendNextAppend() { shouldSuspend = true }

    func waitUntilSuspended() async {
        guard releaseContinuation == nil else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    func appendEvent(_ event: RecordedFlightEvent, recordingID: UUID, synchronize: Bool) async throws {
        if shouldSuspend {
            shouldSuspend = false
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
                waiters.forEach { $0.resume() }
                waiters.removeAll()
            }
        }
        try await base.appendEvent(event, recordingID: recordingID, synchronize: synchronize)
    }

    func create(_ seed: FlightRecordingSeed) async throws { try await base.create(seed) }
    func appendTrackBatch(_ batch: RecordedTrackBatch) async throws { try await base.appendTrackBatch(batch) }
    func synchronizeTrack(recordingID: UUID) async throws { try await base.synchronizeTrack(recordingID: recordingID) }
    func updateRecoveryCheckpoint(recordingID: UUID, at timestamp: Date) async throws {
        try await base.updateRecoveryCheckpoint(recordingID: recordingID, at: timestamp)
    }
    func packages() async -> [FlightRecordingPackageResult] { await base.packages() }
    func readSnapshot(id: UUID) async throws -> FlightRecordingReadSnapshot { try await base.readSnapshot(id: id) }
    func close(id: UUID, closure: FlightRecordingClosure) async throws { try await base.close(id: id, closure: closure) }
    func remove(id: UUID) async throws { try await base.remove(id: id) }
}
