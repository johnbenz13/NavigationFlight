import Foundation

public enum DiagnosticBundleCodecError: Error, Equatable, Sendable {
    case unsupportedSchemaVersion(Int)
    case invalidEventOrder
    case duplicateTrackSegmentIdentifier(UUID)
    case invalidMeasurement
    case invalidEventPayload(kind: String)
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
        var segmentIDs = Set<UUID>()
        for segment in bundle.trackSegments where !segmentIDs.insert(segment.identifier).inserted {
            throw DiagnosticBundleCodecError.duplicateTrackSegmentIdentifier(segment.identifier)
        }
        guard bundle.sourceState == .closed ? bundle.closure != nil : bundle.closure == nil else {
            throw DiagnosticBundleCodecError.sourceStateClosureMismatch
        }
        for segment in bundle.trackSegments {
            guard zip(segment.samples, segment.samples.dropFirst()).allSatisfy({ $0.observedAt <= $1.observedAt }) else {
                throw DiagnosticBundleCodecError.invalidMeasurement
            }
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
                  nonnegative(sample.groundSpeedMetersPerSecond),
                  nonnegative(sample.verticalAccuracyMeters),
                  nonnegative(sample.speedAccuracyMetersPerSecond),
                  nonnegative(sample.courseAccuracyDegrees),
                  nonnegative(sample.deviceHeadingAccuracyDegrees),
                  degrees(sample.courseDegrees),
                  degrees(sample.deviceHeadingDegrees),
                  optionalValues.compactMap({ $0 }).allSatisfy(\.isFinite) else {
                throw DiagnosticBundleCodecError.invalidMeasurement
            }
        }
        for event in bundle.orderedEvents {
            try validate(event.payload)
        }
    }

    private func nonnegative(_ value: Double?) -> Bool {
        value.map { $0 >= 0 } ?? true
    }

    private func degrees(_ value: Double?) -> Bool {
        value.map { (0..<360).contains($0) } ?? true
    }

    private func validate(_ payload: FlightEvidenceBundleV1.EventPayload) throws {
        let keys = Set(payload.values.keys)
        let valid: Bool = switch payload.kind {
        case "recordingStarted":
            keys == ["cause"] && payload.values["cause"]?.stringValue.map {
                ["startLegWithoutLocation", "automaticTakeoff", "partialStart"].contains($0)
            } == true
        case "legStarted", "destinationIdentified", "waypointReached", "finalWaypointReached", "automaticLegRecovery":
            keys == ["legIdentifier"] && payload.values["legIdentifier"]?.isIdentifier == true
        case "identificationPointReached":
            keys == ["legIdentifier", "identificationPointIdentifier"]
                && payload.values.values.allSatisfy(\.isIdentifier)
        case "automaticNextLegTransition":
            keys == ["fromLegIdentifier", "toLegIdentifier"]
                && payload.values.values.allSatisfy(\.isIdentifier)
        case "etaRevised":
            (keys == ["legIdentifier", "targetKind", "targetIdentifier", "committedSeconds"]
                || keys == ["legIdentifier", "targetKind", "targetIdentifier", "priorSeconds", "committedSeconds"])
                && payload.values["legIdentifier"]?.isIdentifier == true
                && payload.values["targetKind"]?.stringValue.map {
                    ["identificationPoint", "destination"].contains($0)
                } == true
                && payload.values["targetIdentifier"]?.isIdentifier == true
                && payload.values["committedSeconds"]?.isInteger == true
                && (payload.values["priorSeconds"] == nil || payload.values["priorSeconds"]?.isInteger == true)
        case "headingRevised":
            keys == ["legIdentifier", "priorDegrees", "committedDegrees"]
                && payload.values["legIdentifier"]?.isIdentifier == true
                && payload.values["priorDegrees"]?.isInteger == true
                && payload.values["committedDegrees"]?.isInteger == true
        case "reachUndone": keys == ["originalEventIdentifier"] && payload.values.values.allSatisfy(\.isIdentifier)
        case "positionCheckRequested", "navigationCompleted", "recoveryContinued", "manualEnd": keys.isEmpty
        case "positionCheckEnded": validatePositionCheck(payload.values)
        case "storageDegraded":
            keys == ["reason"] && payload.values["reason"]?.stringValue.map {
                ["trackWriteFailed", "lowStorage", "bufferOverflow"].contains($0)
            } == true
        case "locationAvailabilityChanged":
            keys == ["availability"] && payload.values["availability"]?.stringValue.map {
                ["servicesDisabled", "signalLost", "permissionDenied", "permissionRestricted", "resumed"].contains($0)
            } == true
        case "physicalStateChanged":
            keys == ["from", "to"]
                && validPhysicalState(payload.values["from"])
                && validPhysicalState(payload.values["to"])
        case "physicalStateCorrected":
            keys == ["originalEventIdentifier", "from", "to"]
                && payload.values["originalEventIdentifier"]?.isIdentifier == true
                && validPhysicalState(payload.values["from"])
                && validPhysicalState(payload.values["to"])
        case "recordingClosed":
            keys == ["outcome", "cause"]
                && payload.values["outcome"]?.stringValue.map {
                    ["complete", "incomplete"].contains($0)
                } == true
                && payload.values["cause"]?.stringValue.map {
                    [
                        "automatic", "manual", "recoveryExpired", "endedDuringRecovery",
                        "supersededDuringRecovery",
                    ].contains($0)
                } == true
        default: false
        }
        guard valid else { throw DiagnosticBundleCodecError.invalidEventPayload(kind: payload.kind) }
    }

    private func validatePositionCheck(_ values: [String: PortableValue]) -> Bool {
        if Set(values.keys) == ["outcome"] {
            return values["outcome"]?.stringValue == "endedWithoutDisclosure"
        }
        guard Set(values.keys) == ["outcome", "sample"],
              values["outcome"]?.stringValue == "disclosed",
              let sample = values["sample"]?.objectValue,
              Set(sample.keys) == [
                "latitudeDegrees", "longitudeDegrees", "observedAt", "horizontalAccuracyMeters",
              ],
              let latitude = sample["latitudeDegrees"]?.numberValue,
              latitude.isFinite,
              (-90...90).contains(latitude),
              let longitude = sample["longitudeDegrees"]?.numberValue,
              longitude.isFinite,
              (-180...180).contains(longitude),
              sample["observedAt"]?.isTimestamp == true,
              let horizontalAccuracy = sample["horizontalAccuracyMeters"]?.numberValue,
              horizontalAccuracy.isFinite,
              horizontalAccuracy >= 0 else { return false }
        return true
    }

    private func validPhysicalState(_ value: PortableValue?) -> Bool {
        value?.stringValue.map {
            ["preparing", "groundMovement", "airborne", "landedAwaitingStop", "stopped", "unavailable"]
                .contains($0)
        } == true
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

private extension PortableValue {
    var stringValue: String? { if case .string(let value) = self { value } else { nil } }
    var isInteger: Bool { if case .integer = self { true } else { false } }
    var isIdentifier: Bool { if case .identifier = self { true } else { false } }
    var numberValue: Double? { if case .number(let value) = self { value } else { nil } }
    var isTimestamp: Bool { if case .timestamp = self { true } else { false } }
    var objectValue: [String: PortableValue]? { if case .object(let value) = self { value } else { nil } }
}
