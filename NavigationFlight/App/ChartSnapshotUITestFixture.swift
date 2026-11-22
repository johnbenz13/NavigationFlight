#if DEBUG && targetEnvironment(simulator)
import UIKit

/// The UI test installs these PDFs through the same store used by the app.
enum ChartSnapshotUITestFixture {
    static var isEnabled: Bool {
        let environment = ProcessInfo.processInfo.environment
        return environment["NAVIGATION_FLIGHT_UI_TEST_CHART_EDITIONS"] == "1"
            && environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] != nil
    }

    static var blocksNetwork: Bool {
        ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_CHART_OFFLINE"] == "1"
    }

    static func verifyNetworkIsBlocked() async throws {
        do {
            _ = try await URLSession.shared.data(from: URL(string: "https://example.invalid/verify-chart-isolation")!)
        } catch let error as NSError where error.domain == ChartUITestOfflineProtocol.errorDomain {
            return
        }
        throw URLError(.cannotParseResponse)
    }

    static func install(_ edition: String, in store: ChartSnapshotStore) async throws {
        let fixture = try stage(edition)
        defer { try? FileManager.default.removeItem(at: fixture.resources.bundleRoot) }
        try await store.install(from: fixture.resources, pin: fixture.pin)
    }

    static func stage(_ edition: String, amendment: String? = nil) throws -> (resources: ChartResources, pin: ChartSnapshotPin) {
        let isFirst = edition == "A"
        let releaseID = "ui-fixture-\(edition.lowercased())"
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let charts = root.appending(path: "AIPCharts", directoryHint: .isDirectory)
        let pdfs = charts.appending(path: "pdf", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: pdfs, withIntermediateDirectories: true)
        let entries = isFirst ? ["fixture-field", "retired-field"] : ["fixture-field"]
        var aerodromes: [[String: Any]] = []
        var assets: [[String: Any]] = []
        let bounds = CGRect(x: 0, y: 0, width: 300, height: 400)
        let box = [0, 0, 300, 400]
        for field in entries {
            let id = "\(field)-chart"
            let title = "Edition \(edition) · \(field == "fixture-field" ? "Test circuit" : "Retired chart")"
            let pdf = UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
                context.beginPage()
                (isFirst ? UIColor.systemBlue : UIColor.systemOrange).setFill()
                context.cgContext.fill(bounds)
                let font = UIFont.boldSystemFont(ofSize: 17)
                (title as NSString).draw(at: CGPoint(x: 18, y: 30), withAttributes: [
                    .font: font, .foregroundColor: UIColor.white,
                ])
            }
            let sha256 = ChartSnapshotVerification.digest(pdf)
            try pdf.write(to: pdfs.appending(path: "\(id).pdf"))
            assets.append([
                "id": id, "file": "artifacts/\(id).pdf", "consumer": "shared", "representation": "pdf",
                "destination": "AIPCharts/pdf/\(id).pdf", "bytes": pdf.count, "sha256": sha256, "pageCount": 1,
            ])
            aerodromes.append([
                "id": field, "name": field == "fixture-field" ? "Fixture Field" : "Retired Field",
                "group": field == "fixture-field" ? "airports" : "airfields",
                "identifiers": [["namespace": "catalog", "value": field]],
                "charts": [[
                    "id": id, "title": title, "roles": ["circuit"], "sourceUrl": "https://example.invalid/fixture.pdf",
                    "edition": ["amendment": "Fixture \(edition)"],
                    "pages": [["assetSha256": sha256, "index": 0, "mediaBox": box, "cropBox": box,
                               "rotation": 0, "publishedLabel": edition]],
                ]],
            ])
        }
        let data = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 2, "releaseId": releaseID,
            "snapshot": ["amendment": amendment ?? edition, "effectiveDate": "2026-11-22"],
            "aerodromes": aerodromes, "artifacts": assets,
        ], options: .sortedKeys)
        try data.write(to: charts.appending(path: "index.json"))
        let bundledPin = ChartResources.bundled.bundleRoot.appending(path: "aip-charts-pin.json")
        let seed = try JSONDecoder().decode(ChartSnapshotPin.self, from: Data(contentsOf: bundledPin))
        let pin = ChartSnapshotPin(
            releaseId: releaseID,
            sequence: seed.sequence + (isFirst ? 1 : 2),
            manifestSha256: ChartSnapshotVerification.digest(data)
        )
        return (ChartResources(bundleRoot: root), pin)
    }
}

final class ChartUITestOfflineProtocol: URLProtocol, @unchecked Sendable {
    nonisolated static let errorDomain = "ChartUITestOfflineProtocol"

    nonisolated override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "http" || request.url?.scheme == "https"
    }

    nonisolated override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    nonisolated override func startLoading() {
        client?.urlProtocol(self, didFailWithError: NSError(domain: Self.errorDomain, code: 1))
    }

    nonisolated override func stopLoading() {}
}
#endif
