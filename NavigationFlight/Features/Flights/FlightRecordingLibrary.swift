import FlightEvidenceCore
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
    enum UnavailableReason: Equatable, Sendable {
        case unsupported
        case unreadable
    }

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
    let maximumBarometricAltitudeMeters: Double?
    let latestDeviceHeadingDegrees: Double?
    let approximateSizeBytes: Int64?
    let canExportDiagnostic: Bool
    let canExportGPX: Bool
    let canDelete: Bool
    let isReadOnlySnapshot: Bool
    let unavailableReason: UnavailableReason?
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

    func export(
        id: UUID,
        using exporter: GPXExporter = GPXExporter()
    ) async throws -> GPXExportResult {
        let snapshot = try await store.readSnapshot(id: id)
        return try await exporter.export(snapshot: snapshot)
    }

    func exportDiagnosticBundle(
        id: UUID,
        sourceState: FlightEvidenceBundleV1.SourceState = .closed,
        using exporter: DiagnosticBundleExporter = DiagnosticBundleExporter(),
        capturedAt: Date = Date(),
        context: FlightEvidenceContext = .current,
        progress: @escaping @Sendable (Double) async -> Void = { _ in }
    ) async throws -> DiagnosticExportResult {
        let evidence = try await prepareDiagnosticSnapshot(
            id: id,
            sourceState: sourceState,
            capturedAt: capturedAt,
            context: context
        )
        return try await exportDiagnosticBundle(
            evidence,
            using: exporter,
            progress: progress
        )
    }

    func prepareDiagnosticSnapshot(
        id: UUID,
        sourceState: FlightEvidenceBundleV1.SourceState,
        capturedAt: Date? = nil,
        context: FlightEvidenceContext = .current
    ) async throws -> FlightEvidenceSnapshot {
        let snapshot = try await store.readSnapshot(id: id)
        return FlightEvidenceSnapshot(
            capturedAt: capturedAt ?? Date(),
            sourceState: sourceState,
            recording: snapshot,
            context: context.replacingDetectorPolicy(snapshot.detectorPolicy)
        )
    }

    func debriefEvidence(
        id: UUID,
        sourceState: FlightEvidenceBundleV1.SourceState,
        capturedAt: Date? = nil
    ) async throws -> FlightEvidenceSnapshot {
        let snapshot = try await store.readSnapshot(id: id)
        let durationComponents = snapshot.evidenceSummary.duration?.components
        let evidenceDuration = durationComponents.map {
            TimeInterval($0.seconds) + TimeInterval($0.attoseconds) / 1e18
        } ?? 0
        return FlightEvidenceSnapshot(
            capturedAt: capturedAt ?? snapshot.recording.startedAt.addingTimeInterval(evidenceDuration),
            sourceState: sourceState,
            recording: snapshot,
            context: .current.replacingDetectorPolicy(snapshot.detectorPolicy)
        )
    }

    func exportDiagnosticBundle(
        _ evidence: FlightEvidenceSnapshot,
        using exporter: DiagnosticBundleExporter = DiagnosticBundleExporter(),
        progress: @escaping @Sendable (Double) async -> Void = { _ in }
    ) async throws -> DiagnosticExportResult {
        try await exporter.export(evidence, progress: progress)
    }

    func detail(
        id: UUID,
        activeRecordingID: UUID? = nil
    ) async throws -> FlightDetailPresentation {
        let snapshot: FlightRecordingReadSnapshot
        do {
            snapshot = try await store.readSnapshot(id: id)
        } catch {
            if let unavailable = await unavailableDetail(id: id) {
                return unavailable
            }
            throw error
        }
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
            maximumBarometricAltitudeMeters: summary.maximumBarometricAltitudeMeters,
            latestDeviceHeadingDegrees: summary.latestDeviceHeadingDegrees,
            approximateSizeBytes: snapshot.approximateSizeBytes,
            canExportDiagnostic: true,
            canExportGPX: snapshot.trackSegments.contains { !$0.samples.isEmpty },
            canDelete: recording.closure != nil,
            isReadOnlySnapshot: recording.closure == nil
            , unavailableReason: nil
        )
    }

    private func unavailableDetail(id: UUID) async -> FlightDetailPresentation? {
        let unavailable = await store.packages().compactMap { result -> (String, FlightDetailPresentation.UnavailableReason)? in
            switch result {
            case .unsupported(let packageID, _) where packageID == id:
                ("Unsupported recording", .unsupported)
            case .corrupt(let packageID) where packageID == id:
                ("Unreadable recording", .unreadable)
            case .available, .unsupported, .corrupt:
                nil
            }
        }.first
        guard let (title, reason) = unavailable else { return nil }
        return FlightDetailPresentation(
            id: id,
            flightPlanTitle: title,
            route: nil,
            startedAt: .distantPast,
            endedAt: nil,
            duration: nil,
            status: .unavailable,
            closureOutcome: nil,
            closureCause: nil,
            gpsCoverage: .unavailable,
            gpsCoverageFraction: nil,
            distanceMeters: nil,
            maximumAltitudeMeters: nil,
            maximumBarometricAltitudeMeters: nil,
            latestDeviceHeadingDegrees: nil,
            approximateSizeBytes: nil,
            canExportDiagnostic: false,
            canExportGPX: false,
            canDelete: true,
            isReadOnlySnapshot: false,
            unavailableReason: reason
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
