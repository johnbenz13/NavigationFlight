import Foundation
import Observation

@MainActor
@Observable
final class AmendmentDraftPersistence {
    enum Status: Equatable {
        case saving, saved, saveFailed, deleting, deleteFailed, recoveryFailed
    }

    private let store: any AmendmentDraftStore
    private let beforeRetry: () -> Void
    private(set) var statuses: [UUID: Status] = [:]
    private var revisions: [UUID: UInt64] = [:]
    private var latest: [UUID: AmendmentDraftRecord] = [:]
    private var latestSnapshots: [UUID: RouteAmendmentDraft.Persistence] = [:]
    private var pending: [UUID: AmendmentDraftRecord] = [:]
    private var blocked: Set<UUID> = []
    private var deleting: Set<UUID> = []
    @ObservationIgnored private var writer: Task<Void, Never>?

    init(store: any AmendmentDraftStore, beforeRetry: @escaping () -> Void = {}) {
        self.store = store
        self.beforeRetry = beforeRetry
    }

    func save(_ draft: RouteAmendmentDraft, recordingSequence: UInt64) {
        let id = draft.flightID
        guard !blocked.contains(id), !deleting.contains(id), let snapshot = draft.persistence else { return }
        guard latestSnapshots[id] != snapshot else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            let (revision, overflow) = (revisions[id] ?? 0).addingReportingOverflow(1)
            guard !overflow else { statuses[id] = .saveFailed; return }
            revisions[id] = revision
            let record = AmendmentDraftRecord(flightID: id, revision: revision,
                                             recordingSequence: recordingSequence, payload: data)
            latest[id] = record
            latestSnapshots[id] = snapshot
            pending[id] = record
            statuses[id] = .saving
            startWriter()
        } catch {
            statuses[id] = .saveFailed
        }
    }

    func retry(flightID: UUID) {
        guard !blocked.contains(flightID), !deleting.contains(flightID), let record = latest[flightID] else { return }
        beforeRetry()
        pending[flightID] = record
        statuses[flightID] = .saving
        startWriter()
    }

    /// One worker owns all writes, independent of view-task cancellation. Coalesce
    /// pending edits and ignore completion status from superseded revisions.
    private func startWriter() {
        guard writer == nil else { return }
        writer = Task {
            while let (id, record) = pending.first {
                pending[id] = nil
                do {
                    try await store.save(record)
                    if latest[id]?.revision == record.revision, !deleting.contains(id) { statuses[id] = .saved }
                } catch {
                    if latest[id]?.revision == record.revision, !deleting.contains(id) { statuses[id] = .saveFailed }
                }
            }
            writer = nil
        }
    }

    func flush() async {
        while let writer { await writer.value }
    }

    func discard(flightID: UUID) async -> Bool {
        guard !deleting.contains(flightID), !blocked.contains(flightID) else { return false }
        deleting.insert(flightID)
        statuses[flightID] = .deleting
        pending[flightID] = nil
        // A previous save must finish before delete, so it cannot recreate a
        // successfully discarded draft. Failed deletion retains the in-memory work.
        await flush()
        do {
            try await store.remove(flightID: flightID)
            latest[flightID] = nil
            latestSnapshots[flightID] = nil
            statuses[flightID] = nil
            deleting.remove(flightID)
            return true
        } catch {
            statuses[flightID] = .deleteFailed
            deleting.remove(flightID)
            return false
        }
    }

    func recover(flight: Flight, route: RouteAmendmentRoute?, lastAmendmentSequence: UInt64?) async -> RouteAmendmentDraft? {
        guard flight.legState != .completed else { return nil }
        let canRecover = flight.pendingRouteAmendment == nil && flight.activatedRouteAmendment == nil && route != nil
        await flush()
        do {
            guard let record = try await store.load(flightID: flight.id) else { return nil }
            try record.validate(for: flight.id)
            // Operational recovery still wins, but a later cancellation can create
            // another draft in this process. Its revision must advance past disk.
            revisions[flight.id] = max(revisions[flight.id] ?? 0, record.revision)
            guard canRecover, let route else { return nil }
            // A confirmed route operation after this snapshot makes it obsolete,
            // even if cleanup failed and the armed amendment was later cancelled.
            if let lastAmendmentSequence, lastAmendmentSequence >= record.recordingSequence { return nil }
            let snapshot = try JSONDecoder().decode(RouteAmendmentDraft.Persistence.self, from: record.payload)
            let draft = try RouteAmendmentDraft(recovering: snapshot, flightID: flight.id, route: route)
            latest[flight.id] = record
            latestSnapshots[flight.id] = snapshot
            statuses[flight.id] = .saved
            return draft
        } catch {
            blocked.insert(flight.id)
            // Keep quarantine visible even while operational recovery wins. After
            // cancellation, preparation must show the scoped error rather than
            // accepting work whose saves and discard would be blocked.
            statuses[flight.id] = .recoveryFailed
            return nil
        }
    }

    /// Call only after the existing operational transaction reports success.
    /// The journal recovery fence protects against a crash or failed cleanup.
    func retire(flightID: UUID) async {
        _ = await discard(flightID: flightID)
        latest[flightID] = nil
        latestSnapshots[flightID] = nil
        statuses[flightID] = nil
        // Cleanup failure is not an unsaved operational amendment. Recovery uses
        // the journal fence rather than exposing this obsolete preparation.
    }
}
