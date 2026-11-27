import Foundation

actor DiskAmendmentDraftStore: AmendmentDraftStore {
    private let rootDirectory: URL
    private let beforeLoad: @Sendable () throws -> Void
    private let beforeWrite: @Sendable () throws -> Void
    private let beforeRemove: @Sendable () throws -> Void

    init(rootDirectory: URL,
         beforeLoad: @escaping @Sendable () throws -> Void = {},
         beforeWrite: @escaping @Sendable () throws -> Void = {},
         beforeRemove: @escaping @Sendable () throws -> Void = {}) {
        self.rootDirectory = rootDirectory
        self.beforeLoad = beforeLoad
        self.beforeWrite = beforeWrite
        self.beforeRemove = beforeRemove
    }

    func load(flightID: UUID) throws -> AmendmentDraftRecord? {
        try beforeLoad()
        let url = fileURL(flightID)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let record: AmendmentDraftRecord
        do { record = try JSONDecoder().decode(AmendmentDraftRecord.self, from: Data(contentsOf: url)) }
        catch { throw AmendmentDraftStoreError.invalidData }
        try record.validate(for: flightID)
        return record
    }

    func save(_ record: AmendmentDraftRecord) throws {
        try record.validate(for: record.flightID)
        // Inspect before replacing: unreadable/newer bytes must never be silently
        // overwritten. This actor performs no suspension inside a file operation.
        if let previous = try load(flightID: record.flightID), previous.revision > record.revision { return }
        try beforeWrite()
        try FileManager.default.createDirectory(at: rootDirectory, withIntermediateDirectories: true)
        try JSONEncoder().encode(record).write(to: fileURL(record.flightID), options: .atomic)
    }

    func remove(flightID: UUID) throws {
        try beforeRemove()
        let url = fileURL(flightID)
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
    }

    private func fileURL(_ flightID: UUID) -> URL {
        rootDirectory.appending(path: "\(flightID.uuidString.lowercased()).json")
    }
}
