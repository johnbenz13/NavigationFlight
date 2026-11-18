import Foundation
import Testing
@testable import NavigationFlight

@Suite("Cockpit operational cue projection")
struct CockpitOperationalCueProjectorTests {
    @Test("Initial and background projections seed without replaying due emphasis")
    func initialAndBackgroundProjectionsSeedWithoutReplayingDueEmphasis() throws {
        let frequencyID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000009"))
        let dueEvents: Set<CockpitOperationalCueState.DueEvent> = [.frequency(frequencyID)]
        let now = Date(timeIntervalSince1970: 1_000)
        var emphasis = CockpitDueEmphasis()

        emphasis.observe(dueEvents, contextID: "leg-1", isVisible: true, at: now)
        #expect(emphasis.activeEvents(at: now).isEmpty)

        emphasis.observe([], contextID: "leg-1", isVisible: false, at: now.addingTimeInterval(1))
        emphasis.observe(dueEvents, contextID: "leg-1", isVisible: true, at: now.addingTimeInterval(2))
        #expect(emphasis.activeEvents(at: now.addingTimeInterval(2)).isEmpty)
    }

    @Test("Simultaneous cue changes emphasize independently for exactly five seconds")
    func simultaneousCueChangesEmphasizeIndependentlyForFiveSeconds() throws {
        let frequencyID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000009"))
        let altitudeID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000006"))
        let frequency = CockpitOperationalCueState.DueEvent.frequency(frequencyID)
        let altitude = CockpitOperationalCueState.DueEvent.altitude(altitudeID)
        let now = Date(timeIntervalSince1970: 2_000)
        var emphasis = CockpitDueEmphasis()
        emphasis.observe([], contextID: "leg-1", isVisible: true, at: now)

        emphasis.observe([frequency, altitude], contextID: "leg-1", isVisible: true, at: now.addingTimeInterval(1))

        #expect(emphasis.activeEvents(at: now.addingTimeInterval(1)) == [frequency, altitude])
        #expect(emphasis.activeEvents(at: now.addingTimeInterval(5.99)) == [frequency, altitude])
        #expect(emphasis.activeEvents(at: now.addingTimeInterval(6)).isEmpty)
    }

    @Test("A due change at the beginning of a new leg is emphasized")
    func dueChangeAtBeginningOfNewLegIsEmphasized() throws {
        let frequencyID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000009"))
        let frequency = CockpitOperationalCueState.DueEvent.frequency(frequencyID)
        let now = Date(timeIntervalSince1970: 3_000)
        var emphasis = CockpitDueEmphasis()
        emphasis.observe([], contextID: "leg-1", isVisible: true, at: now)
        emphasis.observe([frequency], contextID: "leg-1", isVisible: true, at: now.addingTimeInterval(1))

        emphasis.observe([frequency], contextID: "leg-2", isVisible: true, at: now.addingTimeInterval(2))

        #expect(emphasis.activeEvents(at: now.addingTimeInterval(2)) == [frequency])
        #expect(emphasis.activeEvents(at: now.addingTimeInterval(6.99)) == [frequency])
        #expect(emphasis.activeEvents(at: now.addingTimeInterval(7)).isEmpty)
    }

    @Test("Cue projection exposes planning-only frequency and altitude direction descriptions")
    func cueProjectionExposesSemanticDescriptions() throws {
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

        #expect(state.frequencies.map(\.statusLabel) == ["PLANNED NOW", "PLANNED NEXT"])
        #expect(state.frequencies[0].accessibilityDescription.contains("planned now"))
        #expect(state.frequencies[1].accessibilityDescription.contains("planned next"))
        #expect(state.frequencies.allSatisfy { !$0.accessibilityDescription.contains("tuned") })
        #expect(state.altitudeAccessibilityDescription == "Target altitude 2,000 feet MSL, next target 4,000 feet, climb")
    }

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
        #expect(altitudeDue.dueAltitude == .init(target: .init(value: 4_000), direction: .up))
        #expect(altitudeDue.dueEvents == [.altitude(altitudeChangeID)])

