import CoreGraphics
import CryptoKit
import Foundation

nonisolated enum ChartSnapshotVerification {
    private static let maximumIndexBytes = 1024 * 1024
    private static let maximumPDFBytes = 128 * 1024 * 1024
    private static let maximumSnapshotBytes = 512 * 1024 * 1024

    static func inspect(_ resources: ChartResources, pin: ChartSnapshotPin) throws -> ChartSnapshot {
        guard pin.isSupported else { throw ChartSnapshotStoreError.invalidPin }
        let root = resources.bundleRoot.appending(path: "AIPCharts", directoryHint: .isDirectory)
        let pdfs = root.appending(path: "pdf", directoryHint: .isDirectory)
        let index = root.appending(path: "index.json")
        try requireDirectory(resources.bundleRoot)
        guard try directoryNames(root) == ["index.json", "pdf"],
              try fileSize(index) <= maximumIndexBytes else {
            throw ChartSnapshotStoreError.invalidInventory
        }
        let data = try Data(contentsOf: index, options: .mappedIfSafe)
        guard data.count <= maximumIndexBytes, digest(data) == pin.manifestSha256 else {
            throw ChartSnapshotStoreError.invalidManifest
        }
        let catalog = try ChartResources.decodeCatalog(data)
        guard catalog.releaseId == pin.releaseId else { throw ChartSnapshotStoreError.invalidManifest }

        let files = try validateAssets(catalog.artifacts, resources: resources)
        guard try directoryNames(pdfs) == Set(files.map(\.lastPathComponent)) else {
            throw ChartSnapshotStoreError.invalidInventory
        }
        try validateReferences(catalog)
        return ChartSnapshot(pin: pin, catalog: catalog, resources: resources)
    }

    static func verifyPDFs(in snapshot: ChartSnapshot) throws {
        let references = Dictionary(
            grouping: snapshot.catalog.aerodromes.flatMap(\.charts).flatMap(\.pages),
            by: \.assetSha256
        )
        for asset in snapshot.catalog.artifacts {
            try Task.checkCancellation()
            let url = try snapshot.resources.assetURL(for: asset)
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count == asset.bytes, digest(data) == asset.sha256,
                  let provider = CGDataProvider(data: data as CFData),
                  let pdf = CGPDFDocument(provider), pdf.isUnlocked,
                  pdf.numberOfPages == asset.pageCount,
                  references[asset.sha256]?.allSatisfy({ pdf.page(at: $0.index + 1) != nil }) == true else {
                throw ChartSnapshotStoreError.invalidPDF
            }
        }
    }

    static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func directoryNames(_ directory: URL) throws -> Set<String> {
        try requireDirectory(directory)
        return Set(try FileManager.default.contentsOfDirectory(atPath: directory.path))
    }

    private static func requireDirectory(_ directory: URL) throws {
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink == false else {
            throw ChartSnapshotStoreError.invalidInventory
        }
    }

    private static func fileSize(_ file: URL) throws -> Int {
        let values = try file.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink == false, let size = values.fileSize else {
            throw ChartSnapshotStoreError.invalidInventory
        }
        return size
    }

    private static func validateAssets(
        _ assets: [ChartCatalog.Asset],
        resources: ChartResources
    ) throws -> [URL] {
        guard assets.count <= 256 else { throw ChartSnapshotStoreError.invalidInventory }
        var ids = Set<String>()
        var sourceFiles = Set<String>()
        var destinations = Set<String>()
        var checksums = Set<String>()
        var total = 0
        return try assets.map { asset in
            guard let id = asset.id, isID(id), ids.insert(id).inserted,
                  let file = asset.file, file.wholeMatch(of: /artifacts\/[a-z0-9_-]+\.pdf/) != nil,
                  sourceFiles.insert(file).inserted, destinations.insert(asset.destination).inserted,
                  asset.representation == "pdf", asset.consumer == "shared",
                  asset.sha256.wholeMatch(of: /[0-9a-f]{64}/) != nil, checksums.insert(asset.sha256).inserted,
                  (1...maximumPDFBytes).contains(asset.bytes), asset.pageCount > 0 else {
                throw ChartSnapshotStoreError.invalidManifest
            }
            total += asset.bytes
            let url = try resources.assetURL(for: asset)
            guard total <= maximumSnapshotBytes, try fileSize(url) == asset.bytes else {
                throw ChartSnapshotStoreError.invalidInventory
            }
            return url
        }
    }

    private static func validateReferences(_ catalog: ChartCatalog) throws {
        let assets = Dictionary(uniqueKeysWithValues: catalog.artifacts.map { ($0.sha256, $0) })
        var identifiers = Set<String>()
        var referenced = Set<String>()
        for aerodrome in catalog.aerodromes {
            guard isID(aerodrome.id), !aerodrome.name.isEmpty,
                  aerodrome.identifiers.contains(where: { $0.namespace == "catalog" && $0.value == aerodrome.id }) else {
                throw ChartSnapshotStoreError.invalidManifest
            }
            for identifier in aerodrome.identifiers {
                guard ["catalog", "icao", "local"].contains(identifier.namespace),
                      identifier.value.wholeMatch(of: /[a-zA-Z0-9][a-zA-Z0-9_-]{0,63}/) != nil,
                      identifiers.insert("\(identifier.namespace):\(identifier.value.lowercased())").inserted else {
                    throw ChartSnapshotStoreError.invalidManifest
                }
            }
            for chart in aerodrome.charts {
                guard isID(chart.id), !chart.title.isEmpty, !chart.pages.isEmpty,
                      chart.sourceUrl.scheme == "https", Set(chart.roles).count == chart.roles.count else {
                    throw ChartSnapshotStoreError.invalidManifest
                }
                var chartPages = Set<String>()
                for page in chart.pages {
                    guard let asset = assets[page.assetSha256],
                          page.index >= 0, page.index < asset.pageCount,
                          [0, 90, 180, 270].contains(page.rotation),
                          validPageBox(page.mediaBox), validPageBox(page.cropBox),
                          chartPages.insert("\(page.assetSha256):\(page.index)").inserted else {
                        throw ChartSnapshotStoreError.invalidManifest
                    }
                    referenced.insert(page.assetSha256)
                }
            }
        }
        guard referenced.count == assets.count else { throw ChartSnapshotStoreError.invalidManifest }
    }

    private static func isID(_ id: String) -> Bool {
        id.wholeMatch(of: /[a-z0-9][a-z0-9_-]{0,99}/) != nil
    }

    private static func validPageBox(_ box: [Double]) -> Bool {
        box.count == 4 && box.allSatisfy(\.isFinite) && box[0] < box[2] && box[1] < box[3]
    }
}
