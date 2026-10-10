import Foundation

struct WGS84Coordinate: Equatable, Sendable {
    let latitudeDegrees: Double
    let longitudeDegrees: Double
}

struct AltitudeFeet: Equatable, Sendable {
    let value: Double
}

struct Degrees: Equatable, Sendable {
    let value: Double
}

struct Knots: Equatable, Sendable {
    let value: Double
}

struct FrequencyMHz: Equatable, Sendable {
    let value: Double
}

struct NauticalMiles: Equatable, Sendable {
    let value: Double
}

struct Metres: Equatable, Sendable {
    let value: Double
}

struct LegProgress: Equatable, Sendable {
    let fraction: Double
}

struct Wind: Equatable, Sendable {
    /// Direction the wind comes from, measured clockwise from true north.
    let directionFromTrue: Degrees
    let speed: Knots
}

struct NavigationParameters: Equatable, Sendable {
    /// East-positive magnetic variation from the serialized flight plan.
    let magneticVariationEast: Degrees
    let defaultAltitude: AltitudeFeet
    let driftAngle: Degrees
    let planningAirspeed: Knots
}

struct ReportingPointReference: Equatable, Sendable {
    let catalogID: String
    let name: String
    let position: WGS84Coordinate
}

struct RouteWaypoint: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let position: WGS84Coordinate
    let plannedAltitude: AltitudeFeet
    let generatedNumber: Int
    let reportingPointReference: ReportingPointReference?
}

struct NavigationLeg: Identifiable, Equatable, Sendable {
    let id: UUID
    let departure: RouteWaypoint
    let arrival: RouteWaypoint
    let windOverride: Wind?
    let remark: String?
}

struct AnnotationArrangement: Equatable, Sendable {
    let longitudinalOffset: Metres
    let lateralOffset: Metres
    let rotation: Degrees
}

struct IdentificationPoint: Identifiable, Equatable, Sendable {
    let id: UUID
    let legID: UUID
    let progress: LegProgress
    let lateralOffset: Metres
    let timeLabelArrangement: AnnotationArrangement
}

enum AltitudeChangeAnchor: Equatable, Sendable {
    case legProgress(LegProgress)
    case waypoint(UUID)
    case identificationPoint(UUID)
}

enum AltitudeChangeDirection: String, Equatable, Sendable {
    case up
    case down
}

struct AltitudeChange: Identifiable, Equatable, Sendable {
    let id: UUID
    let legID: UUID
    let anchor: AltitudeChangeAnchor
    let targetAltitude: AltitudeFeet
    let symbolDirection: AltitudeChangeDirection
    let showsAnchorMark: Bool
    let arrangement: AnnotationArrangement
}

struct RadioService: Equatable, Sendable {
    let catalogID: String?
    let name: String
}

struct FrequencyChange: Identifiable, Equatable, Sendable {
    let id: UUID
    let legID: UUID
    let progress: LegProgress
    let service: RadioService
    let frequency: FrequencyMHz
    let isFlippedHorizontally: Bool
    let arrangement: AnnotationArrangement
}

enum FlightPhase: String, CaseIterable, Equatable, Sendable {
    case departure
    case enRoute = "en-route"
    case arrival
}

struct ReplacedFrequency: Equatable, Sendable {
    let name: String
    let role: String?
    let frequency: FrequencyMHz
}

struct FrequencyEntry: Identifiable, Equatable, Sendable {
    let id: String
    let phase: FlightPhase
    let name: String
    let frequency: FrequencyMHz
    let replaces: ReplacedFrequency?
}

struct AerodromeReference: Equatable, Sendable {
    let catalogID: String
    let name: String
    let position: WGS84Coordinate
    let icao: String?
    let localCode: String?
}

struct OperationalContext: Equatable, Sendable {
    let defaultWind: Wind?
    let departureAerodrome: AerodromeReference?
    let arrivalAerodrome: AerodromeReference?
    let frequencyEntries: [FrequencyEntry]
    let frequencyOrderByPhase: [FlightPhase: [String]]
}

struct NavigationAidReference: Equatable, Sendable {
    let catalogID: String
    let identifier: String
    let name: String
    let position: WGS84Coordinate
}

enum VORDMECalculation: Equatable, Sendable {
    case automatic
    case manual(radial: Degrees, distance: NauticalMiles)
}

struct VORDMEReference: Identifiable, Equatable, Sendable {
    let id: UUID
    let waypointID: UUID
    let calculation: VORDMECalculation
    let navigationAid: NavigationAidReference
}
