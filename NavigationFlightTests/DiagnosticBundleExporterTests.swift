import FlightEvidenceCore
import Foundation
import Testing
@testable import NavigationFlight

@Suite("Diagnostic bundle exporter")
struct DiagnosticBundleExporterTests {
    @Test("Closed evidence publishes a validated lossless bundle without mutating its source")
    func exportsClosedEvidence() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let snapshot = try closedSnapshot()
        let evidence = FlightEvidenceSnapshot(
            capturedAt: Date(timeIntervalSince1970: 2_000),
            recording: snapshot,
            context: .init(appVersion: "1.2", appBuild: "34", platform: "iPadOS", osVersion: "27.0")
        )

        let result = try await DiagnosticBundleExporter(temporaryDirectory: directory).export(evidence)
        let data = try Data(contentsOf: result.fileURL)
        let bundle = try DiagnosticBundleCodec().decode(data)

        #expect(result.fileURL.pathExtension == "nflightbundle")
        #expect(result.byteCount == data.count)
        #expect(result.schemaVersion == 1)
        #expect(bundle.recordingManifest.recordingIdentifier == snapshot.recording.id)
        #expect(bundle.flightPlan.sourceData == snapshot.recording.flightPlanSnapshot.sourceData)
        #expect(bundle.orderedEvents.map(\.sequence) == snapshot.events.map(\.sequence))
        #expect(bundle.trackSegments.map(\.identifier) == snapshot.trackSegments.map(\.id))
        #expect(bundle.trackSegments[0].samples[0].barometricAltitudeMeters == 101)
        #expect(bundle.trackSegments[0].samples[0].deviceHeadingDegrees == 275)
        #expect(snapshot == evidence.recording)
    }

    @Test("Active evidence is rejected without publishing a file")
    func rejectsActiveEvidence() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let recording = try activeRecording()
        let evidence = FlightEvidenceSnapshot(
            capturedAt: Date(),
            recording: FlightRecordingReadSnapshot(recording: recording, events: []),
            context: .init(appVersion: "1", appBuild: "1", platform: "iOS", osVersion: "27")
        )

        await #expect(throws: DiagnosticExportError.recordingNotClosed(recording.id)) {
            try await DiagnosticBundleExporter(temporaryDirectory: directory).export(evidence)
        }
        #expect(try publishedFiles(in: directory).isEmpty)
    }

    @Test("Cancellation leaves no partial or publishable file and permits retry")
    func cancellationAndRetry() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let evidence = FlightEvidenceSnapshot(
            capturedAt: Date(),
            recording: try closedSnapshot(),
            context: .init(appVersion: "1", appBuild: "1", platform: "iOS", osVersion: "27")
        )
        let exporter = DiagnosticBundleExporter(temporaryDirectory: directory)
        let task = Task {
            try await exporter.export(evidence)
        }
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
        #expect(try publishedFiles(in: directory).isEmpty)

        let retry = try await exporter.export(evidence)
        #expect(FileManager.default.fileExists(atPath: retry.fileURL.path))
    }

    @Test("Every recorded event payload survives mapping and codec round-trip in source order")
    func everyEventPayloadRoundTrips() throws {
        let legID = UUID()
        let otherLegID = UUID()
        let targetID = UUID()
        let originalEventID = UUID()
        let observedAt = Date(timeIntervalSince1970: 1_050)
        let payloads: [RecordedFlightEventPayload] = [
            .recordingStarted(cause: .startLegWithoutLocation),
            .recordingStarted(cause: .automaticTakeoff),
            .recordingStarted(cause: .partialStart),
            .legStarted(legID: legID),
            .destinationIdentified(legID: legID),
            .identificationPointReached(key: .init(legID: legID, identificationPointID: targetID)),
            .waypointReached(legID: legID),
            .automaticNextLegTransition(fromLegID: legID, toLegID: otherLegID),
            .finalWaypointReached(legID: otherLegID),
            .automaticLegRecovery(legID: legID),
            .etaRevised(
                target: .init(legID: legID, kind: .identificationPoint, targetID: targetID),
                priorSeconds: nil,
                committedSeconds: 120
            ),
            .etaRevised(
                target: .init(legID: legID, kind: .destination, targetID: otherLegID),
                priorSeconds: 120,
                committedSeconds: 180
            ),
            .headingRevised(legID: legID, priorDegrees: 359, committedDegrees: 1),
            .reachUndone(originalEventID: originalEventID),
            .positionCheckRequested,
            .positionCheckEnded(outcome: .endedWithoutDisclosure),
            .positionCheckEnded(outcome: .disclosed(sample: .init(
                coordinate: .init(latitudeDegrees: 32.1, longitudeDegrees: 34.8),
                observedAt: observedAt,
                horizontalAccuracyMeters: 4
            ))),
            .storageDegraded(reason: .trackWriteFailed),
            .locationAvailabilityChanged(.signalLost),
            .physicalStateChanged(from: .groundMovement, to: .airborne),
            .physicalStateCorrected(
                originalEventID: originalEventID,
                from: .airborne,
                to: .groundMovement
            ),
            .navigationCompleted,
            .recoveryContinued,
            .manualEnd,
            .recordingClosed(outcome: .incomplete, cause: .manual),
        ]
        let events = payloads.enumerated().map { index, payload in
            RecordedFlightEvent(
                id: UUID(),
                sequence: UInt64(index),
                occurredAt: observedAt.addingTimeInterval(Double(index)),
                elapsed: .seconds(index),
                origin: .system,
                payload: payload
            )
        }
        let closed = try closedSnapshot()
        let snapshot = FlightEvidenceSnapshot(
            capturedAt: observedAt,
            recording: .init(
                recording: closed.recording,
                events: events,
                trackSegments: closed.trackSegments
            ),
            context: .init(appVersion: "1", appBuild: "1", platform: "iPadOS", osVersion: "27")
        )

        let mapped = try FlightEvidenceMapper().bundle(from: snapshot)
        let roundTripped = try DiagnosticBundleCodec().decode(DiagnosticBundleCodec().encode(mapped))

        #expect(roundTripped.orderedEvents.map(\.sequence) == events.map(\.sequence))
        #expect(roundTripped.orderedEvents.map(\.payload) == mapped.orderedEvents.map(\.payload))
        #expect(roundTripped.orderedEvents.count == payloads.count)
    }

    private func closedSnapshot() throws -> FlightRecordingReadSnapshot {
        var recording = try activeRecording()
        let closedAt = recording.startedAt.addingTimeInterval(60)
        let closingEvents = try recording.endManually(
            at: closedAt,
            elapsed: .seconds(60),
            eventIDs: [UUID(), UUID()]
        )
        let event = RecordedFlightEvent(
            id: UUID(),
            sequence: 0,
            occurredAt: recording.startedAt.addingTimeInterval(30),
            elapsed: .seconds(30),
            origin: .pilot,
            payload: .positionCheckEnded(outcome: .disclosed(sample: .init(
                coordinate: .init(latitudeDegrees: 32.1, longitudeDegrees: 34.8),
                observedAt: recording.startedAt.addingTimeInterval(30),
                horizontalAccuracyMeters: 5
            )))
        )
        let sample = RecordedTrackSample(
            coordinate: .init(latitudeDegrees: 32.1, longitudeDegrees: 34.8),
            observedAt: recording.startedAt.addingTimeInterval(20),
            horizontalAccuracyMeters: 4,
            altitudeMeters: 100,
            verticalAccuracyMeters: 2,
            groundSpeedMetersPerSecond: 50,
            speedAccuracyMetersPerSecond: 1,
            courseDegrees: 90,
            courseAccuracyDegrees: 3,
            barometricAltitudeMeters: 101,
            deviceHeadingDegrees: 275,
            deviceHeadingAccuracyDegrees: 4
        )
        return FlightRecordingReadSnapshot(
            recording: recording,
            events: [event] + closingEvents,
            trackSegments: [.init(id: UUID(), samples: [sample])]
        )
    }

    private func activeRecording() throws -> FlightRecording {
        let legID = UUID()
        return try FlightRecording.promoteForStartLeg(
            id: UUID(),
            flightID: UUID(),
            flightPlanSnapshot: .init(
                id: UUID(),
                title: "Synthetic Flight",
                legIDs: [legID],
                sourceData: Data([0, 1, 2, 255])
            ),
            legID: legID,
            startedAt: Date(timeIntervalSince1970: 1_000),
            eventIDs: [UUID(), UUID()]
        ).recording
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func publishedFiles(in directory: URL) throws -> [URL] {
        let exportDirectory = directory.appending(path: "NavigationFlight-Diagnostic-Exports")
        guard FileManager.default.fileExists(atPath: exportDirectory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(
            at: exportDirectory,
            includingPropertiesForKeys: nil
        )
    }
}