        let frequencyDue = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(27.5)
        )
        #expect(frequencyDue.frequencies.map(\.status) == [.other, .current])
        #expect(frequencyDue.dueEvents.contains(.frequency(frequencyChangeID)))
    }

    @Test("Console presentation follows live current and next cues")
    func consolePresentationFollowsLiveCurrentAndNextCues() throws {
        let altitudeEventID = try #require(UUID(uuidString: "00000000-0000-4000-8000-000000000006"))
        let frequencies = [
            displayFrequency(id: "first", service: "PLUTO WEST", value: 118.4),
            displayFrequency(id: "current", service: "PALMACHIM", value: 135.55),
            displayFrequency(id: "next", service: "BEN GURION", value: 120.5)
        ]
        let cues = CockpitOperationalCueState(
            frequencies: [
                .init(frequency: frequencies[0], status: .other),
                .init(frequency: frequencies[1], status: .current),
                .init(frequency: frequencies[2], status: .next)
            ],
            currentAltitude: .init(value: 4_500),
            nextAltitude: nil,
            dueAltitude: .init(target: .init(value: 4_500), direction: .up),
            dueEvents: [.altitude(altitudeEventID)]
        )

        let presentation = CockpitConsoleCuePresentation(
            cues: cues,
            emphasizedEvents: [.altitude(altitudeEventID)]
        )

        #expect(presentation.immediateFrequencyCues.map(\.frequency.id) == ["current", "next"])
        #expect(presentation.isAltitudeEmphasized)
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
        #expect(nextLeg.dueAltitude == .init(target: .init(value: 3_500), direction: .up))
        #expect(nextLeg.dueEvents.contains(.altitude(secondLegID)))
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

    @Test("Next-leg time-zero frequency is previewed on the preceding leg")
    func nextLegTimeZeroFrequencyIsPreviewedOnPrecedingLeg() throws {
        let flightPlan = try twoLegFixtureWithImmediateChanges()
        let start = Date(timeIntervalSince1970: 4_800)
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

        #expect(
            state.frequencies.first(where: { $0.frequency.frequencyMHz == 120.6 })?.status == .next
        )
    }

    @Test("Current frequency carries across legs without a new frequency change")
    func currentFrequencyCarriesAcrossLegsWithoutNewChange() throws {
        let flightPlan = try removingFrequencyChangesFromSecondLeg(
            of: twoLegFixtureWithImmediateChanges()
        )
        let start = Date(timeIntervalSince1970: 4_900)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)
        try flight.reachCurrentWaypoint(at: start.addingTimeInterval(42))

        let state = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(43)
        )

        #expect(state.frequencies.prefix(2).map(\.status) == [.other, .current])
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

    @Test("Ready projection preserves phases and uses the same compact communication entries")
    func readyCommunicationProjectionPreservesPhases() throws {
        let flightPlan = try mutatedFixtureFlightPlan { object in
            var execution = try required(object["execution"] as? [String: Any])
            var phases = try required(execution["frequenciesByPhase"] as? [String: Any])
            var departure = try required(phases["departure"] as? [[String: Any]])
            departure[0]["id"] = "departure:synthetic"
            departure[0]["name"] = "Synthetic tower"
            departure[0]["frequencyMhz"] = 122.2
            departure[0]["source"] = "departure"
            phases["departure"] = departure
            var arrival = try required(phases["arrival"] as? [[String: Any]])
            arrival[0]["id"] = "arrival:synthetic"
            arrival[0]["name"] = "Synthetic arrival"
            arrival[0]["frequencyMhz"] = 119.65
            arrival[0]["source"] = "arrival"
            phases["arrival"] = arrival
            execution["frequenciesByPhase"] = phases
            object["execution"] = execution
        }
        let flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )

        let state = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: Date(timeIntervalSince1970: 10_000)
        )

        #expect(state.communicationPlan.entries.map(\.phase).contains(.departure))
        #expect(state.communicationPlan.entries.map(\.phase).contains(.enRoute))
        #expect(state.communicationPlan.entries.map(\.phase).contains(.arrival))
        #expect(state.communicationPlan.compactEntries.first?.state == .departurePlan)
        #expect(state.communicationPlan.compactEntries.first?.dueContext == "Before navigation")
        #expect(state.communicationPlan.compactEntries.dropFirst().allSatisfy { $0.dueContext.contains("→") })
        #expect(state.communicationPlan.compactEntries.dropFirst().first?.phase == .enRoute)
        #expect(state.communicationPlan.entries.allSatisfy { $0.frequencyMHz >= 118 })
    }

    @Test("Communication projection changes atomically at the exact boundary")
    func communicationProjectionChangesAtomicallyAtBoundary() throws {
        let flightPlan = try fixtureFlightPlan()
        let start = Date(timeIntervalSince1970: 11_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)
        let projector = CockpitOperationalCueProjector()

        let before = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(27.49)
        )
        let atBoundary = try projector.project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(27.5)
        )

        #expect(before.communicationPlan.compactEntries.first?.state == .next)
        #expect(atBoundary.communicationPlan.compactEntries.first?.state == .current)
        #expect(before.communicationPlan.compactEntries.first?.id == atBoundary.communicationPlan.compactEntries.first?.id)
        #expect(atBoundary.communicationPlan.entries.filter { $0.state == .current }.map(\.id)
            == atBoundary.communicationPlan.compactEntries.filter { $0.state == .current }.map(\.id))
    }

    @Test("Completed navigation presents arrival without implying aircraft position")
    func completedNavigationPresentsArrival() throws {
        let flightPlan = try fixtureFlightPlan()
        let start = Date(timeIntervalSince1970: 12_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)
        try flight.reachCurrentWaypoint(at: start.addingTimeInterval(60))

        let state = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(61)
        )

        #expect(state.communicationPlan.compactEntries.allSatisfy { $0.state == .arrival })
        #expect(state.communicationPlan.compactEntries.allSatisfy { $0.dueContext == "After navigation" })
        #expect(state.communicationPlan.entries.filter { $0.phase == .enRoute }.allSatisfy { $0.state == .past })
    }

    @Test("Selected nonfirst Ready leg marks its arrival references for the first flown leg")
    func selectedNonfirstReadyLegMarksArrivalReferences() throws {
        let flightPlan = try multiLegFixtureFlightPlan()
        let reference = try #require(flightPlan.vorDmeReferences.last)
        let legIndex = try #require(flightPlan.legs.firstIndex { $0.arrival.id == reference.waypointID })
        #expect(legIndex > 0)
        let flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: legIndex,
            executionMode: .noWind
        )

        let state = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: Date(timeIntervalSince1970: 13_000)
        )

        let entries = state.navigationAidPlan.stations.flatMap(\.associations)
        let selectedEntries = entries.filter { $0.arrivalWaypoint == flightPlan.legs[legIndex].arrival.name }
        #expect(!selectedEntries.isEmpty)
        #expect(selectedEntries.allSatisfy { $0.state == .firstFlownLeg })
        #expect(entries.count == flightPlan.vorDmeReferences.count)

        let nextUseIndexes = state.navigationAidPlan.stations.compactMap { station in
            station.associations.first(where: { $0.state != .history })?.routeIndex
        }
        #expect(nextUseIndexes == nextUseIndexes.sorted())
        let firstPassedIndex = state.navigationAidPlan.stations.firstIndex {
            $0.associations.allSatisfy { $0.state == .history }
        }
        if let firstPassedIndex {
            #expect(state.navigationAidPlan.stations[firstPassedIndex...].allSatisfy {
                $0.associations.allSatisfy { $0.state == .history }
            })
        }
    }

    @Test("Active, completed, and absent navigation-aid states follow flight progress")
    func navigationAidStatesFollowFlightProgress() throws {
        let flightPlan = try fixtureFlightPlan()
        let start = Date(timeIntervalSince1970: 14_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)

        let active = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: start
        )
        let activeArrival = flightPlan.legs[0].arrival.name
        #expect(active.navigationAidPlan.stations.flatMap(\.associations).filter { $0.arrivalWaypoint == activeArrival }
            .allSatisfy { $0.state == .current })

        try flight.reachCurrentWaypoint(at: start.addingTimeInterval(60))
        let completed = try CockpitOperationalCueProjector().project(
            flightPlan: flightPlan,
            flight: flight,
            at: start.addingTimeInterval(61)
        )
        #expect(completed.navigationAidPlan.stations.flatMap(\.associations).allSatisfy { $0.state == .history })
        let passedLastUseIndexes = completed.navigationAidPlan.stations.compactMap {
            $0.associations.last?.routeIndex
        }
        #expect(passedLastUseIndexes == passedLastUseIndexes.sorted(by: >))

        let planned = try #require(flightPlan.plannedNavigation.plannedNavigation)
        let noReferences = FlightPlan(
            id: flightPlan.id,
            title: flightPlan.title,
            createdAt: flightPlan.createdAt,
            modifiedAt: flightPlan.modifiedAt,
            parameters: flightPlan.parameters,
            waypoints: flightPlan.waypoints,
            legs: flightPlan.legs,
            identificationPoints: flightPlan.identificationPoints,
            altitudeChanges: flightPlan.altitudeChanges,
            frequencyChanges: flightPlan.frequencyChanges,
            vorDmeReferences: [],
            operationalContext: flightPlan.operationalContext,
            plannedNavigation: .eligible(.init(
                calculationVersion: planned.calculationVersion,
                altitudeReference: planned.altitudeReference,
                legs: planned.legs,
                annotations: planned.annotations,
                vorDmeReferences: [],
                frequenciesByPhase: planned.frequenciesByPhase,
                defaultMode: planned.defaultMode
            ))
        )
        let absent = try CockpitOperationalCueProjector().project(
            flightPlan: noReferences,
            flight: flight,
            at: start.addingTimeInterval(61)
        )
        #expect(absent.navigationAidPlan.stations.isEmpty)
    }

    @Test("Every VOR DME reference for the active arrival is planned current")
    func multipleActiveArrivalReferencesAreCurrent() throws {
        let sourcePlan = try fixtureFlightPlan()
        let planned = try #require(sourcePlan.plannedNavigation.plannedNavigation)
        let sourceReference = try #require(sourcePlan.vorDmeReferences.first {
            $0.waypointID == sourcePlan.legs[0].arrival.id
        })
        let resolved = try #require(planned.vorDmeReferences.first { $0.referenceID == sourceReference.id })
        let duplicateID = try #require(UUID(uuidString: "DDDDDDDD-DDDD-4DDD-8DDD-DDDDDDDDDDDD"))
        let duplicateReference = VORDMEReference(
            id: duplicateID,
            waypointID: sourceReference.waypointID,
            calculation: sourceReference.calculation,
            navigationAid: sourceReference.navigationAid
        )
        let duplicateResolved = PlannedVORDMEReference(
            referenceID: duplicateID,
            frequency: resolved.frequency,
            stationElevationMsl: resolved.stationElevationMsl,
            magneticRadialFrom: resolved.magneticRadialFrom,
            slantRange: resolved.slantRange,
            source: resolved.source
        )
        let flightPlan = FlightPlan(
            id: sourcePlan.id,
            title: sourcePlan.title,
            createdAt: sourcePlan.createdAt,
            modifiedAt: sourcePlan.modifiedAt,
            parameters: sourcePlan.parameters,
            waypoints: sourcePlan.waypoints,
            legs: sourcePlan.legs,
            identificationPoints: sourcePlan.identificationPoints,
            altitudeChanges: sourcePlan.altitudeChanges,
            frequencyChanges: sourcePlan.frequencyChanges,
            vorDmeReferences: sourcePlan.vorDmeReferences + [duplicateReference],
            operationalContext: sourcePlan.operationalContext,
            plannedNavigation: .eligible(.init(
                calculationVersion: planned.calculationVersion,
                altitudeReference: planned.altitudeReference,
                legs: planned.legs,
                annotations: planned.annotations,
                vorDmeReferences: planned.vorDmeReferences + [duplicateResolved],
                frequenciesByPhase: planned.frequenciesByPhase,
                defaultMode: planned.defaultMode
            ))
        )
        let start = Date(timeIntervalSince1970: 15_000)
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
            at: start
        )
        let current = state.navigationAidPlan.stations.flatMap(\.associations).filter { $0.state == .current }
        #expect(current.count == 2)
        #expect(current.map(\.id) == [sourceReference.id, duplicateID])
        let groupedStation = try #require(state.navigationAidPlan.stations.first {
            $0.identifier == sourceReference.navigationAid.identifier
                && $0.frequencyMHz == resolved.frequency.value
        })
        let expectedIDs = sourcePlan.vorDmeReferences.compactMap { reference -> UUID? in
            guard reference.navigationAid.identifier == sourceReference.navigationAid.identifier,
                  planned.vorDmeReferences.first(where: { $0.referenceID == reference.id })?.frequency == resolved.frequency
            else { return nil }
            return reference.id
        } + [duplicateID]
        #expect(Set(groupedStation.associations.map(\.id)) == Set(expectedIDs))
        #expect(groupedStation.associations.map(\.routeIndex) == groupedStation.associations.map(\.routeIndex).sorted())
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

    private func multiLegFixtureFlightPlan() throws -> FlightPlan {
        let bundle = Bundle(for: FixtureLocator.self)
        let nested = bundle.url(
            forResource: "llhz-llib-via-jerusalem-v7",
            withExtension: "fplnav",
            subdirectory: "Fixtures/FPLNav/V7/Official"
        )
        let flat = bundle.url(forResource: "llhz-llib-via-jerusalem-v7", withExtension: "fplnav")
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

    private func removingFrequencyChangesFromSecondLeg(of source: FlightPlan) throws -> FlightPlan {
        let secondLegID = source.legs[1].id
        let planned = try #require(source.plannedNavigation.plannedNavigation)
        let removedIDs = Set(source.frequencyChanges.lazy.filter { $0.legID == secondLegID }.map(\.id))
        return FlightPlan(
            id: source.id,
            title: source.title,
            createdAt: source.createdAt,
            modifiedAt: source.modifiedAt,
            parameters: source.parameters,
            waypoints: source.waypoints,
            legs: source.legs,
            identificationPoints: source.identificationPoints,
            altitudeChanges: source.altitudeChanges,
            frequencyChanges: source.frequencyChanges.filter { removedIDs.contains($0.id) == false },
            vorDmeReferences: source.vorDmeReferences,
            operationalContext: source.operationalContext,
            plannedNavigation: .eligible(PlannedNavigation(
                calculationVersion: planned.calculationVersion,
                altitudeReference: planned.altitudeReference,
                legs: planned.legs,
                annotations: planned.annotations.filter { removedIDs.contains($0.entityID) == false },
                vorDmeReferences: planned.vorDmeReferences,
                frequenciesByPhase: planned.frequenciesByPhase,
                defaultMode: planned.defaultMode
            ))
        )
    }

    private func displayFrequency(
        id: String,
        service: String,
        value: Double
    ) -> CockpitPresentationData.DisplayFrequency {
        CockpitPresentationData.DisplayFrequency(
            id: id,
            phases: [.enRoute],
            service: service,
            serviceType: "Control",
            frequencyMHz: value,
            source: .route
        )
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
