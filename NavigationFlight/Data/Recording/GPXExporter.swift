import Foundation

nonisolated enum GPXExportError: Error, Equatable, Sendable {
    case recordingNotClosed(id: UUID)
}

nonisolated struct GPXExportResult: Equatable, Sendable {
    let fileURL: URL
}

nonisolated struct GPXExporter: Sendable {
    private let temporaryDirectory: URL
    private let batchSize: Int

    init(
        temporaryDirectory: URL = FileManager.default.temporaryDirectory,
        batchSize: Int = 256
    ) {
        self.temporaryDirectory = temporaryDirectory
        self.batchSize = max(1, batchSize)
    }

    func export(snapshot: FlightRecordingReadSnapshot) async throws -> GPXExportResult {
        guard let closure = snapshot.recording.closure else {
            throw GPXExportError.recordingNotClosed(id: snapshot.recording.id)
        }
        try Task.checkCancellation()
        let filename = Self.filename(for: snapshot)
        let fileURL = temporaryDirectory.appending(path: filename)
        let partialURL = temporaryDirectory.appending(path: ".\(filename).partial")
        try? FileManager.default.removeItem(at: partialURL)

        do {
            var segments: [String] = []
            for segment in snapshot.trackSegments {
                var points: [String] = []
                let sortedSamples = segment.samples.sorted { $0.observedAt < $1.observedAt }
                for (index, sample) in sortedSamples.enumerated() {
                    if index.isMultiple(of: batchSize) {
                        try Task.checkCancellation()
                        await Task.yield()
                    }
                    points.append(Self.trackPoint(sample))
                }
                segments.append("""
                    <trkseg>
                \(points.joined(separator: "\n"))
                    </trkseg>
                """)
            }
            try Task.checkCancellation()
            let xml = Self.document(snapshot: snapshot, closure: closure, segments: segments)
            try Data(xml.utf8).write(to: partialURL, options: .atomic)
            try Task.checkCancellation()
            var isDirectory: ObjCBool = false
            if FileManager.default.fileExists(atPath: fileURL.path, isDirectory: &isDirectory), !isDirectory.boolValue {
                try FileManager.default.removeItem(at: fileURL)
            }
            try FileManager.default.moveItem(at: partialURL, to: fileURL)
            return GPXExportResult(fileURL: fileURL)
        } catch {
            try? FileManager.default.removeItem(at: partialURL)
            throw error
        }
    }

    private static func document(
        snapshot: FlightRecordingReadSnapshot,
        closure: FlightRecordingClosure,
        segments: [String]
    ) -> String {
        let recording = snapshot.recording
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="NavigationFlight" xmlns="http://www.topografix.com/GPX/1/1" xmlns:navflight="https://navigationflight.app/xmlschemas/GPX/1/0">
          <metadata>
            <name>\(escape(recording.flightPlanSnapshot.title))</name>
            <extensions>
              <navflight:flightPlanID>\(recording.flightPlanSnapshot.id.uuidString)</navflight:flightPlanID>
              <navflight:status>\(closure.outcome == .complete ? "complete" : "incomplete")</navflight:status>
              <navflight:closureCause>\(closureCause(closure.cause))</navflight:closureCause>
              <navflight:coverage>\(coverage(recording.gpsCoverage))</navflight:coverage>
            </extensions>
          </metadata>
          <trk>
            <name>\(escape(recording.flightPlanSnapshot.title))</name>
        \(segments.joined(separator: "\n"))
          </trk>
        </gpx>
        """
    }

    private static func trackPoint(_ sample: RecordedTrackSample) -> String {
        let elevation = sample.altitudeMeters.flatMap { value in
            value.isFinite ? "\n        <ele>\(value)</ele>" : nil
        } ?? ""
        let speed = sample.groundSpeedMetersPerSecond.flatMap { value in
            value.isFinite && value >= 0 ? "\n          <navflight:speed>\(value)</navflight:speed>" : nil
        }
        let course = sample.courseDegrees.flatMap { value in
            value.isFinite && (0..<360).contains(value) ? "\n          <navflight:course>\(value)</navflight:course>" : nil
        }
        let values = [speed, course].compactMap { $0 }.joined()
        let extensions = values.isEmpty ? "" : "\n        <extensions>\(values)\n        </extensions>"
        return """
              <trkpt lat="\(sample.coordinate.latitudeDegrees)" lon="\(sample.coordinate.longitudeDegrees)">
                \(elevation)<time>\(sample.observedAt.formatted(.iso8601))</time>\(extensions)
              </trkpt>
        """
    }

    private static func filename(for snapshot: FlightRecordingReadSnapshot) -> String {
        let allowed = CharacterSet.alphanumerics
        let title = snapshot.recording.flightPlanSnapshot.title
            .components(separatedBy: allowed.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: snapshot.recording.startedAt)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")
        let suffix = snapshot.recording.id.uuidString.prefix(8).lowercased()
        return "\(title.isEmpty ? "Flight" : title)-\(timestamp)-\(suffix).gpx"
    }

    private static func closureCause(_ cause: FlightRecordingClosure.Cause) -> String {
        switch cause {
        case .automatic: "automatic"
        case .manual: "manual"
        case .recoveryExpired: "recovery-expired"
        case .endedDuringRecovery: "ended-during-recovery"
        case .supersededDuringRecovery: "superseded-during-recovery"
        }
    }

    private static func coverage(_ coverage: GPSCoverageState) -> String {
        switch coverage {
        case .available: "available"
        case .partial: "partial"
        case .unavailable: "unavailable"
        }
    }

    private static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
