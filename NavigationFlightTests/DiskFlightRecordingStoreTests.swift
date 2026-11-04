import Foundation
import Synchronization
import Testing
@testable import NavigationFlight

@Suite("Disk flight recording store")
struct DiskFlightRecordingStoreTests {
    @Test("Checksummed track batches round-trip and a torn tail preserves prior samples")
    func trackBatchChecksumAndTornTail() async throws {
        let root = temporaryDirectory()
        let seed = try makeSeed()
        let store = DiskFlightRecordingStore(rootDirectory: root)
        try await store.create(seed)
        let segmentID = UUID()
        let first = recordedSample(at: seed.recording.startedAt, latitude: 32)
        let second = recordedSample(at: seed.recording.startedAt.addingTimeInterval(1), latitude: 33)
        try await store.appendTrackBatch(RecordedTrackBatch(
            recordingID: seed.recording.id,
            segmentID: segmentID,
            samples: [first, second]
        ))
        try await store.synchronizeTrack(recordingID: seed.recording.id)
        let file = root
            .appending(path: seed.recording.id.uuidString.lowercased())
            .appending(path: "track")
            .appending(path: "\(segmentID.uuidString.lowercased()).ndjson")
        let handle = try FileHandle(forWritingTo: file)
        try handle.seekToEnd()
        try handle.write(contentsOf: Data("{\"torn\":".utf8))
        try handle.close()

        let snapshot = try await store.readSnapshot(id: seed.recording.id)

        #expect(snapshot.trackSegments == [RecordedTrackSegment(id: segmentID, samples: [first, second])])
    }

    @Test("Track synchronization is triggered at the configured five-second boundary")
    func configuredSynchronizationInterval() async throws {
        let root = temporaryDirectory()
        let seed = try makeSeed()
        let now = Mutex(seed.recording.startedAt)
        let synchronizationAttempts = Mutex(0)
        let store = DiskFlightRecordingStore(
            rootDirectory: root,
            synchronizationInterval: 5,
            now: { now.withLock { $0 } },
            beforeTrackSynchronization: { _ in synchronizationAttempts.withLock { $0 += 1 } }
        )
        try await store.create(seed)
        let segmentID = UUID()
        now.withLock { $0 = $0.addingTimeInterval(4) }
        try await store.appendTrackBatch(RecordedTrackBatch(
            recordingID: seed.recording.id,
            segmentID: segmentID,
            samples: [recordedSample(at: seed.recording.startedAt, latitude: 32)]
        ))
        #expect(synchronizationAttempts.withLock { $0 } == 0)
        now.withLock { $0 = $0.addingTimeInterval(1) }
        try await store.appendTrackBatch(RecordedTrackBatch(
            recordingID: seed.recording.id,
            segmentID: segmentID,
            samples: [recordedSample(at: seed.recording.startedAt.addingTimeInterval(1), latitude: 33)]
        ))

        #expect(synchronizationAttempts.withLock { $0 } == 1)
    }
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
        #expect(snapshot.recording.flightPlanSnapshot.sourceData == Data("immutable-plan".utf8))
        #expect(snapshot.events == seed.events)
        #expect(await store.packages() == [.available(snapshot)])
    }

    @Test("An active recording cannot be deleted, while a closed recording can")
    func activeRecordingDeletionGuard() async throws {
        let root = temporaryDirectory()
        let seed = try makeSeed()
        let store = DiskFlightRecordingStore(rootDirectory: root)
        try await store.create(seed)

        await #expect(throws: FlightRecordingStoreError.recordingActive(id: seed.recording.id)) {
            try await store.remove(id: seed.recording.id)
        }
        try await store.close(id: seed.recording.id, closure: FlightRecordingClosure(
            outcome: .incomplete,
            cause: .manual,
            closedAt: seed.recording.startedAt.addingTimeInterval(60),
            elapsed: .seconds(60),
            landingEvidenceAvailable: false
        ))
        try await store.remove(id: seed.recording.id)

        #expect(await store.packages().isEmpty)
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
                legIDs: [legID],
                sourceData: Data("immutable-plan".utf8)
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

    private func recordedSample(at date: Date, latitude: Double) -> RecordedTrackSample {
        RecordedTrackSample(
            coordinate: WGS84Coordinate(latitudeDegrees: latitude, longitudeDegrees: 34.8),
            observedAt: date,
            horizontalAccuracyMeters: 20,
            altitudeMeters: nil,
            verticalAccuracyMeters: nil,
            groundSpeedMetersPerSecond: 0,
            speedAccuracyMetersPerSecond: nil,
            courseDegrees: nil,
            courseAccuracyDegrees: nil
        )
    }

    private enum TestFailure: Error {
        case expected
    }
}
