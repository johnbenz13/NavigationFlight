import Foundation

nonisolated struct FlightRecordingSummary: Equatable, Sendable, Identifiable {
    enum Status: Equatable, Sendable {
        case inProgress
        case recoveryRequired
        case complete
        case incomplete
        case manuallyEnded
        case unavailable
    }

    let id: UUID
    let flightPlanTitle: String
    let route: String?
    let startedAt: Date
    let duration: Duration?
    let status: Status
    let gpsCoverage: GPSCoverageState
    let approximateSizeBytes: Int64?
    let canContinue: Bool
    let canDelete: Bool
}

nonisolated struct FlightDetailPresentation: Equatable, Sendable, Identifiable {
    let id: UUID
    let flightPlanTitle: String
    let route: String?
    let startedAt: Date
    let endedAt: Date?
    let duration: Duration?
    let status: FlightRecordingSummary.Status
    let closureOutcome: FlightRecordingClosure.Outcome?
    let closureCause: FlightRecordingClosure.Cause?
    let gpsCoverage: GPSCoverageState
    let gpsCoverageFraction: Double?
    let distanceMeters: Double?
    let maximumAltitudeMeters: Double?
    let approximateSizeBytes: Int64?
    let canExport: Bool
    let canDelete: Bool
    let isReadOnlySnapshot: Bool
}

actor FlightRecordingLibrary {
    private static let rootUnavailableID = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0))
    private let store: any FlightRecordingStore

    init(store: any FlightRecordingStore) {
        self.store = store
    }

    func recordings(activeRecordingID: UUID? = nil) async -> [FlightRecordingSummary] {
        await store.packages()
            .map { result in
                switch result {
                case .available(let snapshot):
                let recording = snapshot.recording
                let isActive = recording.closure == nil
                let route = recording.flightPlanSnapshot.sourceData
                    .flatMap { try? FPLNavDecoder().decode($0) }
                    .flatMap(Self.routeSummary)
                return FlightRecordingSummary(
                    id: recording.id,
                    flightPlanTitle: recording.flightPlanSnapshot.title,
                    route: route,
                    startedAt: recording.startedAt,
                    duration: snapshot.evidenceSummary.duration,
                    status: Self.status(for: recording, activeRecordingID: activeRecordingID),
                    gpsCoverage: recording.gpsCoverage,
                    approximateSizeBytes: snapshot.approximateSizeBytes,
                    canContinue: isActive,
                    canDelete: !isActive
                )
                case .unsupported(let id, _):
                    return Self.unavailableSummary(id: id, title: "Unsupported recording")
                case .corrupt(let id):
                    return Self.unavailableSummary(
                        id: id ?? Self.rootUnavailableID,
                        title: "Unavailable recording",
                        canDelete: id != nil
                    )
                }
            }
            .sorted(by: Self.precedes)
    }

    func delete(id: UUID) async throws {
        try await store.remove(id: id)
    }

    func detail(
        id: UUID,
        activeRecordingID: UUID? = nil
    ) async throws -> FlightDetailPresentation {
        let snapshot = try await store.readSnapshot(id: id)
        let recording = snapshot.recording
        let route = recording.flightPlanSnapshot.sourceData
            .flatMap { try? FPLNavDecoder().decode($0) }
            .flatMap(Self.routeSummary)
        let summary = snapshot.evidenceSummary
        return FlightDetailPresentation(
            id: recording.id,
            flightPlanTitle: recording.flightPlanSnapshot.title,
            route: route,
            startedAt: recording.startedAt,
            endedAt: recording.closure?.closedAt,
            duration: summary.duration,
            status: Self.status(for: recording, activeRecordingID: activeRecordingID),
            closureOutcome: recording.closure?.outcome,
            closureCause: recording.closure?.cause,
            gpsCoverage: recording.gpsCoverage,
            gpsCoverageFraction: summary.gpsCoverageFraction,
            distanceMeters: summary.distanceMeters,
            maximumAltitudeMeters: summary.maximumAltitudeMeters,
            approximateSizeBytes: snapshot.approximateSizeBytes,
            canExport: snapshot.trackSegments.contains { !$0.samples.isEmpty },
            canDelete: recording.closure != nil,
            isReadOnlySnapshot: recording.closure == nil
        )
    }

    private static func precedes(
        _ lhs: FlightRecordingSummary,
        _ rhs: FlightRecordingSummary
    ) -> Bool {
        if lhs.canContinue != rhs.canContinue {
            return lhs.canContinue
        }
        if lhs.startedAt != rhs.startedAt {
            return lhs.startedAt > rhs.startedAt
        }
        return lhs.id.uuidString < rhs.id.uuidString
    }

    private static func status(
        for recording: FlightRecording,
        activeRecordingID: UUID?
    ) -> FlightRecordingSummary.Status {
        guard let closure = recording.closure else {
            return recording.id == activeRecordingID ? .inProgress : .recoveryRequired
        }
        if closure.cause == .manual {
            return .manuallyEnded
        }
        return closure.outcome == .complete ? .complete : .incomplete
    }

    private static func routeSummary(for plan: FlightPlan) -> String? {
        guard let first = plan.waypoints.first?.name,
              let last = plan.waypoints.last?.name else { return nil }
        return first == last ? first : "\(first) → \(last)"
    }

    private static func unavailableSummary(
        id: UUID,
        title: String,
        canDelete: Bool = true
    ) -> FlightRecordingSummary {
        FlightRecordingSummary(
            id: id,
            flightPlanTitle: title,
            route: nil,
            startedAt: .distantPast,
            duration: nil,
            status: .unavailable,
            gpsCoverage: .unavailable,
            approximateSizeBytes: nil,
            canContinue: false,
            canDelete: canDelete
        )
    }
}
