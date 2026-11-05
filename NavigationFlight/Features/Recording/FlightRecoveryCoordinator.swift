import Foundation
import Observation

nonisolated struct RecoveryCandidate: Equatable, Sendable, Identifiable {
    let recordingID: UUID
    let flightPlanTitle: String
    let startedAt: Date
    let lastActivityAt: Date?
    let expiresAt: Date?

    var id: UUID { recordingID }

    init(
        recordingID: UUID,
        flightPlanTitle: String,
        startedAt: Date,
        lastActivityAt: Date? = nil,
        expiresAt: Date? = nil
    ) {
        self.recordingID = recordingID
        self.flightPlanTitle = flightPlanTitle
        self.startedAt = startedAt
        self.lastActivityAt = lastActivityAt
        self.expiresAt = expiresAt
    }
}

nonisolated enum UnavailableRecoveryPackage: Equatable, Sendable {
    case unsupported(id: UUID, schemaVersion: Int)
    case corrupt(id: UUID?)
}

nonisolated enum FlightRecoveryState: Equatable, Sendable {
    case loading
    case none
    case single(RecoveryCandidate)
    case selectionRequired([RecoveryCandidate])
    case reconciledExpired(count: Int)
    case unsupported(UnavailableRecoveryPackage)
    case failure(UnavailableRecoveryPackage)
}

nonisolated struct RecoveredFlight: Equatable, Sendable {
    let flightPlan: FlightPlan
    let flight: Flight
    let recording: FlightRecording
}

nonisolated enum FlightRecoveryError: Error, Equatable, Sendable {
    case missingFlightPlanSnapshot
    case invalidFlightPlanSnapshot
    case invalidJournal
    case recoveryExpired
}

@MainActor
@Observable
final class FlightRecoveryCoordinator {
    private let store: any FlightRecordingStore
    private let monotonicUptime: () -> TimeInterval
    private let now: () -> Date
    private let defaultRecoveryWindow: TimeInterval
    private var bootstrapUptime: TimeInterval?
    private var persistedElapsedByRecordingID: [UUID: Duration] = [:]

    private(set) var state: FlightRecoveryState = .loading
    private(set) var unavailablePackages: [UnavailableRecoveryPackage] = []
    private(set) var selectedRecordingID: UUID?

