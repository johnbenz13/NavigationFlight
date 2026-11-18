import Foundation

public enum DiagnosticBundleCodecError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case invalidEventOrder
    case duplicateTrackSegmentIdentifier(UUID)
    case invalidMeasurement
    case sourceStateClosureMismatch
}

public struct DiagnosticBundleCodec: Sendable {
    public init() {}

    public func encode(_ bundle: FlightEvidenceBundleV1) throws -> Data {
        try validate(bundle)
        return try Self.encoder.encode(bundle)
    }

    public func decode(_ data: Data) throws -> FlightEvidenceBundleV1 {
        let bundle = try Self.decoder.decode(FlightEvidenceBundleV1.self, from: data)
        try validate(bundle)
        return bundle
    }

    public func validate(_ bundle: FlightEvidenceBundleV1) throws {
        guard bundle.schemaVersion == FlightEvidenceBundleV1.schemaVersion else {
            throw DiagnosticBundleCodecError.unsupportedSchemaVersion(bundle.schemaVersion)
        }
        guard zip(bundle.orderedEvents, bundle.orderedEvents.dropFirst()).allSatisfy({ $0.sequence < $1.sequence }) else {
            throw DiagnosticBundleCodecError.invalidEventOrder
        }
        let segmentIDs = bundle.trackSegments.map(\.identifier)
        guard Set(segmentIDs).count == segmentIDs.count else {
            throw DiagnosticBundleCodecError.duplicateTrackSegmentIdentifier(
                segmentIDs.first { id in segmentIDs.filter { $0 == id }.count > 1 }!
            )
        }
        guard bundle.sourceState == .closed ? bundle.closure != nil : bundle.closure == nil else {
            throw DiagnosticBundleCodecError.sourceStateClosureMismatch
        }
        for sample in bundle.trackSegments.flatMap(\.samples) {
            let optionalValues = [
                sample.altitudeMeters, sample.verticalAccuracyMeters,
                sample.groundSpeedMetersPerSecond, sample.speedAccuracyMetersPerSecond,
                sample.courseDegrees, sample.courseAccuracyDegrees,
                sample.barometricAltitudeMeters, sample.deviceHeadingDegrees,
                sample.deviceHeadingAccuracyDegrees,
            ]
            guard sample.latitudeDegrees.isFinite, (-90...90).contains(sample.latitudeDegrees),
                  sample.longitudeDegrees.isFinite, (-180...180).contains(sample.longitudeDegrees),
                  sample.horizontalAccuracyMeters.isFinite, sample.horizontalAccuracyMeters >= 0,
                  optionalValues.compactMap({ $0 }).allSatisfy(\.isFinite) else {
                throw DiagnosticBundleCodecError.invalidMeasurement
            }
        }
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(Self.dateFormatter.string(from: date))
        }
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            guard let date = Self.dateFormatter.date(from: value) else {
                throw DecodingError.dataCorruptedError(in: container, debugDescription: "Expected RFC 3339 timestamp with fractional seconds")
            }
            return date
        }
        return decoder
    }()

    private static var dateFormatter: ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }
}
