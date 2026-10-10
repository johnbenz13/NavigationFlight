import Foundation

struct FPLNavV5DTO: Decodable {
    let format: String
    let formatVersion: Int
    let project: Project
    let navigation: Navigation

    struct Project: Decodable {
        let id: UUID
        let title: String
        let createdAt: Date
        let modifiedAt: Date
    }

    struct Navigation: Decodable {
        let parameters: Parameters
        let route: Route
        let identificationPoints: [IdentificationPoint]
        let altitudeChanges: [AltitudeChange]
        let radioFrequencyChanges: [RadioFrequencyChange]
        let operationalContext: OperationalContext
        let vorDmeReferences: [VORDMEReference]
    }

    struct Parameters: Decodable {
        let magneticVariationEastDegrees: Double
        let defaultAltitudeFeet: Double
        let driftAngleDegrees: Double
        let planningAirspeedKnots: Double
    }

    struct Route: Decodable {
        let waypointOrder: [UUID]
        let waypoints: [Waypoint]
        let legs: [Leg]
    }

    struct Waypoint: Decodable {
        let id: UUID
        let name: String
        let position: Coordinate
        let altitudeFeet: Double
        let generatedNumber: Int
        let reportingPointReference: ReportingPointReference?
    }

    struct Coordinate: Decodable {
        let latitude: Double
        let longitude: Double
    }

    struct ReportingPointReference: Decodable {
        let catalogId: String
        let snapshot: ReportingPointSnapshot
    }

    struct ReportingPointSnapshot: Decodable {
        let name: String
        let position: Coordinate
    }

    struct Leg: Decodable {
        let id: UUID
        let departureWaypointId: UUID
        let arrivalWaypointId: UUID
        let windOverride: Wind?
        let remark: String?
    }

    struct Wind: Decodable {
        let directionFromTrueDegrees: Double
        let speedKnots: Double
    }

    struct IdentificationPoint: Decodable {
        let id: UUID
        let legId: UUID
        let legProgress: Double
        let lateralOffsetMetres: Double
        let timeLabelArrangement: Arrangement
    }

    struct Arrangement: Decodable {
        let longitudinalMetres: Double
        let lateralMetres: Double
        let rotationDegrees: Double
    }

    struct AltitudeChange: Decodable {
        let id: UUID
        let legId: UUID
        let anchor: AltitudeAnchor
        let targetAltitudeFeet: Double
        let symbolDirection: String
        let showAnchorMark: Bool
        let arrangement: Arrangement
    }

    struct AltitudeAnchor: Decodable {
        let kind: String
        let legProgress: Double?
        let waypointId: UUID?
        let identificationPointId: UUID?
    }

    struct RadioFrequencyChange: Decodable {
        let id: UUID
        let legId: UUID
        let legProgress: Double
        let service: Service
        let frequencyMhz: Double
        let flippedHorizontally: Bool
        let arrangement: Arrangement
    }

    struct Service: Decodable {
        let catalogId: String?
        let name: String
    }

    struct OperationalContext: Decodable {
        let defaultWind: Wind?
        let departureAerodromeReference: AerodromeReference?
        let arrivalAerodromeReference: AerodromeReference?
        let frequencyEntries: [FrequencyEntry]
        let frequencyOrderByPhase: FrequencyOrderByPhase
    }

    struct AerodromeReference: Decodable {
        let catalogId: String
        let snapshot: AerodromeSnapshot
    }

    struct AerodromeSnapshot: Decodable {
        let name: String
        let position: Coordinate
        let icao: String?
        let localCode: String?
    }

    struct FrequencyEntry: Decodable {
        let id: String
        let phase: String
        let name: String
        let frequencyMhz: Double
        let replaces: ReplacedFrequency?
    }

    struct ReplacedFrequency: Decodable {
        let name: String
        let role: String?
        let frequencyMhz: Double
    }

    struct FrequencyOrderByPhase: Decodable {
        let departure: [String]
        let enRoute: [String]
        let arrival: [String]

        enum CodingKeys: String, CodingKey {
            case departure
            case enRoute = "en-route"
            case arrival
        }
    }

    struct VORDMEReference: Decodable {
        let id: UUID
        let waypointId: UUID
        let calculation: VORDMECalculation
        let navigationAid: NavigationAid
    }

    struct VORDMECalculation: Decodable {
        let mode: String
        let radialDegrees: Double?
        let distanceNm: Double?
    }

    struct NavigationAid: Decodable {
        let catalogId: String
        let snapshot: NavigationAidSnapshot
    }

    struct NavigationAidSnapshot: Decodable {
        let identifier: String
        let name: String
        let position: Coordinate
    }
}
