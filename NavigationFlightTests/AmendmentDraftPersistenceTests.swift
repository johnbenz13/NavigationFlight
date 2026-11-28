import Foundation
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Unfinished amendment persistence")
struct AmendmentDraftPersistenceTests {
    private func state() throws -> CockpitFeatureState {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appending(path: "Fixtures/FPLNav/V7/Official/llhz-llib-via-jerusalem-v7.fplnav")
        let data = try Data(contentsOf: url)
        var state = CockpitFeatureState()
        try state.accept(FPLNavDecoder().decode(data), sourceData: data)
        try state.startLeg(at: Date(timeIntervalSince1970: 1_000))
        state.prepareAmendmentConfirmationFixture(workspaceFixture: true)
        return state
    }

    private func partial(_ state: inout CockpitFeatureState) throws {
        let route = try #require(state.routeForAmendment)
        let leg = try #require(state.routeAmendmentDraft?.reviewLegs(on: route).first)
        state.updateRouteAmendment(.editLeg(leg.id))
        state.updateRouteAmendment(.editLegField(.duration, ""))
        state.updateRouteAmendment(.selectLegTime(.seconds, 15))
        state.updateRouteAmendment(.selectLegTime(.minutes, nil))
        state.updateRouteAmendment(.editLegField(.visualReference, "  junction / צומת  "))
        state.updateRouteAmendment(.selectLegCue(.altitude, .value(2600)))
        state.updateRouteAmendment(.toggleCues)
    }

