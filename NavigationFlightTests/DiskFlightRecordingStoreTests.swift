import Foundation
import Testing
@testable import NavigationFlight

@Suite("Disk flight recording store")
struct DiskFlightRecordingStoreTests {
    @Test("Package creation is atomic and persists versioned immutable inputs")
    func atomicCreation() async throws {
        let root = temporaryDirectory()
        let seed = try makeSeed()
        let store = DiskFlightRecordingStore(rootDirectory: root)

        try await store.create(seed)

        let package = root.appending(path: seed.recording.id.uuidString.lowercased(), directoryHint: .isDirectory)
        #expect(FileManager.default.fileExists(atPath: package.appending(path: "manifest.json").path()))
        #expect(FileManager.default.fileExists(atPath: package.appending(path: "flight-plan.json").path()))
        #expect(FileManager.default.fileExists(atPath: package.appending(path: "events.ndjson").path()))
        #expect(try FileManager.default.contentsOfDirectory(atPath: root.path()).contains { $0.hasSuffix(".tmp") } == false)

        let snapshot = try await store.readSnapshot(id: seed.recording.id)
        #expect(snapshot.recording == seed.recording)
        #expect(snapshot.events == seed.events)
        #expect(await store.packages() == [.available(snapshot)])
    }

    @Test("Package creation succeeds in the application support hierarchy")
    func applicationSupportCreation() async throws {
        let applicationSupport = try #require(
            FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        )
        let container = applicationSupport.appending(
            path: "FlightRecordingStoreTests-\(UUID().uuidString)",
            directoryHint: .isDirectory
        )
        defer { try? FileManager.default.removeItem(at: container) }
        let root = container.appending(path: "Flights", directoryHint: .isDirectory)
        let seed = try makeSeed()
        let store = DiskFlightRecordingStore(rootDirectory: root)

        try await store.create(seed)

        let snapshot = try await store.readSnapshot(id: seed.recording.id)
        #expect(snapshot.recording == seed.recording)
        #expect(snapshot.events == seed.events)
        #expect(await store.packages() == [.available(snapshot)])
    }

    @Test("Failed atomic installation exposes no partial package")
    func failedCreationLeavesNoPackage() async throws {
        let root = temporaryDirectory()
        let seed = try makeSeed()
        let store = DiskFlightRecordingStore(
            rootDirectory: root,
            beforeInstall: { _ in throw TestFailure.expected }
        )

        await #expect(throws: FlightRecordingStoreError.operationFailed(id: seed.recording.id)) {
            try await store.create(seed)
        }
        let results = await store.packages()
        #expect(results.isEmpty)
    }

    @Test("Synchronized append preserves sequence order")
    func synchronizedAppend() async throws {
        let root = temporaryDirectory()
        let seed = try makeSeed()
        let store = DiskFlightRecordingStore(rootDirectory: root)
        try await store.create(seed)
        let appended = RecordedFlightEvent(
            id: UUID(),
            sequence: 2,
            occurredAt: seed.recording.startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            origin: .pilot,
            payload: .manualEnd
        )

        try await store.appendEvent(appended, recordingID: seed.recording.id, synchronize: true)

        let snapshot = try await store.readSnapshot(id: seed.recording.id)
        #expect(snapshot.events.map(\.sequence) == [0, 1, 2])
        #expect(snapshot.events.last == appended)
    }

    @Test("Unsupported package versions are preserved and reported")
    func unsupportedVersion() async throws {
        let root = temporaryDirectory()
        let seed = try makeSeed()
        let store = DiskFlightRecordingStore(rootDirectory: root)
        try await store.create(seed)
        let manifestURL = root
            .appending(path: seed.recording.id.uuidString.lowercased(), directoryHint: .isDirectory)
            .appending(path: "manifest.json")
        var object = try #require(try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any])
        object["schemaVersion"] = 999
        try JSONSerialization.data(withJSONObject: object).write(to: manifestURL)

        let results = await store.packages()

        #expect(results == [.unsupported(id: seed.recording.id, schemaVersion: 999)])
        #expect(FileManager.default.fileExists(atPath: manifestURL.path()))
    }

    @Test("Failed close preserves the open manifest and complete journal")
    func failedClosePreservesPackage() async throws {
        let root = temporaryDirectory()
        let seed = try makeSeed()
        let store = DiskFlightRecordingStore(
            rootDirectory: root,
            beforeClose: { _ in throw TestFailure.expected }
        )
        try await store.create(seed)
        let closure = FlightRecordingClosure(
            outcome: .incomplete,
            cause: .manual,
            closedAt: seed.recording.startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            landingEvidenceAvailable: false
        )

        await #expect(throws: FlightRecordingStoreError.operationFailed(id: seed.recording.id)) {
            try await store.close(id: seed.recording.id, closure: closure)
        }
        let snapshot = try await store.readSnapshot(id: seed.recording.id)
        #expect(snapshot.recording.closure == nil)
        #expect(snapshot.events == seed.events)
    }

    @Test("Successful close publishes the closure and next journal sequence together")
    func successfulClose() async throws {
        let root = temporaryDirectory()
        let seed = try makeSeed()
        let store = DiskFlightRecordingStore(rootDirectory: root)
        try await store.create(seed)
        var candidate = seed.recording
        let closingEvents = try candidate.endManually(
            at: seed.recording.startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            eventIDs: [UUID(), UUID()]
        )
        for event in closingEvents {
            try await store.appendEvent(
                event,
                recordingID: seed.recording.id,
                synchronize: true
            )
        }

        try await store.close(id: seed.recording.id, closure: try #require(candidate.closure))

        let snapshot = try await store.readSnapshot(id: seed.recording.id)
        #expect(snapshot.recording == candidate)
        #expect(snapshot.events == seed.events + closingEvents)
    }

    private func makeSeed() throws -> FlightRecordingSeed {
        let legID = UUID()
        let promotion = try FlightRecording.promoteForStartLeg(
            id: UUID(),
            flightID: UUID(),
            flightPlanSnapshot: RecordedFlightPlanSnapshot(
                id: UUID(),
                title: "Training flight",
                legIDs: [legID]
            ),
            legID: legID,
            startedAt: Date(timeIntervalSince1970: 1_000),
            eventIDs: [UUID(), UUID()]
        )
        return FlightRecordingSeed(recording: promotion.recording, events: promotion.events)
    }

    private func temporaryDirectory() -> URL {
        URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
    }

    private enum TestFailure: Error {
        case expected
    }
}