    init(
        store: any FlightRecordingStore,
        monotonicUptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime },
        now: @escaping () -> Date = Date.init,
        defaultRecoveryWindow: TimeInterval = 300
    ) {
        self.store = store
        self.monotonicUptime = monotonicUptime
        self.now = now
        self.defaultRecoveryWindow = defaultRecoveryWindow
    }

    func bootstrap() async {
        let packages = await store.packages()
        bootstrapUptime = monotonicUptime()
        persistedElapsedByRecordingID = packages.reduce(into: [:]) { elapsedByID, result in
            guard case .available(let snapshot) = result,
                  snapshot.recording.closure == nil else { return }
            elapsedByID[snapshot.recording.id] = snapshot.events.last?.elapsed ?? .zero
        }
        var candidates: [RecoveryCandidate] = []
        var invalidAvailablePackages: [UnavailableRecoveryPackage] = []
        var expiredCount = 0
        for result in packages {
            guard case .available(let snapshot) = result,
                  snapshot.recording.closure == nil else { continue }
            do {
                let evidenceAt = latestDurableEvidence(in: snapshot)
                guard evidenceAt <= now() else {
                    invalidAvailablePackages.append(.corrupt(id: snapshot.recording.id))
                    continue
                }
                guard now().timeIntervalSince(evidenceAt) < recoveryWindow(for: snapshot.recording) else {
                    try await closeForRecovery(
                        snapshot: snapshot,
                        at: evidenceAt,
                        cause: .recoveryExpired
                    )
                    expiredCount += 1
                    continue
                }
                candidates.append(try validatedCandidate(for: snapshot))
            } catch {
                invalidAvailablePackages.append(.corrupt(id: snapshot.recording.id))
            }
        }
        candidates.sort { lhs, rhs in
            if lhs.startedAt != rhs.startedAt { return lhs.startedAt > rhs.startedAt }
            return lhs.recordingID.uuidString < rhs.recordingID.uuidString
        }

        unavailablePackages = packages.compactMap { result in
            guard case .unsupported(let id, let schemaVersion) = result else { return nil }
            return .unsupported(id: id, schemaVersion: schemaVersion)
        } + packages.compactMap { result in
            guard case .corrupt(let id) = result else { return nil }
            return .corrupt(id: id)
        } + invalidAvailablePackages
        selectedRecordingID = nil
        switch candidates.count {
        case 0:
            if expiredCount > 0 {
                state = .reconciledExpired(count: expiredCount)
            } else if let unsupported = unavailablePackages.first(where: {
                if case .unsupported = $0 { return true }
                return false
            }) {
                state = .unsupported(unsupported)
            } else if let corrupt = unavailablePackages.first {
                state = .failure(corrupt)
            } else {
                state = .none
            }
        case 1:
            state = .single(candidates[0])
        default:
            state = .selectionRequired(candidates)
        }
    }

    private func latestDurableEvidence(in snapshot: FlightRecordingReadSnapshot) -> Date {
        ([snapshot.recording.startedAt]
            + [snapshot.recording.lastRecoveryCheckpointAt].compactMap { $0 }
            + snapshot.events.map(\.occurredAt)
            + snapshot.trackSegments.flatMap(\.samples).map(\.observedAt)).max()
            ?? snapshot.recording.startedAt
    }

    private func recoveryWindow(for recording: FlightRecording) -> TimeInterval {
        recording.recoveryWindowSeconds > 0
            ? recording.recoveryWindowSeconds
            : defaultRecoveryWindow
    }

    private func closeForRecovery(
        snapshot: FlightRecordingReadSnapshot,
        at timestamp: Date,
        cause: FlightRecordingClosure.Cause
    ) async throws {
        if let last = snapshot.events.last,
           last.payload == .recordingClosed(outcome: .incomplete, cause: cause) {
            try await store.close(
                id: snapshot.recording.id,
                closure: FlightRecordingClosure(
                    outcome: .incomplete,
                    cause: cause,
                    closedAt: last.occurredAt,
                    elapsed: last.elapsed,
                    landingEvidenceAvailable: false
                )
            )
            return
        }
        var recording = snapshot.recording
        let elapsed = Duration.seconds(max(0, timestamp.timeIntervalSince(recording.startedAt)))
        let event = try recording.closeDuringRecovery(
            at: timestamp,
            elapsed: elapsed,
            cause: cause,
            eventID: UUID()
        )
        try await store.appendEvent(event, recordingID: recording.id, synchronize: true)
        guard let closure = recording.closure else {
            throw FlightRecordingStoreError.operationFailed(id: recording.id)
        }
        try await store.close(id: recording.id, closure: closure)
    }

    private func validatedCandidate(
        for snapshot: FlightRecordingReadSnapshot
    ) throws -> RecoveryCandidate {
        guard let sourceData = snapshot.recording.flightPlanSnapshot.sourceData else {
            throw FlightRecoveryError.missingFlightPlanSnapshot
        }
        let flightPlan: FlightPlan
        do {
            flightPlan = try FPLNavDecoder().decode(sourceData)
        } catch {
            throw FlightRecoveryError.invalidFlightPlanSnapshot
        }
        _ = try replayFlight(snapshot: snapshot, flightPlan: flightPlan)
        return RecoveryCandidate(
            recordingID: snapshot.recording.id,
            flightPlanTitle: snapshot.recording.flightPlanSnapshot.title,
            startedAt: snapshot.recording.startedAt,
            lastActivityAt: latestDurableEvidence(in: snapshot),
            expiresAt: latestDurableEvidence(in: snapshot).addingTimeInterval(
                recoveryWindow(for: snapshot.recording)
            )
        )
    }

    func dismissUnavailableRecovery() {
        state = .none
        selectedRecordingID = nil
    }

    func rebasedElapsed(for id: UUID) -> Duration {
        let persisted = persistedElapsedByRecordingID[id] ?? .zero
        guard let bootstrapUptime else { return persisted }
        return persisted + .seconds(max(0, monotonicUptime() - bootstrapUptime))
    }

    func endAsIncomplete(
        id: UUID,
        at timestamp: Date,
        elapsed: Duration,
        eventIDs: [UUID]
    ) async throws {
        let snapshot = try await store.readSnapshot(id: id)
        var recording = snapshot.recording
        guard eventIDs.count == 2, let eventID = eventIDs.first else {
            throw FlightRecording.TransitionError.invalidEventIdentifierCount
        }
        let event = try recording.closeDuringRecovery(
            at: timestamp,
            elapsed: elapsed,
            cause: .endedDuringRecovery,
            eventID: eventID
        )
        try await store.appendEvent(event, recordingID: id, synchronize: true)
        guard let closure = recording.closure else {
            throw FlightRecordingStoreError.operationFailed(id: id)
        }
        try await store.close(id: id, closure: closure)
        await bootstrap()
    }

    func continueFlight(
        id: UUID,
        at timestamp: Date,
        elapsed: Duration,
        eventID: UUID
    ) async throws -> RecoveredFlight {
        let snapshot = try await store.readSnapshot(id: id)
        let evidenceAt = latestDurableEvidence(in: snapshot)
        guard evidenceAt <= now(), now().timeIntervalSince(evidenceAt) < recoveryWindow(for: snapshot.recording) else {
            if evidenceAt <= now() {
                try await closeForRecovery(snapshot: snapshot, at: evidenceAt, cause: .recoveryExpired)
            }
            throw FlightRecoveryError.recoveryExpired
        }
        guard let sourceData = snapshot.recording.flightPlanSnapshot.sourceData else {
            throw FlightRecoveryError.missingFlightPlanSnapshot
        }
        let flightPlan: FlightPlan
        do {
            flightPlan = try FPLNavDecoder().decode(sourceData)
        } catch {
            throw FlightRecoveryError.invalidFlightPlanSnapshot
        }
        let flight = try replayFlight(snapshot: snapshot, flightPlan: flightPlan)
        var recording = snapshot.recording
        let event = try recording.recordRecoveryContinuation(
            at: timestamp,
            elapsed: elapsed,
            eventID: eventID
        )
        try await store.appendEvent(event, recordingID: id, synchronize: true)
        for result in await store.packages() {
            guard case .available(let other) = result,
                  other.recording.id != id,
                  other.recording.closure == nil else { continue }
            try await closeForRecovery(
                snapshot: other,
                at: latestDurableEvidence(in: other),
                cause: .supersededDuringRecovery
            )
        }
        state = .none
        selectedRecordingID = nil
        return RecoveredFlight(
            flightPlan: flightPlan,
            flight: flight,
            recording: recording
        )
    }

    func endAllAsIncomplete() async throws {
        for result in await store.packages() {
            guard case .available(let snapshot) = result,
                  snapshot.recording.closure == nil else { continue }
            try await closeForRecovery(
                snapshot: snapshot,
                at: latestDurableEvidence(in: snapshot),
                cause: .endedDuringRecovery
            )
        }
        state = .none
        selectedRecordingID = nil
    }

    private func replayFlight(
        snapshot: FlightRecordingReadSnapshot,
        flightPlan: FlightPlan
    ) throws -> Flight {
        guard snapshot.recording.flightPlanSnapshot.id == flightPlan.id,
              snapshot.recording.flightPlanSnapshot.legIDs == flightPlan.legs.map(\.id),
              let plannedNavigation = flightPlan.plannedNavigation.plannedNavigation else {
            throw FlightRecoveryError.invalidFlightPlanSnapshot
        }
        let undoneEventIDs = Set(snapshot.events.compactMap { event -> UUID? in
            guard case .reachUndone(let originalEventID) = event.payload else { return nil }
            return originalEventID
        })
        let firstStartedLegID = snapshot.events.lazy.compactMap { event -> UUID? in
            guard case .legStarted(let legID) = event.payload else { return nil }
            return legID
        }.first
        let initialIndex = firstStartedLegID.flatMap { id in
            flightPlan.legs.firstIndex { $0.id == id }
        } ?? 0
        var flight = Flight(
            id: snapshot.recording.flightID,
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: initialIndex,
            executionMode: plannedNavigation.defaultMode
        )
        do {
            for event in snapshot.events where !undoneEventIDs.contains(event.id) {
                switch event.payload {
                case .legStarted(let legID):
                    guard let index = flight.legIDs.firstIndex(of: legID) else {
                        throw FlightRecoveryError.invalidJournal
                    }
                    if flight.legState == .ready, flight.activeLegIndex != index {
                        try flight.selectReadyLeg(index: index, mode: flight.executionMode)
                    }
                    if flight.legState == .ready {
                        try flight.startLeg(at: event.occurredAt)
                    }
                case .destinationIdentified(let legID):
                    guard flight.legIDs[flight.activeLegIndex] == legID else {
                        throw FlightRecoveryError.invalidJournal
                    }
                    try flight.identifyDestination(at: event.occurredAt)
                case .identificationPointReached(let key):
                    try flight.reachIdentificationPoint(
                        key: key,
                        orderedActiveLegPointKeys: orderedPointKeys(for: key.legID, in: flightPlan),
                        at: event.occurredAt
                    )
                case .waypointReached(let legID):
                    guard flight.legIDs[flight.activeLegIndex] == legID else {
                        throw FlightRecoveryError.invalidJournal
                    }
                    try flight.reachCurrentWaypoint(
                        orderedActiveLegPointKeys: orderedPointKeys(for: legID, in: flightPlan),
                        at: event.occurredAt
                    )
                case .etaRevised(let target, let priorSeconds, let committedSeconds):
                    flight.initializePilotETA(
                        targetKey: target,
                        plannedElapsedSeconds: priorSeconds ?? committedSeconds
                    )
                    if priorSeconds != nil { flight.beginEditingPilotETA(targetKey: target) }
                    let draft = flight.pilotETAState(targetKey: target)?.draftSeconds ?? committedSeconds
                    flight.adjustPilotETA(targetKey: target, by: committedSeconds - draft)
                    _ = flight.commitPilotETA(targetKey: target)
                case .headingRevised(let legID, let priorDegrees, let committedDegrees):
                    guard flight.legIDs[flight.activeLegIndex] == legID else {
                        throw FlightRecoveryError.invalidJournal
                    }
                    flight.openPilotHeadingEditor(baselineDegrees: priorDegrees)
                    let draft = flight.pilotHeadingState(for: legID)?.draftDegrees ?? committedDegrees
                    flight.adjustPilotHeading(by: committedDegrees - draft)
                    flight.commitPilotHeading()
                case .recordingStarted, .automaticNextLegTransition, .finalWaypointReached,
                     .automaticLegRecovery, .reachUndone, .positionCheckRequested,
                     .positionCheckEnded, .storageDegraded, .locationAvailabilityChanged,
                     .physicalStateChanged, .physicalStateCorrected, .navigationCompleted,
                     .recoveryContinued, .manualEnd, .recordingClosed:
                    break
                }
            }
        } catch let error as FlightRecoveryError {
            throw error
        } catch {
            throw FlightRecoveryError.invalidJournal
        }
        return flight
    }

    private func orderedPointKeys(for legID: UUID, in flightPlan: FlightPlan) -> [IdentificationPointKey] {
        flightPlan.identificationPoints
            .filter { $0.legID == legID }
            .map { IdentificationPointKey(legID: legID, identificationPointID: $0.id) }
    }
}
