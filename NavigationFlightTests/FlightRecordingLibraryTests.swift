import Foundation
import Testing
@testable import NavigationFlight

@Suite("Flight recording library")
struct FlightRecordingLibraryTests {
    @Test("Active recordings sort before newer closed recordings")
    func activeRecordingsSortFirst() async throws {
        let activeID = try #require(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let closedID = try #require(UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB"))
        let active = try recording(id: activeID, startedAt: Date(timeIntervalSince1970: 1_000))
        let closed = try recording(
            id: closedID,
            startedAt: Date(timeIntervalSince1970: 2_000),
            closedAt: Date(timeIntervalSince1970: 2_600)
        )
        let activeSnapshot = FlightRecordingReadSnapshot(recording: active, events: [
            RecordedFlightEvent(
                id: UUID(),
                sequence: 3,
                occurredAt: active.startedAt.addingTimeInterval(300),
                elapsed: .seconds(300),
                origin: .pilot,
                payload: .positionCheckRequested
            ),
        ])
        let store = InMemoryFlightRecordingStore(packageResults: [
            .available(FlightRecordingReadSnapshot(recording: closed, events: [])),
            .available(activeSnapshot),
        ])
        let library = FlightRecordingLibrary(store: store)

        let rows = await library.recordings()

        #expect(rows.map(\.id) == [activeID, closedID])
        #expect(rows.first?.duration == .seconds(300))
    }

    @Test("Closed recording projects stored identity, route, duration, GPS, size, and actions")
    func closedRecordingProjection() async throws {
        let sourceData = try fixtureData()
        let plan = try FPLNavDecoder().decode(sourceData)
        let recordingID = try #require(UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC"))
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let closedAt = Date(timeIntervalSince1970: 4_600)
        let recording = try recording(
            id: recordingID,
            startedAt: startedAt,
            closedAt: closedAt,
            sourceData: sourceData,
            plan: plan
        )
        let store = InMemoryFlightRecordingStore(packageResults: [
            .available(FlightRecordingReadSnapshot(
                recording: recording,
                events: [],
                approximateSizeBytes: 4_800_000
            )),
        ])

        let row = try #require(await FlightRecordingLibrary(store: store).recordings().first)

        #expect(row.flightPlanTitle == "Coastal training navigation")
        #expect(row.route == "Synthetic waypoint 1 → Synthetic waypoint 2")
        #expect(row.duration == .seconds(3_600))
        #expect(row.status == .manuallyEnded)
        #expect(row.gpsCoverage == .unavailable)
        #expect(row.approximateSizeBytes == 4_800_000)
        #expect(row.canContinue == false)
        #expect(row.canDelete)
    }

    @Test("Corrupt package becomes an unavailable row without hiding healthy recordings")
    func corruptPackageIsIsolated() async throws {
        let healthyID = try #require(UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD"))
        let corruptID = try #require(UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE"))
        let healthy = try recording(id: healthyID, startedAt: Date(timeIntervalSince1970: 2_000))
        let store = InMemoryFlightRecordingStore(packageResults: [
            .corrupt(id: corruptID),
            .available(FlightRecordingReadSnapshot(recording: healthy, events: [])),
        ])

        let rows = await FlightRecordingLibrary(store: store).recordings(activeRecordingID: healthyID)

        #expect(rows.map(\.id) == [healthyID, corruptID])
        let unavailable = try #require(rows.last)
        #expect(unavailable.status == .unavailable)
        #expect(unavailable.flightPlanTitle == "Unavailable recording")
        #expect(unavailable.canContinue == false)
        #expect(unavailable.canDelete)
    }

