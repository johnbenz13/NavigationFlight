import Foundation
import Observation

nonisolated struct RecoveryCandidate: Equatable, Sendable, Identifiable {
    let recordingID: UUID
    let flightPlanTitle: String
    let startedAt: Date

    var id: UUID { recordingID }
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
}

@MainActor
@Observable
final class FlightRecoveryCoordinator {
    private let store: any FlightRecordingStore
    private let monotonicUptime: () -> TimeInterval
    private var bootstrapUptime: TimeInterval?
    private var persistedElapsedByRecordingID: [UUID: Duration] = [:]

    private(set) var state: FlightRecoveryState = .loading
    private(set) var unavailablePackages: [UnavailableRecoveryPackage] = []
    private(set) var selectedRecordingID: UUID?

    init(
        store: any FlightRecordingStore,
        monotonicUptime: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.store = store
        self.monotonicUptime = monotonicUptime
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
        for result in packages {
            guard case .available(let snapshot) = result,
                  snapshot.recording.closure == nil else { continue }
            do {
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
            if let unsupported = unavailablePackages.first(where: {
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
            startedAt: snapshot.recording.startedAt
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
        let events = try recording.endManually(
            at: timestamp,
            elapsed: elapsed,
            eventIDs: eventIDs,
            forcedOutcome: .incomplete
        )
        for event in events {
            try await store.appendEvent(event, recordingID: id, synchronize: true)
        }
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
        state = .none
        selectedRecordingID = nil
        return RecoveredFlight(
            flightPlan: flightPlan,
            flight: flight,
            recording: recording
        )
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
