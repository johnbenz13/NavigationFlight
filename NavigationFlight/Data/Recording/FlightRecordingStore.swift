import Foundation

nonisolated protocol FlightRecordingStore: Sendable {
    func create(_ seed: FlightRecordingSeed) async throws
    func appendEvent(
        _ event: RecordedFlightEvent,
        recordingID: UUID,
        synchronize: Bool
    ) async throws
    func appendTrackBatch(_ batch: RecordedTrackBatch) async throws
    func synchronizeTrack(recordingID: UUID) async throws
    func packages() async -> [FlightRecordingPackageResult]
    func readSnapshot(id: UUID) async throws -> FlightRecordingReadSnapshot
    func close(id: UUID, closure: FlightRecordingClosure) async throws
    func remove(id: UUID) async throws
}

nonisolated struct FlightRecordingSeed: Equatable, Sendable {
    let recording: FlightRecording
    let events: [RecordedFlightEvent]
    let trackSegments: [RecordedTrackSegment]

    init(
        recording: FlightRecording,
        events: [RecordedFlightEvent],
        trackSegments: [RecordedTrackSegment] = []
    ) {
        self.recording = recording
        self.events = events
        self.trackSegments = trackSegments
    }
}

nonisolated struct FlightRecordingReadSnapshot: Equatable, Sendable {
    let recording: FlightRecording
    let events: [RecordedFlightEvent]
    var trackSegments: [RecordedTrackSegment]
    let approximateSizeBytes: Int64?

    init(
        recording: FlightRecording,
        events: [RecordedFlightEvent],
        trackSegments: [RecordedTrackSegment] = [],
        approximateSizeBytes: Int64? = nil
    ) {
        self.recording = recording
        self.events = events
        self.trackSegments = trackSegments
        self.approximateSizeBytes = approximateSizeBytes
    }
}

nonisolated enum FlightRecordingPackageResult: Equatable, Sendable {
    case available(FlightRecordingReadSnapshot)
    case unsupported(id: UUID, schemaVersion: Int)
    case corrupt(id: UUID?)
}

nonisolated enum FlightRecordingStoreError: Error, Equatable, Sendable {
    case duplicatePackage(id: UUID)
    case invalidEventSequence(id: UUID)
    case unsupportedVersion(id: UUID, schemaVersion: Int)
    case corruptPackage(id: UUID?)
    case operationFailed(id: UUID?)
    case recordingActive(id: UUID)
}
