import Foundation

enum FPLNavDecoderError: Error, Equatable, Sendable {
    case invalidMetadata
    case unsupportedFormatVersion(Int)
    case invalidV5Document(String)
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

        guard metadata.formatVersion == 5 else {
            throw FPLNavDecoderError.unsupportedFormatVersion(metadata.formatVersion)
        }

        do {
            let document = try decoder.decode(FPLNavV5DTO.self, from: data)
            return try FPLNavV5Mapper().map(document)
        } catch let error as FPLNavMappingError {
            throw FPLNavDecoderError.mapping(error)
        } catch {
            throw FPLNavDecoderError.invalidV5Document(String(describing: error))
        }
    }

    private static func makeJSONDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
