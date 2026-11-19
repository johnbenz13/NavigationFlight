import CoreTransferable
import FlightEvidenceCore
import SwiftUI
import UniformTypeIdentifiers

enum FlightExportFormat: Equatable, Sendable {
    case diagnosticBundle
    case gpx
}

enum FlightExportResult: Sendable {
    case diagnostic(DiagnosticExportResult)
    case gpx(GPXExportResult)
}

struct ProvisionalFlightExportConfirmationView: View {
    let sourceState: FlightEvidenceBundleV1.SourceState
    let capturedAt: Date
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Capsule()
                .fill(Color(red: 0.65, green: 0.66, blue: 0.70))
                .frame(width: 40, height: 5)
                .frame(maxWidth: .infinity)
                .padding(.top, 14)
                .padding(.bottom, 25)
            Text(title)
                .font(.system(size: 26, weight: .semibold))
                .padding(.bottom, 8)
            Text("Snapshot · \(capturedAt.formatted(date: .abbreviated, time: .standard))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(red: 184 / 255, green: 92 / 255, blue: 5 / 255))
                .accessibilityIdentifier("flight-export.snapshot-time")
                .padding(.bottom, 20)
            Text("The bundle will include evidence recorded up to this time. Later Flight evidence will not be included. \(continuationText)")
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.bottom, 46)
            Text("This snapshot is provisional: duration, track, events, and outcome may change.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Color(red: 122 / 255, green: 62 / 255, blue: 0))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 58)
                .padding(.horizontal, 16)
                .background(Color(red: 1, green: 243 / 255, blue: 217 / 255), in: .rect(cornerRadius: 14))
                .accessibilityIdentifier("flight-export.provisional-disclosure")
                .padding(.bottom, 20)
            GeometryReader { proxy in
                let availableWidth = proxy.size.width - 16
                HStack(spacing: 16) {
                    Button {
                        dismiss()
                        onConfirm()
                    } label: {
                        Text("Export Snapshot")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.white)
                    .frame(width: availableWidth * 51 / 77, height: 48)
                    .background(Color(red: 20 / 255, green: 102 / 255, blue: 194 / 255), in: .rect(cornerRadius: 13))
                    .accessibilityIdentifier("flight-export.confirm-snapshot")

                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(red: 11 / 255, green: 70 / 255, blue: 143 / 255))
                    .frame(width: availableWidth * 26 / 77, height: 48)
                    .background(Color(red: 239 / 255, green: 242 / 255, blue: 246 / 255), in: .rect(cornerRadius: 13))
                    .accessibilityIdentifier("flight-export.cancel-snapshot")
                }
            }
            .frame(height: 48)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity)
        .frame(height: 390, alignment: .top)
        .background(Color(.systemBackground))
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
    }

    private var title: LocalizedStringResource {
        sourceState == .active ? "Export Active Recording?" : "Export Recoverable Recording?"
    }

    private var continuationText: LocalizedStringResource {
        sourceState == .active
            ? "Recording and navigation continue unchanged."
            : "Recovery availability and the stored recording remain unchanged."
    }
}

struct FlightExportChoiceView: View {
    let canExportGPX: Bool
    let onSelect: (FlightExportFormat) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                Text("Export Flight")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Choose the evidence you need. Exporting does not change or end this recording.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, 2)

                choice(
                    title: "Diagnostic Bundle",
                    description: "Complete events, track samples, accuracy, detector context, and recording state.",
                    detail: "Complete evidence",
                    format: .diagnosticBundle
                )
                if canExportGPX {
                    choice(
                        title: "GPX Track",
                        description: "Portable GPS track for compatible mapping tools. Events and detector context are not included.",
                        detail: "Track only",
                        format: .gpx
                    )
                }

                Label(
                    "Created on this iPad. Nothing is uploaded automatically.",
                    systemImage: "lock.shield"
                )
                .font(.footnote)
                .foregroundStyle(.green)
                .padding(.vertical, 6)

                Button(role: .cancel) {
                    dismiss()
                } label: {
                    Text("Cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("flight-export.cancel")
            }
            .padding(24)
            .toolbar(.hidden, for: .navigationBar)
        }
        .accessibilityIdentifier("flight-export.choice")
    }

    private func choice(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        detail: LocalizedStringKey,
        format: FlightExportFormat
    ) -> some View {
        Button {
            onSelect(format)
        } label: {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
                Spacer(minLength: 12)
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tint)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 82, alignment: .leading)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(.separator), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            format == .diagnosticBundle
                ? "flight-export.diagnostic"
                : "flight-export.gpx"
        )
    }
}

