import Foundation
import Observation

@MainActor
@Observable
final class FlightRecordingCoordinator {
    enum CoordinationError: Error, Equatable, Sendable {
        case startLegPersistenceFailed
        case noActiveRecording
        case commandInFlight
    }

    private let store: any FlightRecordingStore
    private var engine: FlightRecordingEngine?
    private var publishedFlight: Flight?
    private var publishedRecording: FlightRecording?
    private var locationConsumptionTask: Task<Void, Never>?

    private(set) var status = RecordingStatus.ready
    private(set) var lastError: CoordinationError?
    private(set) var isCommitting = false
    private(set) var storageDegradations: Set<RecordingStorageDegradation> = []

    var snapshot: FlightRecordingEngineSnapshot {
        guard let publishedFlight else {
            preconditionFailure("A recording snapshot is unavailable before a Flight is coordinated")
        }
        return FlightRecordingEngineSnapshot(
            flight: publishedFlight,
            recording: publishedRecording,
            storageDegradations: storageDegradations
        )
    }

    init(store: any FlightRecordingStore) {
        self.store = store
    }

    func arm(flight: Flight, flightPlanSnapshot: RecordedFlightPlanSnapshot) async {
        guard publishedFlight?.id != flight.id || engine == nil else { return }
        let candidate = FlightRecordingEngine(
            store: store,
            flight: flight,
            flightPlanSnapshot: flightPlanSnapshot
        )
        await candidate.arm()
        engine = candidate
        publishedFlight = flight
        publishedRecording = nil
        status = .prepared
        lastError = nil
    }

    func arm(
        flight: Flight,
        flightPlanSnapshot: RecordedFlightPlanSnapshot,
        locationHub: AircraftLocationService
    ) async {
        await arm(flight: flight, flightPlanSnapshot: flightPlanSnapshot)
        locationConsumptionTask?.cancel()
        let updates = await locationHub.recordingUpdates()
        await locationHub.startMonitoring(scope: .recording)
        locationConsumptionTask = Task { [weak self] in
            for await event in updates {
                if Task.isCancelled { return }
                await self?.handleLocationEvent(event)
            }
        }
    }

    func disarm() async {
        locationConsumptionTask?.cancel()
        locationConsumptionTask = nil
        await engine?.disarm()
        engine = nil
        publishedFlight = nil
        publishedRecording = nil
        status = .ready
    }


    func disarm(locationHub: AircraftLocationService) async {
        await disarm()
        await locationHub.stopMonitoring(scope: .recording)
    }

    func handleLocationEvent(_ event: LocationSourceEvent) async {
        guard let engine else { return }
        await engine.ingest(event)
        guard publishedRecording != nil else { return }
        switch event {
        case .sample:
            status = status == .gpsGap ? .gpsResumed : .recording
        case .servicesDisabled, .signalLost, .authorization(.denied), .authorization(.restricted):
            status = .gpsGap
        case .authorization(.notDetermined), .authorization(.whenInUse):
            break
        }
    }

#if DEBUG
    func overrideStatusForTesting(_ status: RecordingStatus) {
        self.status = status
    }
#endif

    func startLeg(
        flight: Flight,
        flightPlanSnapshot: RecordedFlightPlanSnapshot,
        at timestamp: Date,
        recordingID: UUID,
        eventIDs: [UUID]
    ) async throws -> CommittedNavigationTransition {
        guard !isCommitting else { throw CoordinationError.commandInFlight }
        publishedFlight = flight
        publishedRecording = nil
        lastError = nil
        isCommitting = true
        defer { isCommitting = false }

        let candidateEngine: FlightRecordingEngine
        if let engine, publishedFlight?.id == flight.id {
            candidateEngine = engine
        } else {
            candidateEngine = FlightRecordingEngine(
                store: store,
                flight: flight,
                flightPlanSnapshot: flightPlanSnapshot
            )
        }
        do {
            let transition = try await candidateEngine.promoteForStartLeg(
                at: timestamp,
                recordingID: recordingID,
                eventIDs: eventIDs
            )
            engine = candidateEngine
            publishedFlight = transition.flight
            publishedRecording = transition.recording
            let stored = try? await store.readSnapshot(id: transition.recording.id)
            status = stored?.trackSegments.isEmpty == false ? .recording : .recordingGPSUnavailable
            return transition
        } catch {
            lastError = .startLegPersistenceFailed
            status = engine == nil ? .ready : .prepared
            throw error
        }
    }

    func endManually(
        at timestamp: Date,
        elapsed: Duration,
        eventIDs: [UUID]
    ) async throws {
        guard let engine else { throw CoordinationError.noActiveRecording }
        let committed = try await engine.endManually(
            at: timestamp,
            elapsed: elapsed,
            eventIDs: eventIDs
        )
        publishedFlight = committed.flight
        publishedRecording = committed.recording
        status = committed.recording?.closure?.outcome == .complete
            ? .closedComplete
            : .closedIncomplete
    }

    func completeNavigation(
        flight: Flight,
        at timestamp: Date,
        elapsed: Duration,
        eventID: UUID
    ) async throws {
        guard let engine else { throw CoordinationError.noActiveRecording }
        _ = flight
        let transition = try await engine.commit(.completeNavigation(
            at: timestamp,
            elapsed: elapsed,
            eventID: eventID
        ))
        publishedFlight = transition.flight
        publishedRecording = transition.recording
        status = .navigationCompleteRecordingContinues
    }

    func commitNavigation(
        _ command: RecordedNavigationCommand
    ) async throws -> CommittedNavigationTransition {
        guard !isCommitting else { throw CoordinationError.commandInFlight }
        guard let engine else { throw CoordinationError.noActiveRecording }
        lastError = nil
        isCommitting = true
        defer { isCommitting = false }

        let committed = try await engine.commit(command)
        publishedFlight = committed.flight
        publishedRecording = committed.recording
        return committed
    }

    func recordStorageDegradation(
        _ reason: RecordingStorageDegradation,
        at timestamp: Date,
        elapsed: Duration,
        eventID: UUID
    ) async throws {
        storageDegradations.insert(reason)
        status = .recordingDegraded
        _ = try await commitNavigation(.recordStorageDegradation(
            reason: reason,
            at: timestamp,
            elapsed: elapsed,
            eventID: eventID
        ))
    }

    func prepareForFlightReplacement(
        at timestamp: Date,
        eventIDs: [UUID]
    ) async throws {
        if let recording = publishedRecording,
           recording.closure == nil,
           let engine {
            let elapsed = Duration.seconds(max(0, timestamp.timeIntervalSince(recording.startedAt)))
            _ = try await engine.endManually(
                at: timestamp,
                elapsed: elapsed,
                eventIDs: eventIDs
            )
        }
        engine = nil
        publishedFlight = nil
        publishedRecording = nil
        storageDegradations = []
        status = .ready
        lastError = nil
    }
}
