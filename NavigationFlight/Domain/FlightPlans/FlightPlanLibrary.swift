import Foundation

actor FlightPlanLibrary {
    typealias Decode = @Sendable (Data) throws -> FlightPlan

    private let store: any FlightPlanStore
    private let decode: Decode

    init(
        store: any FlightPlanStore,
        decode: @escaping Decode = { try FPLNavDecoder().decode($0) }
    ) {
        self.store = store
        self.decode = decode
    }

    func plans() async throws -> [LibraryFlightPlan] {
        let records = try await records()
        return try records.map(libraryFlightPlan(from:)).sorted {
            if $0.importedAt != $1.importedAt {
                return $0.importedAt > $1.importedAt
            }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func prepareImport(_ data: Data, importedAt: Date) async throws -> ImportProposal {
        let flightPlan: FlightPlan
        do {
            flightPlan = try decode(data)
        } catch {
            throw FlightPlanLibraryError.invalidFlightPlan
        }

        let prepared = PreparedImport(
            record: StoredFlightPlan(
                id: flightPlan.id,
                modifiedAt: flightPlan.modifiedAt,
                importedAt: importedAt,
                sourceData: data,
                storageSchemaVersion: StoredFlightPlan.currentStorageSchemaVersion
            ),
            flightPlan: flightPlan
        )
        guard let existingRecord = try await records().first(where: { $0.id == flightPlan.id }) else {
            return .new(prepared)
        }
        let existing = try libraryFlightPlan(from: existingRecord)
        if existingRecord.modifiedAt == flightPlan.modifiedAt {
            return .sameRevision(existing: existing)
        }
        let replacement = PreparedReplacement(
            candidate: prepared,
            expectedModifiedAt: existingRecord.modifiedAt
        )
        return flightPlan.modifiedAt > existingRecord.modifiedAt
            ? .replaceNewer(replacement)
            : .replaceOlder(replacement)
    }

    func commit(_ proposal: ImportProposal) async throws -> LibraryFlightPlan {
        let prepared: PreparedImport
        let expectedModifiedAt: Date?
        switch proposal {
        case .new(let candidate):
            prepared = candidate
            expectedModifiedAt = nil
        case .replaceNewer(let replacement), .replaceOlder(let replacement):
            prepared = replacement.candidate
            expectedModifiedAt = replacement.expectedModifiedAt
        case .sameRevision:
            throw FlightPlanLibraryError.sameRevisionCannotBeCommitted
        }

        do {
            try await store.replace(prepared.record, expecting: expectedModifiedAt)
        } catch FlightPlanStoreError.conflict {
            throw FlightPlanLibraryError.staleProposal(id: prepared.record.id)
        } catch {
            throw FlightPlanLibraryError.storageFailure(id: prepared.record.id)
        }
        return LibraryFlightPlan(
            flightPlan: prepared.flightPlan,
            importedAt: prepared.record.importedAt
        )
    }

    func remove(id: UUID) async throws {
        do {
            try await store.remove(id: id)
        } catch {
            throw FlightPlanLibraryError.storageFailure(id: id)
        }
    }

    private func records() async throws -> [StoredFlightPlan] {
        do {
            return try await store.records()
        } catch let error as FlightPlanStoreError {
            switch error {
            case .corruptRecord(let id):
                if let id { throw FlightPlanLibraryError.corruptRecord(id: id) }
                throw FlightPlanLibraryError.storageFailure(id: nil)
            case .conflict(let id):
                throw FlightPlanLibraryError.staleProposal(id: id)
            case .operationFailed(let id):
                throw FlightPlanLibraryError.storageFailure(id: id)
            }
        } catch {
            throw FlightPlanLibraryError.storageFailure(id: nil)
        }
    }

    private func libraryFlightPlan(from record: StoredFlightPlan) throws -> LibraryFlightPlan {
        let flightPlan: FlightPlan
        do {
            flightPlan = try decode(record.sourceData)
        } catch {
            throw FlightPlanLibraryError.corruptRecord(id: record.id)
        }
        guard flightPlan.id == record.id, flightPlan.modifiedAt == record.modifiedAt else {
            throw FlightPlanLibraryError.corruptRecord(id: record.id)
        }
        return LibraryFlightPlan(flightPlan: flightPlan, importedAt: record.importedAt)
    }
}
