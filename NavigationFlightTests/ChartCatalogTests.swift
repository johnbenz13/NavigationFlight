import CryptoKit
import PDFKit
import Testing
import UIKit
@testable import NavigationFlight

@MainActor
@Suite("Bundled AIP charts")
struct ChartCatalogTests {
    @Test("The bundled catalog preserves the published groups, order and source page identity")
    func publishedSnapshot() throws {
        let catalog = try ChartResources.bundled.loadCatalog()
        #expect(catalog.releaseId == "domestic-aip-01-2026")
        #expect(catalog.snapshot.amendment == "01-2026")
        #expect(catalog.aerodromes(in: .airports).map(\.code) == ["LLHZ", "LLHA", "LLIB"])
        #expect(catalog.aerodromes(in: .airfields).map(\.code) == [
            "LLBS", "LLBO", "LLMG", "LLMZ", "LLEY", "LLES", "LLFK", "LLKZ", "LLKS", "LLRS",
        ])
        #expect(catalog.aerodromes.flatMap(\.charts).count == 65)
        let chart = try #require(catalog.selection(for: "aip-llhz-chart-11")?.chart)
        #expect(chart.title.contains("תרשים ההקפה"))
        #expect(chart.pages.map(\.publishedLabel) == ["נספח י״ב"])
        #expect(chart.pages.map(\.index) == [0])
        #expect(chart.sourceUrl.host() == "www.gov.il")
    }

    @Test("Every published chart loads and the official Herzliya page preserves the original rendering")
    func openPublishedCharts() throws {
        let resources = ChartResources.bundled
        let catalog = try resources.loadCatalog()
        for chart in catalog.aerodromes.flatMap(\.charts) {
            let actual = try ChartPDFDocument.open(chart, in: catalog, resources: resources)
            #expect(actual.pageCount == chart.pages.count, "\(chart.id)")
        }

        let chart = try #require(catalog.selection(for: "aip-llhz-chart-11")?.chart)
        let asset = try #require(catalog.artifacts.first { $0.sha256 == chart.pages[0].assetSha256 })
        let data = try resources.assetData(for: asset, chartID: chart.id)
        let original = try #require(PDFDocument(data: data))
        let rendered = try ChartPDFDocument.open(chart, in: catalog, resources: resources)
        let originalPage = try #require(original.page(at: 0))
        let renderedPage = try #require(rendered.page(at: 0))
        #expect(renderedPage.bounds(for: .mediaBox) == originalPage.bounds(for: .mediaBox))
        #expect(renderedPage.bounds(for: .cropBox) == originalPage.bounds(for: .cropBox))
        let size = CGSize(width: 480, height: 680)
        #expect(try #require(renderedPage.thumbnail(of: size, for: .cropBox).pngData())
                == #require(originalPage.thumbnail(of: size, for: .cropBox).pngData()))
    }

    @Test("A selected rotated subset keeps published order and cannot jump to the neighboring page")
    func selectedRotatedPages() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.resources.bundleRoot) }
        let catalog = try fixture.resources.loadCatalog()
        let chart = try #require(catalog.selection(for: "fixture-chart")?.chart)
        let document = try ChartPDFDocument.open(chart, in: catalog, resources: fixture.resources)
        let original = try #require(PDFDocument(data: fixture.bytes))

        #expect(document.pageCount == 2)
        #expect(document.outlineRoot == nil)
        #expect(document.page(at: 2) == nil)
        #expect(document.string?.contains("UNRELATED") == false)
        #expect(document.page(at: 0)?.string?.contains("SECOND SELECTED") == true)
        #expect(document.page(at: 1)?.string?.contains("FIRST SELECTED") == true)
        let actual = try #require(document.page(at: 1))
        let rotated = try #require(original.page(at: 0))
        #expect(actual.rotation == 90)
        #expect(actual.bounds(for: .cropBox) == rotated.bounds(for: .cropBox))
        #expect(actual.bounds(for: .mediaBox) == rotated.bounds(for: .mediaBox))
        #expect(actual.annotations.isEmpty)
        let size = CGSize(width: 300, height: 300)
        #expect(try #require(actual.thumbnail(of: size, for: .cropBox).pngData())
                == #require(rotated.thumbnail(of: size, for: .cropBox).pngData()))
        let view = PDFView()
        view.document = document
        view.goToLastPage(nil)
        #expect(view.currentPage === actual)
        #expect(!view.canGoToNextPage)
    }

    @Test("A missing index, invalid page, and unreadable asset fail without replacing unrelated charts")
    func errorsAreScoped() throws {
        let fixture = try makeFixture()
        defer { try? FileManager.default.removeItem(at: fixture.resources.bundleRoot) }
        let catalog = try fixture.resources.loadCatalog()
        let invalid = try #require(catalog.selection(for: "invalid-page")?.chart)
        #expect(throws: ChartResourceError.unavailablePage) {
            try ChartPDFDocument.open(invalid, in: catalog, resources: fixture.resources)
        }
        let available = try #require(catalog.selection(for: "fixture-chart")?.chart)
        let corrupt = try #require(catalog.selection(for: "corrupt-chart")?.chart)
        #expect(throws: ChartResourceError.invalidAsset) {
            try ChartPDFDocument.open(corrupt, in: catalog, resources: fixture.resources)
        }
        #expect(try ChartPDFDocument.open(available, in: catalog, resources: fixture.resources).pageCount == 2)
        try FileManager.default.removeItem(at: fixture.resources.bundleRoot.appending(path: "AIPCharts/index.json"))
        #expect(throws: (any Error).self) { try fixture.resources.loadCatalog() }
    }

    private func makeFixture() throws -> (resources: ChartResources, bytes: Data) {
        let size = CGRect(x: 0, y: 0, width: 240, height: 360)
        let initial = UIGraphicsPDFRenderer(bounds: size).pdfData { context in
            for text in ["FIRST SELECTED", "UNRELATED", "SECOND SELECTED"] {
                context.beginPage()
                (text as NSString).draw(at: CGPoint(x: 40, y: 50), withAttributes: [.font: UIFont.systemFont(ofSize: 14)])
            }
        }
        let pdf = try #require(PDFDocument(data: initial))
        let first = try #require(pdf.page(at: 0))
        let second = try #require(pdf.page(at: 1))
        first.rotation = 90
        first.setBounds(CGRect(x: 12, y: 16, width: 210, height: 315), for: .cropBox)
        let link = PDFAnnotation(bounds: CGRect(x: 10, y: 10, width: 15, height: 15), forType: .link, withProperties: nil)
        link.action = PDFActionGoTo(destination: PDFDestination(page: second, at: .zero))
        first.addAnnotation(link)

        let bytes = try #require(pdf.dataRepresentation())
        let stored = try #require(PDFDocument(data: bytes))
        let invalidBytes = Data("Not a PDF".utf8)
        func sha(_ data: Data) -> String {
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
        let hash = sha(bytes)
        let corruptHash = sha(invalidBytes)
        func page(_ index: Int, hash: String) -> [String: Any] {
            let page = stored.page(at: index)
            func coordinates(_ rect: CGRect) -> [CGFloat] { [rect.minX, rect.minY, rect.maxX, rect.maxY] }
            return [
                "index": index, "assetSha256": hash, "publishedLabel": "Fixture page",
                "mediaBox": coordinates(page?.bounds(for: .mediaBox) ?? size),
                "cropBox": coordinates(page?.bounds(for: .cropBox) ?? size),
                "rotation": page?.rotation ?? 0,
            ]
        }
        func chart(_ id: String, _ pages: [[String: Any]]) -> [String: Any] {
            [
                "id": id, "title": id, "sourceUrl": "https://www.gov.il/he/pages/aip",
                "edition": [:], "pages": pages,
            ]
        }
        let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        let folder = root.appending(path: "AIPCharts/pdf")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try bytes.write(to: folder.appending(path: "fixture.pdf"))
        try invalidBytes.write(to: folder.appending(path: "corrupt.pdf"))
        let manifest: [String: Any] = [
            "schemaVersion": 2, "releaseId": "fixture",
            "snapshot": ["amendment": "fixture", "effectiveDate": "2026-01-01"],
            "artifacts": [
                ["destination": "AIPCharts/pdf/fixture.pdf", "sha256": hash, "bytes": bytes.count, "pageCount": 3],
                ["destination": "AIPCharts/pdf/corrupt.pdf", "sha256": corruptHash, "bytes": invalidBytes.count, "pageCount": 1],
            ],
            "aerodromes": [[
                "id": "fixture", "name": "Fixture", "group": "airports", "identifiers": [],
                "charts": [
                    chart("fixture-chart", [page(2, hash: hash), page(0, hash: hash)]),
                    chart("invalid-page", [page(5, hash: hash)]),
                    chart("corrupt-chart", [page(0, hash: corruptHash)]),
                ],
            ]],
        ]
        try JSONSerialization.data(withJSONObject: manifest).write(to: root.appending(path: "AIPCharts/index.json"))
        return (ChartResources(bundleRoot: root), bytes)
    }
}
