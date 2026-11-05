import SwiftUI
import CoreTransferable
import UniformTypeIdentifiers

struct FlightDetailLoaderView: View {
    let id: UUID
    let library: FlightRecordingLibrary
    let activeRecordingID: UUID?
    let onContinue: (UUID) -> Void
    let exporter: GPXExporter
    let onDeleted: () async -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var detail: FlightDetailPresentation?
    @State private var loadFailed = false
    @State private var exportResult: GPXExportResult?
    @State private var exportFailed = false
    @State private var isExporting = false

    var body: some View {
        Group {
            if let detail {
                FlightDetailView(
                    detail: detail,
                    onContinue: { onContinue(id) },
                    isExporting: isExporting,
                    onExport: export,
                    onDelete: delete
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
        .navigationDestination(isPresented: Binding(
            get: { exportResult != nil },
            set: { if !$0 { exportResult = nil } }
        )) {
            if let exportResult {
                GPXExportResultView(result: exportResult)
            }
        }
        .alert("GPX export failed", isPresented: $exportFailed) {
            Button("Retry") { Task { await export() } }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("No file was shared. The recording is unchanged and remains available to export again.")
        }
    }

    @MainActor
    private func delete() async {
        do {
            try await library.delete(id: id)
            await onDeleted()
            dismiss()
        } catch {
            detail = try? await library.detail(id: id, activeRecordingID: activeRecordingID)
        }
    }

    @MainActor
    private func export() async {
        guard !isExporting else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            exportResult = try await library.export(id: id, using: exporter)
        } catch is CancellationError {
            return
        } catch {
            exportFailed = true
        }
    }
}

struct FlightDetailView: View {
    let detail: FlightDetailPresentation
    let onContinue: () -> Void
    let isExporting: Bool
    let onExport: () async -> Void
    let onDelete: () async -> Void

    @State private var confirmsDeletion = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if let route = detail.route {
                    Text(route)
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

                summaryCard

                if detail.isReadOnlySnapshot {
                    Button(action: onContinue) {
                        Label("Continue Flight", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.roundedRectangle(radius: 14))
                        .controlSize(.large)
                        .accessibilityIdentifier("flight-detail.continue")
                } else if detail.canExport {
                    Button {
                        Task { await onExport() }
                    } label: {
                        if isExporting {
                            ProgressView("Preparing GPX")
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

                storedEvidence
                detailSections

                if detail.canDelete {
                    Button(role: .destructive) {
                        confirmsDeletion = true
                    } label: {
                        Label("Delete recording", systemImage: "trash")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .controlSize(.large)
                    .accessibilityIdentifier("flight-detail.delete")
                }
            }
            .frame(maxWidth: 600, alignment: .leading)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Flight · \(statusText)")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog(
            "Delete \(detail.flightPlanTitle)?",
            isPresented: $confirmsDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task { await onDelete() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently removes the GPS track and navigation event history from this device.")
        }
        .accessibilityIdentifier("flight-detail.\(detail.id.uuidString)")
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("\(durationText)  •  \(distanceText)")
                .font(.title3.weight(.bold))
            Text("Max \(altitudeText)")
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
            Text("GPS track and operational history are retained on device for future debrief features. This release exposes summaries and GPX export only.")
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
                valueRow("Maximum altitude", altitudeText)
                valueRow("Recording size", sizeText)
            }
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
        detail.status == .complete ? "Export GPX" : "Export partial GPX"
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
