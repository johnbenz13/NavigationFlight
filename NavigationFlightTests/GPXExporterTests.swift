import Foundation
import Testing
@testable import NavigationFlight

@Suite("GPX exporter")
struct GPXExporterTests {
    @Test("Closed snapshot exports escaped GPX 1.1 points in chronological order")
    func exportsClosedSnapshot() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = try makeSnapshot(
            title: "Coastal & <Training>",
            samples: [
                makeSample(latitude: 32.2, longitude: 34.8, at: Date(timeIntervalSince1970: 200)),
                makeSample(latitude: 32.1, longitude: 34.7, at: Date(timeIntervalSince1970: 100)),
            ]
        )

        let result = try await GPXExporter(temporaryDirectory: directory).export(snapshot: snapshot)
        let xml = try String(contentsOf: result.fileURL, encoding: .utf8)

        #expect(xml.contains("<gpx version=\"1.1\""))
        #expect(xml.contains("Coastal &amp; &lt;Training&gt;"))
        #expect(xml.contains("lat=\"32.1\" lon=\"34.7\""))
        #expect(xml.contains("lat=\"32.2\" lon=\"34.8\""))
        #expect(try #require(xml.range(of: "lat=\"32.1\"")).lowerBound < #require(xml.range(of: "lat=\"32.2\"")).lowerBound)
    }

    @Test("Stored gaps remain separate segments and invalid optional values are omitted")
    func preservesSegmentsAndOmitsInvalidOptionalValues() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        var first = makeSample(latitude: 32.1, longitude: 34.7, at: Date(timeIntervalSince1970: 100))
        first = RecordedTrackSample(
            coordinate: first.coordinate,
            observedAt: first.observedAt,
            horizontalAccuracyMeters: 5,
            altitudeMeters: 250.5,
            verticalAccuracyMeters: 4,
            groundSpeedMetersPerSecond: 41.2,
            speedAccuracyMetersPerSecond: 1,
            courseDegrees: 278.25,
            courseAccuracyDegrees: 2
        )
        let invalid = RecordedTrackSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32.2, longitudeDegrees: 34.8),
            observedAt: Date(timeIntervalSince1970: 200),
            horizontalAccuracyMeters: 5,
            altitudeMeters: .nan,
            verticalAccuracyMeters: 4,
            groundSpeedMetersPerSecond: -1,
            speedAccuracyMetersPerSecond: 1,
            courseDegrees: 361,
            courseAccuracyDegrees: 2
        )
        let snapshot = try makeSnapshot(
            title: "Coastal",
            segments: [
                RecordedTrackSegment(id: UUID(), samples: [first]),
                RecordedTrackSegment(id: UUID(), samples: [invalid]),
            ]
        )

        let result = try await GPXExporter(temporaryDirectory: directory).export(snapshot: snapshot)
        let xml = try String(contentsOf: result.fileURL, encoding: .utf8)

        #expect(xml.components(separatedBy: "<trkseg>").count - 1 == 2)
        #expect(xml.contains("<ele>250.5</ele>"))
        #expect(xml.contains("<navflight:speed>41.2</navflight:speed>"))
        #expect(xml.contains("<navflight:course>278.25</navflight:course>"))
        #expect(xml.components(separatedBy: "<ele>").count - 1 == 1)
        #expect(xml.components(separatedBy: "<navflight:speed>").count - 1 == 1)
        #expect(xml.components(separatedBy: "<navflight:course>").count - 1 == 1)
        #expect(xml.contains("<wpt") == false)
    }

    @Test("Metadata and filename identify the closed recording deterministically")
    func metadataAndFilename() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = try makeSnapshot(
            title: "  Coastal / Training  ",
            segments: [RecordedTrackSegment(
                id: UUID(),
                samples: [makeSample(latitude: 32, longitude: 34, at: Date(timeIntervalSince1970: 100))]
            )]
        )

        let result = try await GPXExporter(temporaryDirectory: directory).export(snapshot: snapshot)
        let xml = try String(contentsOf: result.fileURL, encoding: .utf8)

        #expect(result.fileURL.lastPathComponent == "Coastal-Training-19700101T000140Z-12345678.gpx")
        #expect(xml.contains("<navflight:flightPlanID>"))
        #expect(xml.contains("<navflight:status>incomplete</navflight:status>"))
        #expect(xml.contains("<navflight:closureCause>manual</navflight:closureCause>"))
        #expect(xml.contains("<navflight:coverage>unavailable</navflight:coverage>"))
    }

    @Test("Active and recoverable snapshots are rejected without creating files")
    func rejectsOpenRecording() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = try makeSnapshot(
            title: "Coastal",
            segments: [],
            closeRecording: false
        )

        await #expect(throws: GPXExportError.recordingNotClosed(id: snapshot.recording.id)) {
            try await GPXExporter(temporaryDirectory: directory).export(snapshot: snapshot)
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test("Cancellation and failed installation clean partial files")
    func cancellationAndFailureCleanPartialFiles() async throws {
        let cancelledDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: cancelledDirectory) }
        let snapshot = try makeSnapshot(
            title: "Coastal",
            segments: [RecordedTrackSegment(
                id: UUID(),
                samples: [makeSample(latitude: 32, longitude: 34, at: Date(timeIntervalSince1970: 100))]
            )]
        )
        let task = Task {
            try await GPXExporter(temporaryDirectory: cancelledDirectory).export(snapshot: snapshot)
        }
        task.cancel()
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(try FileManager.default.contentsOfDirectory(atPath: cancelledDirectory.path).isEmpty)

        let failedDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: failedDirectory) }
        let destination = failedDirectory.appending(path: "Coastal-19700101T000140Z-12345678.gpx")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: false)
        await #expect(throws: (any Error).self) {
            try await GPXExporter(temporaryDirectory: failedDirectory).export(snapshot: snapshot)
        }
        let names = try FileManager.default.contentsOfDirectory(atPath: failedDirectory.path)
        #expect(names == [destination.lastPathComponent])
    }

    private func makeSnapshot(
        title: String,
        samples: [RecordedTrackSample]
    ) throws -> FlightRecordingReadSnapshot {
        try makeSnapshot(
            title: title,
            segments: [RecordedTrackSegment(id: UUID(), samples: samples)]
        )
    }

    private func makeSnapshot(
        title: String,
        segments: [RecordedTrackSegment],
        closeRecording: Bool = true
    ) throws -> FlightRecordingReadSnapshot {
        let startedAt = Date(timeIntervalSince1970: 100)
        let recordingID = try #require(UUID(uuidString: "12345678-1234-1234-1234-123456789ABC"))
        let legID = UUID()
        var recording = try FlightRecording.promoteForStartLeg(
            id: recordingID,
            flightID: UUID(),
            flightPlanSnapshot: RecordedFlightPlanSnapshot(
                id: UUID(),
                title: title,
                legIDs: [legID]
            ),
            legID: legID,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()]
        ).recording
        if closeRecording {
            _ = try recording.endManually(
                at: Date(timeIntervalSince1970: 300),
                elapsed: .seconds(200),
                eventIDs: [UUID(), UUID()]
            )
        }
        return FlightRecordingReadSnapshot(
            recording: recording,
            events: [],
            trackSegments: segments
        )
    }

    private func makeSample(
        latitude: Double,
        longitude: Double,
        at date: Date
    ) -> RecordedTrackSample {
        RecordedTrackSample(
            coordinate: WGS84Coordinate(latitudeDegrees: latitude, longitudeDegrees: longitude),
            observedAt: date,
            horizontalAccuracyMeters: 5,
            altitudeMeters: nil,
            verticalAccuracyMeters: nil,
            groundSpeedMetersPerSecond: nil,
            speedAccuracyMetersPerSecond: nil,
            courseDegrees: nil,
            courseAccuracyDegrees: nil
        )
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