struct FlightExportProgressView: View {
    let format: FlightExportFormat
    let progress: Double
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
            VStack(spacing: 22) {
                Text(title)
                    .font(.title3.weight(.semibold))
                VStack(spacing: 8) {
                    HStack {
                        Spacer()
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.blue)
                            .monospacedDigit()
                    }
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("The Flight recording remains unchanged. No file is shared until preparation completes.")
                    .font(.footnote)
                    .foregroundStyle(.green)
                    .multilineTextAlignment(.center)
                Button(action: onCancel) {
                    Text("Cancel Export")
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 14))
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("flight-export.cancel-progress")
            }
            .padding(24)
            .frame(maxWidth: 570, minHeight: 301)
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .shadow(radius: 18, y: 8)
            .padding(24)
        }
    }

    private var title: String {
        format == .diagnosticBundle ? "Preparing Diagnostic Bundle" : "Preparing GPX Track"
    }

    private var detail: String {
        format == .diagnosticBundle
            ? "Validating retained track samples and recorded events…"
            : "Preparing valid GPS samples for compatible mapping tools…"
    }
}

struct FlightExportFailureView: View {
    let format: FlightExportFormat
    let onRetry: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.24)
                .ignoresSafeArea()
            VStack(spacing: 24) {
                Text("Export Couldn’t Be Completed")
                    .font(.title3.weight(.semibold))
                Text(explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Text(reason)
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color.red.opacity(0.08), in: .rect(cornerRadius: 12))
                HStack(spacing: 16) {
                    Button(action: onRetry) {
                        Text("Try Again")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("flight-export.retry")

                    Button(role: .cancel, action: onCancel) {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("flight-export.cancel-failure")
                }
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .controlSize(.large)
            }
            .padding(24)
            .frame(maxWidth: 570, minHeight: 330)
            .background(.regularMaterial, in: .rect(cornerRadius: 24))
            .shadow(radius: 18, y: 8)
            .padding(24)
        }
        .accessibilityIdentifier("flight-export.failure")
    }

    private var explanation: LocalizedStringResource {
        format == .diagnosticBundle
            ? "The diagnostic bundle could not be prepared. No incomplete file was shared, and the Flight recording was not changed."
            : "The GPX track could not be prepared. No incomplete file was shared, and the Flight recording was not changed."
    }

    private var reason: LocalizedStringResource {
        format == .diagnosticBundle
            ? "Storage became unavailable while assembling the bundle."
            : "Storage became unavailable while assembling the track."
    }
}

struct FlightExportResultView: View {
    let result: FlightExportResult

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                Text(summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(formatLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 28)
                    .background(Color.green.opacity(0.1), in: .capsule)

                Text(fileURL.lastPathComponent)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("flight-export.filename")

                Text(contentsDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                shareLink
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

    @ViewBuilder
    private var shareLink: some View {
        switch result {
        case .diagnostic:
            ShareLink(
                item: DiagnosticBundleShareItem(fileURL: fileURL),
                preview: SharePreview(fileURL.lastPathComponent)
            ) {
                shareLabel
            }
        case .gpx:
            ShareLink(
                item: GPXFlightShareItem(fileURL: fileURL),
                preview: SharePreview(fileURL.lastPathComponent)
            ) {
                shareLabel
            }
        }
    }

    private var shareLabel: some View {
        Label("Open Share Sheet", systemImage: "square.and.arrow.up")
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.roundedRectangle(radius: 14))
            .controlSize(.large)
            .accessibilityIdentifier("flight-export.share")
    }

    private var fileURL: URL {
        switch result {
        case .diagnostic(let value): value.fileURL
        case .gpx(let value): value.fileURL
        }
    }

    private var formatLabel: String {
        switch result {
        case .diagnostic: "DIAGNOSTIC BUNDLE"
        case .gpx: "GPX"
        }
    }

    private var summary: String {
        switch result {
        case .diagnostic: "Complete Flight evidence is ready to share"
        case .gpx: "Track exported as GPX"
        }
    }

    private var contentsDescription: String {
        switch result {
        case .diagnostic:
            "Includes the retained plan, closure, events, segmented track, accuracy, and supplemental measurements."
        case .gpx:
            "Includes valid GPS samples only. Navigation events and private app metadata stay on device."
        }
    }
}

private struct DiagnosticBundleShareItem: Transferable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .navigationFlightDiagnosticBundle) { item in
            SentTransferredFile(item.fileURL)
        }
    }
}

private struct GPXFlightShareItem: Transferable {
    let fileURL: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .navigationFlightGPX) { item in
            SentTransferredFile(item.fileURL)
        }
    }
}

private extension UTType {
    static let navigationFlightDiagnosticBundle = UTType(
        exportedAs: "app.navigationflight.diagnostic-bundle",
        conformingTo: .json
    )
    static let navigationFlightGPX = UTType(
        exportedAs: "app.navigationflight.gpx",
        conformingTo: .xml
    )
}
