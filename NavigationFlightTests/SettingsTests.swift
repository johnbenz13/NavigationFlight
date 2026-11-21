import Foundation
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Device Settings")
struct SettingsTests {
    @Test("Foundation preferences round-trip without resetting the checklist", arguments: [
        PreferenceChange.showDriftLines(false), .progression(.manual),
        .recoveryWindow(.oneMinute), .recoveryWindow(.twoMinutes),
        .recoveryWindow(.fiveMinutes), .recoveryWindow(.tenMinutes)
    ])
    func typedFoundationValues(_ change: PreferenceChange) async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskSettingsStore(directory: directory)
        try await store.save(.startChecklist(.establishHeading))
        try await store.save(change)
        var expected = AppPreferences(startChecklist: .establishHeading)
        expected.apply(change)
        #expect(await DiskSettingsStore(directory: directory).load().preferences == expected)
    }

    @Test("Every checklist choice survives independent store reload", arguments: StartChecklistSelection.allCases)
    func checklistRelaunch(_ choice: StartChecklistSelection) async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskSettingsStore(directory: directory)
        try await store.save(.showDriftLines(false))
        try await store.save(.startChecklist(choice))
        let reloaded = await DiskSettingsStore(directory: directory).load().preferences
        #expect(reloaded.startChecklist == choice)
        #expect(!reloaded.showDriftLines)
        #expect(reloaded.progression == .automatic)
        #expect(reloaded.recoveryWindow == .fiveMinutes)
    }

    @Test("Missing, malformed, unknown and future values fall back independently", arguments: [
        "{}", "invalid", "{\"version\":1,\"value\":\"unknown\"}", "{\"version\":99,\"value\":\"none\"}"
    ])
    func independentFallback(_ invalid: String) async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskSettingsStore(directory: directory)
        try await store.save(.showDriftLines(false))
        let file = directory.appending(path: "cockpit.startChecklist.json")
        try Data(invalid.utf8).write(to: file)
        let unknownFile = directory.appending(path: "future.json")
        try Data("preserve".utf8).write(to: unknownFile)
        let result = await store.load().preferences
        #expect(result.startChecklist == .tzeKivun)
        #expect(!result.showDriftLines)
        #expect(try Data(contentsOf: file) == Data(invalid.utf8))
        #expect(try Data(contentsOf: unknownFile) == Data("preserve".utf8))
    }

    @Test("Failed first creation and replacement retain effective and saved values", arguments: [false, true])
    func failedWriteRetainsValue(_ existing: Bool) async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        if existing { try await DiskSettingsStore(directory: directory).save(.startChecklist(.establishHeading)) }
        let controller = SettingsController(store: DiskSettingsStore(directory: directory, failNextSaves: 1))
        await controller.bootstrap()
        let prior = controller.preferences
        controller.change(.startChecklist(.none))
        await controller.waitForPendingChanges()
        #expect(controller.preferences == prior)
        #expect(controller.failedAttempt?.change == .startChecklist(.none))
        #expect(await DiskSettingsStore(directory: directory).load().preferences == prior)
        controller.retry()
        await controller.waitForPendingChanges()
        #expect(controller.preferences.startChecklist == .none)
        #expect(controller.failedAttempt == nil)
    }

    @Test("Dismiss never retries or changes effective value")
    func dismissFailure() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = SettingsController(store: DiskSettingsStore(directory: directory, failNextSaves: 1))
        await controller.bootstrap()
        controller.change(.startChecklist(.none))
        await controller.waitForPendingChanges()
        controller.dismissFailure()
        #expect(controller.failedAttempt == nil)
        #expect(controller.preferences.startChecklist == .tzeKivun)
    }

    @Test("Queued choices commit in order and preserve unrelated changes")
    func queuedChoices() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let controller = SettingsController(store: DiskSettingsStore(directory: directory, failNextSaves: 1))
        controller.change(.startChecklist(.none))
        controller.change(.showDriftLines(false))
        controller.change(.startChecklist(.establishHeading))
        await controller.waitForPendingChanges()
        #expect(controller.failedAttempt == nil)
        #expect(controller.preferences.startChecklist == .establishHeading)
        #expect(!controller.preferences.showDriftLines)
        #expect(await DiskSettingsStore(directory: directory).load().preferences == controller.preferences)
    }

    @Test("Presentation-only warning does not claim track loss")
    func accurateWarning() {
        let warning = RecordingStatusPresentation(status: .checklistPersistenceFailed)
        #expect(String(localized: warning.detail).contains("Checklist changes could not be saved"))
        #expect(!String(localized: warning.detail).contains("track data"))
        #expect(warning.tone == .caution)
    }

    @Test("A presentation write failure retains durable state and leaves navigation available")
    func presentationFailureDoesNotBlockNavigation() async throws {
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskFlightRecordingStore(rootDirectory: directory, beforeAppend: { event in
            if event.payload == .cockpitPresentationChanged { throw CocoaError(.fileWriteNoPermission) }
        })
        let legs = [UUID(), UUID()]
        let flight = Flight(flightPlanID: UUID(), legIDs: legs, activeLegIndex: 0, executionMode: .noWind)
        let coordinator = FlightRecordingCoordinator(store: store)
        let time = Date(timeIntervalSince1970: 1_000)
        let started = try await coordinator.startLeg(flight: flight,
            flightPlanSnapshot: .init(id: flight.flightPlanID, title: "Test", legIDs: legs),
            at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        var memory = try #require(started.cockpitContext)
        memory.checklists[legs[0]]?.reviewState = .noted
        await coordinator.recordPresentation(memory, at: time.addingTimeInterval(1))
        #expect(coordinator.presentationWriteFailed)
        #expect(coordinator.effectiveStatus == .checklistPersistenceFailed)
        let durable = try await store.readSnapshot(id: started.recording.id)
        #expect(durable.events.last?.cockpitContext?.checklists[legs[0]]?.reviewState == .pending)
        let arrival = try await coordinator.commitNavigation(.reachCurrentWaypoint(orderedActiveLegPointKeys: [],
            at: time.addingTimeInterval(2), elapsed: .seconds(2), eventIDs: [UUID(), UUID()]),
            context: memory, checklistSelection: .none)
        #expect(arrival.flight.activeLegIndex == 1)
        #expect(arrival.cockpitContext?.checklists[legs[1]]?.selection == StartChecklistSelection.none)
        #expect(!coordinator.presentationWriteFailed)
        let savedAfterArrival = try await store.readSnapshot(id: started.recording.id)
        #expect(savedAfterArrival.events.last?.cockpitContext?.checklists[legs[0]]?.reviewState == .noted)
        await coordinator.recordPresentation(memory, at: time.addingTimeInterval(2.5))
        #expect(!coordinator.presentationWriteFailed)
        var current = try #require(arrival.cockpitContext)
        current.areDriftLinesVisible.toggle()
        await coordinator.recordPresentation(current, at: time.addingTimeInterval(2.6))
        #expect(coordinator.presentationWriteFailed)
        await coordinator.recordPresentation(memory, at: time.addingTimeInterval(2.7))
        #expect(coordinator.presentationWriteFailed)
        try await coordinator.recordStorageDegradation(.trackWriteFailed, at: time.addingTimeInterval(3), elapsed: .seconds(3), eventID: UUID())
        #expect(coordinator.effectiveStatus == .recordingDegraded)
    }

    @Test("A suspended older save cannot publish an optimistic value or override a newer attempt")
    func suspendedSaveOrdering() async {
        let store = SuspendedSettingsStore()
        let controller = SettingsController(store: store)
        await controller.bootstrap()
        controller.change(.startChecklist(.none))
        await store.waitUntilSuspended()
        let newestID = controller.change(.startChecklist(.establishHeading))
        #expect(controller.preferences.startChecklist == .tzeKivun)
        await store.release()
        await controller.waitForPendingChanges()
        #expect(controller.preferences.startChecklist == .establishHeading)
        #expect(controller.failedAttempt == nil)
        #expect(controller.completedRequestID == newestID)
    }
}

private actor SuspendedSettingsStore: SettingsStore {
    private var first = true
    private var suspended = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var continuation: CheckedContinuation<Void, Never>?

    func load() -> SettingsLoadResult { .init(preferences: AppPreferences()) }

    func save(_ change: PreferenceChange) async throws {
        guard first else { return }
        first = false
        await withCheckedContinuation { continuation in
            self.continuation = continuation
            suspended = true
            waiters.forEach { $0.resume() }
            waiters = []
        }
        throw CocoaError(.fileWriteNoPermission)
    }

    func waitUntilSuspended() async {
        guard !suspended else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        continuation?.resume()
        continuation = nil
    }
}
