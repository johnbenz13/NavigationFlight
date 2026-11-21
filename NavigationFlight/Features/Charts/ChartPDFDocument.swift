import CryptoKit
import PDFKit

@MainActor
enum ChartPDFDocument {
    static func open(
        _ chart: ChartCatalog.Chart,
        in catalog: ChartCatalog,
        resources: ChartResources
    ) throws -> PDFDocument {
        guard !chart.pages.isEmpty else {
            throw ChartResourceError.invalidAsset
        }

        var sources: [String: PDFDocument] = [:]
        let projection = PDFDocument()
        for reference in chart.pages {
            let source: PDFDocument
            if let existing = sources[reference.assetSha256] {
                source = existing
            } else {
                let matches = catalog.artifacts.filter { $0.sha256 == reference.assetSha256 }
                guard matches.count == 1, let asset = matches.first else {
                    throw ChartResourceError.invalidAsset
                }
                source = try openAsset(asset, chartID: chart.id, resources: resources)
                sources[reference.assetSha256] = source
            }

            guard reference.index >= 0, reference.index < source.pageCount,
                  let original = source.page(at: reference.index),
                  matchesGeometry(original, reference: reference),
                  let selectedPage = original.copy() as? PDFPage,
                  matchesGeometry(selectedPage, reference: reference) else {
                throw ChartResourceError.unavailablePage
            }
            // Navigation actions in the original may point outside the selected chart.
            for annotation in selectedPage.annotations
                where annotation.type == "Link" || annotation.action != nil {
                selectedPage.removeAnnotation(annotation)
            }
            projection.insert(selectedPage, at: projection.pageCount)
        }
        return projection
    }

    private static func openAsset(
        _ asset: ChartCatalog.Asset,
        chartID: String,
        resources: ChartResources
    ) throws -> PDFDocument {
        let data = try resources.assetData(for: asset, chartID: chartID)
        guard data.count == asset.bytes,
              SHA256.hash(data: data).map({ String(format: "%02x", $0) }).joined() == asset.sha256,
              let pdf = PDFDocument(data: data), !pdf.isLocked, pdf.pageCount == asset.pageCount else {
            throw ChartResourceError.invalidAsset
        }
        return pdf
    }

    private static func matchesGeometry(_ page: PDFPage, reference: ChartCatalog.Chart.Page) -> Bool {
        func matches(_ rect: CGRect, _ box: [Double]) -> Bool {
            let coordinates = [rect.minX, rect.minY, rect.maxX, rect.maxY]
            // The shared index records the source coordinates to two decimal places.
            return box.count == coordinates.count
                && zip(box, coordinates).allSatisfy { abs($0 - $1) < 0.02 }
        }

        return matches(page.bounds(for: .mediaBox), reference.mediaBox)
            && matches(page.bounds(for: .cropBox), reference.cropBox)
            && page.rotation == reference.rotation
    }
}
