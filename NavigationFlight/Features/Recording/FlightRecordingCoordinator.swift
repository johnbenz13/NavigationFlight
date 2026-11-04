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

    private(set) var status = RecordingStatus.ready
    private(set) var lastError: CoordinationError?
    private(set) var isCommitting = false

    var snapshot: FlightRecordingEngineSnapshot {
        guard let publishedFlight else {
            preconditionFailure("A recording snapshot is unavailable before a Flight is coordinated")
        }
        return FlightRecordingEngineSnapshot(
            flight: publishedFlight,
            recording: publishedRecording
        )
    }

    init(store: any FlightRecordingStore) {
        self.store = store
    }

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

        let candidateEngine = FlightRecordingEngine(
            store: store,
            flight: flight,
            flightPlanSnapshot: flightPlanSnapshot
        )
        do {
            let transition = try await candidateEngine.promoteForStartLeg(
                at: timestamp,
                recordingID: recordingID,
                eventIDs: eventIDs
            )
            engine = candidateEngine
            publishedFlight = transition.flight
            publishedRecording = transition.recording
            status = .recordingGPSUnavailable
            return transition
        } catch {
            lastError = .startLegPersistenceFailed
            status = .ready
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
        let committed = try await engine.completeNavigation(
            flight: flight,
            at: timestamp,
            elapsed: elapsed,
            eventID: eventID
        )
        publishedFlight = committed.flight
        publishedRecording = committed.recording
        status = .navigationCompleteRecordingContinues
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
        status = .ready
        lastError = nil
    }
}
