import Darwin
import Foundation

actor DiskFlightRecordingStore: FlightRecordingStore {
    typealias BeforeInstall = @Sendable (URL) throws -> Void
    typealias BeforeClose = @Sendable (UUID) throws -> Void

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let beforeInstall: BeforeInstall
    private let beforeClose: BeforeClose

    init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        beforeInstall: @escaping BeforeInstall = { _ in },
        beforeClose: @escaping BeforeClose = { _ in }
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.beforeInstall = beforeInstall
        self.beforeClose = beforeClose
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
            try synchronizeDirectory(temporary)
            try beforeInstall(temporary)
            try fileManager.moveItem(at: temporary, to: destination)
            try synchronizeDirectory(rootDirectory)
        } catch let error as FlightRecordingStoreError {
            try? fileManager.removeItem(at: temporary)
            throw error
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw FlightRecordingStoreError.operationFailed(id: seed.recording.id)
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
            try synchronizeDirectory(directory)
        } catch let error as FlightRecordingStoreError {
            try? fileManager.removeItem(at: temporary)
            throw error
        } catch {
            try? fileManager.removeItem(at: temporary)
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
            return FlightRecordingReadSnapshot(
                recording: try manifest.domain(
                    snapshot: plan.domain,
                    navigationState: events.contains { $0.payload == .navigationCompleted }
                        ? .complete
                        : nil,
                    nextEventSequence: UInt64(events.count)
                ),
                events: events
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

    private func writeAndSynchronize(_ data: Data, to url: URL) throws {
        try data.write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        try handle.synchronize()
        try handle.close()
    }

    private func synchronizeDirectory(_ url: URL) throws {
        let descriptor = open(url.path, O_RDONLY)
        guard descriptor >= 0 else { throw CocoaError(.fileWriteUnknown) }
        defer { Darwin.close(descriptor) }
        guard fsync(descriptor) == 0 else { throw CocoaError(.fileWriteUnknown) }
    }
}