    @Test("Corrupt package exposes a deletable unavailable detail without reading evidence")
    func corruptPackageDetail() async throws {
        let id = try #require(UUID(uuidString: "EFEFEFEF-EFEF-EFEF-EFEF-EFEFEFEFEFEF"))
        let store = InMemoryFlightRecordingStore(packageResults: [.corrupt(id: id)])

        let detail = try await FlightRecordingLibrary(store: store).detail(id: id)

        #expect(detail.id == id)
        #expect(detail.flightPlanTitle == "Unavailable recording")
        #expect(detail.status == .unavailable)
        #expect(detail.canExport == false)
        #expect(detail.canDelete)
        #expect(detail.isReadOnlySnapshot == false)
    }

    @Test("Deletion revalidates durable eligibility")
    func deletionEligibility() async throws {
        let activeID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let closedID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let active = try recording(id: activeID, startedAt: Date(timeIntervalSince1970: 1_000))
        let closed = try recording(
            id: closedID,
            startedAt: Date(timeIntervalSince1970: 2_000),
            closedAt: Date(timeIntervalSince1970: 2_100)
        )
        let store = InMemoryFlightRecordingStore(packageResults: [
            .available(FlightRecordingReadSnapshot(recording: active, events: [])),
            .available(FlightRecordingReadSnapshot(recording: closed, events: [])),
        ])
        let library = FlightRecordingLibrary(store: store)

        await #expect(throws: FlightRecordingStoreError.recordingActive(id: activeID)) {
            try await library.delete(id: activeID)
        }
        try await library.delete(id: closedID)