    @Test func losslessPartialEditorAndUndoRoundTrip() async throws {
        var original = try state()
        try partial(&original)
        let flight = try #require(original.flight)
        let route = try #require(original.routeForAmendment)
        let draft = try #require(original.routeAmendmentDraft)
        let store = InMemoryAmendmentDraftStore()
        let persistence = AmendmentDraftPersistence(store: store)
        persistence.save(draft, recordingSequence: 2)
        await persistence.flush()
        let recovered = AmendmentDraftPersistence(store: store)
        let restored = try #require(await recovered.recover(flight: flight, route: route, lastAmendmentSequence: nil))
        #expect(restored.persistence == draft.persistence)
        #expect(restored.isPaused)
        #expect(restored.editor?.entry.minutes == "")
        #expect(restored.editor?.entry.seconds == "15")
        #expect(restored.editor?.entry.visualReference == "  junction / צומת  ")
        var cockpit = CockpitFeatureState()
        cockpit.restore(flightPlan: try #require(original.flightPlan), flight: flight, sourceData: original.flightPlanSourceData)
        cockpit.restoreAmendmentDraft(restored)
        #expect(!cockpit.isAmendmentWorkspaceVisible)
        #expect(cockpit.flight == flight)
        cockpit.updateRouteAmendment(.open)
        #expect(cockpit.routeAmendmentDraft?.editor == draft.editor)
        cockpit.updateRouteAmendment(.saveLegValues)
        original.updateRouteAmendment(.saveLegValues)
        cockpit.updateRouteAmendment(.undo)
        original.updateRouteAmendment(.undo)
        #expect(cockpit.routeAmendmentDraft?.persistence == original.routeAmendmentDraft?.persistence)
        #expect(cockpit.flight == flight)
    }

    @Test func recoveredOpenGeometryResumesDirectDrawingWithoutAddingOnOpen() async throws {
        var cockpit = try state()
        cockpit.updateRouteAmendment(.undo)
        let draft = try #require(cockpit.routeAmendmentDraft)
        #expect(draft.rejoin == nil)
        let flight = try #require(cockpit.flight)
        let route = try #require(cockpit.routeForAmendment)
        let store = InMemoryAmendmentDraftStore()
        let persistence = AmendmentDraftPersistence(store: store)
        persistence.save(draft, recordingSequence: 2)
        await persistence.flush()
        let restored = try #require(await AmendmentDraftPersistence(store: store).recover(
            flight: flight, route: route, lastAmendmentSequence: nil))
        cockpit.clearAmendmentDraft()
        cockpit.restoreAmendmentDraft(restored)
        #expect(!cockpit.isAmendmentWorkspaceVisible)
        cockpit.updateRouteAmendment(.open)
        #expect(cockpit.isAmendmentPlotting)
        #expect(cockpit.routeAmendmentDraft?.points == draft.points)
        #expect(cockpit.routeAmendmentDraft?.step == .drawing)
        let last = try #require(draft.points.last?.position)
        cockpit.updateRouteAmendment(.plot(.init(position: .init(latitudeDegrees: last.latitudeDegrees + 0.01,
                                                                 longitudeDegrees: last.longitudeDegrees + 0.01))))
        #expect(cockpit.routeAmendmentDraft?.points.count == draft.points.count + 1)
        #expect(cockpit.flight == flight)
    }

    @Test func untouchedExitStoresNothing() async throws {
        var cockpit = try state()
        cockpit.clearAmendmentDraft()
        cockpit.updateRouteAmendment(.open)
        let store = InMemoryAmendmentDraftStore()
        let persistence = AmendmentDraftPersistence(store: store)
        persistence.save(try #require(cockpit.routeAmendmentDraft), recordingSequence: 2)
        cockpit.updateRouteAmendment(.pause)
        await persistence.flush()
        #expect(cockpit.routeAmendmentDraft == nil)
        #expect(try await store.load(flightID: #require(cockpit.flight?.id)) == nil)
    }

    @Test func failedSaveRetainsLatestAndRetryPersistsIt() async throws {
        var cockpit = try state()
        let store = InMemoryAmendmentDraftStore(failure: .save)
        let persistence = AmendmentDraftPersistence(store: store)
        let id = try #require(cockpit.flight?.id)
        persistence.save(try #require(cockpit.routeAmendmentDraft), recordingSequence: 2)
        await persistence.flush()
        #expect(persistence.statuses[id] == .saveFailed)
        try partial(&cockpit)
        persistence.save(try #require(cockpit.routeAmendmentDraft), recordingSequence: 2)
        await persistence.flush()
        cockpit.updateRouteAmendment(.pause)
        #expect(cockpit.routeAmendmentDraft?.editor?.entry.seconds == "15")
        await store.setFailure(nil)
        persistence.retry(flightID: id)
        await persistence.flush()
        #expect(persistence.statuses[id] == .saved)
        let flight = try #require(cockpit.flight)
        let restored = try #require(await AmendmentDraftPersistence(store: store).recover(
            flight: flight, route: cockpit.routeForAmendment, lastAmendmentSequence: nil))
        #expect(restored.persistence == cockpit.routeAmendmentDraft?.persistence)
    }

    @Test func failedDeletePreservesDraftThenRetryRemovesIt() async throws {
        let cockpit = try state()
        let store = InMemoryAmendmentDraftStore()
        let persistence = AmendmentDraftPersistence(store: store)
        let id = try #require(cockpit.flight?.id)
        persistence.save(try #require(cockpit.routeAmendmentDraft), recordingSequence: 2)
        await persistence.flush()
        await store.setFailure(.remove)
        #expect(await persistence.discard(flightID: id) == false)
        #expect(persistence.statuses[id] == .deleteFailed)
        #expect(try await store.load(flightID: id) != nil)
        await store.setFailure(nil)
        #expect(await persistence.discard(flightID: id))
        #expect(try await store.load(flightID: id) == nil)
    }

    @Test func flightIsolationClosedAndArmedPrecedence() async throws {
        let cockpit = try state()
        var flight = try #require(cockpit.flight)
        let route = try #require(cockpit.routeForAmendment)
        let store = InMemoryAmendmentDraftStore()
        let persistence = AmendmentDraftPersistence(store: store)
        persistence.save(try #require(cockpit.routeAmendmentDraft), recordingSequence: 2)
        await persistence.flush()
        let other = try #require(try state().flight)
        #expect(await persistence.recover(flight: other, route: route, lastAmendmentSequence: nil) == nil)
        // Durable arm, followed by cancellation, still fences stale preparation.
        await store.setFailure(.remove)
        await persistence.retire(flightID: flight.id)
        #expect(persistence.statuses[flight.id] == nil)
        #expect(try await store.load(flightID: flight.id) != nil)
        #expect(await persistence.recover(flight: flight, route: route, lastAmendmentSequence: 2) == nil)
        let amendment = try PendingRouteAmendment(id: UUID(), draft: #require(cockpit.routeAmendmentDraft), flight: flight, route: route)
        try flight.installPendingAmendment(amendment, in: #require(cockpit.flightPlan))
        #expect(await persistence.recover(flight: flight, route: route, lastAmendmentSequence: nil) == nil)
        #expect(try await store.load(flightID: flight.id) != nil)
        #expect(await persistence.recover(flight: other, route: nil, lastAmendmentSequence: nil) == nil)
        var completed = other
        while completed.legState != .completed {
            if completed.legState == .ready { try completed.startLeg(at: Date(timeIntervalSince1970: 1_000)) }
            try completed.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 1_000))
        }
        #expect(await persistence.recover(flight: completed, route: route, lastAmendmentSequence: nil) == nil)
    }

    @Test func corruptPayloadIsPreservedAndCannotBeOverwritten() async throws {
        let cockpit = try state()
        let flight = try #require(cockpit.flight)
        let bytes = Data("broken payload".utf8)
        let record = AmendmentDraftRecord(flightID: flight.id, revision: 4, recordingSequence: 2, payload: bytes)
        let store = InMemoryAmendmentDraftStore(records: [flight.id: record])
        let persistence = AmendmentDraftPersistence(store: store)
        #expect(await persistence.recover(flight: flight, route: cockpit.routeForAmendment, lastAmendmentSequence: nil) == nil)
        #expect(persistence.statuses[flight.id] == .recoveryFailed)
        persistence.save(try #require(cockpit.routeAmendmentDraft), recordingSequence: 3)
        persistence.retry(flightID: flight.id)
        await persistence.flush()
        #expect(try await store.load(flightID: flight.id) == record)
    }

    @Test func assistedModeProvenanceAndStaleDepartureSurviveRestart() async throws {
        let cockpit = try state()
        let flight = try #require(cockpit.flight)
        let route = try #require(cockpit.routeForAmendment)
        var draft = RouteAmendmentDraft(flightID: flight.id, mode: .assisted)
        let departure = route.anchor(at: 0, fraction: 0.2)
        draft.update(.chooseAnchor(departure), route: route)
        draft.update(.plot(.init(position: .init(latitudeDegrees: 32.2, longitudeDegrees: 35.1))), route: route)
        let leg = try #require(draft.reviewLegs(on: route).first)
        draft.update(.editLeg(leg.id), route: route)
        draft.update(.editLegField(.heading, "123"), route: route)
        let savedEditor = draft.editor
        let store = InMemoryAmendmentDraftStore()
        let persistence = AmendmentDraftPersistence(store: store)
        persistence.save(draft, recordingSequence: 2)
        await persistence.flush()
        let staleRoute = RouteAmendmentRoute(legs: route.legs, firstAvailable: route.anchor(at: 0, fraction: 0.8))
        let restored = try #require(await AmendmentDraftPersistence(store: store).recover(
            flight: flight, route: staleRoute, lastAmendmentSequence: nil))
        #expect(restored.mode == .assisted)
        #expect(restored.editor == savedEditor)
        #expect(restored.editor?.entry.estimateProvenance?.headingOverridden == true)
        #expect(restored.step == .staleDeparture)
        #expect(restored.points == draft.points)
        #expect(restored.rejoin == nil)
    }

    @Test func delayedSaveCannotWinOverNewEditsOrRecreateDiscard() async throws {
        var cockpit = try state()
        let id = try #require(cockpit.flight?.id)
        let store = SuspendedDraftStore()
        let persistence = AmendmentDraftPersistence(store: store)
        persistence.save(try #require(cockpit.routeAmendmentDraft), recordingSequence: 2)
        await store.waitForFirstSave()
        try partial(&cockpit)
        let expected = cockpit.routeAmendmentDraft?.persistence
        persistence.save(try #require(cockpit.routeAmendmentDraft), recordingSequence: 2)
        await store.releaseFirstSave()
        await persistence.flush()
        let flight = try #require(cockpit.flight)
        let restored = try #require(await AmendmentDraftPersistence(store: store).recover(
            flight: flight, route: cockpit.routeForAmendment, lastAmendmentSequence: nil))
        #expect(restored.persistence == expected)
        #expect(await persistence.discard(flightID: id))
        #expect(try await store.load(flightID: id) == nil)
    }

    @Test func draftWritesLeaveRecordingAndPlanSnapshotUnchanged() async throws {
        let cockpit = try state()
        let plan = try #require(cockpit.flightPlan)
        let source = try #require(cockpit.flightPlanSourceData)
        let recordingStore = InMemoryFlightRecordingStore()
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0,
                            executionMode: .noWind, progressionPolicy: .automaticNextLeg)
        let engine = FlightRecordingEngine(store: recordingStore, flight: flight,
                                          flightPlanSnapshot: .init(id: plan.id, title: plan.title,
                                                                   legIDs: flight.legIDs, sourceData: source))
        let started = try await engine.promoteForStartLeg(at: Date(timeIntervalSince1970: 1_000),
                                                         recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let before = try await recordingStore.readSnapshot(id: started.recording.id)
        let persistence = AmendmentDraftPersistence(store: InMemoryAmendmentDraftStore())
        persistence.save(try #require(cockpit.routeAmendmentDraft), recordingSequence: started.recording.nextEventSequence)
        await persistence.flush()
        let after = try await recordingStore.readSnapshot(id: started.recording.id)
        #expect(after == before)
        #expect(after.recording.flightPlanSnapshot.sourceData == source)
        #expect(after.trackSegments == before.trackSegments)
    }

    @Test func failedRetirementRestartCancellationAndNewDraftRoundTrip() async throws {
        var cockpit = try state()
        var flight = try #require(cockpit.flight)
        let route = try #require(cockpit.routeForAmendment)
        let original = try #require(cockpit.routeAmendmentDraft)
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiskAmendmentDraftStore(rootDirectory: root, beforeRemove: {
            throw AmendmentDraftStoreError.operationFailed
        })
        try await store.save(.init(flightID: flight.id, revision: 9, recordingSequence: 2,
                                  payload: JSONEncoder().encode(original.persistence)))
        await AmendmentDraftPersistence(store: store).retire(flightID: flight.id)
        #expect(try await store.load(flightID: flight.id)?.revision == 9)
        let amendment = try PendingRouteAmendment(id: UUID(), draft: original, flight: flight, route: route)
        try flight.installPendingAmendment(amendment, in: #require(cockpit.flightPlan))
        let restarted = AmendmentDraftPersistence(store: DiskAmendmentDraftStore(rootDirectory: root))
        #expect(await restarted.recover(flight: flight, route: route, lastAmendmentSequence: 3) == nil)
        #expect(restarted.statuses[flight.id] == nil)
        try flight.cancelPendingAmendment(id: amendment.id)
        try partial(&cockpit)
        let fresh = try #require(cockpit.routeAmendmentDraft)
        restarted.save(fresh, recordingSequence: 5)
        await restarted.flush()
        #expect(restarted.statuses[flight.id] == .saved)
        #expect(try await store.load(flightID: flight.id)?.revision == 10)
        let cold = AmendmentDraftPersistence(store: DiskAmendmentDraftStore(rootDirectory: root))
        let restored = try #require(await cold.recover(flight: flight, route: route, lastAmendmentSequence: 4))
        #expect(restored.persistence == fresh.persistence)
        var expected = fresh
        var actual = restored
        expected.update(.open, route: route)
        actual.update(.open, route: route)
        expected.update(.saveLegValues, route: route)
        actual.update(.saveLegValues, route: route)
        expected.update(.undo, route: route)
        actual.update(.undo, route: route)
        #expect(actual.persistence == expected.persistence)
    }

    @Test(arguments: ["corrupt", "unsupported", "load"])
    func armedLoadFailureRemainsVisibleAfterCancellation(failure: String) async throws {
        let cockpit = try state()
        var flight = try #require(cockpit.flight)
        let route = try #require(cockpit.routeForAmendment)
        let draft = try #require(cockpit.routeAmendmentDraft)
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let file = root.appending(path: "\(flight.id.uuidString.lowercased()).json")
        let record = AmendmentDraftRecord(flightID: flight.id, revision: 9, recordingSequence: 2,
                                         payload: try JSONEncoder().encode(draft.persistence),
                                         schemaVersion: failure == "unsupported" ? 99 : 1)
        let bytes = failure == "corrupt" ? Data("{broken".utf8) : try JSONEncoder().encode(record)
        try bytes.write(to: file)
        let store = DiskAmendmentDraftStore(rootDirectory: root, beforeLoad: {
            if failure == "load" { throw AmendmentDraftStoreError.operationFailed }
        })
        let amendment = try PendingRouteAmendment(id: UUID(), draft: draft, flight: flight, route: route)
        try flight.installPendingAmendment(amendment, in: #require(cockpit.flightPlan))
        let armed = flight
        let restarted = AmendmentDraftPersistence(store: store)
        #expect(await restarted.recover(flight: flight, route: route, lastAmendmentSequence: 3) == nil)
        #expect(flight == armed)
        #expect(restarted.statuses[flight.id] == .recoveryFailed)
        try flight.cancelPendingAmendment(id: amendment.id)
        // The editor's existing recoveryFailed gate rejects preparation. Even a
        // direct persistence call must retain the visible error and original bytes.
        restarted.save(draft, recordingSequence: 5)
        await restarted.flush()
        #expect(restarted.statuses[flight.id] == .recoveryFailed)
        restarted.retry(flightID: flight.id)
        await restarted.flush()
        #expect(restarted.statuses[flight.id] == .recoveryFailed)
        #expect(await restarted.discard(flightID: flight.id) == false)
        #expect(restarted.statuses[flight.id] == .recoveryFailed)
        #expect(try Data(contentsOf: file) == bytes)
    }

    @Test func rejectedDiskWriteAndRetryNeverPublishSaved() async throws {
        let cockpit = try state()
        let draft = try #require(cockpit.routeAmendmentDraft)
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiskAmendmentDraftStore(rootDirectory: root)
        let newest = AmendmentDraftRecord(flightID: draft.flightID, revision: 9, recordingSequence: 2,
                                         payload: try JSONEncoder().encode(draft.persistence))
        try await store.save(newest)
        let persistence = AmendmentDraftPersistence(store: store)
        persistence.save(draft, recordingSequence: 3)
        await persistence.flush()
        #expect(persistence.statuses[draft.flightID] == .saveFailed)
        persistence.retry(flightID: draft.flightID)
        await persistence.flush()
        #expect(persistence.statuses[draft.flightID] == .saveFailed)
        #expect(try await store.load(flightID: draft.flightID) == newest)
    }

    @Test func diskRejectsOlderRevisionsAndPreservesUnsupportedAndMismatchedBytes() async throws {
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let store = DiskAmendmentDraftStore(rootDirectory: root)
        let id = UUID()
        let newest = AmendmentDraftRecord(flightID: id, revision: 9, recordingSequence: 3, payload: Data("new".utf8))
        try await store.save(newest)
        await #expect(throws: AmendmentDraftStoreError.staleRevision) {
            try await store.save(.init(flightID: id, revision: 2, recordingSequence: 2, payload: Data("old".utf8)))
        }
        #expect(try await store.load(flightID: id) == newest)
        let file = root.appending(path: "\(id.uuidString.lowercased()).json")
        for record in [AmendmentDraftRecord(flightID: id, revision: 10, recordingSequence: 3, payload: Data(), schemaVersion: 99),
                       AmendmentDraftRecord(flightID: UUID(), revision: 10, recordingSequence: 3, payload: Data()),
                       AmendmentDraftRecord(flightID: id, revision: .max, recordingSequence: 3, payload: Data())] {
            let bytes = try JSONEncoder().encode(record)
            try bytes.write(to: file)
            await #expect(throws: (any Error).self) { try await store.load(flightID: id) }
            await #expect(throws: (any Error).self) { try await store.save(newest) }
            #expect(try Data(contentsOf: file) == bytes)
        }
        let corrupt = Data("{corrupt".utf8)
        try corrupt.write(to: file)
        await #expect(throws: AmendmentDraftStoreError.invalidData) { try await store.load(flightID: id) }
        await #expect(throws: (any Error).self) { try await store.save(newest) }
        #expect(try Data(contentsOf: file) == corrupt)
    }
}


private actor SuspendedDraftStore: AmendmentDraftStore {
    private var record: AmendmentDraftRecord?
    private var firstSaveStarted = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var releaseWaiter: CheckedContinuation<Void, Never>?

    func waitForFirstSave() async {
        if firstSaveStarted { return }
        await withCheckedContinuation { startWaiter = $0 }
    }

    func releaseFirstSave() { releaseWaiter?.resume(); releaseWaiter = nil }

    func load(flightID: UUID) -> AmendmentDraftRecord? { record?.flightID == flightID ? record : nil }

    func save(_ record: AmendmentDraftRecord) async {
        if !firstSaveStarted {
            firstSaveStarted = true
            startWaiter?.resume()
            startWaiter = nil
            await withCheckedContinuation { releaseWaiter = $0 }
        }
        self.record = record
    }

    func remove(flightID: UUID) { if record?.flightID == flightID { record = nil } }
}
