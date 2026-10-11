import Foundation

struct FPLNavV7DTO: Decodable {
    let format: String
    let formatVersion: Int
    let project: FPLNavV5DTO.Project
    let navigation: Navigation
    let execution: Execution

    struct Navigation: Decodable {
        let parameters: FPLNavV5DTO.Parameters
        let route: FPLNavV5DTO.Route
        let identificationPoints: [FPLNavV5DTO.IdentificationPoint]
        let altitudeChanges: [FPLNavV5DTO.AltitudeChange]
        let radioFrequencyChanges: [FPLNavV5DTO.RadioFrequencyChange]
        let presentation: Presentation
        let operationalContext: FPLNavV5DTO.OperationalContext
        let vorDmeReferences: [FPLNavV5DTO.VORDMEReference]
    }

    struct Presentation: Decodable {
        let navigationLog: NavigationLog
    }

    struct NavigationLog: Decodable {
        let windEnabled: Bool
    }

    struct Execution: Decodable {
        let calculationVersion: String
        let altitudeReference: String
        let legs: [Leg]
        let annotations: [Annotation]
        let vorDmeReferences: [VORDME]
        let frequenciesByPhase: FrequenciesByPhase
    }

    struct Leg: Decodable {
        let legId: UUID
        let trueCourseDegrees: Double
        let magneticCourseDegrees: Double
        let distanceNauticalMiles: Double
        let initialAltitudeFeetMsl: Double
        let noWind: Timing
        let withWind: WindSolution?
    }

    struct Timing: Decodable {
        let plannedDurationSeconds: Int
        let plannedGroundSpeedKnots: Double
    }

    struct WindSolution: Decodable {
        let plannedDurationSeconds: Int
        let plannedGroundSpeedKnots: Double
        let effectiveWind: FPLNavV5DTO.Wind
        let trueHeadingDegrees: Double
        let magneticHeadingDegrees: Double
        let windCorrectionDegrees: Double
    }

    struct Annotation: Decodable {
        let entityId: UUID
        let kind: String
        let legId: UUID
        let position: FPLNavV5DTO.Coordinate
        let noWindTimeFromLegStartSeconds: Int
        let withWindTimeFromLegStartSeconds: Int?
    }

    struct VORDME: Decodable {
        let referenceId: UUID
        let frequencyMhz: Double
        let stationElevationFeetMsl: Double?
        let magneticRadialFromDegrees: Double
        let slantRangeNauticalMiles: Double
        let source: String
    }

    struct FrequenciesByPhase: Decodable {
        let departure: [Frequency]
        let enRoute: [Frequency]
        let arrival: [Frequency]

        enum CodingKeys: String, CodingKey {
            case departure
            case enRoute = "en-route"
            case arrival
        }
    }

    struct Frequency: Decodable {
        let id: String
        let name: String
        let role: String?
        let frequencyMhz: Double
        let source: String
    }
}
