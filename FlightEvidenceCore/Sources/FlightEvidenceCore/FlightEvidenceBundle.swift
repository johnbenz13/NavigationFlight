import Foundation

public struct FlightEvidenceBundleV1: Codable, Equatable, Sendable {
    public static let schemaVersion = 1

    public let schemaVersion: Int
    public let bundleIdentifier: UUID
    public let capturedAt: Date
    public let sourceState: SourceState
    public let applicationContext: ApplicationContext
    public let detectorPolicyContext: DetectorPolicyContext?
    public let recordingManifest: RecordingManifest
    public let flightPlan: FlightPlanEvidence
    public let closure: ClosureEvidence?
    public let orderedEvents: [EventEvidence]
    public let trackSegments: [TrackSegmentEvidence]

    public init(
        schemaVersion: Int = Self.schemaVersion,
        bundleIdentifier: UUID,
        capturedAt: Date,
        sourceState: SourceState,
        applicationContext: ApplicationContext,
        detectorPolicyContext: DetectorPolicyContext?,
        recordingManifest: RecordingManifest,
        flightPlan: FlightPlanEvidence,
        closure: ClosureEvidence?,
        orderedEvents: [EventEvidence],
        trackSegments: [TrackSegmentEvidence]
    ) {
        self.schemaVersion = schemaVersion
        self.bundleIdentifier = bundleIdentifier
        self.capturedAt = capturedAt
        self.sourceState = sourceState
        self.applicationContext = applicationContext
        self.detectorPolicyContext = detectorPolicyContext
        self.recordingManifest = recordingManifest
        self.flightPlan = flightPlan
        self.closure = closure
        self.orderedEvents = orderedEvents
        self.trackSegments = trackSegments
    }
}

public extension FlightEvidenceBundleV1 {
    enum SourceState: String, Codable, Equatable, Sendable {
        case closed
        case active
        case recoverable
    }

    struct ApplicationContext: Codable, Equatable, Sendable {
        public let appVersion: String
        public let appBuild: String
        public let platform: String
        public let osVersion: String

        public init(appVersion: String, appBuild: String, platform: String, osVersion: String) {
            self.appVersion = appVersion
            self.appBuild = appBuild
            self.platform = platform
            self.osVersion = osVersion
        }
    }

    struct DetectorPolicyContext: Codable, Equatable, Sendable {
        public let version: String
        public let values: [String: PortableValue]

        public init(version: String, values: [String: PortableValue]) {
            self.version = version
            self.values = values
        }
    }

    struct RecordingManifest: Codable, Equatable, Sendable {
        public let recordingIdentifier: UUID
        public let flightIdentifier: UUID
        public let startedAt: Date
        public let physicalState: String
        public let navigationState: String
        public let gpsCoverage: String

        public init(
            recordingIdentifier: UUID,
            flightIdentifier: UUID,
            startedAt: Date,
            physicalState: String,
            navigationState: String,
            gpsCoverage: String
        ) {
            self.recordingIdentifier = recordingIdentifier
            self.flightIdentifier = flightIdentifier
            self.startedAt = startedAt
            self.physicalState = physicalState
            self.navigationState = navigationState
            self.gpsCoverage = gpsCoverage
        }
    }

    struct FlightPlanEvidence: Codable, Equatable, Sendable {
        public let identifier: UUID
        public let title: String
        public let legIdentifiers: [UUID]
        public let sourceData: Data?

        public init(identifier: UUID, title: String, legIdentifiers: [UUID], sourceData: Data?) {
            self.identifier = identifier
            self.title = title
            self.legIdentifiers = legIdentifiers
            self.sourceData = sourceData
        }
    }

    struct ClosureEvidence: Codable, Equatable, Sendable {
        public let outcome: String
        public let cause: String
        public let closedAt: Date
        public let elapsedNanoseconds: Int64
        public let landingEvidenceAvailable: Bool

        public init(
            outcome: String,
            cause: String,
            closedAt: Date,
            elapsedNanoseconds: Int64,
            landingEvidenceAvailable: Bool
        ) {
            self.outcome = outcome
            self.cause = cause
            self.closedAt = closedAt
            self.elapsedNanoseconds = elapsedNanoseconds
            self.landingEvidenceAvailable = landingEvidenceAvailable
        }
    }

    struct EventEvidence: Codable, Equatable, Sendable {
        public let identifier: UUID
        public let sequence: UInt64
        public let recordedAt: Date
        public let elapsedNanoseconds: Int64
        public let origin: String
        public let payload: EventPayload

        public init(
            identifier: UUID,
            sequence: UInt64,
            recordedAt: Date,
            elapsedNanoseconds: Int64,
            origin: String,
            payload: EventPayload
        ) {
            self.identifier = identifier
            self.sequence = sequence
            self.recordedAt = recordedAt
            self.elapsedNanoseconds = elapsedNanoseconds
            self.origin = origin
            self.payload = payload
        }
    }

    struct EventPayload: Codable, Equatable, Sendable {
        public let kind: String
        public let values: [String: PortableValue]

