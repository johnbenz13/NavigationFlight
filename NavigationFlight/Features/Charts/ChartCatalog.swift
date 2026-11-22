import Foundation

nonisolated struct ChartCatalog: Decodable, Sendable {
    enum Group: String, CaseIterable, Decodable, Sendable {
        case airports
        case airfields

        var title: String {
            switch self {
            case .airports: "Airports"
            case .airfields: "Airfields"
            }
        }

        var singularTitle: String {
            switch self {
            case .airports: "Airport"
            case .airfields: "Airfield"
            }
        }
    }

    struct Aerodrome: Decodable, Identifiable, Sendable {
        struct Identifier: Decodable, Sendable {
            let namespace: String
            let value: String
        }

        let id: String
        let name: String
        let group: Group
        let identifiers: [Identifier]
        let charts: [Chart]

        var code: String {
            identifiers.first { $0.namespace == "icao" }?.value
                ?? identifiers.first { $0.namespace == "local" }?.value
                ?? id.uppercased()
        }
    }

    struct Chart: Decodable, Identifiable, Sendable {
        enum Role: String, Decodable, Sendable {
            case departure, arrival, circuit
        }

        struct Edition: Decodable, Sendable {
            let amendment: String?
            let printedDate: String?
        }

        struct Page: Decodable, Equatable, Sendable {
            let assetSha256: String
            let index: Int
            let publishedLabel: String?
            let mediaBox: [Double]
            let cropBox: [Double]
            let rotation: Int
        }

        let id: String
        let title: String
        let roles: [Role]
        let sourceUrl: URL
        let edition: Edition
        let pages: [Page]

        var pageLabel: String? {
            let labels = pages.compactMap(\.publishedLabel)
            return labels.isEmpty ? nil : labels.joined(separator: " · ")
        }
    }

    struct Asset: Decodable, Sendable {
        let id: String?
        let file: String?
        let representation: String?
        let consumer: String?
        let destination: String
        let bytes: Int
        let sha256: String
        let pageCount: Int
    }

    struct Snapshot: Decodable, Sendable {
        let amendment: String
        let effectiveDate: String
    }

    let schemaVersion: Int
    let releaseId: String
    let snapshot: Snapshot
    let aerodromes: [Aerodrome]
    let artifacts: [Asset]

    static let officialSource = URL(string: "https://www.gov.il/he/pages/aip?chapterIndex=1")!

    func aerodromes(in group: Group) -> [Aerodrome] {
        aerodromes.filter { $0.group == group }
    }

#if DEBUG
    func fixtureWithoutCharts(for id: String) -> ChartCatalog {
        let entries = aerodromes.map { entry in
            guard entry.id == id else { return entry }
            return Aerodrome(
                id: entry.id, name: entry.name, group: entry.group, identifiers: entry.identifiers, charts: []
            )
        }
        return ChartCatalog(
            schemaVersion: schemaVersion, releaseId: releaseId, snapshot: snapshot,
            aerodromes: entries, artifacts: artifacts
        )
    }
#endif

    func selection(for id: String) -> ChartSelection? {
        for aerodrome in aerodromes {
            if let chart = aerodrome.charts.first(where: { $0.id == id }) {
                return ChartSelection(aerodrome: aerodrome, chart: chart)
            }
        }
        return nil
    }
}

nonisolated struct ChartSelection: Identifiable, Sendable {
    let aerodrome: ChartCatalog.Aerodrome
    let chart: ChartCatalog.Chart

    var id: String { chart.id }
}

nonisolated struct ChartResources: Sendable {
    let bundleRoot: URL
    var unreadableChartID: String? = nil

    static let bundled = ChartResources(bundleRoot: Bundle.main.bundleURL)

    func loadCatalog() throws -> ChartCatalog {
        let index = bundleRoot.appending(path: "AIPCharts/index.json")
        return try Self.decodeCatalog(Data(contentsOf: index))
    }

    static func decodeCatalog(_ data: Data) throws -> ChartCatalog {
        let catalog = try JSONDecoder().decode(ChartCatalog.self, from: data)
        guard catalog.schemaVersion == 2, !catalog.releaseId.isEmpty,
              !catalog.aerodromes.isEmpty, !catalog.artifacts.isEmpty,
              Set(catalog.aerodromes.map(\.id)).count == catalog.aerodromes.count else {
            throw ChartResourceError.invalidCatalog
        }
        let charts = catalog.aerodromes.flatMap(\.charts)
        guard !charts.isEmpty, Set(charts.map(\.id)).count == charts.count else {
            throw ChartResourceError.invalidCatalog
        }
        return catalog
    }

    func assetData(for asset: ChartCatalog.Asset, chartID: String) throws -> Data {
#if DEBUG
        if chartID == unreadableChartID {
            return Data("Unreadable chart fixture".utf8)
        }
#endif
        return try Data(contentsOf: assetURL(for: asset), options: .mappedIfSafe)
    }

    func assetURL(for asset: ChartCatalog.Asset) throws -> URL {
        let parts = asset.destination.split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "AIPCharts", parts[1] == "pdf",
              parts[2].wholeMatch(of: /[a-z0-9_-]+\.pdf/) != nil else {
            throw ChartResourceError.invalidAsset
        }
        return bundleRoot.appending(path: asset.destination)
    }
}

enum ChartResourceError: Error {
    case invalidCatalog
    case invalidAsset
    case unavailablePage
}
