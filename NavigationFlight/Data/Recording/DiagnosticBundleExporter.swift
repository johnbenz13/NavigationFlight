import FlightEvidenceCore
import Foundation

nonisolated enum DiagnosticExportError: Error, Equatable, Sendable {
    case recordingNotClosed(UUID)
    case publishedFileValidationFailed
}

nonisolated struct DiagnosticExportResult: Equatable, Sendable {
    let fileURL: URL
    let byteCount: Int
    let schemaVersion: Int
}

actor DiagnosticBundleExporter {
    private let temporaryDirectory: URL
    private let codec: DiagnosticBundleCodec
    private let mapper: FlightEvidenceMapper
    private let preparationDelay: Duration

    init(
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        codec: DiagnosticBundleCodec = DiagnosticBundleCodec(),
        mapper: FlightEvidenceMapper = FlightEvidenceMapper(),
        preparationDelay: Duration = .zero
    ) {
        self.temporaryDirectory = temporaryDirectory
        self.codec = codec
        self.mapper = mapper
        self.preparationDelay = preparationDelay
    }

    func export(
        _ snapshot: FlightEvidenceSnapshot,
        progress: @escaping @Sendable (Double) async -> Void = { _ in }
    ) async throws -> DiagnosticExportResult {
        guard snapshot.recording.recording.closure != nil else {
            throw DiagnosticExportError.recordingNotClosed(snapshot.recording.recording.id)
        }

        try Task.checkCancellation()
        await progress(0.12)
        let bundleIdentifier = UUID()
        let bundle = try mapper.bundle(from: snapshot, bundleIdentifier: bundleIdentifier)
        let data = try codec.encode(bundle)
        try Task.checkCancellation()
        await progress(0.64)
        if preparationDelay > .zero {
            try await Task.sleep(for: preparationDelay)
        }

        let exportDirectory = temporaryDirectory
            .appending(path: "NavigationFlight-Diagnostic-Exports", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: exportDirectory,
            withIntermediateDirectories: true
        )

        let filename = Self.filename(for: snapshot.recording, bundleIdentifier: bundleIdentifier)
        let publishedURL = exportDirectory.appending(path: filename)
        let partialURL = exportDirectory.appending(path: ".\(filename).partial")
        try? FileManager.default.removeItem(at: partialURL)
        try? FileManager.default.removeItem(at: publishedURL)

        do {
            try data.write(to: partialURL, options: [.atomic])
            try Task.checkCancellation()

            let stagedData = try Data(contentsOf: partialURL)
            let decoded = try codec.decode(stagedData)
            guard decoded.bundleIdentifier == bundle.bundleIdentifier,
                  decoded.recordingManifest.recordingIdentifier
                    == bundle.recordingManifest.recordingIdentifier else {
                throw DiagnosticExportError.publishedFileValidationFailed
            }

            try Task.checkCancellation()
            await progress(0.86)
            try FileManager.default.moveItem(at: partialURL, to: publishedURL)
            await progress(1)
            return DiagnosticExportResult(
                fileURL: publishedURL,
                byteCount: data.count,
                schemaVersion: decoded.schemaVersion
            )
        } catch {
            try? FileManager.default.removeItem(at: partialURL)
            try? FileManager.default.removeItem(at: publishedURL)
            throw error
        }
    }

    func removePublishedFile(at url: URL) {
        guard url.pathExtension == "nflightbundle",
              url.deletingLastPathComponent().lastPathComponent == "NavigationFlight-Diagnostic-Exports" else {
            return
        }
        try? FileManager.default.removeItem(at: url)
    }

    private static func filename(
        for snapshot: FlightRecordingReadSnapshot,
        bundleIdentifier: UUID
    ) -> String {
        let allowed = CharacterSet.alphanumerics
        let title = snapshot.recording.flightPlanSnapshot.title
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let date = formatter.string(from: snapshot.recording.startedAt)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
        return "\(title.isEmpty ? "Flight" : title)-\(date)-\(bundleIdentifier.uuidString.prefix(8).lowercased()).nflightbundle"
    }
}
