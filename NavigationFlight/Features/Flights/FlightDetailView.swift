import SwiftUI
import CoreTransferable
import FlightEvidenceCore
import UniformTypeIdentifiers

struct FlightDetailLoaderView: View {
    let id: UUID
    let library: FlightRecordingLibrary
    let activeRecordingID: UUID?
    let onContinue: (UUID) -> Void
    let exporter: GPXExporter
    let diagnosticExporter: DiagnosticBundleExporter
    @Binding var flightsState: FlightsFeatureState
    let onRequestDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var detail: FlightDetailPresentation?
    @State private var loadFailed = false
    @State private var exportChoicePresented = false
    @State private var pendingSnapshot: FlightEvidenceSnapshot?
    @State private var exportResult: FlightExportResult?
    @State private var failedFormat: FlightExportFormat?
    @State private var failedSnapshot: FlightEvidenceSnapshot?
    @State private var exportTask: Task<Void, Never>?
    @State private var exportingFormat: FlightExportFormat?
    @State private var exportProgress = 0.12
    @State private var debriefPresented = false

    private var isExporting: Bool { exportTask != nil }

    var body: some View {
        Group {
            if let detail {
                FlightDetailView(
                    detail: detail,
                    onContinue: { onContinue(id) },
                    isExporting: isExporting,
                    onExport: { exportChoicePresented = true },
                    onDebrief: { debriefPresented = true },
                    onDelete: onRequestDelete
                )
            } else if loadFailed {
                ContentUnavailableView(
                    "Flight unavailable",
                    systemImage: "questionmark.circle",
                    description: Text("This recording cannot be read.")
                )
            } else {
                ProgressView("Loading Flight")
            }
        }
        .task(id: id) {
            do {
                detail = try await library.detail(
                    id: id,
                    activeRecordingID: activeRecordingID
                )
            } catch {
                loadFailed = true
            }
        }
        .sheet(isPresented: $exportChoicePresented) {
            FlightExportChoiceView(canExportGPX: detail?.canExportGPX ?? false) { format in
                exportChoicePresented = false
                prepareExport(format)
            }
            .presentationSizing(.page)
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $pendingSnapshot) { snapshot in
            ZStack(alignment: .bottom) {
                Color.black.opacity(0.24)
                ProvisionalFlightExportConfirmationView(
                    sourceState: snapshot.sourceState,
                    capturedAt: snapshot.capturedAt
                ) {
                    beginExport(.diagnosticBundle, snapshot: snapshot)
                }
            }
            .ignoresSafeArea()
            .presentationBackground(.clear)
        }
        .overlay {
            if isExporting {
                FlightExportProgressView(
                    format: exportingFormat ?? .diagnosticBundle,
                    progress: exportProgress
                ) {
                    exportTask?.cancel()
                }
            }
        }
        .overlay {
            if let failedFormat {
                FlightExportFailureView(
                    format: failedFormat,
                    onRetry: {
                        self.failedFormat = nil
                        let snapshot = self.failedSnapshot
                        self.failedSnapshot = nil
                        if let snapshot {
                            beginExport(failedFormat, snapshot: snapshot)
                        } else {
                            prepareExport(failedFormat)
                        }
                    },
                    onCancel: {
                        self.failedFormat = nil
                        self.failedSnapshot = nil
                    }
                )
            }
        }
        .navigationDestination(isPresented: Binding(
            get: { exportResult != nil },
            set: { if !$0 { exportResult = nil } }
        )) {
            if let exportResult {
                FlightExportResultView(result: exportResult)
            }
        }
        .navigationDestination(isPresented: $debriefPresented) {
            FlightDebriefLoaderView(
                id: id,
                library: library,
                sourceState: currentSourceState,
                unavailableReason: detail?.unavailableReason
            )
        }
        .onChange(of: flightsState.rows.contains(where: { $0.id == id })) { wasPresent, isPresent in
            if wasPresent, !isPresent {
                dismiss()
            }
        }
        .onDisappear {
            exportTask?.cancel()
        }
    }

    private func prepareExport(_ format: FlightExportFormat) {
        guard format == .diagnosticBundle, let sourceState = currentSourceState, sourceState != .closed else {
            beginExport(format)
            return
        }
        Task {
            do {
                pendingSnapshot = try await library.prepareDiagnosticSnapshot(
                    id: id,
                    sourceState: sourceState
                )
            } catch {
                failedSnapshot = nil
                failedFormat = format
            }
        }
    }

    private var currentSourceState: FlightEvidenceBundleV1.SourceState? {
        guard let detail else { return nil }
        return switch detail.status {
        case .inProgress: .active
        case .recoveryRequired: .recoverable
        case .complete, .incomplete, .manuallyEnded: .closed
        case .unavailable: nil
        }
    }

