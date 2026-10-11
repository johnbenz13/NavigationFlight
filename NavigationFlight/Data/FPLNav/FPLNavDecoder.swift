import Foundation

enum FPLNavDecoderError: Error, Equatable, Sendable {
    case invalidMetadata
    case unsupportedFormatVersion(Int)
    case invalidV5Document(String)
    case invalidV7Document(String)
    case invalidV7Execution(FPLNavV7ValidationError)
    case mapping(FPLNavMappingError)
}

struct FPLNavDecoder: Sendable {
    private struct Metadata: Decodable {
        let formatVersion: Int
    }

    func decode(_ data: Data) throws -> NavigationFlight {
        let decoder = Self.makeJSONDecoder()
        let metadata: Metadata

        do {
            metadata = try decoder.decode(Metadata.self, from: data)
        } catch {
            throw FPLNavDecoderError.invalidMetadata
        }

        switch metadata.formatVersion {
        case 5:
            do {
            let document = try decoder.decode(FPLNavV5DTO.self, from: data)
            return try FPLNavV5Mapper().map(document)
            } catch let error as FPLNavMappingError {
                throw FPLNavDecoderError.mapping(error)
            } catch {
                throw FPLNavDecoderError.invalidV5Document(String(describing: error))
            }
        case 7:
            do {
                try validateStrictExecutionObjects(in: data)
                return try FPLNavV7Mapper().map(decoder.decode(FPLNavV7DTO.self, from: data))
            } catch let error as FPLNavV7ValidationError {
                throw FPLNavDecoderError.invalidV7Execution(error)
            } catch let error as FPLNavMappingError {
                throw FPLNavDecoderError.mapping(error)
            } catch let error as FPLNavDecoderError {
                throw error
            } catch {
                throw FPLNavDecoderError.invalidV7Document(String(describing: error))
            }
        default:
            throw FPLNavDecoderError.unsupportedFormatVersion(metadata.formatVersion)
        }
    }

    private static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func validateStrictExecutionObjects(in data: Data) throws {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let execution = root["execution"] as? [String: Any] else {
            throw FPLNavDecoderError.invalidV7Document("Missing execution object")
        }
        try keys(execution, allowed: ["calculationVersion", "altitudeReference", "legs", "annotations", "vorDmeReferences", "frequenciesByPhase"], path: "execution")
        for (index, value) in (execution["legs"] as? [[String: Any]] ?? []).enumerated() {
            try keys(value, allowed: ["legId", "trueCourseDegrees", "magneticCourseDegrees", "distanceNauticalMiles", "initialAltitudeFeetMsl", "noWind", "withWind"], path: "execution.legs[\(index)]")
            if let timing = value["noWind"] as? [String: Any] { try keys(timing, allowed: ["plannedDurationSeconds", "plannedGroundSpeedKnots"], path: "execution.legs[\(index)].noWind") }
            if let wind = value["withWind"] as? [String: Any] {
                try keys(wind, allowed: ["plannedDurationSeconds", "plannedGroundSpeedKnots", "effectiveWind", "trueHeadingDegrees", "magneticHeadingDegrees", "windCorrectionDegrees"], path: "execution.legs[\(index)].withWind")
                if let effective = wind["effectiveWind"] as? [String: Any] { try keys(effective, allowed: ["directionFromTrueDegrees", "speedKnots"], path: "execution.legs[\(index)].withWind.effectiveWind") }
            }
        }
        for (index, value) in (execution["annotations"] as? [[String: Any]] ?? []).enumerated() {
            try keys(value, allowed: ["entityId", "kind", "legId", "position", "noWindTimeFromLegStartSeconds", "withWindTimeFromLegStartSeconds"], path: "execution.annotations[\(index)]")
            if let position = value["position"] as? [String: Any] { try keys(position, allowed: ["latitude", "longitude"], path: "execution.annotations[\(index)].position") }
        }
        for (index, value) in (execution["vorDmeReferences"] as? [[String: Any]] ?? []).enumerated() {
            try keys(value, allowed: ["referenceId", "frequencyMhz", "stationElevationFeetMsl", "magneticRadialFromDegrees", "slantRangeNauticalMiles", "source"], path: "execution.vorDmeReferences[\(index)]")
        }
        if let phases = execution["frequenciesByPhase"] as? [String: Any] {
            try keys(phases, allowed: ["departure", "en-route", "arrival"], path: "execution.frequenciesByPhase")
            for phase in ["departure", "en-route", "arrival"] {
                for (index, value) in (phases[phase] as? [[String: Any]] ?? []).enumerated() {
                    try keys(value, allowed: ["id", "name", "role", "frequencyMhz", "source"], path: "execution.frequenciesByPhase.\(phase)[\(index)]")
                }
            }
        }
    }

    private func keys(_ object: [String: Any], allowed: Set<String>, path: String) throws {
        if let unknown = object.keys.first(where: { !allowed.contains($0) }) {
            throw FPLNavDecoderError.invalidV7Execution(.init(path: path + "." + unknown, reason: "unknown property in strict execution object"))
        }
    }
}
