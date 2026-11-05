import Darwin
import Foundation

actor DiskFlightRecordingStore: FlightRecordingStore {
    typealias BeforeInstall = @Sendable (URL) throws -> Void
    typealias BeforeClose = @Sendable (UUID) throws -> Void
    typealias BeforeTrackSynchronization = @Sendable (UUID) throws -> Void

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let beforeInstall: BeforeInstall
    private let beforeClose: BeforeClose
    private let synchronizationInterval: TimeInterval
    private let now: @Sendable () -> Date
    private let beforeTrackSynchronization: BeforeTrackSynchronization
    private var lastTrackSynchronization: [UUID: Date] = [:]

    init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        beforeInstall: @escaping BeforeInstall = { _ in },
        beforeClose: @escaping BeforeClose = { _ in },
        synchronizationInterval: TimeInterval = 5,
        now: @escaping @Sendable () -> Date = Date.init,
        beforeTrackSynchronization: @escaping BeforeTrackSynchronization = { _ in }
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.beforeInstall = beforeInstall
        self.beforeClose = beforeClose
        self.synchronizationInterval = synchronizationInterval
        self.now = now
        self.beforeTrackSynchronization = beforeTrackSynchronization
    }

    func create(_ seed: FlightRecordingSeed) throws {
        let destination = packageDirectory(id: seed.recording.id)
        guard !fileManager.fileExists(atPath: destination.path) else {
            throw FlightRecordingStoreError.duplicatePackage(id: seed.recording.id)
        }
        let temporary = rootDirectory.appending(
            path: ".\(seed.recording.id.uuidString.lowercased())-\(UUID().uuidString).tmp",
            directoryHint: .isDirectory
        )
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: temporary, withIntermediateDirectories: false)
            try writeAndSynchronize(
                FlightRecordingCoding.encoder.encode(FlightRecordingManifestDTO(recording: seed.recording)),
                to: temporary.appending(path: "manifest.json")
            )
            try writeAndSynchronize(
                FlightRecordingCoding.encoder.encode(
                    RecordedFlightPlanSnapshotDTO(snapshot: seed.recording.flightPlanSnapshot)
                ),
                to: temporary.appending(path: "flight-plan.json")
            )
            let eventData = try seed.events.map { event in
                try FlightRecordingCoding.encoder.encode(RecordedFlightEventEnvelopeDTO(event: event))
            }.reduce(into: Data()) { data, line in
                data.append(line)
                data.append(0x0A)
            }
            try writeAndSynchronize(eventData, to: temporary.appending(path: "events.ndjson"))
            let trackDirectory = temporary.appending(path: "track", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: trackDirectory, withIntermediateDirectories: false)
            for segment in seed.trackSegments {
                let batch = RecordedTrackBatch(
                    recordingID: seed.recording.id,
                    segmentID: segment.id,
                    samples: segment.samples
                )
                var data = try FlightRecordingCoding.encoder.encode(RecordedTrackBatchEnvelopeDTO(batch: batch))
                data.append(0x0A)
                try writeAndSynchronize(data, to: trackFile(recordingID: seed.recording.id, segmentID: segment.id, root: temporary))
            }
            let initialSnapshot = FlightRecordingReadSnapshot(
                recording: seed.recording,
                events: seed.events,
                trackSegments: seed.trackSegments
            )
            try? writeAndSynchronize(
                FlightRecordingCoding.encoder.encode(initialSnapshot.evidenceSummary),
                to: temporary.appending(path: "summary.json")
            )
            try synchronizeDirectory(temporary)
            try beforeInstall(temporary)
            try fileManager.moveItem(at: temporary, to: destination)
            try synchronizeDirectory(rootDirectory)
            lastTrackSynchronization[seed.recording.id] = now()
        } catch let error as FlightRecordingStoreError {
            try? fileManager.removeItem(at: temporary)
            throw error
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw FlightRecordingStoreError.operationFailed(id: seed.recording.id)
        }
    }

    func appendTrackBatch(_ batch: RecordedTrackBatch) throws {
        guard !batch.samples.isEmpty else { return }
        let trackDirectory = packageDirectory(id: batch.recordingID)
            .appending(path: "track", directoryHint: .isDirectory)
        do {
            try fileManager.createDirectory(at: trackDirectory, withIntermediateDirectories: true)
            let url = trackFile(recordingID: batch.recordingID, segmentID: batch.segmentID)
            if !fileManager.fileExists(atPath: url.path) {
                fileManager.createFile(atPath: url.path, contents: nil)
            }
            let handle = try FileHandle(forWritingTo: url)
            try handle.seekToEnd()
            try handle.write(contentsOf: FlightRecordingCoding.encoder.encode(
                RecordedTrackBatchEnvelopeDTO(batch: batch)
            ))
            try handle.write(contentsOf: Data([0x0A]))
            try handle.close()
            try? fileManager.removeItem(at: packageDirectory(id: batch.recordingID).appending(path: "summary.json"))
            let last = lastTrackSynchronization[batch.recordingID] ?? .distantPast
            if now().timeIntervalSince(last) >= synchronizationInterval {
                try synchronizeTrack(recordingID: batch.recordingID)
            }
        } catch {
            throw FlightRecordingStoreError.operationFailed(id: batch.recordingID)
        }
    }

    func synchronizeTrack(recordingID: UUID) throws {
        let trackDirectory = packageDirectory(id: recordingID).appending(path: "track", directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: trackDirectory.path) else {
            throw FlightRecordingStoreError.corruptPackage(id: recordingID)
        }
        do {
            try beforeTrackSynchronization(recordingID)
            for file in try fileManager.contentsOfDirectory(at: trackDirectory, includingPropertiesForKeys: nil) {
                let handle = try FileHandle(forWritingTo: file)
                try handle.synchronize()
                try handle.close()
            }
            try synchronizeDirectory(trackDirectory)
            lastTrackSynchronization[recordingID] = now()
        } catch {
            throw FlightRecordingStoreError.operationFailed(id: recordingID)
        }
    }

    func appendEvent(
        _ event: RecordedFlightEvent,
        recordingID: UUID,
        synchronize: Bool
    ) throws {
        let snapshot = try readSnapshot(id: recordingID)
        let expectedSequence = snapshot.events.last.map { $0.sequence + 1 } ?? 0
        guard event.sequence == expectedSequence else {
            throw FlightRecordingStoreError.invalidEventSequence(id: recordingID)
        }
        do {
            let handle = try FileHandle(
                forWritingTo: packageDirectory(id: recordingID).appending(path: "events.ndjson")
            )
            try handle.seekToEnd()
            try handle.write(contentsOf: FlightRecordingCoding.encoder.encode(
                RecordedFlightEventEnvelopeDTO(event: event)
            ))
            try handle.write(contentsOf: Data([0x0A]))
            if synchronize { try handle.synchronize() }
            try handle.close()
            try? fileManager.removeItem(at: packageDirectory(id: recordingID).appending(path: "summary.json"))
        } catch let error as FlightRecordingStoreError {
            throw error
        } catch {
            throw FlightRecordingStoreError.operationFailed(id: recordingID)
        }
    }

    func packages() -> [FlightRecordingPackageResult] {
        guard fileManager.fileExists(atPath: rootDirectory.path) else { return [] }
        guard let directories = try? fileManager.contentsOfDirectory(
            at: rootDirectory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [.corrupt(id: nil)] }
        return directories.compactMap { directory in
            guard (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                  !directory.lastPathComponent.hasSuffix(".tmp") else { return nil }
            let id = UUID(uuidString: directory.lastPathComponent)
            do {
                return .available(try readSnapshot(at: directory, expectedID: id))
            } catch let FlightRecordingStoreError.unsupportedVersion(id, version) {
                return .unsupported(id: id, schemaVersion: version)
            } catch {
                return .corrupt(id: id)
            }
        }
    }

    func readSnapshot(id: UUID) throws -> FlightRecordingReadSnapshot {
        try readSnapshot(at: packageDirectory(id: id), expectedID: id)
    }

    func close(id: UUID, closure: FlightRecordingClosure) throws {
        let directory = packageDirectory(id: id)
        let manifestURL = directory.appending(path: "manifest.json")
        let temporary = directory.appending(path: ".manifest-\(UUID().uuidString).tmp")
        do {
            var manifest = try FlightRecordingCoding.decoder.decode(
                FlightRecordingManifestDTO.self,
                from: Data(contentsOf: manifestURL)
            )
            guard manifest.closure == nil else {
                throw FlightRecordingStoreError.operationFailed(id: id)
            }
            try beforeClose(id)
            manifest.closure = FlightRecordingClosureDTO(closure: closure)
            let snapshot = try readSnapshot(id: id)
            if snapshot.recording.navigationState == .complete {
                manifest.navigationState = "complete"
            }
            manifest.nextEventSequence = UInt64(snapshot.events.count)
            try writeAndSynchronize(FlightRecordingCoding.encoder.encode(manifest), to: temporary)
            _ = try fileManager.replaceItemAt(manifestURL, withItemAt: temporary)
            try? fileManager.removeItem(at: directory.appending(path: "summary.json"))
            try synchronizeDirectory(directory)
        } catch let error as FlightRecordingStoreError {
            try? fileManager.removeItem(at: temporary)
            throw error
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw FlightRecordingStoreError.operationFailed(id: id)
        }
    }

    func remove(id: UUID) throws {
        let snapshot = try readSnapshot(id: id)
        guard snapshot.recording.closure != nil else {
            throw FlightRecordingStoreError.recordingActive(id: id)
        }
        do {
            try fileManager.removeItem(at: packageDirectory(id: id))
            try synchronizeDirectory(rootDirectory)
            lastTrackSynchronization[id] = nil
        } catch {
            throw FlightRecordingStoreError.operationFailed(id: id)
        }
    }

    private func readSnapshot(
        at directory: URL,
        expectedID: UUID?
    ) throws -> FlightRecordingReadSnapshot {
        do {
            let manifest = try FlightRecordingCoding.decoder.decode(
                FlightRecordingManifestDTO.self,
                from: Data(contentsOf: directory.appending(path: "manifest.json"))
            )
            guard expectedID == nil || expectedID == manifest.id else {
                throw FlightRecordingStoreError.corruptPackage(id: expectedID)
            }
            let plan = try FlightRecordingCoding.decoder.decode(
                RecordedFlightPlanSnapshotDTO.self,
                from: Data(contentsOf: directory.appending(path: "flight-plan.json"))
            )
            guard plan.schemaVersion == RecordedFlightPlanSnapshotDTO.currentSchemaVersion else {
                throw FlightRecordingStoreError.unsupportedVersion(
                    id: manifest.id,
                    schemaVersion: plan.schemaVersion
                )
            }
            let eventData = try Data(contentsOf: directory.appending(path: "events.ndjson"))
            let events = try eventData.split(separator: 0x0A).map { line in
                try FlightRecordingCoding.decoder.decode(
                    RecordedFlightEventEnvelopeDTO.self,
                    from: Data(line)
                ).domain()
            }
            guard events.map(\.sequence) == Array(0..<UInt64(events.count)) else {
                throw FlightRecordingStoreError.corruptPackage(id: manifest.id)
            }
            let trackSegments = try readTrackSegments(recordingID: manifest.id, directory: directory)
            let gpsCoverage: GPSCoverageState = trackSegments.isEmpty
                ? .unavailable
                : (trackSegments.count == 1 ? .available : .partial)
            let restoredPhysicalState = events.reversed().compactMap { event -> PhysicalFlightState? in
                switch event.payload {
                case .physicalStateChanged(_, let to), .physicalStateCorrected(_, _, let to): to
                default: nil
                }
            }.first
            let snapshot = FlightRecordingReadSnapshot(
                recording: try manifest.domain(
                    snapshot: plan.domain,
                    physicalState: restoredPhysicalState,
                    navigationState: events.contains { $0.payload == .navigationCompleted }
                        ? .complete
                        : nil,
                    gpsCoverage: gpsCoverage,
                    nextEventSequence: UInt64(events.count)
                ),
                events: events,
                trackSegments: trackSegments,
                approximateSizeBytes: approximatePackageSize(at: directory)
            )
            let summaryURL = directory.appending(path: "summary.json")
            let summary: FlightRecordingEvidenceSummary
            if let data = try? Data(contentsOf: summaryURL),
               let cached = try? FlightRecordingCoding.decoder.decode(
                   FlightRecordingEvidenceSummary.self,
                   from: data
               ) {
                summary = cached
            } else {
                summary = FlightRecordingSummaryProjector().project(snapshot: snapshot)
                try? replaceSummary(summary, at: summaryURL, directory: directory)
            }
            return FlightRecordingReadSnapshot(
                recording: snapshot.recording,
                events: snapshot.events,
                trackSegments: snapshot.trackSegments,
                approximateSizeBytes: approximatePackageSize(at: directory),
                evidenceSummary: summary
            )
        } catch let error as FlightRecordingStoreError {
            throw error
        } catch {
            throw FlightRecordingStoreError.corruptPackage(id: expectedID)
        }
    }

    private func packageDirectory(id: UUID) -> URL {
        rootDirectory.appending(path: id.uuidString.lowercased(), directoryHint: .isDirectory)
    }

    private func trackFile(recordingID: UUID, segmentID: UUID, root: URL? = nil) -> URL {
        (root ?? packageDirectory(id: recordingID))
            .appending(path: "track", directoryHint: .isDirectory)
            .appending(path: "\(segmentID.uuidString.lowercased()).ndjson")
    }

    private func readTrackSegments(recordingID: UUID, directory: URL) throws -> [RecordedTrackSegment] {
        let trackDirectory = directory.appending(path: "track", directoryHint: .isDirectory)
        guard fileManager.fileExists(atPath: trackDirectory.path) else { return [] }
        let files = try fileManager.contentsOfDirectory(at: trackDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "ndjson" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        return try files.compactMap { file in
            guard let segmentID = UUID(uuidString: file.deletingPathExtension().lastPathComponent) else {
                throw FlightRecordingStoreError.corruptPackage(id: recordingID)
            }
            let data = try Data(contentsOf: file)
            let lines = data.split(separator: 0x0A, omittingEmptySubsequences: false)
            var samples: [RecordedTrackSample] = []
            for (index, line) in lines.enumerated() where !line.isEmpty {
                do {
                    let batch = try FlightRecordingCoding.decoder.decode(
                        RecordedTrackBatchEnvelopeDTO.self,
                        from: Data(line)
                    ).domain()
                    guard batch.recordingID == recordingID, batch.segmentID == segmentID else {
                        throw FlightRecordingStoreError.corruptPackage(id: recordingID)
                    }
                    samples.append(contentsOf: batch.samples)
                } catch where index == lines.indices.last {
                    break
                }
            }
            return RecordedTrackSegment(id: segmentID, samples: samples)
        }
    }

    private func approximatePackageSize(at directory: URL) -> Int64? {
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return nil }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(
                forKeys: [.isRegularFileKey, .fileSizeKey]
            ),
            values.isRegularFile == true,
            let fileSize = values.fileSize else { continue }
            total += Int64(fileSize)
        }
        return total
    }

    private func writeAndSynchronize(_ data: Data, to url: URL) throws {
        try data.write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        try handle.synchronize()
        try handle.close()
    }

    private func replaceSummary(
        _ summary: FlightRecordingEvidenceSummary,
        at destination: URL,
        directory: URL
    ) throws {
        let temporary = directory.appending(path: ".summary-\(UUID().uuidString).tmp")
        try writeAndSynchronize(FlightRecordingCoding.encoder.encode(summary), to: temporary)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
        try synchronizeDirectory(directory)
    }

    private func synchronizeDirectory(_ url: URL) throws {
        let descriptor = open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { Darwin.close(descriptor) }
        guard fsync(descriptor) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