    private func beginExport(
        _ format: FlightExportFormat,
        snapshot: FlightEvidenceSnapshot? = nil
    ) {
        guard exportTask == nil else { return }
        exportingFormat = format
        exportProgress = 0.12
        exportTask = Task {
            defer {
                exportTask = nil
                exportingFormat = nil
            }
            do {
                switch format {
                case .diagnosticBundle:
                    if let snapshot {
                        exportResult = .diagnostic(try await library.exportDiagnosticBundle(
                            snapshot,
                            using: diagnosticExporter,
                            progress: { progress in
                                await MainActor.run { exportProgress = progress }
                            }
                        ))
                    } else {
                        exportResult = .diagnostic(try await library.exportDiagnosticBundle(
                            id: id,
                            sourceState: currentSourceState ?? .closed,
                            using: diagnosticExporter,
                            progress: { progress in
                                await MainActor.run { exportProgress = progress }
                            }
                        ))
                    }
                case .gpx:
                    exportResult = .gpx(try await library.export(id: id, using: exporter))
                }
            } catch is CancellationError {
                return
            } catch {
                failedFormat = format
                failedSnapshot = snapshot
            }
        }
    }
}

struct FlightDetailView: View {
    let detail: FlightDetailPresentation
    let onContinue: () -> Void
    let isExporting: Bool
    let onExport: () -> Void
    let onDebrief: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let route = detail.route {
                    Text(route)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if detail.status == .unavailable {
                    Text("Recording cannot be read")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Label(statusText, systemImage: statusSymbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 28)
                    .background(Color(.secondarySystemBackground), in: .capsule)
                    .accessibilityIdentifier("flight-detail.status")

                if detail.status == .unavailable {
                    UnavailableRecordingCard()
                } else {
                    summaryCard
                }

                if detail.isReadOnlySnapshot {
                    Button(action: onContinue) {
                        Label("Continue Flight", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .controlSize(.large)
                        .accessibilityIdentifier("flight-detail.continue")
                }

                if detail.canExportDiagnostic {
                    Button(action: onExport) {
                        if isExporting {
                            ProgressView("Preparing Export")
                                .frame(maxWidth: .infinity)
                        } else {
                            Label(exportTitle, systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                    }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .controlSize(.large)
                        .disabled(isExporting)
                        .accessibilityIdentifier("flight-detail.export")
                }

                if detail.status != .unavailable || detail.unavailableReason != nil {
                    Button(action: onDebrief) {
                        Label("Open Debrief", systemImage: "chart.xyaxis.line")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .controlSize(.large)
                    .accessibilityIdentifier("flight-detail.debrief")
                }

                if detail.status == .unavailable, detail.canDelete {
                    FlightDeletionButton(action: onDelete)
                }

                storedEvidence

                if detail.status != .unavailable {
                    detailSections

                    if detail.canDelete {
                        FlightDeletionButton(action: onDelete)
                    }
                }
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Flight · \(statusText)")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("flight-detail.\(detail.id.uuidString)")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(durationText)  •  \(distanceText)")
                .font(.title3.weight(.bold))
            Text("GPS max \(altitudeText)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text(coverageSummaryText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
        .accessibilityIdentifier("flight-detail.summary")
    }

    private var storedEvidence: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stored evidence")
                .font(.title3.weight(.bold))
            Text("GPS track and operational history are retained on device for future debrief features. Diagnostic evidence and GPX tracks can be exported separately.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var detailSections: some View {
        VStack(spacing: 16) {
            detailSection("Identity and route") {
                valueRow("Flight Plan", detail.flightPlanTitle)
                valueRow("Route", detail.route ?? "Unavailable")
            }
            detailSection("Timing") {
                valueRow("Started", detail.startedAt.formatted(date: .abbreviated, time: .shortened))
                valueRow("Ended", detail.endedAt?.formatted(date: .abbreviated, time: .shortened) ?? "In progress")
                valueRow("Duration", durationText)
            }
            detailSection("Completion and coverage") {
                valueRow("Completion", completionText)
                valueRow("Closure", closureText)
                valueRow("GPS coverage", gpsCoverageText)
            }
            detailSection("Stored summary") {
                valueRow("Distance", distanceText)
                valueRow("Maximum GPS altitude", altitudeText)
                valueRow("Recording size", sizeText)
            }
            SupplementalEvidenceSection(
                maximumBarometricAltitude: barometricAltitudeText,
                latestDeviceHeading: deviceHeadingText
            )
        }
    }

    private func detailSection<Content: View>(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
    }

    private func valueRow(_ label: LocalizedStringKey, _ value: String) -> some View {
        LabeledContent {
            Text(value)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        } label: {
            Text(label)
        }
    }

    private var statusText: String {
        switch detail.status {
        case .inProgress: "In Progress"
        case .recoveryRequired: "Recovery Required"
        case .complete: "Complete"
        case .incomplete: "Incomplete"
        case .manuallyEnded: "Manually Ended"
        case .unavailable: "Unavailable"
        }
    }

    private var statusSymbol: String {
        switch detail.status {
        case .inProgress: "record.circle.fill"
        case .recoveryRequired: "arrow.clockwise.circle.fill"
        case .complete: "checkmark.circle.fill"
        case .incomplete, .manuallyEnded: "exclamationmark.circle.fill"
        case .unavailable: "questionmark.circle.fill"
        }
    }

    private var statusColor: Color {
        switch detail.status {
        case .inProgress, .recoveryRequired: .accentColor
        case .complete: .green
        case .incomplete, .manuallyEnded: .orange
        case .unavailable: .red
        }
    }

    private var exportTitle: String {
        "Export Flight"
    }

    private var durationText: String {
        guard let duration = detail.duration else { return "Unavailable" }
        let seconds = max(0, duration.components.seconds)
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    private var distanceText: String {
        guard let distance = detail.distanceMeters else { return "Unavailable" }
        return Measurement(value: distance / 1_000, unit: UnitLength.kilometers)
            .formatted(.measurement(width: .abbreviated, usage: .road))
    }

    private var altitudeText: String {
        guard let altitude = detail.maximumAltitudeMeters else { return "Unavailable" }
        return Measurement(value: altitude, unit: UnitLength.meters)
            .converted(to: .feet)
            .formatted(.measurement(width: .abbreviated, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0))))
    }

    private var barometricAltitudeText: String {
        guard let altitude = detail.maximumBarometricAltitudeMeters else { return "Unavailable" }
        return Measurement(value: altitude, unit: UnitLength.meters)
            .converted(to: .feet)
            .formatted(.measurement(
                width: .abbreviated,
                usage: .asProvided,
                numberFormatStyle: .number.precision(.fractionLength(0))
            ))
    }

    private var deviceHeadingText: String {
        guard let heading = detail.latestDeviceHeadingDegrees else { return "Unavailable" }
        return "\(heading.formatted(.number.precision(.fractionLength(0))))° device-relative"
    }

    private var sizeText: String {
        detail.approximateSizeBytes.map {
            ByteCountFormatter.string(fromByteCount: $0, countStyle: .file)
        } ?? "Unavailable"
    }

    private var coverageSummaryText: String {
        switch detail.gpsCoverage {
        case .available: "GPS track + navigation events"
        case .partial: "Partial GPS track + navigation events"
        case .unavailable: "GPS track unavailable · navigation events retained"
        }
    }

    private var gpsCoverageText: String {
        let state = switch detail.gpsCoverage {
        case .available: "Available"
        case .partial: "Partial"
        case .unavailable: "Unavailable"
        }
        guard let fraction = detail.gpsCoverageFraction else { return state }
        return "\(state) · \(fraction.formatted(.percent.precision(.fractionLength(0))))"
    }

    private var completionText: String {
        switch detail.closureOutcome {
        case .complete: "Complete"
        case .incomplete: "Incomplete"
        case nil: "In progress"
        }
    }

    private var closureText: String {
        switch detail.closureCause {
        case .automatic: "Automatic"
        case .manual: "Manual"
        case .recoveryExpired: "Recovery expired"
        case .endedDuringRecovery: "Ended during recovery"
        case .supersededDuringRecovery: "Superseded during recovery"
        case nil: "Not closed"
        }
    }
}

private struct SupplementalEvidenceSection: View {
    let maximumBarometricAltitude: String
    let latestDeviceHeading: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Supplemental evidence")
                .font(.headline)
            LabeledContent("Anchored barometric maximum") {
                Text(maximumBarometricAltitude)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("flight-detail.supplemental-altitude")
            LabeledContent("Latest device compass heading") {
                Text(latestDeviceHeading)
                    .foregroundStyle(.secondary)
            }
            .accessibilityIdentifier("flight-detail.device-heading")
            Text("Best-effort device evidence; not authoritative aircraft altitude or heading.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 14))
        .accessibilityIdentifier("flight-detail.supplemental-evidence")
    }
}

private struct UnavailableRecordingCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Track unavailable")
                .font(.title3.weight(.bold))
            Text("The recording metadata is damaged.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Deletion remains available.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 0.5)
        }
        .accessibilityIdentifier("flight-detail.summary")
    }
}

private struct FlightDeletionButton: View {
    let action: () -> Void

    var body: some View {
        Button(role: .destructive, action: action) {
            Label("Delete recording", systemImage: "trash")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.roundedRectangle(radius: 14))
        .controlSize(.large)
        .accessibilityIdentifier("flight-detail.delete")
    }
}

private struct GPXExportResultView: View {
    let result: GPXExportResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text("Track exported as GPX")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text("GPX")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 28)
                    .background(Color.green.opacity(0.1), in: .capsule)

                Text(result.fileURL.lastPathComponent)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("flight-export.filename")

                Text("Includes valid GPS samples only. Navigation events and private app metadata stay on device.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ShareLink(
                    item: GPXShareItem(fileURL: result.fileURL),
                    preview: SharePreview(result.fileURL.lastPathComponent)
                ) {
                    Label("Open Share Sheet", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .controlSize(.large)
                .accessibilityIdentifier("flight-export.share")
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Export result")
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("flight-export.result")
    }
}

private struct GPXShareItem: Transferable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .navigationFlightGPX) { item in
            SentTransferredFile(item.fileURL)
        }
    }
}

private extension UTType {
    static let navigationFlightGPX = UTType(
        exportedAs: "app.navigationflight.gpx",
        conformingTo: .xml
    )
}
