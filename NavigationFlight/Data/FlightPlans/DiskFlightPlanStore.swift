import Foundation

actor DiskFlightPlanStore: FlightPlanStore {
    typealias BeforeInstall = @Sendable (URL) throws -> Void
    typealias BeforeRemove = @Sendable (UUID) throws -> Void

    private struct Metadata: Codable {
        let id: UUID
        let modifiedAt: Date
        let importedAt: Date
        let storageSchemaVersion: Int
    }

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let beforeInstall: BeforeInstall
    private let beforeRemove: BeforeRemove

    init(
        rootDirectory: URL,
        fileManager: FileManager = .default,
        beforeInstall: @escaping BeforeInstall = { _ in },
        beforeRemove: @escaping BeforeRemove = { _ in }
    ) {
        self.rootDirectory = rootDirectory
        self.fileManager = fileManager
        self.beforeInstall = beforeInstall
        self.beforeRemove = beforeRemove
    }

    func records() throws -> [StoredFlightPlan] {
        guard fileManager.fileExists(atPath: rootDirectory.path(percentEncoded: false)) else { return [] }
        let directories: [URL]
        do {
            directories = try fileManager.contentsOfDirectory(
                at: rootDirectory,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
                    && !url.lastPathComponent.hasSuffix(".tmp")
            }
        } catch {
            throw FlightPlanStoreError.operationFailed(id: nil)
        }
        return try directories.map(readRecord(at:))
    }

    func replace(_ record: StoredFlightPlan, expecting expectedModifiedAt: Date?) throws {
        let destination = recordDirectory(id: record.id)
        let existingRevision: Date?
        if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
            existingRevision = try readMetadata(at: destination, fallbackID: record.id).modifiedAt
        } else {
            existingRevision = nil
        }
        guard existingRevision == expectedModifiedAt else {
            throw FlightPlanStoreError.conflict(id: record.id)
        }

        let temporary = rootDirectory.appending(
            path: ".\(record.id.uuidString.lowercased())-\(UUID().uuidString).tmp",
            directoryHint: .isDirectory
        )
        do {
            try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: temporary, withIntermediateDirectories: false)
            try writeAndSynchronize(record.sourceData, to: temporary.appending(path: "plan.fplnav"))
            let metadata = Metadata(
                id: record.id,
                modifiedAt: record.modifiedAt,
                importedAt: record.importedAt,
                storageSchemaVersion: record.storageSchemaVersion
            )
            try writeAndSynchronize(try Self.encoder.encode(metadata), to: temporary.appending(path: "metadata.json"))
            try beforeInstall(temporary)

            if fileManager.fileExists(atPath: destination.path(percentEncoded: false)) {
                _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
            } else {
                try fileManager.moveItem(at: temporary, to: destination)
            }
        } catch let error as FlightPlanStoreError {
            try? fileManager.removeItem(at: temporary)
            throw error
        } catch {
            try? fileManager.removeItem(at: temporary)
            throw FlightPlanStoreError.operationFailed(id: record.id)
        }
    }

    func remove(id: UUID) throws {
        let directory = recordDirectory(id: id)
        do {
            try beforeRemove(id)
            if fileManager.fileExists(atPath: directory.path(percentEncoded: false)) {
                try fileManager.removeItem(at: directory)
            }
            guard !fileManager.fileExists(atPath: directory.path(percentEncoded: false)) else {
                throw FlightPlanStoreError.operationFailed(id: id)
            }
        } catch let error as FlightPlanStoreError {
            throw error
        } catch {
            throw FlightPlanStoreError.operationFailed(id: id)
        }
    }

    private func readRecord(at directory: URL) throws -> StoredFlightPlan {
        let fallbackID = UUID(uuidString: directory.lastPathComponent)
        let metadata = try readMetadata(at: directory, fallbackID: fallbackID)
        let sourceData: Data
        do {
            sourceData = try Data(contentsOf: directory.appending(path: "plan.fplnav"))
        } catch {
            throw FlightPlanStoreError.corruptRecord(id: metadata.id)
        }
        return StoredFlightPlan(
            id: metadata.id,
            modifiedAt: metadata.modifiedAt,
            importedAt: metadata.importedAt,
            sourceData: sourceData,
            storageSchemaVersion: metadata.storageSchemaVersion
        )
    }

    private func readMetadata(at directory: URL, fallbackID: UUID?) throws -> Metadata {
        do {
            let data = try Data(contentsOf: directory.appending(path: "metadata.json"))
            let metadata = try Self.decoder.decode(Metadata.self, from: data)
            guard metadata.id == fallbackID || fallbackID == nil,
                  metadata.storageSchemaVersion == StoredFlightPlan.currentStorageSchemaVersion else {
                throw FlightPlanStoreError.corruptRecord(id: fallbackID ?? metadata.id)
            }
            return metadata
        } catch let error as FlightPlanStoreError {
            throw error
        } catch {
            throw FlightPlanStoreError.corruptRecord(id: fallbackID)
        }
    }

    private func recordDirectory(id: UUID) -> URL {
        rootDirectory.appending(path: id.uuidString.lowercased(), directoryHint: .isDirectory)
    }

    private func writeAndSynchronize(_ data: Data, to url: URL) throws {
        try data.write(to: url)
        let handle = try FileHandle(forWritingTo: url)
        try handle.synchronize()
        try handle.close()
    }

    nonisolated private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(iso8601String(from: date, includingFractionalSeconds: true))
        }
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    nonisolated private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = iso8601Date(from: value, includingFractionalSeconds: true)
                ?? iso8601Date(from: value, includingFractionalSeconds: false) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Expected an ISO 8601 date."
            )
        }
        return decoder
    }

    nonisolated private static func iso8601String(
        from date: Date,
        includingFractionalSeconds: Bool
    ) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = includingFractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter.string(from: date)
    }

    nonisolated private static func iso8601Date(
        from value: String,
        includingFractionalSeconds: Bool
    ) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = includingFractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
