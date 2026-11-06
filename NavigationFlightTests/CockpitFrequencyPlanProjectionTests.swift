import Foundation
import Testing
@testable import NavigationFlight

@Suite("Cockpit frequency plan projection")
struct CockpitFrequencyPlanProjectionTests {
    private let adapter = CockpitPresentationAdapter()

    @Test("Empty imported plan produces no frequency plan entries")
    func emptyPlan() {
        let plan = adapter.makeFrequencyPlan(frequencies: [:], references: [])

        #expect(plan.entries.isEmpty)
        #expect(plan.immediateEntries.isEmpty)
    }

    @Test("One imported communication entry retains its planned service, value, and phase")
    func oneCommunicationEntry() throws {
        let frequency = CockpitPresentationData.Frequency(
            id: "departure-tower",
            phase: .departure,
            role: "Tower",
            service: "HERZLIYA TOWER",
            frequencyMHz: 123.05,
            source: .departure
        )

        let plan = adapter.makeFrequencyPlan(
            frequencies: [.departure: [frequency]],
            references: []
        )

        let entry = try #require(plan.entries.first)
        #expect(plan.entries.count == 1)
        #expect(entry.sequence == .now)
        #expect(entry.kind == .communication)
        #expect(entry.service == "HERZLIYA TOWER")
        #expect(entry.role == "Tower")
        #expect(entry.frequencyMHz == 123.05)
        #expect(entry.association == "Departure")
        #expect(plan.immediateEntries == [entry])
    }

    @Test("Repeated services remain distinct entries in imported operational order")
    func repeatedServiceEntries() {
        let first = frequency(id: "tower-departure", phase: .departure, service: "TOWER", value: 123.05)
        let second = frequency(id: "tower-arrival", phase: .arrival, service: "TOWER", value: 118.1)

        let plan = adapter.makeFrequencyPlan(
            frequencies: [.arrival: [second], .departure: [first]],
            references: []
        )

        #expect(plan.entries.map(\.id) == ["tower-departure", "tower-arrival"])
        #expect(plan.entries.map(\.sequence) == [.now, .next])
        #expect(plan.entries.map(\.association) == ["Departure", "Arrival"])
    }

    @Test("Full plan retains communication order and associates navigation aids with the route endpoint")
    func fullPlan() throws {
        let referenceID = try #require(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let frequencies: [FlightPhase: [CockpitPresentationData.Frequency]] = [
            .departure: [frequency(id: "tower", phase: .departure, service: "HERZLIYA TOWER", value: 123.05, role: "Tower", source: .departure)],
            .enRoute: [frequency(id: "control", phase: .enRoute, service: "TEL AVIV CONTROL", value: 121.4, role: "Control")],
            .arrival: [
                frequency(id: "arrival-tower", phase: .arrival, service: "BEN GURION TOWER", value: 118.1, role: "Tower", source: .arrival),
                frequency(id: "bgn", phase: .arrival, service: "BGN", value: 113.5, role: "VOR/DME", source: .vorDme)
            ]
        ]
        let reference = CockpitPresentationData.PlannedReference(
            id: referenceID,
            endpointName: "RAMAT",
            station: "BGN",
            frequencyMHz: 113.5,
            magneticRadialFromDegrees: 245,
            slantRangeNauticalMiles: 18.6,
            source: .automatic
        )

        let plan = adapter.makeFrequencyPlan(frequencies: frequencies, references: [reference])

        #expect(plan.entries.map(\.id) == ["tower", "control", "arrival-tower", "bgn"])
        #expect(plan.entries.map(\.sequence) == [.now, .next, .later, .later])
        #expect(plan.entries.map(\.kind) == [.communication, .communication, .communication, .navigationAid])
        let navigationAid = try #require(plan.entries.last)
        #expect(navigationAid.service == "BGN")
        #expect(navigationAid.role == "VOR/DME")
        #expect(navigationAid.frequencyMHz == 113.5)
        #expect(navigationAid.association == "RAMAT")
        #expect(plan.immediateEntries.map(\.id) == ["tower", "control"])
    }

    private func frequency(
        id: String,
        phase: FlightPhase,
        service: String,
        value: Double,
        role: String? = nil,
        source: PlannedFrequencySource = .route
    ) -> CockpitPresentationData.Frequency {
        CockpitPresentationData.Frequency(
            id: id,
            phase: phase,
            role: role,
            service: service,
            frequencyMHz: value,
            source: source
        )
    }
}
