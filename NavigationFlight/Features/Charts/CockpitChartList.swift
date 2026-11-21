import Foundation

struct CockpitChartList {
    enum Endpoint: String, CaseIterable {
        case departure = "Departure"
        case arrival = "Arrival"

        var role: ChartCatalog.Chart.Role {
            switch self {
            case .departure: .departure
            case .arrival: .arrival
            }
        }
    }

    enum Tier: String, CaseIterable {
        case procedures = "Departure & arrival procedures"
        case circuits = "Circuits"
        case other = "Other charts"
    }

    struct Row: Identifiable {
        let selection: ChartSelection
        let endpoints: [Endpoint]

        var id: String { selection.id }

        var context: String {
            let roles = endpoints.map(\.rawValue).joined(separator: " & ")
            let aerodrome = selection.aerodrome
            return "\(roles) · \(aerodrome.name) (\(aerodrome.code))"
        }

        var tier: Tier {
            let chart = selection.chart
            if endpoints.contains(where: { chart.roles.contains($0.role) }) { return .procedures }
            return chart.roles.contains(.circuit) ? .circuits : .other
        }
    }

    struct Group: Identifiable {
        let tier: Tier
        let rows: [Row]
        var id: Tier { tier }
    }

    struct Notice: Identifiable {
        let endpoint: Endpoint
        let reason: Reason
        let name: String?

        var id: Endpoint { endpoint }
        var title: String { "\(endpoint.rawValue) charts unavailable" }

        var detail: String {
            switch reason {
            case .unspecified: "The loaded Flight Plan does not specify a \(endpoint.rawValue.lowercased()) aerodrome."
            case .unresolved: "The AIP could not identify \(name ?? "the aerodrome") from the Flight Plan identifiers."
            case .noCharts: "The AIP has no published charts for \(name ?? "this aerodrome")."
            }
        }
    }

    enum Reason: Equatable {
        case unspecified, unresolved, noCharts
    }

    let groups: [Group]
    let notices: [Notice]

    func row(for id: String) -> Row? {
        groups.lazy.flatMap(\.rows).first { $0.id == id }
    }

    init(catalog: ChartCatalog, departure: AerodromeReference?, arrival: AerodromeReference?) {
        var available: [(aerodrome: ChartCatalog.Aerodrome, endpoints: [Endpoint])] = []
        var notices: [Notice] = []
        for (endpoint, reference) in [(Endpoint.departure, departure), (.arrival, arrival)] {
            guard let reference else {
                notices.append(Notice(endpoint: endpoint, reason: .unspecified, name: nil))
                continue
            }
            guard let aerodrome = catalog.aerodrome(matching: reference) else {
                notices.append(Notice(endpoint: endpoint, reason: .unresolved, name: reference.name))
                continue
            }
            guard !aerodrome.charts.isEmpty else {
                notices.append(Notice(endpoint: endpoint, reason: .noCharts, name: aerodrome.name))
                continue
            }
            if let index = available.firstIndex(where: { $0.aerodrome.id == aerodrome.id }) {
                available[index].endpoints.append(endpoint)
            } else {
                available.append((aerodrome, [endpoint]))
            }
        }
        self.notices = notices
        groups = Tier.allCases.compactMap { tier in
            let order = tier == .circuits ? Array(available.reversed()) : available
            let rows = order.flatMap { entry in
                entry.aerodrome.charts.map { chart in
                    Row(selection: ChartSelection(aerodrome: entry.aerodrome, chart: chart), endpoints: entry.endpoints)
                }.filter { $0.tier == tier }
            }
            return rows.isEmpty ? nil : Group(tier: tier, rows: rows)
        }
    }
}

private extension ChartCatalog {
    func aerodrome(matching reference: AerodromeReference) -> Aerodrome? {
        func normalized(_ value: String?) -> String? {
            let value = value?.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            return value == "" ? nil : value
        }

        let tokens = [
            ("catalog", normalized(reference.catalogID)),
            ("icao", normalized(reference.icao)),
            ("local", normalized(reference.localCode)),
        ].compactMap { namespace, value in value.map { (namespace, $0) } }

        var candidate: Aerodrome?
        for (namespace, value) in tokens {
            let matches = aerodromes.filter { aerodrome in
                aerodrome.identifiers.contains { $0.namespace == namespace && normalized($0.value) == value }
            }
            guard matches.count <= 1 else { return nil }
            if let match = matches.first {
                if let candidate, candidate.id != match.id { return nil }
                candidate = match
            }
        }

        guard let candidate else { return nil }
        for (namespace, value) in tokens where namespace != "catalog" {
            let known = candidate.identifiers.filter { $0.namespace == namespace }
            if !known.isEmpty && !known.contains(where: { normalized($0.value) == value }) {
                return nil
            }
        }
        return candidate
    }
}
