import Foundation
import Testing
@testable import NavigationFlight

@Suite("Cockpit operational cue projection")
struct CockpitOperationalCueProjectorTests {
    @Test("Ready first leg projects planned current and next cues")
    func readyFirstLegProjectsPlannedCurrentAndNextCues() throws {
        let flightPlan = try fixtureFlightPlan()
        let flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )

        let state = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: Date(timeIntervalSince1970: 1_000)
        )

        #expect(state.frequencies.map(\.status) == [.current, .next])
        #expect(state.frequencies.map(\.frequency.frequencyMHz) == [113.5, 120.5])
        #expect(state.currentAltitude == AltitudeFeet(value: 2_000))
        #expect(state.nextAltitude == .init(
            target: AltitudeFeet(value: 4_000),
            direction: .up
        ))
        #expect(state.dueEvents.isEmpty)
    }

    @Test("Active changes become current at their planned elapsed time")
    func activeChangesBecomeCurrentAtPlannedElapsedTime() throws {
        let flightPlan = try fixtureFlightPlan()
        let start = Date(timeIntervalSince1970: 2_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)
        let projector = CockpitOperationalCueProjector()
        let altitudeChangeID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000006"))
        let frequencyChangeID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000009"))

        let beforeAltitude = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(9.49)
        )
        #expect(beforeAltitude.currentAltitude == AltitudeFeet(value: 2_000))
        #expect(beforeAltitude.dueEvents.isEmpty)

        let altitudeDue = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(9.5)
        )
        #expect(altitudeDue.currentAltitude == AltitudeFeet(value: 4_000))
        #expect(altitudeDue.nextAltitude == .init(target: .init(value: 3_200), direction: .up))
        #expect(altitudeDue.dueEvents == [.altitude(altitudeChangeID)])

        let frequencyDue = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(27.5)
        )
        #expect(frequencyDue.frequencies.map(\.status) == [.other, .current])
        #expect(frequencyDue.dueEvents.contains(.frequency(frequencyChangeID)))
    }

    @Test("Repeated service and frequency do not create a false change")
    func repeatedServiceAndFrequencyDoNotCreateFalseChange() throws {
        let repeatedID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000019"))
        let flightPlan = try mutatedFixtureFlightPlan { object in
            var navigation = try required(object["navigation"] as? [String: Any])
            var changes = try required(navigation["radioFrequencyChanges"] as? [[String: Any]])
            var repeated = try required(changes.first)
            repeated["id"] = repeatedID.uuidString.lowercased()
            repeated["legProgress"] = 0.8
            changes.append(repeated)
            navigation["radioFrequencyChanges"] = changes
            object["navigation"] = navigation

            var execution = try required(object["execution"] as? [String: Any])
            var annotations = try required(execution["annotations"] as? [[String: Any]])
            var annotation = try required(annotations.last)
            annotation["entityId"] = repeatedID.uuidString.lowercased()
            annotation["noWindTimeFromLegStartSeconds"] = 32
            annotation["withWindTimeFromLegStartSeconds"] = 32
            annotations.append(annotation)
            execution["annotations"] = annotations
            var phases = try required(execution["frequenciesByPhase"] as? [String: Any])
            var enRoute = try required(phases["en-route"] as? [[String: Any]])
            var repeatedFrequency = try required(enRoute.first)
            repeatedFrequency["id"] = "route:\(repeatedID.uuidString.lowercased())"
            enRoute.append(repeatedFrequency)
            phases["en-route"] = enRoute
            execution["frequenciesByPhase"] = phases
            object["execution"] = execution
        }
        let start = Date(timeIntervalSince1970: 3_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)

        let state = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(35)
        )

        #expect(state.frequencies.map(\.status) == [.other, .current])
        #expect(state.dueEvents.contains(.frequency(repeatedID)) == false)
    }

    @Test("Early leg completion resolves the next leg without replaying missed cues")
    func earlyLegCompletionResolvesNextLegWithoutReplay() throws {
        let flightPlan = try twoLegFixtureWithImmediateChanges()
        let altitudeChangeID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000022"))
        let frequencyChangeID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000023"))
        let start = Date(timeIntervalSince1970: 4_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)
        try flight.reachCurrentWaypoint(at: start.addingTimeInterval(5))

        let state = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(6)
        )

        #expect(flight.activeLegIndex == 1)
        #expect(flight.legState == .active)
        #expect(state.currentAltitude == AltitudeFeet(value: 1_500))
        #expect(state.frequencies.first(where: { $0.frequency.frequencyMHz == 120.6 })?.status == .current)
        #expect(state.dueEvents == [
            .altitude(altitudeChangeID),
            .frequency(frequencyChangeID)
        ])
    }

    @Test("Next leg initial altitude is previewed and becomes current on progression")
    func nextLegInitialAltitudeIsPreviewedAndBecomesCurrent() throws {
        let source = try twoLegFixtureWithImmediateChanges()
        let secondLegID = source.legs[1].id
        let planned = try #require(source.plannedNavigation.plannedNavigation)
        let removedAltitudeIDs = Set(source.altitudeChanges.lazy.filter { $0.legID == secondLegID }.map(\.id))
        let removedFrequencyIDs = Set(source.frequencyChanges.lazy.filter { $0.legID == secondLegID }.map(\.id))
        var plannedLegs = planned.legs
        let second = plannedLegs[1]
        plannedLegs[1] = PlannedLegNavigation(
            legID: second.legID,
            trueCourse: second.trueCourse,
            magneticCourse: second.magneticCourse,
            groundDistance: second.groundDistance,
            initialAltitudeMsl: AltitudeFeet(value: 3_500),
            noWind: second.noWind,
            withWind: second.withWind
        )
        var frequenciesByPhase = planned.frequenciesByPhase
        let enRouteFrequencies: [PlannedFrequency] = frequenciesByPhase[.enRoute] ?? []
        frequenciesByPhase[.enRoute] = enRouteFrequencies.filter { frequency in
            removedFrequencyIDs.contains { id in
                frequency.id == "route:\(id.uuidString.lowercased())"
            } == false
        }
        let flightPlan = FlightPlan(
            id: source.id,
            title: source.title,
            createdAt: source.createdAt,
            modifiedAt: source.modifiedAt,
            parameters: source.parameters,
            waypoints: source.waypoints,
            legs: source.legs,
            identificationPoints: source.identificationPoints,
            altitudeChanges: source.altitudeChanges.filter { removedAltitudeIDs.contains($0.id) == false },
            frequencyChanges: source.frequencyChanges.filter { removedFrequencyIDs.contains($0.id) == false },
            vorDmeReferences: source.vorDmeReferences,
            operationalContext: source.operationalContext,
            plannedNavigation: .eligible(PlannedNavigation(
                calculationVersion: planned.calculationVersion,
                altitudeReference: planned.altitudeReference,
                legs: plannedLegs,
                annotations: planned.annotations.filter {
                    removedAltitudeIDs.contains($0.entityID) == false &&
                    removedFrequencyIDs.contains($0.entityID) == false
                },
                vorDmeReferences: planned.vorDmeReferences,
                frequenciesByPhase: frequenciesByPhase,
                defaultMode: planned.defaultMode
            ))
        )
        let start = Date(timeIntervalSince1970: 4_500)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)
        let projector = CockpitOperationalCueProjector()

        let precedingLeg = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(41)
        )
        #expect(precedingLeg.currentAltitude == AltitudeFeet(value: 2_500))
        #expect(precedingLeg.nextAltitude == .init(target: .init(value: 3_500), direction: .up))

        try flight.reachCurrentWaypoint(at: start.addingTimeInterval(42))
        let nextLeg = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(43)
        )
        #expect(nextLeg.currentAltitude == AltitudeFeet(value: 3_500))
    }

    @Test("Next-leg time-zero altitude takes precedence over its initial altitude")
    func nextLegTimeZeroAltitudeTakesPrecedenceOverInitialAltitude() throws {
        let flightPlan = try twoLegFixtureWithImmediateChanges()
        let start = Date(timeIntervalSince1970: 4_700)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)

        let state = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(41)
        )

        #expect(state.currentAltitude == AltitudeFeet(value: 2_500))
        #expect(state.nextAltitude == .init(target: .init(value: 1_500), direction: .up))
    }

    @Test("Selected navigation mode controls annotation timing")
    func selectedNavigationModeControlsTiming() throws {
        let flightPlan = try mutatedFixtureFlightPlan { object in
            var execution = try required(object["execution"] as? [String: Any])
            var annotations = try required(execution["annotations"] as? [[String: Any]])
            let altitudeID = "00000000-0000-4000-8000-000000000006"
            let index = try required(annotations.firstIndex {
                $0["entityId"] as? String == altitudeID
            })
            annotations[index]["withWindTimeFromLegStartSeconds"] = 20
            execution["annotations"] = annotations
            object["execution"] = execution
        }
        let start = Date(timeIntervalSince1970: 5_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        try flight.startLeg(at: start)
        let projector = CockpitOperationalCueProjector()

        let beforeWindTime = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(15)
        )
        let atWindTime = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(20)
        )

        #expect(beforeWindTime.currentAltitude == AltitudeFeet(value: 2_000))
        #expect(atWindTime.currentAltitude == AltitudeFeet(value: 4_000))
    }

    @Test("Coincident frequency and altitude changes remain independent")
    func coincidentFrequencyAndAltitudeChangesRemainIndependent() throws {
        let flightPlan = try mutatedFixtureFlightPlan { object in
            var execution = try required(object["execution"] as? [String: Any])
            var annotations = try required(execution["annotations"] as? [[String: Any]])
            let frequencyID = "00000000-0000-4000-8000-000000000009"
            let index = try required(annotations.firstIndex {
                $0["entityId"] as? String == frequencyID
            })
            annotations[index]["noWindTimeFromLegStartSeconds"] = 10
            execution["annotations"] = annotations
            object["execution"] = execution
        }
        let altitudeID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000006"))
        let frequencyID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000009"))
        let start = Date(timeIntervalSince1970: 6_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)

        let state = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(10)
        )

        #expect(state.currentAltitude == AltitudeFeet(value: 4_000))
        #expect(state.frequencies.map(\.status) == [.other, .current])
        #expect(state.dueEvents == [.altitude(altitudeID), .frequency(frequencyID)])
    }

    @Test("Projection reconstructs current state after an interruption")
    func projectionReconstructsCurrentStateAfterInterruption() throws {
        let flightPlan = try fixtureFlightPlan()
        let start = Date(timeIntervalSince1970: 7_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)
        let projector = CockpitOperationalCueProjector()

        let uninterrupted = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(35)
        )
        let reconstructed = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(35)
        )

        #expect(reconstructed == uninterrupted)
        #expect(reconstructed.currentAltitude == AltitudeFeet(value: 3_200))
        #expect(reconstructed.frequencies.map(\.status) == [.other, .current])
    }

    @Test("First-leg time-zero changes preview ready and become due on start")
    func firstLegTimeZeroChangesPreviewReadyAndBecomeDueOnStart() throws {
        let flightPlan = try mutatedFixtureFlightPlan { object in
            var execution = try required(object["execution"] as? [String: Any])
            var annotations = try required(execution["annotations"] as? [[String: Any]])
            let timeZeroIDs = [
                "00000000-0000-4000-8000-000000000006",
                "00000000-0000-4000-8000-000000000009"
            ]
            for index in annotations.indices where timeZeroIDs.contains(annotations[index]["entityId"] as? String ?? "") {
                annotations[index]["noWindTimeFromLegStartSeconds"] = 0
                annotations[index]["withWindTimeFromLegStartSeconds"] = 0
            }
            execution["annotations"] = annotations
            object["execution"] = execution
        }
        let start = Date(timeIntervalSince1970: 8_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        let projector = CockpitOperationalCueProjector()

        let ready = try projector.project(flightPlan: flightPlan, flight: flight, at: start)
        #expect(ready.currentAltitude == AltitudeFeet(value: 2_000))
        #expect(ready.nextAltitude == .init(target: .init(value: 4_000), direction: .up))
        #expect(ready.frequencies.map(\.status) == [.current, .next])
        #expect(ready.dueEvents.isEmpty)

        try flight.startLeg(at: start)
        let active = try projector.project(flightPlan: flightPlan, flight: flight, at: start)
        #expect(active.currentAltitude == AltitudeFeet(value: 4_000))
        #expect(active.frequencies.map(\.status) == [.other, .current])
        #expect(active.dueEvents.count == 2)
    }

    @Test("Unrepresentable current frequency leaves every row neutral")
    func unrepresentableCurrentFrequencyLeavesRowsNeutral() throws {
        let decoded = try fixtureFlightPlan()
        let planned = try #require(decoded.plannedNavigation.plannedNavigation)
        var frequencies = planned.frequenciesByPhase
        frequencies[.enRoute] = []
        let modifiedPlan = FlightPlan(
            id: decoded.id,
            title: decoded.title,
            createdAt: decoded.createdAt,
            modifiedAt: decoded.modifiedAt,
            parameters: decoded.parameters,
            waypoints: decoded.waypoints,
            legs: decoded.legs,
            identificationPoints: decoded.identificationPoints,
            altitudeChanges: decoded.altitudeChanges,
            frequencyChanges: decoded.frequencyChanges,
            vorDmeReferences: decoded.vorDmeReferences,
            operationalContext: decoded.operationalContext,
            plannedNavigation: .eligible(.init(
                calculationVersion: planned.calculationVersion,
                altitudeReference: planned.altitudeReference,
                legs: planned.legs,
                annotations: planned.annotations,
                vorDmeReferences: planned.vorDmeReferences,
                frequenciesByPhase: frequencies,
                defaultMode: planned.defaultMode
            ))
        )
        let start = Date(timeIntervalSince1970: 9_000)
        var flight = Flight(
            flightPlanID: modifiedPlan.id,
            legIDs: modifiedPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)

        let state = try CockpitOperationalCueProjector().project(
            flightPlan: modifiedPlan,
            flight: flight,
            at: start.addingTimeInterval(30)
        )

        #expect(state.frequencies.allSatisfy { $0.status == .other })
    }

    private func fixtureFlightPlan() throws -> FlightPlan {
        let bundle = Bundle(for: FixtureLocator.self)
        let nested = bundle.url(
            forResource: "representative-v7",
            withExtension: "fplnav",
            subdirectory: "Fixtures/FPLNav/V7/Official"
        )
        let flat = bundle.url(forResource: "representative-v7", withExtension: "fplnav")
        let url = try #require(nested ?? flat)
        return try FPLNavDecoder().decode(Data(contentsOf: url))
    }

    private func mutatedFixtureFlightPlan(
        _ mutation: (inout [String: Any]) throws -> Void
    ) throws -> FlightPlan {
        let data = try fixtureData()
        var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        try mutation(&object)
        return try FPLNavDecoder().decode(JSONSerialization.data(withJSONObject: object))
    }

    private func twoLegFixtureWithImmediateChanges() throws -> FlightPlan {
        try mutatedFixtureFlightPlan { object in
            var navigation = try required(object["navigation"] as? [String: Any])
            var route = try required(navigation["route"] as? [String: Any])
            var waypoints = try required(route["waypoints"] as? [[String: Any]])
            var third = try required(waypoints.last)
            let thirdID = "00000000-0000-4000-8000-000000000020"
            let secondLegID = "00000000-0000-4000-8000-000000000021"
            let altitudeID = "00000000-0000-4000-8000-000000000022"
            let frequencyID = "00000000-0000-4000-8000-000000000023"
            third["id"] = thirdID
            third["name"] = "Third waypoint"
            third["position"] = ["latitude": 0.03, "longitude": 0.01]
            waypoints.append(third)
            let firstWaypointID = try required(waypoints.first?["id"] as? String)
            let secondWaypointID = try required(waypoints[1]["id"] as? String)
            route["waypoints"] = waypoints
            route["waypointOrder"] = [firstWaypointID, secondWaypointID, thirdID]
            var sourceLegs = try required(route["legs"] as? [[String: Any]])
            var secondLeg = try required(sourceLegs.first)
            secondLeg["id"] = secondLegID
            secondLeg["departureWaypointId"] = secondWaypointID
            secondLeg["arrivalWaypointId"] = thirdID
            sourceLegs.append(secondLeg)
            route["legs"] = sourceLegs
            navigation["route"] = route

            var altitudeChanges = try required(navigation["altitudeChanges"] as? [[String: Any]])
            var altitude = try required(altitudeChanges.first)
            altitude["id"] = altitudeID
            altitude["legId"] = secondLegID
            altitude["anchor"] = ["kind": "leg-progress", "legProgress": 0]
            altitude["targetAltitudeFeet"] = 1_500
            altitudeChanges.append(altitude)
            navigation["altitudeChanges"] = altitudeChanges

            var frequencyChanges = try required(navigation["radioFrequencyChanges"] as? [[String: Any]])
            var frequency = try required(frequencyChanges.first)
            frequency["id"] = frequencyID
            frequency["legId"] = secondLegID
            frequency["legProgress"] = 0
            frequency["service"] = ["name": "Next Control"]
            frequency["frequencyMhz"] = 120.6
            frequencyChanges.append(frequency)
            navigation["radioFrequencyChanges"] = frequencyChanges
            object["navigation"] = navigation

            var execution = try required(object["execution"] as? [String: Any])
            var legs = try required(execution["legs"] as? [[String: Any]])
            var resolvedLeg = try required(legs.first)
            resolvedLeg["legId"] = secondLegID
            legs.append(resolvedLeg)
            execution["legs"] = legs
            let departurePosition = try required(waypoints[1]["position"] as? [String: Any])
            var annotations = try required(execution["annotations"] as? [[String: Any]])
            var altitudeAnnotation = annotations[1]
            altitudeAnnotation["entityId"] = altitudeID
            altitudeAnnotation["legId"] = secondLegID
            altitudeAnnotation["position"] = departurePosition
            altitudeAnnotation["noWindTimeFromLegStartSeconds"] = 0
            altitudeAnnotation["withWindTimeFromLegStartSeconds"] = 0
            annotations.append(altitudeAnnotation)
            var frequencyAnnotation = annotations[4]
            frequencyAnnotation["entityId"] = frequencyID
            frequencyAnnotation["legId"] = secondLegID
            frequencyAnnotation["position"] = departurePosition
            frequencyAnnotation["noWindTimeFromLegStartSeconds"] = 0
            frequencyAnnotation["withWindTimeFromLegStartSeconds"] = 0
            annotations.append(frequencyAnnotation)
            execution["annotations"] = annotations
            var phases = try required(execution["frequenciesByPhase"] as? [String: Any])
            var enRoute = try required(phases["en-route"] as? [[String: Any]])
            enRoute.append([
                "id": "route:\(frequencyID)",
                "name": "Next Control",
                "frequencyMhz": 120.6,
                "source": "route"
            ])
            phases["en-route"] = enRoute
            execution["frequenciesByPhase"] = phases
            object["execution"] = execution
        }
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: FixtureLocator.self)
        let nested = bundle.url(
            forResource: "representative-v7",
            withExtension: "fplnav",
            subdirectory: "Fixtures/FPLNav/V7/Official"
        )
        let flat = bundle.url(forResource: "representative-v7", withExtension: "fplnav")
        return try Data(contentsOf: #require(nested ?? flat))
    }

    private func required<T>(_ value: T?) throws -> T {
        try #require(value)
    }
}

private final class FixtureLocator {}
