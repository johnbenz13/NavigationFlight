import Foundation
import Testing
@testable import NavigationFlight

@Suite("Flight Plan Library")
@MainActor
struct FlightPlanLibraryTests {
    @Test("New import persists the validated original bytes and metadata")
    func newImportPersistsOriginalBytes() async throws {
        let sourceData = try fixtureData()
        let decoded = try FPLNavDecoder().decode(sourceData)
        let importedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let store = InMemoryFlightPlanStore()
        let library = FlightPlanLibrary(store: store)

        let proposal = try await library.prepareImport(sourceData, importedAt: importedAt)
        let committed = try await library.commit(proposal)
        let records = await store.records()

        #expect(committed.flightPlan == decoded)
        #expect(committed.importedAt == importedAt)
        #expect(records == [StoredFlightPlan(
            id: decoded.id,
            modifiedAt: decoded.modifiedAt,
            importedAt: importedAt,
            sourceData: sourceData,
            storageSchemaVersion: 1
        )])
    }

    @Test("Disk persistence preserves fractional revision timestamps")
    func diskPersistencePreservesFractionalRevisionTimestamp() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "NavigationFlight-FractionalRevision-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceData = try changing(
            fixtureData(),
            modifiedAtText: "2026-10-18T10:11:12.345Z"
        )
        let decoded = try FPLNavDecoder().decode(sourceData)
        let library = FlightPlanLibrary(store: DiskFlightPlanStore(rootDirectory: root))

        let proposal = try await library.prepareImport(sourceData, importedAt: .now)
        _ = try await library.commit(proposal)

        let plans = try await library.plans()
        #expect(plans.count == 1)
        #expect(plans.first?.flightPlan.modifiedAt == decoded.modifiedAt)
    }

    @Test("Library reads legacy metadata that truncated fractional revision timestamps")
    func readsLegacyTruncatedRevisionTimestamp() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "NavigationFlight-LegacyFractionalRevision-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceData = try changing(
            fixtureData(),
            modifiedAtText: "2026-10-18T10:11:12.345Z"
        )
        let decoded = try FPLNavDecoder().decode(sourceData)
        let recordDirectory = root.appending(path: decoded.id.uuidString.lowercased(), directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: recordDirectory, withIntermediateDirectories: true)
        try sourceData.write(to: recordDirectory.appending(path: "plan.fplnav"))
        let legacyMetadata: [String: Any] = [
            "id": decoded.id.uuidString.lowercased(),
            "modifiedAt": "2026-10-18T10:11:12Z",
            "importedAt": "2026-11-03T04:00:00Z",
            "storageSchemaVersion": 1
        ]
        try JSONSerialization.data(withJSONObject: legacyMetadata, options: [.sortedKeys])
            .write(to: recordDirectory.appending(path: "metadata.json"))
        let library = FlightPlanLibrary(store: DiskFlightPlanStore(rootDirectory: root))

        let plans = try await library.plans()
        let proposal = try await library.prepareImport(sourceData, importedAt: .now)

        #expect(plans.map(\.flightPlan.modifiedAt) == [decoded.modifiedAt])
        guard case .sameRevision = proposal else {
            Issue.record("Expected the legacy record to be recognized as the same revision")
            return
        }
    }

    @Test("Same revision neither writes nor refreshes its import date")
    func sameRevisionDoesNotWrite() async throws {
        let sourceData = try fixtureData()
        let firstImportDate = Date(timeIntervalSince1970: 100)
        let store = InMemoryFlightPlanStore()
        let library = FlightPlanLibrary(store: store)
        let initialProposal = try await library.prepareImport(sourceData, importedAt: firstImportDate)
        _ = try await library.commit(initialProposal)

        let proposal = try await library.prepareImport(
            sourceData,
            importedAt: Date(timeIntervalSince1970: 200)
        )

        guard case .sameRevision(let existing) = proposal else {
            Issue.record("Expected a same-revision proposal")
            return
        }
        #expect(existing.importedAt == firstImportDate)
        await #expect(throws: FlightPlanLibraryError.sameRevisionCannotBeCommitted) {
            try await library.commit(proposal)
        }
        let records = await store.records()
        #expect(records.first?.importedAt == firstImportDate)
    }

    @Test("Newer and older revisions produce distinct replacement proposals")
    func revisionClassification() async throws {
        let original = try fixtureData()
        let decoded = try FPLNavDecoder().decode(original)
        let store = InMemoryFlightPlanStore(records: [stored(original, decoded: decoded, importedAt: .distantPast)])
        let library = FlightPlanLibrary(store: store)

        let newer = try await library.prepareImport(
            changing(original, modifiedAt: decoded.modifiedAt.addingTimeInterval(1)),
            importedAt: .now
        )
        let older = try await library.prepareImport(
            changing(original, modifiedAt: decoded.modifiedAt.addingTimeInterval(-1)),
            importedAt: .now
        )

        guard case .replaceNewer(let newerReplacement) = newer,
              case .replaceOlder(let olderReplacement) = older else {
            Issue.record("Expected distinct newer and older proposals")
            return
        }
        #expect(newerReplacement.expectedModifiedAt == decoded.modifiedAt)
        #expect(olderReplacement.expectedModifiedAt == decoded.modifiedAt)
    }

    @Test("A proposal cannot replace a record changed after preparation")
    func staleProposalIsRejected() async throws {
        let original = try fixtureData()
        let decoded = try FPLNavDecoder().decode(original)
        let store = InMemoryFlightPlanStore(records: [stored(original, decoded: decoded, importedAt: .distantPast)])
        let library = FlightPlanLibrary(store: store)
        let first = try await library.prepareImport(
            changing(original, modifiedAt: decoded.modifiedAt.addingTimeInterval(1)),
            importedAt: Date(timeIntervalSince1970: 1)
        )
        let stale = try await library.prepareImport(
            changing(original, modifiedAt: decoded.modifiedAt.addingTimeInterval(2)),
            importedAt: Date(timeIntervalSince1970: 2)
        )

        _ = try await library.commit(first)

        await #expect(throws: FlightPlanLibraryError.staleProposal(id: decoded.id)) {
            try await library.commit(stale)
        }
    }

    @Test("Identity, not title, controls replacement and list ordering is deterministic")
    func identityAndOrdering() async throws {
        let original = try fixtureData()
        let first = try FPLNavDecoder().decode(original)
        let secondID = try #require(UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff"))
        let secondData = try changing(original, id: secondID, title: first.title)
        let second = try FPLNavDecoder().decode(secondData)
        let importDate = Date(timeIntervalSince1970: 123)
        let store = InMemoryFlightPlanStore(records: [
            stored(secondData, decoded: second, importedAt: importDate),
            stored(original, decoded: first, importedAt: importDate)
        ])

        let plans = try await FlightPlanLibrary(store: store).plans()

        #expect(plans.map(\.id) == [first.id, second.id].sorted { $0.uuidString < $1.uuidString })
        #expect(plans.map(\.flightPlan.title) == [first.title, first.title])
    }

    @Test("Validation failure preserves stored records and returns a typed error")
    func validationFailurePreservesRecords() async throws {
        let sourceData = try fixtureData()
        let decoded = try FPLNavDecoder().decode(sourceData)
        let existing = stored(sourceData, decoded: decoded, importedAt: .distantPast)
        let store = InMemoryFlightPlanStore(records: [existing])
        let library = FlightPlanLibrary(store: store)

        await #expect(throws: FlightPlanLibraryError.invalidFlightPlan) {
            try await library.prepareImport(Data("invalid".utf8), importedAt: .now)
        }
        let records = await store.records()
        #expect(records == [existing])
    }

    @Test("Removal no longer returns the record")
    func removal() async throws {
        let sourceData = try fixtureData()
        let decoded = try FPLNavDecoder().decode(sourceData)
        let store = InMemoryFlightPlanStore(records: [stored(sourceData, decoded: decoded, importedAt: .now)])
        let library = FlightPlanLibrary(store: store)

        try await library.remove(id: decoded.id)

        let plans = try await library.plans()
        #expect(plans.isEmpty)
    }

    @Test("Persistence failure is typed and preserves the prior record")
    func persistenceFailurePreservesRecord() async throws {
        let sourceData = try fixtureData()
        let decoded = try FPLNavDecoder().decode(sourceData)
        let existing = stored(sourceData, decoded: decoded, importedAt: .distantPast)
        let store = FailingFlightPlanStore(record: existing)
        let library = FlightPlanLibrary(store: store)
        let candidate = try await library.prepareImport(
            changing(sourceData, modifiedAt: decoded.modifiedAt.addingTimeInterval(1)),
            importedAt: .now
        )

        await #expect(throws: FlightPlanLibraryError.storageFailure(id: decoded.id)) {
            try await library.commit(candidate)
        }
        #expect(try await store.records() == [existing])
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: FixtureLocatorForLibrary.self)
        let nested = bundle.url(
            forResource: "representative-v7",
            withExtension: "fplnav",
            subdirectory: "Fixtures/FPLNav/V7/Official"
        )
        let url = try #require(nested ?? bundle.url(forResource: "representative-v7", withExtension: "fplnav"))
        return try Data(contentsOf: url)
    }

    private func changing(
        _ data: Data,
        id: UUID? = nil,
        title: String? = nil,
        modifiedAt: Date? = nil
    ) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var project = try #require(object["project"] as? [String: Any])
        if let id { project["id"] = id.uuidString.lowercased() }
        if let title { project["title"] = title }
        if let modifiedAt { project["modifiedAt"] = ISO8601DateFormatter().string(from: modifiedAt) }
        object["project"] = project
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func changing(_ data: Data, modifiedAtText: String) throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var project = try #require(object["project"] as? [String: Any])
        project["modifiedAt"] = modifiedAtText
        object["project"] = project
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func stored(_ data: Data, decoded: FlightPlan, importedAt: Date) -> StoredFlightPlan {
        StoredFlightPlan(
            id: decoded.id,
            modifiedAt: decoded.modifiedAt,
            importedAt: importedAt,
            sourceData: data,
            storageSchemaVersion: StoredFlightPlan.currentStorageSchemaVersion
        )
    }
}

@Suite("In-Memory Flight Plan Store")
@MainActor
struct InMemoryFlightPlanStoreTests {
    @Test("Replacement preconditions reject creation over an existing record")
    func replacementPreconditions() async throws {
        let id = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let revision = Date(timeIntervalSince1970: 1)
        let record = StoredFlightPlan(
            id: id,
            modifiedAt: revision,
            importedAt: revision,
            sourceData: Data(),
            storageSchemaVersion: 1
        )
        let store = InMemoryFlightPlanStore(records: [record])

        await #expect(throws: FlightPlanStoreError.conflict(id: id)) {
            try await store.replace(record, expecting: nil)
        }
        try await store.replace(record, expecting: revision)
    }
}

private final class FixtureLocatorForLibrary {}

@MainActor
private final class FailingFlightPlanStore: FlightPlanStore {
    private let record: StoredFlightPlan

    init(record: StoredFlightPlan) {
        self.record = record
    }

    func records() -> [StoredFlightPlan] { [record] }

    func replace(_ record: StoredFlightPlan, expecting: Date?) throws {
        throw FlightPlanStoreError.operationFailed(id: record.id)
    }

    func remove(id: UUID) throws {
        throw FlightPlanStoreError.operationFailed(id: id)
    }
}
