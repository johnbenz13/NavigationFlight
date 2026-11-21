import Foundation
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Cockpit chart selection")
struct CockpitChartListTests {
    @Test("An official Flight Plan ranks only its endpoints in approved order")
    func officialPlan() throws {
        let catalog = try ChartResources.bundled.loadCatalog()
        let context = try plan("V7/Official/llhz-llib-via-jerusalem-v7").operationalContext
        let list = CockpitChartList(
            catalog: catalog, departure: context.departureAerodrome, arrival: context.arrivalAerodrome
        )

        #expect(list.notices.isEmpty)
        #expect(list.groups.map(\.tier) == [.procedures, .circuits, .other])
        #expect(list.groups[1].rows.map(\.id) == ["aip-llib-chart-05", "aip-llhz-chart-11"])
        #expect(list.groups[1].rows.map(\.endpoints) == [[.arrival], [.departure]])
        let herzliya = try #require(catalog.aerodromes.first { $0.id == "llhz" })
        let roshPina = try #require(catalog.aerodromes.first { $0.id == "llib" })
        let procedures = herzliya.charts.filter { $0.roles.contains(.departure) }
            + roshPina.charts.filter { $0.roles.contains(.arrival) }
        #expect(list.groups[0].rows.map(\.id) == procedures.map(\.id))
        #expect(Set(list.groups.flatMap(\.rows).map { $0.selection.aerodrome.id }) == ["llhz", "llib"])
    }

    @Test("Identifier namespaces, aliases and conflicts independently determine each endpoint")
    func typedIdentifiers() throws {
        let catalog = try makeCatalog()
        let list = CockpitChartList(
            catalog: catalog,
            departure: reference("Legacy-Alpha", icao: " aaaa ", local: " LOCAL-A "),
            arrival: reference("zzz", icao: "BBBB")
        )
        #expect(list.notices.isEmpty)
        #expect(list.groups.first?.rows.map(\.id) == ["alpha-procedure", "bravo-procedure"])

        let conflicts = CockpitChartList(
            catalog: catalog,
            departure: reference("alpha", icao: "BBBB"),
            arrival: reference("bravo", icao: "UNKNOWN")
        )
        #expect(conflicts.notices.map(\.reason) == [.unresolved, .unresolved])
        #expect(conflicts.groups.isEmpty)

        let wrongNamespace = CockpitChartList(catalog: catalog, departure: reference("AAAA"), arrival: nil)
        #expect(wrongNamespace.notices.map(\.reason) == [.unresolved, .unspecified])
        #expect(wrongNamespace.groups.isEmpty)
    }

    @Test("Unavailable endpoints leave the other end usable and a shared end is deduplicated")
    func availabilityAndDeduplication() throws {
        let catalog = try makeCatalog()
        let alpha = reference("alpha", icao: "AAAA")
        let absent = CockpitChartList(catalog: catalog, departure: nil, arrival: alpha)
        #expect(absent.notices.map(\.reason) == [.unspecified])
        #expect(absent.groups.map(\.tier) == [.circuits, .other])

        let empty = CockpitChartList(catalog: catalog, departure: alpha, arrival: reference("empty"))
        #expect(empty.notices.first?.reason == .noCharts)
        #expect(empty.groups.first?.rows.map(\.id) == ["alpha-procedure"])

        let shared = CockpitChartList(catalog: catalog, departure: alpha, arrival: alpha)
        let rows = shared.groups.flatMap(\.rows)
        #expect(rows.map(\.id) == ["alpha-procedure", "alpha-circuit"])
        #expect(rows.allSatisfy { $0.endpoints == [.departure, .arrival] })
    }

    @Test(arguments: ["V8/representative-v8", "V9/representative-v9"])
    func existingFormats(_ filename: String) throws {
        let catalog = try ChartResources.bundled.loadCatalog()
        let context = try plan(filename).operationalContext
        let list = CockpitChartList(
            catalog: catalog, departure: context.departureAerodrome, arrival: context.arrivalAerodrome
        )
        if context.departureAerodrome == nil, context.arrivalAerodrome == nil {
            #expect(list.notices.map(\.reason) == [.unspecified, .unspecified])
            #expect(list.groups.isEmpty)
        } else {
            let references = [context.departureAerodrome, context.arrivalAerodrome].compactMap { $0 }
            #expect(list.groups.flatMap(\.rows).allSatisfy { row in
                references.contains { reference in
                    reference.catalogID.lowercased() == row.selection.aerodrome.id
                        || reference.icao?.uppercased() == Optional(row.selection.aerodrome.code)
                }
            })
        }
    }

    private func plan(_ filename: String) throws -> FlightPlan {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        return try FPLNavDecoder().decode(Data(contentsOf: root.appending(path: "Fixtures/FPLNav/\(filename).fplnav")))
    }

    private func reference(_ id: String, icao: String? = nil, local: String? = nil) -> AerodromeReference {
        AerodromeReference(
            catalogID: id,
            name: "Sample",
            position: .init(latitudeDegrees: 32, longitudeDegrees: 34),
            icao: icao,
            localCode: local
        )
    }

    private func makeCatalog() throws -> ChartCatalog {
        func chart(_ id: String, _ roles: [String]) -> [String: Any] {
            ["id": id, "title": id, "roles": roles, "sourceUrl": "https://www.gov.il", "edition": [:], "pages": []]
        }
        func aerodrome(_ id: String, identifiers: [[String: String]], charts: [[String: Any]]) -> [String: Any] {
            [
                "id": id, "name": id, "group": "airports", "charts": charts,
                "identifiers": [["namespace": "catalog", "value": id]] + identifiers,
            ]
        }
        let object: [String: Any] = [
            "schemaVersion": 2, "releaseId": "fixture",
            "snapshot": ["amendment": "fixture", "effectiveDate": "2026-01-01"],
            "artifacts": [],
            "aerodromes": [
                aerodrome("alpha", identifiers: [
                    ["namespace": "catalog", "value": "legacy-alpha"],
                    ["namespace": "icao", "value": "AAAA"],
                    ["namespace": "local", "value": "local-a"],
                ], charts: [chart("alpha-circuit", ["circuit"]), chart("alpha-procedure", ["departure"])]),
                aerodrome("bravo", identifiers: [["namespace": "icao", "value": "BBBB"]],
                          charts: [chart("bravo-procedure", ["arrival"])]),
                aerodrome("empty", identifiers: [], charts: []),
            ],
        ]
        return try JSONDecoder().decode(ChartCatalog.self, from: JSONSerialization.data(withJSONObject: object))
    }
}