        #expect(await library.recordings().map(\.id) == [activeID])
    }

    @Test("Failed deletion preserves the recording for a retry")
    func failedDeletionPreservesRecording() async throws {
        let id = try #require(UUID(uuidString: "23232323-2323-2323-2323-232323232323"))
        let closed = try recording(
            id: id,
            startedAt: Date(timeIntervalSince1970: 2_000),
            closedAt: Date(timeIntervalSince1970: 2_100)
        )
        let store = InMemoryFlightRecordingStore(
            failure: .remove,
            packageResults: [.available(FlightRecordingReadSnapshot(recording: closed, events: []))]
        )
        let library = FlightRecordingLibrary(store: store)

        await #expect(throws: FlightRecordingStoreError.operationFailed(id: id)) {
            try await library.delete(id: id)
        }

        #expect(await library.recordings().map(\.id) == [id])
        #expect(await store.removeCallCount == 1)
    }

    @Test("Repeated executions remain distinct and equal start times use stable identity order")
    func repeatedExecutionsRemainDistinct() async throws {
        let firstID = try #require(UUID(uuidString: "10000000-0000-0000-0000-000000000000"))
        let secondID = try #require(UUID(uuidString: "20000000-0000-0000-0000-000000000000"))
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let first = try recording(id: firstID, startedAt: startedAt, closedAt: startedAt.addingTimeInterval(60))
        let second = try recording(id: secondID, startedAt: startedAt, closedAt: startedAt.addingTimeInterval(60))
        let store = InMemoryFlightRecordingStore(packageResults: [
            .available(FlightRecordingReadSnapshot(recording: second, events: [])),
            .available(FlightRecordingReadSnapshot(recording: first, events: [])),
        ])

        let rows = await FlightRecordingLibrary(store: store).recordings()

        #expect(rows.map(\.id) == [firstID, secondID])
        #expect(rows.map(\.flightPlanTitle) == ["Coastal Navigation", "Coastal Navigation"])
    }

    @Test("Detail projects identity, timing, closure, evidence summaries, and action eligibility")
    func detailProjection() async throws {
        let sourceData = try fixtureData()
        let plan = try FPLNavDecoder().decode(sourceData)
        let id = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let closedAt = Date(timeIntervalSince1970: 4_600)
        let recording = try recording(
            id: id,
            startedAt: startedAt,
            closedAt: closedAt,
            sourceData: sourceData,
            plan: plan
        )
        let segment = RecordedTrackSegment(id: UUID(), samples: [
            trackSample(latitude: 32, longitude: 34, at: startedAt, altitude: 100),
            trackSample(latitude: 32, longitude: 34.01, at: closedAt, altitude: 250),
        ])
        let store = InMemoryFlightRecordingStore(packageResults: [
            .available(FlightRecordingReadSnapshot(
                recording: recording,
                events: [],
                trackSegments: [segment],
                approximateSizeBytes: 4_800_000
            )),
        ])

        let detail = try await FlightRecordingLibrary(store: store).detail(id: id)

        #expect(detail.id == id)
        #expect(detail.flightPlanTitle == "Coastal training navigation")
        #expect(detail.route == "Synthetic waypoint 1 → Synthetic waypoint 2")
        #expect(detail.startedAt == startedAt)
        #expect(detail.endedAt == closedAt)
        #expect(detail.duration == .seconds(3_600))
        #expect(detail.closureOutcome == .incomplete)
        #expect(detail.closureCause == .manual)
        #expect(detail.distanceMeters != nil)
        #expect(detail.maximumAltitudeMeters == 250)
        #expect(detail.approximateSizeBytes == 4_800_000)
        #expect(detail.canExport)
        #expect(detail.canDelete)
        #expect(detail.isReadOnlySnapshot == false)
    }

    @Test("Export uses a closed immutable snapshot without changing the recording")
    func exportSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let recording = try recording(
            id: id,
            startedAt: startedAt,
            closedAt: startedAt.addingTimeInterval(60)
        )
        let snapshot = FlightRecordingReadSnapshot(
            recording: recording,
            events: [],
            trackSegments: [RecordedTrackSegment(id: UUID(), samples: [
                trackSample(latitude: 32, longitude: 34, at: startedAt, altitude: nil),
            ])]
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let library = FlightRecordingLibrary(store: store)

        let result = try await library.export(
            id: id,
            using: GPXExporter(temporaryDirectory: directory)
        )

        #expect(FileManager.default.fileExists(atPath: result.fileURL.path))
        #expect(try await store.readSnapshot(id: id) == snapshot)
    }

    private func recording(
        id: UUID,
        startedAt: Date,
        closedAt: Date? = nil,
        sourceData: Data? = nil,
        plan: FlightPlan? = nil
    ) throws -> FlightRecording {
        let planID = plan?.id ?? UUID()
        let legID = plan?.legs.first?.id ?? UUID()
        var recording = try FlightRecording.promoteForStartLeg(
            id: id,
            flightID: UUID(),
            flightPlanSnapshot: RecordedFlightPlanSnapshot(
                id: planID,
                title: plan?.title ?? "Coastal Navigation",
                legIDs: plan?.legs.map(\.id) ?? [legID],
                sourceData: sourceData
            ),
            legID: legID,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()]
        ).recording
        if let closedAt {
            _ = try recording.endManually(
                at: closedAt,
                elapsed: .seconds(closedAt.timeIntervalSince(startedAt)),
                eventIDs: [UUID(), UUID()]
            )
        }
        return recording
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: FlightRecordingLibraryFixtureLocator.self)
        let nested = bundle.url(
            forResource: "representative-v7",
            withExtension: "fplnav",
            subdirectory: "Fixtures/FPLNav/V7/Official"
        )
        let url = try #require(
            nested ?? bundle.url(forResource: "representative-v7", withExtension: "fplnav")
        )
        return try Data(contentsOf: url)
    }

    private func trackSample(
        latitude: Double,
        longitude: Double,
        at date: Date,
        altitude: Double?
    ) -> RecordedTrackSample {
        RecordedTrackSample(
            coordinate: WGS84Coordinate(latitudeDegrees: latitude, longitudeDegrees: longitude),
            observedAt: date,
            horizontalAccuracyMeters: 5,
            altitudeMeters: altitude,
            verticalAccuracyMeters: 5,
            groundSpeedMetersPerSecond: nil,
            speedAccuracyMetersPerSecond: nil,
            courseDegrees: nil,
            courseAccuracyDegrees: nil
        )
    }
}

private final class FlightRecordingLibraryFixtureLocator {}