        public init(kind: String, values: [String: PortableValue] = [:]) {
            self.kind = kind
            self.values = values
        }
    }

    struct TrackSegmentEvidence: Codable, Equatable, Sendable {
        public let identifier: UUID
        public let samples: [TrackSampleEvidence]

        public init(identifier: UUID, samples: [TrackSampleEvidence]) {
            self.identifier = identifier
            self.samples = samples
        }
    }

    struct TrackSampleEvidence: Codable, Equatable, Sendable {
        public let latitudeDegrees: Double
        public let longitudeDegrees: Double
        public let observedAt: Date
        public let horizontalAccuracyMeters: Double
        public let altitudeMeters: Double?
        public let verticalAccuracyMeters: Double?
        public let groundSpeedMetersPerSecond: Double?
        public let speedAccuracyMetersPerSecond: Double?
        public let courseDegrees: Double?
        public let courseAccuracyDegrees: Double?
        public let barometricAltitudeMeters: Double?
        public let deviceHeadingDegrees: Double?
        public let deviceHeadingAccuracyDegrees: Double?

        public init(
            latitudeDegrees: Double,
            longitudeDegrees: Double,
            observedAt: Date,
            horizontalAccuracyMeters: Double,
            altitudeMeters: Double? = nil,
            verticalAccuracyMeters: Double? = nil,
            groundSpeedMetersPerSecond: Double? = nil,
            speedAccuracyMetersPerSecond: Double? = nil,
            courseDegrees: Double? = nil,
            courseAccuracyDegrees: Double? = nil,
            barometricAltitudeMeters: Double? = nil,
            deviceHeadingDegrees: Double? = nil,
            deviceHeadingAccuracyDegrees: Double? = nil
        ) {
            self.latitudeDegrees = latitudeDegrees
            self.longitudeDegrees = longitudeDegrees
            self.observedAt = observedAt
            self.horizontalAccuracyMeters = horizontalAccuracyMeters
            self.altitudeMeters = altitudeMeters
            self.verticalAccuracyMeters = verticalAccuracyMeters
            self.groundSpeedMetersPerSecond = groundSpeedMetersPerSecond
            self.speedAccuracyMetersPerSecond = speedAccuracyMetersPerSecond
            self.courseDegrees = courseDegrees
            self.courseAccuracyDegrees = courseAccuracyDegrees
            self.barometricAltitudeMeters = barometricAltitudeMeters
            self.deviceHeadingDegrees = deviceHeadingDegrees
            self.deviceHeadingAccuracyDegrees = deviceHeadingAccuracyDegrees
        }
    }
}

public enum PortableValue: Codable, Equatable, Sendable {
    case string(String)
    case integer(Int64)
    case unsignedInteger(UInt64)
    case number(Double)
    case boolean(Bool)
    case identifier(UUID)
    case timestamp(Date)
    case object([String: PortableValue])
    case array([PortableValue])

    private enum CodingKeys: String, CodingKey { case type, value }
    private enum ValueType: String, Codable {
        case string, integer, unsignedInteger, number, boolean, identifier, timestamp, object, array
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(ValueType.self, forKey: .type) {
        case .string: self = .string(try container.decode(String.self, forKey: .value))
        case .integer: self = .integer(try container.decode(Int64.self, forKey: .value))
        case .unsignedInteger: self = .unsignedInteger(try container.decode(UInt64.self, forKey: .value))
        case .number: self = .number(try container.decode(Double.self, forKey: .value))
        case .boolean: self = .boolean(try container.decode(Bool.self, forKey: .value))
        case .identifier: self = .identifier(try container.decode(UUID.self, forKey: .value))
        case .timestamp: self = .timestamp(try container.decode(Date.self, forKey: .value))
        case .object: self = .object(try container.decode([String: PortableValue].self, forKey: .value))
        case .array: self = .array(try container.decode([PortableValue].self, forKey: .value))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .string(let value): try container.encode(ValueType.string, forKey: .type); try container.encode(value, forKey: .value)
        case .integer(let value): try container.encode(ValueType.integer, forKey: .type); try container.encode(value, forKey: .value)
        case .unsignedInteger(let value): try container.encode(ValueType.unsignedInteger, forKey: .type); try container.encode(value, forKey: .value)
        case .number(let value): try container.encode(ValueType.number, forKey: .type); try container.encode(value, forKey: .value)
        case .boolean(let value): try container.encode(ValueType.boolean, forKey: .type); try container.encode(value, forKey: .value)
        case .identifier(let value): try container.encode(ValueType.identifier, forKey: .type); try container.encode(value, forKey: .value)
        case .timestamp(let value): try container.encode(ValueType.timestamp, forKey: .type); try container.encode(value, forKey: .value)
        case .object(let value): try container.encode(ValueType.object, forKey: .type); try container.encode(value, forKey: .value)
        case .array(let value): try container.encode(ValueType.array, forKey: .type); try container.encode(value, forKey: .value)
        }
    }
}
