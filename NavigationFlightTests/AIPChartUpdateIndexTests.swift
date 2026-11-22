import CryptoKit
import Foundation
import Testing
@testable import NavigationFlight

@Suite("Signed AIP update index")
struct AIPChartUpdateIndexTests {
    private typealias Index = AIPChartUpdateIndex
    private let signer = Curve25519.Signing.PrivateKey()

    @Test("The published envelope verifies with the shipped public key")
    func publishedEnvelope() throws {
        let bytes = Data(Self.publishedFixture.utf8)
        let index = try Index.verify(bytes)
        let offer = try #require(index.offer(after: 0))
        #expect(index.generation == 1)
        #expect(offer.pin == ChartSnapshotPin(
            releaseId: "domestic-aip-01-2026", sequence: 1,
            manifestSha256: "f147632710deaaffa62039c045d112f0574f657dccabc421a497b5caa04336cf"
        ))
        #expect(offer.totalPdfBytes == 32_536_962)
        #expect(index.offer(after: offer.sequence) == nil)
    }

    @Test("The highest compatible sequence wins independently of order")
    func highestCompatibleOffer() throws {
        let index = try verify(envelope(releases: [offer(2), offer(9, schema: 3), offer(5), offer(4)]))
        #expect(index.offer(after: 1)?.sequence == 5)
        #expect(index.offer(after: 5) == nil)
        #expect(index.offer(after: 5, supportedManifestSchemas: [2, 3])?.sequence == 9)
    }

    @Test("Exact repeats pass, stale or conflicting generations fail, and newer retractions pass")
    func generations() throws {
        let bytes = try envelope(generation: 3, releases: [offer(2)])
        let previous = try verify(bytes)
        #expect(try verify(bytes, after: previous).offer(after: 1)?.sequence == 2)
        #expect(throws: Index.VerificationError.staleGeneration) {
            try verify(envelope(generation: 2, releases: [offer(4)]), after: previous)
        }
        #expect(throws: Index.VerificationError.staleGeneration) {
            try verify(envelope(generation: 3, releases: [offer(4)]), after: previous)
        }
        let retraction = try verify(envelope(generation: 4, releases: []), after: previous)
        #expect(retraction.offer(after: 1) == nil)
    }

    @Test("A changed payload and an untrusted key fail signature verification")
    func authentication() throws {
        let bytes = try envelope(releases: [offer(2)])
        var changed = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: String])
        changed["payload"] = Data("{}".utf8).base64EncodedString()
        #expect(throws: Index.VerificationError.invalidSignature) {
            try verify(JSONSerialization.data(withJSONObject: changed))
        }
        #expect(throws: Index.VerificationError.invalidSignature) {
            try Index.verify(bytes)
        }
    }

    @Test("Wrong key IDs, noncanonical base64, and oversized envelopes are rejected")
    func envelopeValidation() throws {
        let bytes = try envelope(releases: [offer(2)])
        var changed = try #require(JSONSerialization.jsonObject(with: bytes) as? [String: String])
        changed["keyId"] = "untrusted"
        #expect(throws: Index.VerificationError.invalidEnvelope) {
            try verify(JSONSerialization.data(withJSONObject: changed))
        }
        changed["keyId"] = Index.keyID
        changed["signature"] = " " + (changed["signature"] ?? "")
        #expect(throws: Index.VerificationError.invalidEnvelope) {
            try verify(JSONSerialization.data(withJSONObject: changed))
        }
        #expect(throws: Index.VerificationError.invalidEnvelope) {
            try verify(Data(repeating: 32, count: Index.maximumBytes + 1))
        }
    }

    @Test("Signed descriptors still require unique identities and exact release URLs")
    func descriptorValidation() throws {
        let duplicateIDs = [offer(2), offer(3, id: "edition-2")]
        let duplicateSequences = [offer(2), offer(2, id: "another-edition")]
        var otherHost = offer(4)
        otherHost["manifestUrl"] = "https://example.invalid/releases/edition-4/manifest.json"
        var invalidDate = offer(4)
        invalidDate["effectiveDate"] = "2026-02-30"
        var unsafeBytes = offer(4)
        unsafeBytes["totalPdfBytes"] = 512 * 1024 * 1024 + 1
        for releases in [duplicateIDs, duplicateSequences, [otherHost], [invalidDate], [unsafeBytes]] {
            #expect(throws: Index.VerificationError.invalidPayload) {
                try verify(envelope(releases: releases))
            }
        }
    }

    private func verify(_ bytes: Data, after previous: Index.Verified? = nil) throws -> Index.Verified {
        try Index.verify(bytes, after: previous, publicKey: signer.publicKey.rawRepresentation)
    }

    private func offer(_ sequence: Int, id: String? = nil, schema: Int = 2) -> [String: Any] {
        let id = id ?? "edition-\(sequence)"
        return [
            "sequence": sequence, "releaseId": id, "amendment": "0\(sequence)-2026",
            "effectiveDate": "2026-08-06", "manifestSchemaVersion": schema,
            "manifestUrl": "https://github.com/johnbenz13/fplnav-downloads/releases/download/\(id)/manifest.json",
            "manifestSha256": String(repeating: "a", count: 64), "totalPdfBytes": 1024,
        ]
    }

    private func envelope(generation: Int = 1, releases: [[String: Any]]) throws -> Data {
        let payload = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "dataset": "aip-charts", "generation": generation, "releases": releases,
        ], options: .sortedKeys)
        return try JSONSerialization.data(withJSONObject: [
            "keyId": Index.keyID,
            "payload": payload.base64EncodedString(),
            "signature": signer.signature(for: payload).base64EncodedString(),
        ], options: .sortedKeys)
    }

    // This envelope was retrieved anonymously from the public v1 index.
    private static let publishedFixture = """
    {
      "keyId" : "aip-index-ed25519-v1",
      "payload" : "ewogICJkYXRhc2V0IjogImFpcC1jaGFydHMiLAogICJnZW5lcmF0aW9uIjogMSwKICAicmVsZWFzZXMiOiBbCiAgICB7CiAgICAgICJhbWVuZG1lbnQiOiAiMDEtMjAyNiIsCiAgICAgICJlZmZlY3RpdmVEYXRlIjogIjIwMjYtMDgtMDYiLAogICAgICAibWFuaWZlc3RTY2hlbWFWZXJzaW9uIjogMiwKICAgICAgIm1hbmlmZXN0U2hhMjU2IjogImYxNDc2MzI3MTBkZWFhZmZhNjIwMzljMDQ1ZDExMmYwNTc0ZjY1N2RjY2FiYzQyMWE0OTdiNWNhYTA0MzM2Y2YiLAogICAgICAibWFuaWZlc3RVcmwiOiAiaHR0cHM6Ly9naXRodWIuY29tL2pvaG5iZW56MTMvZnBsbmF2LWRvd25sb2Fkcy9yZWxlYXNlcy9kb3dubG9hZC9kb21lc3RpYy1haXAtMDEtMjAyNi9tYW5pZmVzdC5qc29uIiwKICAgICAgInJlbGVhc2VJZCI6ICJkb21lc3RpYy1haXAtMDEtMjAyNiIsCiAgICAgICJzZXF1ZW5jZSI6IDEsCiAgICAgICJ0b3RhbFBkZkJ5dGVzIjogMzI1MzY5NjIKICAgIH0KICBdLAogICJzY2hlbWFWZXJzaW9uIjogMQp9Cg==",
      "signature" : "cQ7YcO80Hi96Zg/liFFUIxQ04xM2r6dinEEhgcvKXJpLScdcmzWFuDAbmPtkVJNTaWB/uY5xtWR8xOTqDU5gBQ=="
    }
    """
}
