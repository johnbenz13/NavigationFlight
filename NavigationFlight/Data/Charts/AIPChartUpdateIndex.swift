import CryptoKit
import Foundation

nonisolated enum AIPChartUpdateIndex {
    static let endpoint = URL(string: "https://raw.githubusercontent.com/johnbenz13/fplnav-downloads/main/v1/aip-charts.json")!
    static let maximumBytes = 64 * 1024
    static let keyID = "aip-index-ed25519-v1"
    static let trustedPublicKey = Data(base64Encoded: "RBnFGBcQK4O8JbdphGMNycF39Wp1KqxwRwzkkQ1BoCo=")!
    private static let releaseBase = "https://github.com/johnbenz13/fplnav-downloads/releases/download/"
    private static let maximumSafeInteger: Int64 = 9_007_199_254_740_991
    private static let maximumPDFBytes = 512 * 1024 * 1024

    enum VerificationError: Error, Equatable {
        case invalidEnvelope
        case invalidSignature
        case invalidPayload
        case staleGeneration
    }

    struct Offer: Decodable, Equatable, Sendable {
        let sequence: Int
        let releaseId: String
        let amendment: String
        let effectiveDate: String
        let manifestSchemaVersion: Int
        let manifestUrl: String
        let manifestSha256: String
        let totalPdfBytes: Int

        var pin: ChartSnapshotPin {
            ChartSnapshotPin(releaseId: releaseId, sequence: sequence, manifestSha256: manifestSha256)
        }
    }

    struct Verified: Sendable {
        let generation: Int
        fileprivate let payloadBytes: Data
        fileprivate let releases: [Offer]

        func offer(after installedSequence: Int, supportedManifestSchemas: Set<Int> = [2]) -> Offer? {
            releases.lazy.filter {
                $0.sequence > installedSequence && supportedManifestSchemas.contains($0.manifestSchemaVersion)
            }.max { $0.sequence < $1.sequence }
        }
    }

    private struct Envelope: Decodable {
        let keyId: String
        let payload: String
        let signature: String
    }

    private struct Payload: Decodable {
        let schemaVersion: Int
        let dataset: String
        let generation: Int
        let releases: [Offer]
    }

    static func verify(
        _ bytes: Data,
        after previous: Verified? = nil,
        publicKey: Data = trustedPublicKey
    ) throws -> Verified {
        let decoder = JSONDecoder()
        guard bytes.count <= maximumBytes, String(data: bytes, encoding: .utf8) != nil,
              let envelope = try? decoder.decode(Envelope.self, from: bytes), envelope.keyId == keyID,
              let payloadBytes = canonicalBase64(envelope.payload),
              let signature = canonicalBase64(envelope.signature), signature.count == 64 else {
            throw VerificationError.invalidEnvelope
        }
        guard let key = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKey),
              key.isValidSignature(signature, for: payloadBytes) else {
            throw VerificationError.invalidSignature
        }
        guard String(data: payloadBytes, encoding: .utf8) != nil,
              let payload = try? decoder.decode(Payload.self, from: payloadBytes),
              payload.schemaVersion == 1, payload.dataset == "aip-charts", isPositiveSafeInteger(payload.generation),
              Set(payload.releases.map(\.releaseId)).count == payload.releases.count,
              Set(payload.releases.map(\.sequence)).count == payload.releases.count,
              payload.releases.allSatisfy(isValidOffer) else {
            throw VerificationError.invalidPayload
        }
        if let previous {
            guard payload.generation > previous.generation
                    || (payload.generation == previous.generation && payloadBytes == previous.payloadBytes) else {
                throw VerificationError.staleGeneration
            }
        }
        return Verified(generation: payload.generation, payloadBytes: payloadBytes, releases: payload.releases)
    }

    private static func canonicalBase64(_ value: String) -> Data? {
        guard let bytes = Data(base64Encoded: value), bytes.base64EncodedString() == value else { return nil }
        return bytes
    }

    private static func isPositiveSafeInteger(_ value: Int) -> Bool {
        value > 0 && Int64(value) <= maximumSafeInteger
    }

    private static func isValidOffer(_ offer: Offer) -> Bool {
        let date = Date.ISO8601FormatStyle().year().month().day().dateSeparator(.dash)
        guard offer.effectiveDate.wholeMatch(of: /[0-9]{4}-[0-9]{2}-[0-9]{2}/) != nil,
              let parsedDate = try? date.parse(offer.effectiveDate), date.format(parsedDate) == offer.effectiveDate else {
            return false
        }
        return offer.pin.isSupported && isPositiveSafeInteger(offer.sequence)
            && offer.releaseId.wholeMatch(of: /[a-z0-9][a-z0-9-]{0,99}/) != nil
            && !offer.amendment.isEmpty && isPositiveSafeInteger(offer.manifestSchemaVersion)
            && (1...maximumPDFBytes).contains(offer.totalPdfBytes)
            && offer.manifestUrl == "\(releaseBase)\(offer.releaseId)/manifest.json"
    }
}
