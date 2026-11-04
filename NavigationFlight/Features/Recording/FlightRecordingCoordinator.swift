import Foundation
import Observation

@MainActor
@Observable
final class FlightRecordingCoordinator {
    enum CoordinationError: Error, Equatable, Sendable {
        case startLegPersistenceFailed
        case automaticPromotionPersistenceFailed
        case noActiveRecording
        case commandInFlight
    }

    private let store: any FlightRecordingStore
    private let detectorPolicy: PhysicalFlightDetectionPolicy
    private let monotonicNow: @MainActor @Sendable () -> Duration
    private var engine: FlightRecordingEngine?
    private var publishedFlight: Flight?
    private var publishedRecording: FlightRecording?
    private var locationConsumptionTask: Task<Void, Never>?
    private var recordingLocationHub: AircraftLocationService?

    private(set) var status = RecordingStatus.ready
    private(set) var lastError: CoordinationError?
    private(set) var isCommitting = false
    private(set) var storageDegradations: Set<RecordingStorageDegradation> = []

    var isNavigationCompletionCommitted: Bool {
        publishedRecording?.navigationState == .complete
    }

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

    init(
        store: any FlightRecordingStore,
        detectorPolicy: PhysicalFlightDetectionPolicy = .production,
        monotonicNow: @escaping @MainActor @Sendable () -> Duration = {
            .seconds(ProcessInfo.processInfo.systemUptime)
        }
    ) {
        self.store = store
        self.detectorPolicy = detectorPolicy
        self.monotonicNow = monotonicNow
    }

    func arm(flight: Flight, flightPlanSnapshot: RecordedFlightPlanSnapshot) async {
        guard publishedFlight?.id != flight.id || engine == nil else { return }
        let candidate = FlightRecordingEngine(
            store: store,
            flight: flight,
            flightPlanSnapshot: flightPlanSnapshot,
            detectorPolicy: detectorPolicy
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
        recordingLocationHub = locationHub
        locationConsumptionTask = Task { [weak self] in
            for await event in updates {
                if Task.isCancelled { return }
                await self?.handleLocationEvent(event)
            }
        }
    }

    func restore(_ recovered: RecoveredFlight) async {
        locationConsumptionTask?.cancel()
        locationConsumptionTask = nil
        recordingLocationHub = nil
        let stored = try? await store.readSnapshot(id: recovered.recording.id)
        let degradations: Set<RecordingStorageDegradation> = Set(stored?.events.compactMap { event in
            guard case .storageDegraded(let reason) = event.payload else { return nil }
            return reason
        } ?? [])
        let candidate = FlightRecordingEngine(
            store: store,
            recoveredFlight: recovered.flight,
            recoveredRecording: recovered.recording,
            detectorPolicy: detectorPolicy,
            storageDegradations: degradations
        )
        await candidate.arm()
        engine = candidate
        publishedFlight = recovered.flight
        publishedRecording = recovered.recording
        storageDegradations = degradations
        status = Self.status(for: recovered.recording, hasDegradation: !degradations.isEmpty)
        lastError = nil
    }

    func disarm() async {
        locationConsumptionTask?.cancel()
        locationConsumptionTask = nil
        recordingLocationHub = nil
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
        let outcome = await engine.ingest(event, monotonicTime: monotonicNow())
        if case .promoted(let recording, let partial) = outcome {
            publishedRecording = recording
            status = partial ? .partialRecording : .recording
            return
        }
        if outcome == .promotionPersistenceFailed {
            lastError = .automaticPromotionPersistenceFailed
            status = .prepared
            return
        }
        switch outcome {
        case .physicalStateChanged(let recording):
            publishedRecording = recording
            status = recording.physicalState == .landedAwaitingStop ? .landedAwaitingStop : .recording
            return
        case .physicalStateCorrected(let recording):
            publishedRecording = recording
            status = .physicalPhaseCorrected
            return
        case .closed(let recording):
            publishedRecording = recording
            status = recording.closure?.outcome == .complete ? .closedComplete : .closedIncomplete
            await stopRecordingLocationCapture()
            return
        case .none, .provisionalBegan, .provisionalDiscarded, .promoted, .promotionPersistenceFailed:
            break
        }
        guard publishedRecording != nil else { return }
        if publishedRecording?.navigationState == .complete {
            status = .navigationCompleteRecordingContinues
            return
        }
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
        let priorPublishedRecording = publishedRecording
        publishedFlight = flight
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
                flightPlanSnapshot: flightPlanSnapshot,
                detectorPolicy: detectorPolicy
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
            publishedRecording = priorPublishedRecording
            lastError = .startLegPersistenceFailed
            status = priorPublishedRecording == nil ? (engine == nil ? .ready : .prepared) : .recording
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
        await stopRecordingLocationCapture()
    }

    private func stopRecordingLocationCapture() async {
        locationConsumptionTask?.cancel()
        locationConsumptionTask = nil
        if let recordingLocationHub {
            await recordingLocationHub.stopMonitoring(scope: .recording)
            self.recordingLocationHub = nil
        }
    }

    private static func status(
        for recording: FlightRecording,
        hasDegradation: Bool
    ) -> RecordingStatus {
        if hasDegradation { return .recordingDegraded }
        if let closure = recording.closure {
            return closure.outcome == .complete ? .closedComplete : .closedIncomplete
        }
        if recording.navigationState == .complete { return .navigationCompleteRecordingContinues }
        if recording.physicalState == .landedAwaitingStop { return .landedAwaitingStop }
        return switch recording.gpsCoverage {
        case .available: .recording
        case .partial: .partialRecording
        case .unavailable: .recordingGPSUnavailable
        }
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
        if transition.recording.closure?.outcome == .complete {
            status = .closedComplete
            await stopRecordingLocationCapture()
        } else {
            status = .navigationCompleteRecordingContinues
        }
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
                eventIDs: eventIDs,
                forcedOutcome: .incomplete
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
