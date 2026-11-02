import Foundation
import Testing
@testable import NavigationFlight

@Suite("Disk Flight Plan Store")
@MainActor
struct DiskFlightPlanStoreTests {
    @Test("Round trip persists exact source bytes and complete metadata")
    func roundTrip() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let record = try sampleRecord()
        let store = DiskFlightPlanStore(rootDirectory: root)

        try await store.replace(record, expecting: nil)

        #expect(try await store.records() == [record])
        let directory = root.appending(path: record.id.uuidString.lowercased(), directoryHint: .isDirectory)
        #expect(try Data(contentsOf: directory.appending(path: "plan.fplnav")) == record.sourceData)
        let metadata = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: directory.appending(path: "metadata.json")))
                as? [String: Any]
        )
        #expect(metadata["id"] as? String == record.id.uuidString.lowercased())
        #expect(metadata["storageSchemaVersion"] as? Int == 1)
    }

    @Test("A failed replacement preserves the prior record and cleans temporary artifacts")
    func failedReplacementPreservesRecord() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try sampleRecord()
        try await DiskFlightPlanStore(rootDirectory: root).replace(original, expecting: nil)
        let replacement = StoredFlightPlan(
            id: original.id,
            modifiedAt: original.modifiedAt.addingTimeInterval(1),
            importedAt: original.importedAt.addingTimeInterval(1),
            sourceData: Data("replacement".utf8),
            storageSchemaVersion: 1
        )
        let failing = DiskFlightPlanStore(rootDirectory: root) { _ in throw TestFailure.expected }

        await #expect(throws: FlightPlanStoreError.operationFailed(id: original.id)) {
            try await failing.replace(replacement, expecting: original.modifiedAt)
        }

        #expect(try await DiskFlightPlanStore(rootDirectory: root).records() == [original])
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path())
        #expect(names == [original.id.uuidString.lowercased()])
    }

    @Test("Replacement atomically exposes only the complete new record")
    func atomicReplacement() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let original = try sampleRecord()
        let replacement = StoredFlightPlan(
            id: original.id,
            modifiedAt: original.modifiedAt.addingTimeInterval(1),
            importedAt: original.importedAt.addingTimeInterval(1),
            sourceData: Data("complete replacement bytes".utf8),
            storageSchemaVersion: 1
        )
        let store = DiskFlightPlanStore(rootDirectory: root)
        try await store.replace(original, expecting: nil)

        try await store.replace(replacement, expecting: original.modifiedAt)

        #expect(try await store.records() == [replacement])
        let names = try FileManager.default.contentsOfDirectory(atPath: root.path())
        #expect(names == [original.id.uuidString.lowercased()])
    }

    @Test("Corrupt records are reported with identity and preserved")
    func corruptionIsPreserved() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let record = try sampleRecord()
        let store = DiskFlightPlanStore(rootDirectory: root)
        try await store.replace(record, expecting: nil)
        let directory = root.appending(path: record.id.uuidString.lowercased(), directoryHint: .isDirectory)
        try Data("broken".utf8).write(to: directory.appending(path: "metadata.json"))

        await #expect(throws: FlightPlanStoreError.corruptRecord(id: record.id)) {
            try await store.records()
        }
        #expect(FileManager.default.fileExists(atPath: directory.path()))
    }

    @Test("Removal is durable and idempotent")
    func removal() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let record = try sampleRecord()
        let store = DiskFlightPlanStore(rootDirectory: root)
        try await store.replace(record, expecting: nil)

        try await store.remove(id: record.id)
        try await store.remove(id: record.id)

        #expect(try await store.records().isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: root.appending(path: record.id.uuidString.lowercased()).path()
        ))
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "NavigationFlight-DiskStore-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func sampleRecord() throws -> StoredFlightPlan {
        StoredFlightPlan(
            id: try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111")),
            modifiedAt: Date(timeIntervalSince1970: 100),
            importedAt: Date(timeIntervalSince1970: 200),
            sourceData: Data("original bytes".utf8),
            storageSchemaVersion: 1
        )
    }
}

private enum TestFailure: Error {
    case expected
}
