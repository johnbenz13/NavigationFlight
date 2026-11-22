#if DEBUG && targetEnvironment(simulator)
import CryptoKit
import Foundation

enum AIPChartDownloadFixture {
    static func service() -> AIPChartDownloadService? {
        let env = ProcessInfo.processInfo.environment
        guard env["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] != nil,
              let mode = env["NAVIGATION_FLIGHT_UI_TEST_DOWNLOADS"] else { return nil }
        return makeService(mode: mode, assetDelay: mode == "held" ? .seconds(14) : .seconds(5))
    }

    static func makeService(mode: String, assetDelay: Duration = .seconds(5)) -> AIPChartDownloadService {
        do {
            let fixture = try ChartSnapshotUITestFixture.stage("B", amendment: "02-2026")
            let resources = fixture.resources
            defer { try? FileManager.default.removeItem(at: resources.bundleRoot) }

            let manifest = try Data(contentsOf: resources.bundleRoot.appending(path: "AIPCharts/index.json"))
            let catalog = try resources.loadCatalog()
            let pdfs = try Dictionary(uniqueKeysWithValues: catalog.artifacts.map { asset in
                guard let id = asset.id else { throw AIPChartDownloadService.Failure.verification }
                return ("artifact-\(id)", try Data(contentsOf: resources.assetURL(for: asset)))
            })
            let offer: [String: Any] = [
                "sequence": fixture.pin.sequence, "releaseId": fixture.pin.releaseId,
                "amendment": catalog.snapshot.amendment, "effectiveDate": catalog.snapshot.effectiveDate,
                "manifestSchemaVersion": 2, "manifestSha256": fixture.pin.manifestSha256,
                "manifestUrl": "https://github.com/johnbenz13/fplnav-downloads/releases/download/\(fixture.pin.releaseId)/manifest.json",
                "totalPdfBytes": pdfs.values.reduce(0) { $0 + $1.count },
            ]
            let payload = try JSONSerialization.data(withJSONObject: [
                "schemaVersion": 1, "dataset": "aip-charts", "generation": mode == "retracted" ? 2 : 1,
                "releases": mode == "current" || mode == "retracted" ? [] : [offer],
            ], options: .sortedKeys)
            let signer = try Curve25519.Signing.PrivateKey(rawRepresentation: Data(repeating: 29, count: 32))
            let index = try JSONSerialization.data(withJSONObject: [
                "keyId": AIPChartUpdateIndex.keyID, "payload": payload.base64EncodedString(),
                "signature": signer.signature(for: payload).base64EncodedString(),
            ])
            let transport = FixtureTransport(mode: mode, index: index, manifest: manifest, pdfs: pdfs, assetDelay: assetDelay)
            return AIPChartDownloadService(publicKey: signer.publicKey.rawRepresentation) { url, limit, progress in
                try await transport.read(url, limit, progress)
            }
        } catch {
            preconditionFailure("Could not build the Downloads fixture: \(error)")
        }
    }

    private actor FixtureTransport {
        let mode: String
        let index: Data
        let manifest: Data
        let pdfs: [String: Data]
        let assetDelay: Duration
        var hasFailedVerification = false

        init(mode: String, index: Data, manifest: Data, pdfs: [String: Data], assetDelay: Duration) {
            self.mode = mode
            self.index = index
            self.manifest = manifest
            self.pdfs = pdfs
            self.assetDelay = assetDelay
        }

        func read(_ url: URL, _ limit: Int, _ progress: AIPChartDownloadService.Progress) async throws -> Data {
            if mode == "offline" { throw URLError(.notConnectedToInternet) }
            if url == AIPChartUpdateIndex.endpoint {
                if mode == "held" { try await Task.sleep(for: .seconds(7)) }
                return index
            }
            if url.lastPathComponent == "manifest.json" { return manifest }
            guard let pdf = pdfs[url.lastPathComponent], pdf.count <= limit else { throw URLError(.fileDoesNotExist) }
            await progress(pdf.count * 40 / 100)
            try await Task.sleep(for: assetDelay)
            if mode == "transfer-failure", !hasFailedVerification {
                hasFailedVerification = true
                throw URLError(.networkConnectionLost)
            }
            if mode == "verification-failure", !hasFailedVerification {
                hasFailedVerification = true
                return Data(repeating: 0, count: pdf.count)
            }
            return pdf
        }
    }
}
#endif
