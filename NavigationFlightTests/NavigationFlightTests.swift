//
//  NavigationFlightTests.swift
//  NavigationFlightTests
//
//  Created by Jonathan Bensaid on 10/10/2026.
//

import Foundation
import Testing
@testable import NavigationFlight

private final class FixtureLocator {}

struct NavigationFlightTests {
    @Test func representativeV5MapsIntoDomain() throws {
        let flight = try FPLNavDecoder().decode(try representativeData())

        #expect(flight.title == "Coastal training navigation")
        #expect(flight.waypoints.map(\.name) == ["BAZRA", "Visual checkpoint"])
        #expect(flight.legs.count == 1)
        #expect(flight.legs[0].departure.id == flight.waypoints[0].id)
        #expect(flight.legs[0].arrival.id == flight.waypoints[1].id)
        #expect(flight.waypoints[0].position == WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.5))
        #expect(flight.waypoints[1].plannedAltitude == AltitudeFeet(value: 3500))

        // V5 explicitly distinguishes east-positive magnetic variation and true wind direction.
        #expect(flight.parameters.magneticVariationEast == Degrees(value: 5))
        #expect(flight.operationalContext.defaultWind?.directionFromTrue == Degrees(value: 270))

        #expect(flight.identificationPoints[0].progress == LegProgress(fraction: 0.4))
        #expect(flight.altitudeChanges.map(\.targetAltitude.value) == [4000, 2500, 3200])
        #expect(flight.frequencyChanges[0].service.name == "Tel Aviv Control")
        #expect(flight.frequencyChanges[0].frequency == FrequencyMHz(value: 120.5))
        #expect(flight.vorDmeReferences.count == 2)
        #expect(flight.vorDmeReferences[0].calculation == .automatic)
        #expect(
            flight.vorDmeReferences[1].calculation
                == .manual(radial: Degrees(value: 270), distance: NauticalMiles(value: 12.4))
        )
        #expect(flight.operationalContext.departureAerodrome?.icao == "LLHZ")
        #expect(flight.operationalContext.arrivalAerodrome?.localCode == "LLMG")
        #expect(flight.execution == .unavailableLegacyFormat(version: 5))
    }

    @Test func documentMetadataIdentifiesV5() throws {
        let object = try representativeJSONObject()
        #expect(object["formatVersion"] as? Int == 5)
        #expect(object["format"] as? String == "fpl-navigation-project")
    }

    @Test func editorOnlyAndUnknownPropertiesAreIgnored() throws {
        var object = try representativeJSONObject()
        object["futureEditorState"] = ["selection": "ignored"]
        var navigation = try #require(object["navigation"] as? [String: Any])
        navigation["futureEditorTool"] = true
        object["navigation"] = navigation

        let flight = try FPLNavDecoder().decode(try JSONSerialization.data(withJSONObject: object))
        #expect(flight.waypoints.count == 2)
    }

    @Test func unsupportedVersionIsTyped() throws {
        var object = try representativeJSONObject()
        object["formatVersion"] = 6

        #expect(throws: FPLNavDecoderError.unsupportedFormatVersion(6)) {
            try FPLNavDecoder().decode(try JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test func brokenWaypointRelationshipIsTyped() throws {
        var object = try representativeJSONObject()
        var navigation = try #require(object["navigation"] as? [String: Any])
        var route = try #require(navigation["route"] as? [String: Any])
        var order = try #require(route["waypointOrder"] as? [String])
        order[0] = "00000000-0000-4000-8000-000000000099"
        route["waypointOrder"] = order
        navigation["route"] = route
        object["navigation"] = navigation

        let expectedID = try #require(UUID(uuidString: order[0]))
        #expect(throws: FPLNavDecoderError.mapping(.missingWaypointInOrder(expectedID))) {
            try FPLNavDecoder().decode(try JSONSerialization.data(withJSONObject: object))
        }
    }

    @Test func samePositionEventsRemainIndependentAndRepresentable() throws {
        var object = try representativeJSONObject()
        var navigation = try #require(object["navigation"] as? [String: Any])
        var frequencyChanges = try #require(navigation["radioFrequencyChanges"] as? [[String: Any]])
        frequencyChanges[0]["legProgress"] = 0.25
        navigation["radioFrequencyChanges"] = frequencyChanges
        object["navigation"] = navigation

        let flight = try FPLNavDecoder().decode(try JSONSerialization.data(withJSONObject: object))
        #expect(flight.altitudeChanges[0].anchor == .legProgress(LegProgress(fraction: 0.25)))
        #expect(flight.frequencyChanges[0].progress == LegProgress(fraction: 0.25))
    }

    @Test func officialV7MapsSavedExecutionWithoutRecalculation() throws {
        var object = try fixtureJSONObject("representative-v7", directory: "V7/Official")
        var execution = try #require(object["execution"] as? [String: Any])
        var legs = try #require(execution["legs"] as? [[String: Any]])
        legs[0]["trueCourseDegrees"] = 123.456789
        legs[0]["distanceNauticalMiles"] = 9.87654321
        legs[0]["initialAltitudeFeetMsl"] = 4100
        var withWind = try #require(legs[0]["withWind"] as? [String: Any])
        withWind["trueHeadingDegrees"] = 222.25
        legs[0]["withWind"] = withWind
        execution["legs"] = legs
        var references = try #require(execution["vorDmeReferences"] as? [[String: Any]])
        references[0]["magneticRadialFromDegrees"] = 17.125
        references[0]["slantRangeNauticalMiles"] = 8.7654321
        execution["vorDmeReferences"] = references
        object["execution"] = execution

        let flight = try decode(object)
        let saved = try eligibleExecution(flight)
        #expect(saved.calculationVersion == "synthetic-conformance-1")
        #expect(saved.altitudeReference == .msl)
        #expect(saved.legs[0].trueCourse.value == 123.456789)
        #expect(saved.legs[0].groundDistance.value == 9.87654321)
        #expect(saved.legs[0].initialAltitudeMsl.value == 4100)
        #expect(flight.waypoints[0].plannedAltitude.value == 2000)
        #expect(saved.legs[0].withWind?.trueHeading.value == 222.25)
        #expect(saved.vorDmeReferences[0].magneticRadialFrom.value == 17.125)
        #expect(saved.vorDmeReferences[0].slantRange.value == 8.7654321)
        #expect(saved.legs[0].noWind.groundSpeed == Knots(value: 90))
    }

    @Test(arguments: ["editor-wind", "editor-no-wind", "editor-calm"])
    func editorV7VectorsDecode(_ name: String) throws {
        let flight = try FPLNavDecoder().decode(try fixtureData(name, directory: "V7/Editor"))
        let execution = try eligibleExecution(flight)
        #expect(execution.legs.count == 1)
        #expect(execution.annotations.count == 5)
        #expect(execution.vorDmeReferences.count == 2)
        #expect(execution.legs[0].initialAltitudeMsl.value == 3000)
        #expect(flight.waypoints[0].plannedAltitude.value == 3000)
        #expect(flight.waypoints[1].plannedAltitude.value == 3500)
        #expect(flight.altitudeChanges.map(\.targetAltitude.value) == [4000, 2500, 3200])
        #expect(execution.annotations[0].position.longitudeDegrees == 34.58082289823876)
        #expect(execution.annotations[0].noWindTimeFromLegStartSeconds == 238)
        #expect(execution.vorDmeReferences[1].source == .manual)
        #expect(execution.vorDmeReferences[0].slantRange.value == 20.08342967034671)
        #expect(execution.vorDmeReferences[1].magneticRadialFrom.value == 270)
        #expect(execution.vorDmeReferences[1].slantRange.value == 12.4)
        #expect(execution.frequenciesByPhase[.departure]?.map(\.id) == [
            "user:handoff-override", "vor-dme:00000000-0000-4000-8000-00000000000a",
            "catalog:herzlia:secondary", "catalog:herzlia:cpt"
        ])
        #expect(execution.frequenciesByPhase[.departure]?.first?.role == "Override")

        if name == "editor-no-wind" {
            #expect(execution.defaultMode == .noWind)
            #expect(execution.legs[0].withWind == nil)
            #expect(execution.annotations[0].withWindTimeFromLegStartSeconds == nil)
        } else {
            #expect(execution.defaultMode == .wind)
            #expect(execution.legs[0].withWind != nil)
            #expect(execution.annotations[0].withWindTimeFromLegStartSeconds == (name == "editor-wind" ? 222 : 238))
        }
        if name == "editor-wind" {
            #expect(execution.legs[0].withWind?.effectiveWind == Wind(directionFromTrue: .init(value: 250), speed: .init(value: 8)))
            #expect(execution.legs[0].withWind?.windCorrection.value == -2.395800157284725)
        }
        if name == "editor-calm" {
            #expect(execution.legs[0].withWind?.effectiveWind.speed.value == 0)
            #expect(execution.legs[0].withWind?.trueHeading.value == execution.legs[0].trueCourse.value)
        }
    }

    @Test func validEmptyV7IsDecodedButNotExecutionEligible() throws {
        var object = try fixtureJSONObject("representative-v7", directory: "V7/Official")
        var navigation = try #require(object["navigation"] as? [String: Any])
        var route = try #require(navigation["route"] as? [String: Any])
        route["waypointOrder"] = []
        route["waypoints"] = []
        route["legs"] = []
        navigation["route"] = route
        navigation["identificationPoints"] = []
        navigation["altitudeChanges"] = []
        navigation["radioFrequencyChanges"] = []
        navigation["vorDmeReferences"] = []
        object["navigation"] = navigation
        var execution = try #require(object["execution"] as? [String: Any])
        execution["legs"] = []
        execution["annotations"] = []
        execution["vorDmeReferences"] = []
        execution["frequenciesByPhase"] = ["departure": [], "en-route": [], "arrival": []]
        object["execution"] = execution

        let flight = try decode(object)
        #expect(!flight.execution.isExecutionEligible)
        guard case .emptyPlan(let saved) = flight.execution else { Issue.record("Expected empty V7 execution"); return }
        #expect(saved.legs.isEmpty)
    }

    @Test(arguments: V7Mutation.allCases)
    func invalidV7ExecutionIsRejected(_ mutation: V7Mutation) throws {
        var object = try fixtureJSONObject("representative-v7", directory: "V7/Official")
        try mutation.apply(to: &object)
        do {
            _ = try decode(object)
            Issue.record("Expected mutation to be rejected: \(mutation)")
        } catch let FPLNavDecoderError.invalidV7Execution(error) {
            #expect(!error.path.isEmpty)
            #expect(!error.reason.isEmpty)
        } catch {
            Issue.record("Expected typed V7 execution error for \(mutation), received \(error)")
        }
    }

    @Test(arguments: ["editor-wind", "editor-no-wind", "editor-calm"])
    func cockpitPresentationUsesSavedModes(_ name: String) throws {
        let flight = try FPLNavDecoder().decode(try fixtureData(name, directory: "V7/Editor"))
        let execution = try eligibleExecution(flight)
        let adapter = CockpitPresentationAdapter()
        let noWind = try adapter.makePresentation(flight: flight, legIndex: 0, mode: .noWind)

        #expect(noWind.magneticCourseDegrees == 35.23764544187969)
        #expect(noWind.magneticHeadingDegrees == nil)
        #expect(noWind.groundSpeedKnots == 95)
        #expect(noWind.legDurationSeconds == 596)
        #expect(noWind.initialAltitudeFeetMsl == 3000)
        #expect(noWind.destinationCrossingAltitudeFeet == 3500)
        #expect(noWind.routeEvents[0].id == execution.annotations[0].entityID)
        #expect(noWind.routeEvents[0].entityIDs == [execution.annotations[0].entityID, execution.annotations[3].entityID])
        #expect(noWind.routeEvents[0].kinds == [.identificationPoint, .altitudeChange])
        #expect(noWind.routeEvents[0].position == execution.annotations[0].position)
        #expect(noWind.routeEvents[0].timeFromLegStartSeconds == 238)
        #expect(noWind.references[0].slantRangeNauticalMiles == 20.08342967034671)
        #expect(noWind.references[1].slantRangeNauticalMiles == 12.4)
        #expect(noWind.frequencies[.departure]?.map(\.id) == [
            "user:handoff-override", "vor-dme:00000000-0000-4000-8000-00000000000a",
            "catalog:herzlia:secondary", "catalog:herzlia:cpt"
        ])
        #expect(noWind.frequencies[.departure]?.first?.role == "Override")

        if name == "editor-no-wind" {
            #expect(!noWind.supportsWindMode)
            #expect(throws: CockpitPresentationError.unavailableWindMode) {
                try adapter.makePresentation(flight: flight, legIndex: 0, mode: .wind)
            }
        } else {
            let wind = try adapter.makePresentation(flight: flight, legIndex: 0, mode: .wind)
            #expect(wind.supportsWindMode)
            #expect(wind.magneticHeadingDegrees != nil)
            #expect(wind.routeEvents[0].timeFromLegStartSeconds == (name == "editor-wind" ? 222 : 238))
            if name == "editor-wind" {
                #expect(wind.groundSpeedKnots == 101.86169458001739)
                #expect(wind.legDurationSeconds == 556)
            } else {
                #expect(wind.groundSpeedKnots == 95)
                #expect(wind.legDurationSeconds == 596)
                #expect(wind.magneticHeadingDegrees == wind.magneticCourseDegrees)
            }
        }
    }

    @Test(arguments: [
        (2.0, "002°"),
        (5.0, "005°"),
        (348.0, "348°")
    ])
    func cockpitUsesThreeDigitAviationDegrees(_ value: Double, _ expected: String) {
        let formatted = CockpitPresentationFormatter.aviationDegrees(value)

        #expect(formatted == expected)
        #expect(!formatted.contains("M"))
    }

    @Test func cockpitCollapsesIdenticalFrequenciesAcrossPhasesForDisplayOnly() throws {
        let enRoute = CockpitPresentationData.Frequency(
            id: "en-route-nat",
            phase: .enRoute,
            role: nil,
            service: "NAT",
            frequencyMHz: 112.4,
            source: .vorDme
        )
        let arrival = CockpitPresentationData.Frequency(
            id: "arrival-nat",
            phase: .arrival,
            role: nil,
            service: "NAT",
            frequencyMHz: 112.4,
            source: .vorDme
        )
        let frequencies: [FlightPhase: [CockpitPresentationData.Frequency]] = [
            .enRoute: [enRoute],
            .arrival: [arrival]
        ]

        let display = CockpitPresentationAdapter().makeDisplayFrequencies(from: frequencies)

        #expect(display.count == 1)
        let collapsed = try #require(display.first)
        #expect(collapsed.service == "NAT")
        #expect(collapsed.serviceType == "VOR/DME")
        #expect(collapsed.frequencyMHz == 112.4)
        #expect(collapsed.phases == [.enRoute, .arrival])
        #expect(frequencies[.enRoute] == [enRoute])
        #expect(frequencies[.arrival] == [arrival])
    }

    @Test func cockpitKeepsMeaningfullyDifferentFrequenciesDistinct() {
        let frequencies: [FlightPhase: [CockpitPresentationData.Frequency]] = [
            .enRoute: [
                .init(id: "en-route-nat", phase: .enRoute, role: nil, service: "NAT", frequencyMHz: 112.4, source: .vorDme)
            ],
            .arrival: [
                .init(id: "arrival-nat", phase: .arrival, role: nil, service: "NAT", frequencyMHz: 113.5, source: .vorDme)
            ]
        ]

        let display = CockpitPresentationAdapter().makeDisplayFrequencies(from: frequencies)

        #expect(display.count == 2)
        #expect(display.map(\.frequencyMHz) == [112.4, 113.5])
        #expect(display.allSatisfy { $0.serviceType == "VOR/DME" })
    }

    @Test func newFlightSessionIsReadyForExpectedLegAndMode() {
        let flightID = UUID()
        let legIDs = [UUID(), UUID(), UUID()]
        let session = FlightSession(
            flightID: flightID,
            legIDs: legIDs,
            activeLegIndex: 2,
            executionMode: .wind
        )

        #expect(session.flightID == flightID)
        #expect(session.legIDs == legIDs)
        #expect(session.activeLegIndex == 2)
        #expect(session.executionMode == .wind)
        #expect(session.legState == .ready)
        #expect(session.legStartedAt == nil)
    }

    @Test func startingLegRecordsTimestampAndDerivesElapsedTime() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var session = FlightSession(
            flightID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .noWind
        )

        try session.startLeg(at: startedAt)
        #expect(session.legState == .active)
        #expect(session.legStartedAt == startedAt)
        #expect(try #require(session.elapsedTime(at: startedAt.addingTimeInterval(37))) == 37)
    }

    @Test func startingActiveLegDoesNotReplaceOriginalTimestamp() throws {
        let originalStart = Date(timeIntervalSince1970: 1_000)
        var session = FlightSession(
            flightID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .wind
        )

        try session.startLeg(at: originalStart)
        #expect(throws: FlightSession.TransitionError.legAlreadyStarted(0)) {
            try session.startLeg(at: originalStart.addingTimeInterval(20))
        }
        #expect(session.legStartedAt == originalStart)
    }

    @Test func startingLegDoesNotMutateImportedResolvedExecution() throws {
        let flight = try FPLNavDecoder().decode(
            try fixtureData("editor-wind", directory: "V7/Editor")
        )
        let originalFlight = flight
        let originalExecution = try eligibleExecution(flight)
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: originalExecution.defaultMode
        )

        try session.startLeg(at: Date(timeIntervalSince1970: 1_000))

        #expect(flight == originalFlight)
        #expect(try eligibleExecution(flight) == originalExecution)
        #expect(session.executionMode == originalExecution.defaultMode)
    }

    @Test func automaticWaypointProgressionUsesOneAtomicTimestamp() throws {
        let legIDs = [UUID(), UUID()]
        let startedAt = Date(timeIntervalSince1970: 36_000)
        let reachedAt = Date(timeIntervalSince1970: 36_314)
        var session = FlightSession(
            flightID: UUID(),
            legIDs: legIDs,
            activeLegIndex: 0,
            executionMode: .noWind,
            progressionPolicy: .automaticNextLeg
        )

        try session.startLeg(at: startedAt)
        try session.reachCurrentWaypoint(at: reachedAt)

        #expect(session.activeLegIndex == 1)
        #expect(session.legState == .active)
        #expect(session.legTimings[0].legID == legIDs[0])
        #expect(session.legTimings[0].reachedAt == reachedAt)
        #expect(session.legTimings[0].actualElapsedDuration == 314)
        #expect(session.legTimings[1].startedAt == reachedAt)
        #expect(session.legTimings[0].reachedAt == session.legTimings[1].startedAt)
        #expect(session.legStartedAt == reachedAt)
    }

    @Test func destinationIdentificationRecordsOnceWithoutChangingActiveTiming() throws {
        let startedAt = Date(timeIntervalSince1970: 100)
        let identifiedAt = Date(timeIntervalSince1970: 140)
        var session = FlightSession(
            flightID: UUID(),
            legIDs: [UUID(), UUID()],
            activeLegIndex: 0,
            executionMode: .wind
        )
        try session.startLeg(at: startedAt)

        try session.identifyDestination(at: identifiedAt)

        #expect(session.destinationIdentifiedAt == identifiedAt)
        #expect(session.legTimings[0].destinationIdentifiedAt == identifiedAt)
        #expect(session.legStartedAt == startedAt)
        #expect(session.elapsedTime(at: Date(timeIntervalSince1970: 175)) == 75)
        #expect(session.activeLegIndex == 0)
        #expect(session.legState == .active)
        #expect(throws: FlightSession.TransitionError.destinationAlreadyIdentified(0)) {
            try session.identifyDestination(at: Date(timeIntervalSince1970: 160))
        }
        #expect(session.destinationIdentifiedAt == identifiedAt)
    }

    @Test func reachingWithoutIdentificationDoesNotFabricateIdentification() throws {
        let reachedAt = Date(timeIntervalSince1970: 200)
        var session = FlightSession(
            flightID: UUID(),
            legIDs: [UUID(), UUID()],
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try session.startLeg(at: Date(timeIntervalSince1970: 100))

        try session.reachCurrentWaypoint(at: reachedAt)

        #expect(session.legTimings[0].destinationIdentifiedAt == nil)
        #expect(session.legTimings[0].reachedAt == reachedAt)
        #expect(session.legTimings[1].startedAt == reachedAt)
    }

    @Test func manualWaypointProgressionWaitsForASecondStartTimestamp() throws {
        let reachedAt = Date(timeIntervalSince1970: 36_314)
        let secondStart = Date(timeIntervalSince1970: 36_400)
        var session = FlightSession(
            flightID: UUID(),
            legIDs: [UUID(), UUID()],
            activeLegIndex: 0,
            executionMode: .wind,
            progressionPolicy: .manualNextLeg
        )

        try session.startLeg(at: Date(timeIntervalSince1970: 36_000))
        try session.reachCurrentWaypoint(at: reachedAt)

        #expect(session.activeLegIndex == 1)
        #expect(session.legState == .ready)
        #expect(session.legStartedAt == nil)
        #expect(session.legTimings.count == 1)

        try session.startLeg(at: secondStart)
        #expect(session.legState == .active)
        #expect(session.legStartedAt == secondStart)
    }

    @Test func waypointCannotBeReachedWhileReady() {
        var session = FlightSession(
            flightID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .noWind
        )

        #expect(throws: FlightSession.TransitionError.legNotActive) {
            try session.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 100))
        }
        #expect(session.legTimings.isEmpty)
    }

    @Test func duplicateFinalWaypointDoesNotOverwriteRecordedTimestamp() throws {
        let reachedAt = Date(timeIntervalSince1970: 200)
        var session = FlightSession(
            flightID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try session.startLeg(at: Date(timeIntervalSince1970: 100))
        try session.reachCurrentWaypoint(at: reachedAt)

        #expect(throws: FlightSession.TransitionError.waypointAlreadyReached(0)) {
            try session.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 300))
        }
        #expect(session.legTimings[0].reachedAt == reachedAt)
        #expect(session.activeLegIndex == 0)
        #expect(session.legState == .completed)
    }

    @Test func progressionDoesNotMutateImportedResolvedExecution() throws {
        let flight = try twoLegFlight()
        let originalFlight = flight
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )

        try session.startLeg(at: Date(timeIntervalSince1970: 100))
        try session.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 200))

        #expect(flight == originalFlight)
        #expect(session.activeLegIndex == 1)
    }

    @Test func cockpitFeatureStateAdvancesPresentationInManualMode() throws {
        let flight = try twoLegFlight()
        var state = CockpitFeatureState(progressionPolicy: .manualNextLeg)
        try state.accept(flight)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))
        try state.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 200))

        let session = try #require(state.session)
        let cockpit = try CockpitPresentationAdapter().makePresentation(
            flight: flight,
            legIndex: state.selectedLegIndex,
            mode: state.mode
        )
        let map = try AviationMapPresentationFactory().makePresentation(
            flight: flight,
            session: session
        )

        #expect(state.selectedLegIndex == 1)
        #expect(session.legState == .ready)
        #expect(session.legStartedAt == nil)
        #expect(cockpit.origin == flight.legs[1].departure.name)
        #expect(cockpit.destination == flight.legs[1].arrival.name)
        #expect(map.activeLeg?.id == flight.legs[1].id)
        #expect(map.nextLegPreview == nil)
        #expect(map.readyFocusTarget == map.activeLeg?.from)
    }

    @Test func nextLegPreparationUsesSavedResolvedValuesAndIsAbsentOnFinalLeg() throws {
        let flight = try twoLegFlight()
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let adapter = CockpitPresentationAdapter()

        let next = try #require(try adapter.makeNextLegPreparation(flight: flight, session: session))
        #expect(next.legIndex == 1)
        #expect(next.direction == .heading(355))
        #expect(next.initialAltitudeFeetMsl == 2000)
        #expect(next.immediateAltitudeFeetMsl == nil)
        #expect(next.immediateFrequencyChange == nil)

        try session.startLeg(at: Date(timeIntervalSince1970: 100))
        try session.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 140))
        #expect(try adapter.makeNextLegPreparation(flight: flight, session: session) == nil)
    }

    @Test func nextLegPreparationLabelsSavedCourseWhenNoHeadingExists() throws {
        let flight = try twoLegFlight()
        let session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )

        let next = try #require(
            try CockpitPresentationAdapter().makeNextLegPreparation(flight: flight, session: session)
        )
        #expect(next.direction == .course(355))
    }

    @Test func nextLegPreparationUsesExplicitSavedStartChanges() throws {
        let flight = try twoLegFlight(withImmediateChanges: true)
        let session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )

        let next = try #require(
            try CockpitPresentationAdapter().makeNextLegPreparation(flight: flight, session: session)
        )
        #expect(next.immediateAltitudeFeetMsl == 1500)
        #expect(next.immediateFrequencyChange == .init(service: "Next Control", frequencyMHz: 120.6))
    }

    @Test func previousLegSummaryUsesSavedValuesAndSessionTiming() throws {
        let flight = try summaryFlight()
        let originalFlight = flight
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let adapter = CockpitPresentationAdapter()
        #expect(try adapter.makePreviousLegSummary(flight: flight, session: session) == nil)

        try session.startLeg(at: Date(timeIntervalSince1970: 1_000))
        try session.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 1_375))
        let summary = try #require(try adapter.makePreviousLegSummary(flight: flight, session: session))

        #expect(summary.plannedDurationSeconds == 382)
        #expect(summary.revisedETASeconds == nil)
        #expect(summary.actualDurationSeconds == 375)
        #expect(summary.deltaSeconds == -7)
        #expect(CockpitPresentationFormatter.signedDuration(summary.deltaSeconds) == "-00:07")
        #expect(summary.magneticHeadingDegrees == 355)
        #expect(summary.magneticCourseDegrees == 355)
        #expect(summary.vorDme?.station == "SYN")
        #expect(summary.vorDme?.magneticRadialFromDegrees == 270)
        #expect(summary.vorDme?.slantRangeNauticalMiles == 12.4)
        #expect(flight == originalFlight)
    }

    @Test func previousLegSummaryUsesCompletedLegRevisedDestinationETAAsComparisonBasis() throws {
        let flight = try summaryFlight()
        let originalFlight = flight
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let target = NavigationTimingTargetKey(
            legID: flight.legs[0].id,
            kind: .destination,
            targetID: flight.legs[0].arrival.id
        )
        session.initializePilotETA(targetKey: target, plannedElapsedSeconds: 382)
        for _ in 0..<4 { session.adjustPilotETA(targetKey: target, by: 5) }
        session.commitPilotETA(targetKey: target)
        try session.startLeg(at: Date(timeIntervalSince1970: 1_000))
        try session.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 1_407))

        let summary = try #require(
            try CockpitPresentationAdapter().makePreviousLegSummary(flight: flight, session: session)
        )
        #expect(summary.plannedDurationSeconds == 382)
        #expect(summary.revisedETASeconds == 400)
        #expect(summary.actualDurationSeconds == 407)
        #expect(summary.deltaSeconds == 7)
        #expect(CockpitPresentationFormatter.signedDuration(summary.deltaSeconds) == "+00:07")
        #expect(flight == originalFlight)
    }

    @Test func previousLegSummaryOnlyExposesMostRecentlyCompletedLeg() throws {
        let flight = try twoLegFlight()
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        try session.startLeg(at: Date(timeIntervalSince1970: 100))
        try session.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 140))
        try session.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 180))

        let summary = try #require(
            try CockpitPresentationAdapter().makePreviousLegSummary(flight: flight, session: session)
        )
        #expect(summary.legIndex == 1)
        #expect(summary.origin == flight.legs[1].departure.name)
        #expect(summary.destination == flight.legs[1].arrival.name)
    }

    @Test func advancingToSecondLegPreservesFirstLegRevisedETAHistoricalComparison() throws {
        let flight = try twoLegFlight()
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let map = try AviationMapPresentationFactory().makePresentation(flight: flight, session: session)
        let planned = map.destinationTarget.plannedElapsedSeconds
        session.initializePilotETA(targetKey: map.destinationTarget.id, plannedElapsedSeconds: planned)
        session.adjustPilotETA(targetKey: map.destinationTarget.id, by: 10)
        session.commitPilotETA(targetKey: map.destinationTarget.id)
        let revised = try #require(session.committedPilotETA(targetKey: map.destinationTarget.id))
        let start = Date(timeIntervalSince1970: 2_000)
        try session.startLeg(at: start)
        try session.reachCurrentWaypoint(at: start.addingTimeInterval(TimeInterval(revised + 2)))

        #expect(session.activeLegIndex == 1)
        let summary = try #require(
            try CockpitPresentationAdapter().makePreviousLegSummary(flight: flight, session: session)
        )
        #expect(summary.legIndex == 0)
        #expect(summary.plannedDurationSeconds == planned)
        #expect(summary.revisedETASeconds == revised)
        #expect(summary.actualDurationSeconds == revised + 2)
        #expect(summary.deltaSeconds == 2)
    }

    @Test func startingFirstLegCreatesPendingChecklistWithoutChangingTimingOrExecution() throws {
        let flight = try twoLegFlight()
        let originalFlight = flight
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var state = CockpitFeatureState()
        try state.accept(flight)

        try state.startLeg(at: startedAt)

        let checklist = try #require(state.activeLegStartChecklist)
        #expect(checklist.legID == flight.legs[0].id)
        #expect(checklist.reviewState == .pending)
        #expect(checklist.presentationState == .expanded)
        #expect(checklist.phaseState == .available)
        #expect(state.session?.legStartedAt == startedAt)
        #expect(state.session?.elapsedTime(at: startedAt.addingTimeInterval(17)) == 17)
        #expect(state.flight == originalFlight)
    }

    @Test func builtInLegStartTemplateDefinesTzeKivunAndGamadWithoutFlightValues() throws {
        let template = LegStartChecklistTemplate.tzeKivun
        let gamad = try #require(template.gamadSection)
        let allTemplateText = ([template.featureTitle, template.displayName, template.collapsedTitle] +
            template.sections.flatMap { section in
                [section.title].compactMap { $0 } + section.items.flatMap {
                    [$0.title, $0.instruction].compactMap { $0 } + $0.staticLines
                }
            }).joined(separator: " ")

        #expect(template.id == "tze-kivun-gamad")
        #expect(template.displayName == "צא כיוון")
        #expect(gamad.title == "גמ״ד")
        #expect(gamad.items.map(\.kind) == [.altitude, .speedAndEngine, .reporting])
        #expect(template.item(.direction)?.instruction == "Check magnetic compass")
        #expect(template.item(.speedAndEngine)?.staticLines == [
            "Oil pressure", "Oil temperature", "Amperage · Suction · Fuel"
        ])
        #expect(!allTemplateText.contains("002°"))
        #expect(!allTemplateText.contains("3,000"))
        #expect(!allTemplateText.contains("KIAS"))
    }

    @Test(arguments: [false, true])
    func waypointIdentificationHidesChecklistWithoutChangingReviewOrTiming(wasNoted: Bool) throws {
        let flight = try twoLegFlight()
        let originalFlight = flight
        let start = Date(timeIntervalSince1970: 100)
        let identified = Date(timeIntervalSince1970: 125)
        var state = CockpitFeatureState()
        try state.accept(flight)
        try state.startLeg(at: start)
        if wasNoted {
            state.noteLegStartChecklist()
        }

        try state.identifyDestination(at: identified)

        let checklist = try #require(state.activeLegStartChecklist)
        #expect(checklist.phaseState == .hiddenForPhase)
        #expect(checklist.reviewState == (wasNoted ? .noted : .pending))
        #expect(state.session?.destinationIdentifiedAt == identified)
        #expect(state.session?.legStartedAt == start)
        #expect(state.session?.elapsedTime(at: Date(timeIntervalSince1970: 140)) == 40)
        #expect(state.flight == originalFlight)
        state.reopenLegStartChecklist()
        #expect(state.activeLegStartChecklist?.phaseState == .hiddenForPhase)
    }

    @Test func reachedNowHidesPendingChecklistWithoutFabricatingNoted() throws {
        let flight = try twoLegFlight()
        var state = CockpitFeatureState(progressionPolicy: .manualNextLeg)
        try state.accept(flight)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))

        try state.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 140))

        let firstLegChecklist = try #require(state.legStartChecklists[flight.legs[0].id])
        #expect(firstLegChecklist.phaseState == .hiddenForPhase)
        #expect(firstLegChecklist.reviewState == .pending)
        #expect(state.activeLegStartChecklist == nil)
    }

    @Test func previousDrawerCollapseDoesNotAcknowledgeChecklist() throws {
        let flight = try twoLegFlight()
        var state = CockpitFeatureState()
        try state.accept(flight)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))

        state.collapseLegStartChecklist()

        #expect(state.activeLegStartChecklist?.presentationState == .collapsed)
        #expect(state.activeLegStartChecklist?.reviewState == .pending)
        #expect(state.activeLegStartChecklist?.phaseState == .available)
    }

    @Test func automaticProgressionCreatesFreshPendingChecklistForNewLeg() throws {
        let flight = try twoLegFlight()
        var state = CockpitFeatureState()
        try state.accept(flight)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))
        state.noteLegStartChecklist()

        try state.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 140))

        let checklist = try #require(state.activeLegStartChecklist)
        #expect(checklist.legID == flight.legs[1].id)
        #expect(checklist.reviewState == .pending)
        #expect(checklist.presentationState == .expanded)
        #expect(state.legStartChecklists[flight.legs[0].id]?.reviewState == .noted)
        #expect(state.legStartChecklists[flight.legs[0].id]?.phaseState == .hiddenForPhase)
        #expect(state.session?.legStartedAt == Date(timeIntervalSince1970: 140))
    }

    @Test func manualProgressionWaitsUntilStartBeforeCreatingChecklist() throws {
        let flight = try twoLegFlight()
        var state = CockpitFeatureState(progressionPolicy: .manualNextLeg)
        try state.accept(flight)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))
        state.noteLegStartChecklist()

        try state.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 140))
        #expect(state.session?.legState == .ready)
        #expect(state.activeLegStartChecklist == nil)
        #expect(state.legStartChecklists[flight.legs[1].id] == nil)

        try state.startLeg(at: Date(timeIntervalSince1970: 150))
        #expect(state.activeLegStartChecklist?.legID == flight.legs[1].id)
        #expect(state.activeLegStartChecklist?.reviewState == .pending)
        #expect(state.session?.legStartedAt == Date(timeIntervalSince1970: 150))
    }

    @Test func checklistCollapseReopenAndNotedAreScopedToActiveLeg() throws {
        let flight = try twoLegFlight()
        var state = CockpitFeatureState()
        try state.accept(flight)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))

        state.collapseLegStartChecklist()
        #expect(state.activeLegStartChecklist?.reviewState == .pending)
        #expect(state.activeLegStartChecklist?.presentationState == .collapsed)
        state.reopenLegStartChecklist()
        #expect(state.activeLegStartChecklist?.presentationState == .expanded)
        state.noteLegStartChecklist()
        #expect(state.activeLegStartChecklist?.reviewState == .noted)
        #expect(state.activeLegStartChecklist?.presentationState == .collapsed)
        state.reopenLegStartChecklist()
        #expect(state.activeLegStartChecklist?.reviewState == .noted)
        #expect(state.activeLegStartChecklist?.presentationState == .expanded)
    }

    @Test func checklistInteractionsDoNotChangeTimerOrResolvedNavigationValues() throws {
        let flight = try twoLegFlight()
        let originalFlight = flight
        let start = Date(timeIntervalSince1970: 200)
        var state = CockpitFeatureState()
        try state.accept(flight)
        try state.startLeg(at: start)

        state.collapseLegStartChecklist()
        state.reopenLegStartChecklist()
        state.noteLegStartChecklist()

        #expect(state.session?.legStartedAt == start)
        #expect(state.session?.elapsedTime(at: start.addingTimeInterval(42)) == 42)
        #expect(state.flight == originalFlight)
    }

    @Test func checklistUsesOnlySavedDirectionAltitudeAndContractSupportedIAS() throws {
        let flight = try twoLegFlight()
        var noWindSession = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try noWindSession.startLeg(at: Date(timeIntervalSince1970: 100))

        let noWind = try #require(
            try CockpitPresentationAdapter().makeLegStartChecklist(
                flight: flight,
                session: noWindSession
            )
        )
        #expect(noWind.direction == .course(355))
        #expect(noWind.plannedAltitudeFeetMsl == 2000)
        #expect(noWind.plannedIndicatedAirspeedKnots == nil)
        #expect(noWind.template == .tzeKivun)

        var windSession = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        try windSession.startLeg(at: Date(timeIntervalSince1970: 100))
        let wind = try #require(
            try CockpitPresentationAdapter().makeLegStartChecklist(
                flight: flight,
                session: windSession
            )
        )
        #expect(wind.direction == .heading(355))
    }

    @Test func cockpitFeatureStateLoadsAtomicallyAndPreservesModeWhileBrowsing() throws {
        let flight = try twoLegFlight()
        var state = CockpitFeatureState()
        try state.accept(flight)
        #expect(state.selectedLegIndex == 0)
        #expect(state.mode == .wind)

        state.selectMode(.noWind)
        state.selectNextLeg()
        #expect(state.selectedLegIndex == 1)
        #expect(state.mode == .noWind)
        state.selectPreviousLeg()
        #expect(state.selectedLegIndex == 0)
        #expect(state.mode == .noWind)

        let preserved = state
        state.cancelImport()
        #expect(state == preserved)
        do {
            try state.accept(FPLNavDecoder().decode(try representativeData()))
            Issue.record("V5 should not enter the executable Cockpit")
        } catch CockpitPlanError.legacyPlan(version: 5) {
            #expect(state == preserved)
        }
        do {
            try state.accept(try emptyV7Flight())
            Issue.record("Empty V7 should not enter the executable Cockpit")
        } catch CockpitPlanError.emptyPlan {
            #expect(state == preserved)
        }
    }

    @Test func fileLoaderOpensAStagedV7Fixture() throws {
        let bundle = Bundle(for: FixtureLocator.self)
        let nested = bundle.url(forResource: "editor-wind", withExtension: "fplnav", subdirectory: "Fixtures/FPLNav/V7/Editor")
        let url = try #require(nested ?? bundle.url(forResource: "editor-wind", withExtension: "fplnav"))
        let flight = try FPLNavFileLoader().load(url)
        var state = CockpitFeatureState()
        try state.accept(flight)
        #expect(state.flight?.title == "Synthetic Editor V7 wind handoff")
    }

    @Test func cockpitAdapterPresentsTheSelectedResolvedLegAndOnlySumsSavedTime() throws {
        let flight = try twoLegFlight()
        let presentation = try CockpitPresentationAdapter().makePresentation(
            flight: flight,
            legIndex: 1,
            mode: .wind
        )

        #expect(presentation.legPosition == "Leg 2 of 2")
        #expect(presentation.origin == "Synthetic waypoint 2")
        #expect(presentation.destination == "Third waypoint")
        #expect(presentation.magneticCourseDegrees == 355)
        #expect(presentation.magneticHeadingDegrees == 355)
        #expect(presentation.legDurationSeconds == 40)
        #expect(presentation.cumulativeDurationSeconds == 80)
        #expect(presentation.initialAltitudeFeetMsl == 2000)
        #expect(presentation.routeEvents.isEmpty)
    }

    @Test func mapPresentationUsesDomainRouteOrderAndSessionActiveLeg() throws {
        let flight = try twoLegFlight()
        let originalFlight = flight
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 1,
            executionMode: .wind
        )

        let presentation = try AviationMapPresentationFactory().makePresentation(
            flight: flight,
            session: session
        )

        #expect(presentation.waypoints.map(\.name) == flight.waypoints.map(\.name))
        #expect(presentation.legs.map(\.id) == flight.legs.map(\.id))
        #expect(presentation.activeLegIndex == session.activeLegIndex)
        #expect(presentation.activeLeg?.id == flight.legs[1].id)
        #expect(presentation.nextLegPreview == nil)
        #expect(presentation.readyFocusTarget == presentation.activeLeg?.from)
        #expect(presentation.activeFocusTarget == presentation.activeLeg?.to)
        #expect(presentation.plannedDurationSeconds == 40)
        #expect(presentation.plannedDurationText == "00:40")
        #expect(presentation.minuteMarkers.isEmpty)
        #expect(flight == originalFlight)

        try session.startLeg(at: Date(timeIntervalSince1970: 1_000))
        let activePresentation = try AviationMapPresentationFactory().makePresentation(
            flight: flight,
            session: session
        )
        #expect(activePresentation == presentation)
        #expect(flight == originalFlight)
    }

    @Test func mapPresentationSelectsBeginningOfFollowingLeg() throws {
        let flight = try twoLegFlight()
        let session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )

        let presentation = try AviationMapPresentationFactory().makePresentation(
            flight: flight,
            session: session
        )

        #expect(presentation.activeLeg?.id == flight.legs[0].id)
        #expect(presentation.nextLegPreview?.id == flight.legs[1].id)
        #expect(presentation.nextLegPreview?.from == presentation.activeLeg?.to)
        #expect(presentation.readyFocusTarget?.latitude == flight.legs[0].departure.position.latitudeDegrees)
        #expect(presentation.activeFocusTarget?.longitude == flight.legs[0].arrival.position.longitudeDegrees)
    }

    @Test func destinationIdentificationDoesNotChangeMapPresentation() throws {
        let flight = try twoLegFlight()
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        try session.startLeg(at: Date(timeIntervalSince1970: 100))
        let before = try AviationMapPresentationFactory().makePresentation(flight: flight, session: session)

        try session.identifyDestination(at: Date(timeIntervalSince1970: 120))
        let after = try AviationMapPresentationFactory().makePresentation(flight: flight, session: session)

        #expect(after == before)
    }

    @Test(arguments: [
        (AviationMapCoordinate(latitude: 0, longitude: 0), AviationMapCoordinate(latitude: 1, longitude: 0), 0.0),
        (AviationMapCoordinate(latitude: 0, longitude: 0), AviationMapCoordinate(latitude: 0, longitude: 1), 90.0),
        (AviationMapCoordinate(latitude: 0, longitude: 0), AviationMapCoordinate(latitude: -1, longitude: 0), 180.0),
        (AviationMapCoordinate(latitude: 0, longitude: 0), AviationMapCoordinate(latitude: 0, longitude: -1), 270.0)
    ])
    func mapBearingIsStable(
        from: AviationMapCoordinate,
        to: AviationMapCoordinate,
        expected: Double
    ) {
        #expect(abs(AviationMapGeometry.bearing(from: from, to: to) - expected) < 0.000_001)
    }

    @Test func mapMinuteMarkersUseEveryFullMinuteOfSavedPlannedDuration() {
        let from = AviationMapCoordinate(latitude: 32, longitude: 34)
        let to = AviationMapCoordinate(latitude: 33, longitude: 35)

        let markers = AviationMapSymbology.minuteMarkers(
            from: from,
            to: to,
            plannedDurationSeconds: 382
        )

        #expect(markers.map(\.minute) == [1, 2, 3, 4, 5, 6])
        #expect(markers.map(\.level) == [.odd, .even, .odd, .even, .odd, .even])
        for marker in markers {
            #expect(abs(marker.fraction - Double(marker.minute * 60) / 382) < 0.000_001)
        }
        #expect(markers.filter(\.showsLabel).map(\.minute) == [2, 4, 6])
    }

    @Test func mapVisualStyleMakesEvenMinuteTicksLonger() {
        let style = AviationMapVisualStyle.default

        #expect(style.minuteTickLengthFraction(for: .even) > style.minuteTickLengthFraction(for: .odd))
        #expect(style.evenMinuteTickLengthFraction / style.oddMinuteTickLengthFraction >= 1.6)
        #expect(style.evenMinuteTickLengthFraction / style.oddMinuteTickLengthFraction <= 2)
    }

    @Test func mapVisualStyleUsesTranslucentSurfacesAndOpaqueDetails() {
        let style = AviationMapVisualStyle.default

        #expect(abs(style.destinationWaypointFillOpacity - 0.20) < 0.001)
        #expect(style.destinationWaypointStrokeOpacity == 1)
        #expect(abs(style.etaCalloutBackgroundOpacity - 0.72) < 0.001)
        #expect(abs(style.etaExpandedCalloutBackgroundOpacity - 0.90) < 0.001)
        #expect(style.etaCalloutBorderOpacity == 1)
        #expect(style.etaCalloutTextOpacity == 1)
        #expect(style.currentLegAccentColor != style.nextLegAccentColor)
        #expect(style.activeLegColor == style.currentLegAccentColor)
        #expect(style.defaultEtaCalloutOffset.x <= -160)
        #expect(abs(style.identificationPointCollapsedCalloutBackgroundOpacity - 0.72) < 0.001)
        #expect(abs(style.identificationPointExpandedCalloutBackgroundOpacity - 0.90) < 0.001)
        #expect(style.identificationPointColor != style.currentLegAccentColor)
        #expect(style.identificationPointColor != style.nextLegAccentColor)
        #expect(style.identificationPointColor != style.identificationPointReachedColor)
        #expect(abs(style.defaultIdentificationPointCalloutOffset.x) >= 80)
        #expect(style.defaultIdentificationPointCalloutOffset.y != 0)
        #expect(style.identificationPointEllipseFillOpacity < 0.15)
        #expect(style.identificationPointEllipseOutlineOpacity >= 0.9)
    }

    @Test func movingIdentificationLabelKeepsResolvedEllipseAnchorAndPlanUnchanged() throws {
        let flight = try FPLNavDecoder().decode(try fixtureData("editor-wind", directory: "V7/Editor"))
        let originalFlight = flight
        let session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let presentation = try AviationMapPresentationFactory().makePresentation(flight: flight, session: session)
        let point = try #require(presentation.identificationPoints.first)
        let initial = AviationMapVisualStyle.default.defaultIdentificationPointCalloutOffset
        let moved = initial.translated(x: 85, y: 35)

        #expect(initial.x != 0)
        #expect(moved != initial)
        #expect(point.coordinate == presentation.identificationPoints.first?.coordinate)
        #expect(point.plannedElapsedSeconds == presentation.identificationPoints.first?.plannedElapsedSeconds)
        #expect(flight == originalFlight)
    }

    @Test func committedETAPropagatesToMapPresentationWithoutMutatingFlight() throws {
        let flight = try FPLNavDecoder().decode(try fixtureData("editor-wind", directory: "V7/Editor"))
        let originalFlight = flight
        let destinationID = try #require(flight.legs.first?.arrival.id)
        let legID = try #require(flight.legs.first?.id)
        let targetKey = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: destinationID)
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        session.initializePilotETA(targetKey: targetKey, plannedElapsedSeconds: 556)
        session.adjustPilotETA(targetKey: targetKey, by: 25)

        let beforeCommit = try AviationMapPresentationFactory().makePresentation(flight: flight, session: session)
        #expect(beforeCommit.destinationTarget.committedETASeconds == nil)
        #expect(beforeCommit.destinationTarget.plannedElapsedSeconds == 556)

        session.commitPilotETA(targetKey: targetKey)
        let afterCommit = try AviationMapPresentationFactory().makePresentation(flight: flight, session: session)
        #expect(afterCommit.destinationTarget.committedETASeconds == 580)
        #expect(afterCommit.destinationTarget.plannedElapsedSeconds == 556)
        #expect(flight == originalFlight)
        #expect(session.legTimings.isEmpty)
        #expect(session.activeLegIndex == 0)
        #expect(session.legState == .ready)
    }

    @Test func movingEtaCalloutOffsetDoesNotMoveDestinationOrResolvedExecution() throws {
        let flight = try twoLegFlight()
        let originalFlight = flight
        let session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let presentation = try AviationMapPresentationFactory().makePresentation(
            flight: flight,
            session: session
        )
        let destination = try #require(presentation.activeFocusTarget)
        let initial = AviationMapVisualStyle.default.defaultEtaCalloutOffset
        let moved = initial.translated(x: 42, y: -18)

        #expect(moved == AviationMapCalloutOffset(x: initial.x + 42, y: initial.y - 18))
        #expect(presentation.activeFocusTarget == destination)
        #expect(flight == originalFlight)
    }

    @Test func mapMinuteMarkersOmitDurationsShorterThanOneMinute() {
        let point = AviationMapCoordinate(latitude: 32, longitude: 34)
        #expect(AviationMapSymbology.minuteMarkers(
            from: point,
            to: point,
            plannedDurationSeconds: 59
        ).isEmpty)
    }

    @Test func mapMinuteMarkersAtExactMinuteDoNotExtendBeyondArrival() {
        let from = AviationMapCoordinate(latitude: 0, longitude: 0)
        let to = AviationMapCoordinate(latitude: 1, longitude: 1)
        let markers = AviationMapSymbology.minuteMarkers(
            from: from,
            to: to,
            plannedDurationSeconds: 300
        )

        #expect(markers.map(\.minute) == [1, 2, 3, 4, 5])
        #expect(markers.last?.fraction == 1)
        #expect(markers.allSatisfy { $0.fraction <= 1 })
    }

    @Test func mapDestinationCalloutFormatsSavedDurationWithoutChangingIt() {
        let savedDuration = 382
        #expect(AviationMapSymbology.formatDuration(savedDuration) == "06:22")
        #expect(savedDuration == 382)
    }

    @Test func importedIdentificationPointOrderingAndResolvedLegETAArePreserved() throws {
        let flight = try FPLNavDecoder().decode(try fixtureData("editor-wind", directory: "V7/Editor"))
        let pointID = try #require(flight.identificationPoints.first?.id)
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        try session.startLeg(at: Date(timeIntervalSince1970: 1_000))

        let presentation = try AviationMapPresentationFactory().makePresentation(flight: flight, session: session)

        #expect(presentation.identificationPoints.map(\.id.identificationPointID) == flight.identificationPoints.map(\.id))
        #expect(presentation.identificationPoints.first?.id.identificationPointID == pointID)
        #expect(presentation.identificationPoints.first?.coordinate.latitude == 32.179463389700274)
        #expect(presentation.identificationPoints.first?.plannedElapsedSeconds == 222)
    }

    @Test func identificationPointReachRecordsOnceWithoutChangingLeg() throws {
        let pointA = UUID()
        let pointB = UUID()
        let legIDs = [UUID(), UUID()]
        let keyA = IdentificationPointKey(legID: legIDs[0], identificationPointID: pointA)
        let keyB = IdentificationPointKey(legID: legIDs[0], identificationPointID: pointB)
        let startedAt = Date(timeIntervalSince1970: 36_000)
        let reachedA = startedAt.addingTimeInterval(173)
        let reachedB = startedAt.addingTimeInterval(240)
        var session = FlightSession(
            flightID: UUID(),
            legIDs: legIDs,
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try session.startLeg(at: startedAt)

        try session.reachIdentificationPoint(key: keyA, at: reachedA)
        try session.reachIdentificationPoint(key: keyB, at: reachedB)

        #expect(session.identificationPointTiming(for: keyA)?.reachedAt == reachedA)
        #expect(session.actualLegElapsedDuration(atIdentificationPoint: keyA) == 173)
        #expect(session.identificationPointTiming(for: keyB)?.reachedAt == reachedB)
        #expect(session.identificationPointTimings.count == 2)
        #expect(session.activeLegIndex == 0)
        #expect(session.legState == .active)
        #expect(session.legStartedAt == startedAt)
        #expect(session.elapsedTime(at: startedAt.addingTimeInterval(300)) == 300)
        #expect(throws: FlightSession.TransitionError.identificationPointAlreadyReached(pointA)) {
            try session.reachIdentificationPoint(key: keyA, at: startedAt.addingTimeInterval(400))
        }
        #expect(session.identificationPointTiming(for: keyA)?.reachedAt == reachedA)
    }

    @Test func identificationPointTimingDeltaAndTargetProgressionAreDeterministic() throws {
        let pointA = UUID()
        let pointB = UUID()
        let destination = UUID()
        let legID = UUID()
        let pointAKey = IdentificationPointKey(legID: legID, identificationPointID: pointA)
        let pointBKey = IdentificationPointKey(legID: legID, identificationPointID: pointB)
        let destinationKey = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: destination)
        let points = [
            AviationMapIdentificationPoint(id: pointAKey, name: "A", coordinate: .init(latitude: 1, longitude: 1), plannedElapsedSeconds: 160, isReached: true, committedETASeconds: nil),
            AviationMapIdentificationPoint(id: pointBKey, name: "B", coordinate: .init(latitude: 2, longitude: 2), plannedElapsedSeconds: 256, isReached: false, committedETASeconds: nil)
        ]
        let presentation = AviationMapPresentation(
            waypoints: [], legs: [], activeLegIndex: 0, nextLegPreview: nil,
            endpointReferences: [], plannedDurationSeconds: 338, minuteMarkers: [],
            identificationPoints: points,
            destinationTarget: .init(id: destinationKey, name: "Destination", plannedElapsedSeconds: 338, committedETASeconds: nil)
        )

        #expect(presentation.nextETATarget(after: pointAKey)?.id.targetID == pointB)
        let completedPoints = points.map {
            AviationMapIdentificationPoint(id: $0.id, name: $0.name, coordinate: $0.coordinate, plannedElapsedSeconds: $0.plannedElapsedSeconds, isReached: true, committedETASeconds: nil)
        }
        let completedPresentation = AviationMapPresentation(
            waypoints: [], legs: [], activeLegIndex: 0, nextLegPreview: nil,
            endpointReferences: [], plannedDurationSeconds: 338, minuteMarkers: [],
            identificationPoints: completedPoints,
            destinationTarget: presentation.destinationTarget
        )
        #expect(completedPresentation.nextETATarget(after: pointAKey)?.id == destinationKey)
        #expect(completedPresentation.nextETATarget(after: pointBKey)?.id == destinationKey)

        let actual = 173
        #expect(actual - points[0].plannedElapsedSeconds == 13)
    }

    @Test func pilotETARoundsAndAdjustsWithoutMutatingPlan() {
        let legID = UUID()
        let targetID = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: UUID())
        let plan = 338
        var session = FlightSession(
            flightID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )

        session.initializePilotETA(targetKey: targetID, plannedElapsedSeconds: plan)
        #expect(session.pilotETAState(targetKey: targetID)?.draftSeconds == 340)
        #expect(session.committedPilotETA(targetKey: targetID) == nil)
        session.adjustPilotETA(targetKey: targetID, by: 5)
        #expect(session.pilotETAState(targetKey: targetID)?.draftSeconds == 345)
        #expect(session.committedPilotETA(targetKey: targetID) == nil)
        session.commitPilotETA(targetKey: targetID)
        #expect(session.committedPilotETA(targetKey: targetID) == 345)
        #expect(session.pilotETAState(targetKey: targetID)?.isEditing == false)
        session.showPilotETACheck(targetKey: targetID)
        #expect(session.pilotETAState(targetKey: targetID)?.isCheckResultVisible == true)
        session.beginEditingPilotETA(targetKey: targetID)
        #expect(session.pilotETAState(targetKey: targetID)?.draftSeconds == 345)
        #expect(session.pilotETAState(targetKey: targetID)?.isCheckResultVisible == false)
        session.adjustPilotETA(targetKey: targetID, by: 5)
        #expect(session.committedPilotETA(targetKey: targetID) == 345)
        #expect(session.pilotETAState(targetKey: targetID)?.draftSeconds == 350)
        session.commitPilotETA(targetKey: targetID)
        #expect(session.committedPilotETA(targetKey: targetID) == 350)

        var earlierSession = FlightSession(
            flightID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )
        earlierSession.initializePilotETA(targetKey: targetID, plannedElapsedSeconds: plan)
        earlierSession.adjustPilotETA(targetKey: targetID, by: -5)
        #expect(earlierSession.pilotETAState(targetKey: targetID)?.draftSeconds == 335)
        #expect(earlierSession.committedPilotETA(targetKey: targetID) == nil)
        #expect(plan == 338)
    }

    @Test func destinationAndIdentificationTargetsUseTheSameCanonicalETAStateMachine() throws {
        let legID = UUID()
        let observation = IdentificationPointKey(legID: legID, identificationPointID: UUID())
        let destination = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: UUID())
        let identification = NavigationTimingTargetKey(
            legID: legID,
            kind: .identificationPoint,
            targetID: UUID()
        )
        var session = FlightSession(
            flightID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )

        session.initializePilotETA(
            targetKey: destination,
            plannedElapsedSeconds: 256,
            timingObservationKey: observation
        )
        session.initializePilotETA(targetKey: identification, plannedElapsedSeconds: 190)
        session.adjustPilotETA(targetKey: destination, by: 5)
        session.commitPilotETA(targetKey: destination)

        #expect(session.pilotETAState(targetKey: destination)?.draftSeconds == 260)
        #expect(session.pilotETAState(targetKey: destination)?.committedSeconds == 260)
        #expect(session.pilotETAState(targetKey: destination)?.timingObservationKey == observation)
        #expect(session.pilotETAState(targetKey: identification)?.draftSeconds == 190)
        #expect(session.pilotETAState(targetKey: identification)?.committedSeconds == nil)
        session.showPilotETACheck(targetKey: destination)
        #expect(session.pilotETAState(targetKey: destination)?.isCheckResultVisible == true)
        session.beginEditingPilotETA(targetKey: destination)
        #expect(session.pilotETAState(targetKey: destination)?.isCheckResultVisible == false)
        #expect(session.pilotETAState(targetKey: destination)?.draftSeconds == 260)
    }

    @Test func nextTargetShortcutAndDirectLookupResolveTheSameCanonicalKey() {
        let legID = UUID()
        let first = IdentificationPointKey(legID: legID, identificationPointID: UUID())
        let second = IdentificationPointKey(legID: legID, identificationPointID: UUID())
        let expected = NavigationTimingTargetKey(
            legID: legID,
            kind: .identificationPoint,
            targetID: second.identificationPointID
        )
        let presentation = AviationMapPresentation(
            waypoints: [], legs: [], activeLegIndex: 0, nextLegPreview: nil,
            endpointReferences: [], plannedDurationSeconds: 256, minuteMarkers: [],
            identificationPoints: [
                .init(id: first, name: "Identification Point 1", coordinate: .init(latitude: 0, longitude: 0), plannedElapsedSeconds: 90, isReached: true, committedETASeconds: nil),
                .init(id: second, name: "Identification Point 2", coordinate: .init(latitude: 1, longitude: 1), plannedElapsedSeconds: 180, isReached: false, committedETASeconds: nil)
            ],
            destinationTarget: .init(
                id: .init(legID: legID, kind: .destination, targetID: UUID()),
                name: "Destination", plannedElapsedSeconds: 256, committedETASeconds: nil
            )
        )

        #expect(presentation.nextETATarget(after: first)?.id == expected)
        #expect(presentation.timingTarget(for: expected)?.id == expected)
    }

    @Test func directTargetEditorReusesShortcutStateAndKeepsItsObservationSource() throws {
        let flight = try twoLegFlight(withIdentificationPointsOnBothLegs: true)
        var state = CockpitFeatureState()
        try state.accept(flight)
        try state.startLeg(at: Date(timeIntervalSince1970: 10_000))
        let session = try #require(state.session)
        let presentation = try AviationMapPresentationFactory().makePresentation(flight: flight, session: session)
        let point = try #require(presentation.identificationPoints.first)
        let target = try #require(presentation.nextETATarget(after: point.id))
        try state.reachIdentificationPoint(
            key: point.id,
            nextTarget: target,
            at: Date(timeIntervalSince1970: 10_015)
        )
        state.adjustPilotETA(targetKey: target.id, by: 5)
        state.commitPilotETA(targetKey: target.id)
        state.openPilotETAEditor(target: target)

        let etaState = try #require(state.session?.pilotETAState(targetKey: target.id))
        #expect(etaState.timingObservationKey == point.id)
        #expect(etaState.isEditing == false)
        #expect(etaState.draftSeconds == etaState.committedSeconds)
    }

    @Test func consecutiveLegIdentificationPointStateIsIsolated() throws {
        let flight = try twoLegFlight(withIdentificationPointsOnBothLegs: true)
        let originalFlight = flight
        var session = FlightSession(
            flightID: flight.id,
            legIDs: flight.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let start = Date(timeIntervalSince1970: 40_000)
        try session.startLeg(at: start)

        let firstPresentation = try AviationMapPresentationFactory().makePresentation(flight: flight, session: session)
        let firstPoint = try #require(firstPresentation.identificationPoints.first)
        #expect(firstPresentation.identificationPoints.count == 1)
        #expect(firstPoint.name == "Identification Point 1")
        let firstTarget = firstPresentation.destinationTarget.id
        let firstOffset = AviationMapCalloutOffset(x: 91, y: -63)
        let storedOffsets = [firstPoint.id: firstOffset]

        try session.reachIdentificationPoint(key: firstPoint.id, at: start.addingTimeInterval(16))
        session.initializePilotETA(targetKey: firstTarget, plannedElapsedSeconds: 40)
        session.adjustPilotETA(targetKey: firstTarget, by: 5)
        session.commitPilotETA(targetKey: firstTarget)
        session.showPilotETACheck(targetKey: firstTarget)
        try session.identifyDestination(at: start.addingTimeInterval(35))
        try session.reachCurrentWaypoint(at: start.addingTimeInterval(40))

        let secondPresentation = try AviationMapPresentationFactory().makePresentation(flight: flight, session: session)
        let secondPoint = try #require(secondPresentation.identificationPoints.first)
        #expect(secondPresentation.identificationPoints.count == 1)
        #expect(secondPoint.name == "Identification Point 1")
        #expect(firstPoint.id != secondPoint.id)
        #expect(firstPoint.id.legID != secondPoint.id.legID)
        #expect(secondPoint.isReached == false)
        #expect(secondPoint.committedETASeconds == nil)
        #expect(storedOffsets[secondPoint.id] == nil)
        #expect(session.pilotETAState(targetKey: secondPresentation.destinationTarget.id) == nil)
        #expect(session.pilotETAState(targetKey: firstTarget)?.committedSeconds == 45)
        #expect(session.pilotETAState(targetKey: firstTarget)?.isCheckResultVisible == true)
        #expect(session.identificationPointTiming(for: firstPoint.id) != nil)
        #expect(session.identificationPointTiming(for: secondPoint.id) == nil)
        #expect(Set(secondPresentation.identificationPoints.map(\.id.legID)) == [flight.legs[1].id])
        #expect(flight == originalFlight)
    }

    @Test func proportionalReferenceAndInvalidCases() throws {
        let reference = try #require(IdentificationPointTimingCalculator.referenceTargetElapsed(
            plannedReachedElapsed: 160,
            actualReachedElapsed: 173,
            plannedTargetElapsed: 256
        ))
        #expect(abs(reference - 276.8) < 0.000_001)
        let displayed = IdentificationPointTimingCalculator.displaySeconds(reference)
        #expect(displayed == 277)
        #expect(280 - displayed == 3)
        #expect(IdentificationPointTimingCalculator.referenceTargetElapsed(
            plannedReachedElapsed: 0, actualReachedElapsed: 173, plannedTargetElapsed: 256
        ) == nil)
        #expect(IdentificationPointTimingCalculator.referenceTargetElapsed(
            plannedReachedElapsed: nil, actualReachedElapsed: 173, plannedTargetElapsed: 256
        ) == nil)
        #expect(IdentificationPointTimingCalculator.referenceTargetElapsed(
            plannedReachedElapsed: 160, actualReachedElapsed: nil, plannedTargetElapsed: 256
        ) == nil)
        #expect(IdentificationPointTimingCalculator.referenceTargetElapsed(
            plannedReachedElapsed: 160, actualReachedElapsed: 173, plannedTargetElapsed: nil
        ) == nil)
    }

    private func representativeData() throws -> Data {
        let bundle = Bundle(for: FixtureLocator.self)
        let nestedURL = bundle.url(
            forResource: "representative",
            withExtension: "fplnav",
            subdirectory: "Fixtures/FPLNav/V5"
        )
        let url = nestedURL ?? bundle.url(forResource: "representative", withExtension: "fplnav")
        return try Data(contentsOf: #require(url))
    }

    private func representativeJSONObject() throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: representativeData()) as? [String: Any])
    }

    private func fixtureData(_ name: String, directory: String) throws -> Data {
        let bundle = Bundle(for: FixtureLocator.self)
        let nested = bundle.url(forResource: name, withExtension: "fplnav", subdirectory: "Fixtures/FPLNav/\(directory)")
        let flat = bundle.url(forResource: name, withExtension: "fplnav")
        return try Data(contentsOf: #require(nested ?? flat))
    }

    private func fixtureJSONObject(_ name: String, directory: String) throws -> [String: Any] {
        try #require(JSONSerialization.jsonObject(with: fixtureData(name, directory: directory)) as? [String: Any])
    }

    private func decode(_ object: [String: Any]) throws -> NavigationFlight {
        try FPLNavDecoder().decode(JSONSerialization.data(withJSONObject: object))
    }

    private func eligibleExecution(_ flight: NavigationFlight) throws -> NavigationExecution {
        guard case .eligible(let execution) = flight.execution else {
            throw FPLNavV7ValidationError(path: "execution", reason: "expected eligible execution")
        }
        return execution
    }

    private func emptyV7Flight() throws -> NavigationFlight {
        var object = try fixtureJSONObject("representative-v7", directory: "V7/Official")
        var navigation = try #require(object["navigation"] as? [String: Any])
        var route = try #require(navigation["route"] as? [String: Any])
        route["waypointOrder"] = []; route["waypoints"] = []; route["legs"] = []
        navigation["route"] = route
        navigation["identificationPoints"] = []; navigation["altitudeChanges"] = []
        navigation["radioFrequencyChanges"] = []; navigation["vorDmeReferences"] = []
        object["navigation"] = navigation
        var execution = try #require(object["execution"] as? [String: Any])
        execution["legs"] = []; execution["annotations"] = []; execution["vorDmeReferences"] = []
        execution["frequenciesByPhase"] = ["departure": [], "en-route": [], "arrival": []]
        object["execution"] = execution
        return try decode(object)
    }

    private func twoLegFlight(
        withImmediateChanges: Bool = false,
        withIdentificationPointsOnBothLegs: Bool = false
    ) throws -> NavigationFlight {
        var object = try fixtureJSONObject("representative-v7", directory: "V7/Official")
        var navigation = try #require(object["navigation"] as? [String: Any])
        var route = try #require(navigation["route"] as? [String: Any])
        var waypoints = try #require(route["waypoints"] as? [[String: Any]])
        var third = waypoints[1]
        let thirdID = "00000000-0000-4000-8000-000000000020"
        third["id"] = thirdID; third["name"] = "Third waypoint"
        third["position"] = ["latitude": 0.03, "longitude": 0.01]
        waypoints.append(third); route["waypoints"] = waypoints
        let firstID = try #require(waypoints[0]["id"] as? String)
        let secondWaypointID = try #require(waypoints[1]["id"] as? String)
        route["waypointOrder"] = [firstID, secondWaypointID, thirdID]
        var sourceLegs = try #require(route["legs"] as? [[String: Any]])
        var second = sourceLegs[0]
        let secondID = "00000000-0000-4000-8000-000000000021"
        second["id"] = secondID; second["departureWaypointId"] = secondWaypointID; second["arrivalWaypointId"] = thirdID
        sourceLegs.append(second); route["legs"] = sourceLegs
        navigation["route"] = route
        var execution = try #require(object["execution"] as? [String: Any])
        var legs = try #require(execution["legs"] as? [[String: Any]])
        var resolved = legs[0]; resolved["legId"] = secondID
        legs.append(resolved); execution["legs"] = legs
        if withIdentificationPointsOnBothLegs {
            let pointID = "00000000-0000-4000-8000-000000000024"
            var points = try #require(navigation["identificationPoints"] as? [[String: Any]])
            var point = points[0]
            point["id"] = pointID
            point["legId"] = secondID
            points.append(point)
            navigation["identificationPoints"] = points

            var annotations = try #require(execution["annotations"] as? [[String: Any]])
            var annotation = annotations[0]
            annotation["entityId"] = pointID
            annotation["legId"] = secondID
            annotation["position"] = ["latitude": 0.023, "longitude": 0.006]
            annotations.append(annotation)
            execution["annotations"] = annotations
        }
        if withImmediateChanges {
            let altitudeID = "00000000-0000-4000-8000-000000000022"
            let frequencyID = "00000000-0000-4000-8000-000000000023"
            var altitudeChanges = try #require(navigation["altitudeChanges"] as? [[String: Any]])
            var altitude = altitudeChanges[0]
            altitude["id"] = altitudeID
            altitude["legId"] = secondID
            altitude["anchor"] = ["kind": "leg-progress", "legProgress": 0]
            altitude["targetAltitudeFeet"] = 1500
            altitudeChanges.append(altitude)
            navigation["altitudeChanges"] = altitudeChanges

            var frequencyChanges = try #require(navigation["radioFrequencyChanges"] as? [[String: Any]])
            var frequency = frequencyChanges[0]
            frequency["id"] = frequencyID
            frequency["legId"] = secondID
            frequency["legProgress"] = 0
            frequency["service"] = ["name": "Next Control"]
            frequency["frequencyMhz"] = 120.6
            frequencyChanges.append(frequency)
            navigation["radioFrequencyChanges"] = frequencyChanges

            let departurePosition = try #require(waypoints[1]["position"] as? [String: Any])
            var annotations = try #require(execution["annotations"] as? [[String: Any]])
            var altitudeExecution = annotations[1]
            altitudeExecution["entityId"] = altitudeID
            altitudeExecution["legId"] = secondID
            altitudeExecution["position"] = departurePosition
            altitudeExecution["noWindTimeFromLegStartSeconds"] = 0
            altitudeExecution["withWindTimeFromLegStartSeconds"] = 0
            annotations.append(altitudeExecution)
            var frequencyExecution = annotations[4]
            frequencyExecution["entityId"] = frequencyID
            frequencyExecution["legId"] = secondID
            frequencyExecution["position"] = departurePosition
            frequencyExecution["noWindTimeFromLegStartSeconds"] = 0
            frequencyExecution["withWindTimeFromLegStartSeconds"] = 0
            annotations.append(frequencyExecution)
            execution["annotations"] = annotations
            var frequenciesByPhase = try #require(execution["frequenciesByPhase"] as? [String: Any])
            var enRoute = try #require(frequenciesByPhase["en-route"] as? [[String: Any]])
            enRoute.append([
                "id": "route:\(frequencyID)",
                "name": "Next Control",
                "frequencyMhz": 120.6,
                "source": "route"
            ])
            frequenciesByPhase["en-route"] = enRoute
            execution["frequenciesByPhase"] = frequenciesByPhase
        }
        object["navigation"] = navigation
        object["execution"] = execution
        return try decode(object)
    }

    private func summaryFlight() throws -> NavigationFlight {
        var object = try fixtureJSONObject("representative-v7", directory: "V7/Official")
        var execution = try #require(object["execution"] as? [String: Any])
        var legs = try #require(execution["legs"] as? [[String: Any]])
        var leg = legs[0]
        var noWind = try #require(leg["noWind"] as? [String: Any])
        noWind["plannedDurationSeconds"] = 382
        leg["noWind"] = noWind
        var withWind = try #require(leg["withWind"] as? [String: Any])
        withWind["plannedDurationSeconds"] = 382
        leg["withWind"] = withWind
        legs[0] = leg
        execution["legs"] = legs
        object["execution"] = execution
        return try decode(object)
    }
}

enum V7Mutation: String, CaseIterable, CustomStringConvertible, Sendable {
    case missingLeg, duplicateLeg, reorderedLeg, missingAnnotation, duplicateAnnotation
    case missingReference, duplicateReference, invalidCourse, invalidDuration, invalidAnnotationTime
    case absentWind, unexpectedWind, mismatchedWind, missingAutomaticElevation, inconsistentManualValues
    case invalidFrequency, missingRouteFrequency, missingUserFrequency, duplicatePhaseFrequency, unknownExecutionProperty

    var description: String { rawValue }

    func apply(to object: inout [String: Any]) throws {
        var navigation = try required(object["navigation"] as? [String: Any])
        var execution = try required(object["execution"] as? [String: Any])
        switch self {
        case .missingLeg:
            execution["legs"] = []
        case .duplicateLeg:
            var legs = try required(execution["legs"] as? [[String: Any]])
            legs.append(legs[0]); execution["legs"] = legs
        case .reorderedLeg:
            try makeTwoLegPlan(navigation: &navigation, execution: &execution)
            var legs = try required(execution["legs"] as? [[String: Any]])
            legs.swapAt(0, 1); execution["legs"] = legs
        case .missingAnnotation:
            var values = try required(execution["annotations"] as? [[String: Any]])
            values.removeLast(); execution["annotations"] = values
        case .duplicateAnnotation:
            var values = try required(execution["annotations"] as? [[String: Any]])
            values[1] = values[0]; execution["annotations"] = values
        case .missingReference:
            var values = try required(execution["vorDmeReferences"] as? [[String: Any]])
            values.removeLast(); execution["vorDmeReferences"] = values
        case .duplicateReference:
            var values = try required(execution["vorDmeReferences"] as? [[String: Any]])
            values[1] = values[0]; execution["vorDmeReferences"] = values
        case .invalidCourse:
            try mutateFirstLeg(&execution) { $0["trueCourseDegrees"] = 360 }
        case .invalidDuration:
            try mutateFirstLeg(&execution) { leg in
                var timing = try required(leg["noWind"] as? [String: Any]); timing["plannedDurationSeconds"] = 0; leg["noWind"] = timing
            }
        case .invalidAnnotationTime:
            var values = try required(execution["annotations"] as? [[String: Any]])
            values[0]["noWindTimeFromLegStartSeconds"] = 41; execution["annotations"] = values
        case .absentWind:
            try mutateFirstLeg(&execution) { $0.removeValue(forKey: "withWind") }
        case .unexpectedWind:
            var presentation = try required(navigation["presentation"] as? [String: Any])
            var log = try required(presentation["navigationLog"] as? [String: Any]); log["windEnabled"] = false
            presentation["navigationLog"] = log; navigation["presentation"] = presentation
        case .mismatchedWind:
            try mutateFirstLeg(&execution) { leg in
                var wind = try required(leg["withWind"] as? [String: Any])
                wind["effectiveWind"] = ["directionFromTrueDegrees": 90, "speedKnots": 1]; leg["withWind"] = wind
            }
        case .missingAutomaticElevation:
            var values = try required(execution["vorDmeReferences"] as? [[String: Any]])
            values[0].removeValue(forKey: "stationElevationFeetMsl"); execution["vorDmeReferences"] = values
        case .inconsistentManualValues:
            var values = try required(execution["vorDmeReferences"] as? [[String: Any]])
            values[1]["slantRangeNauticalMiles"] = 12.5; execution["vorDmeReferences"] = values
        case .invalidFrequency:
            var phases = try required(execution["frequenciesByPhase"] as? [String: Any])
            var values = try required(phases["departure"] as? [[String: Any]])
            values[0]["frequencyMhz"] = 1000; phases["departure"] = values; execution["frequenciesByPhase"] = phases
        case .missingRouteFrequency:
            var phases = try required(execution["frequenciesByPhase"] as? [String: Any]); phases["en-route"] = []; execution["frequenciesByPhase"] = phases
        case .missingUserFrequency:
            var context = try required(navigation["operationalContext"] as? [String: Any])
            context["frequencyEntries"] = [["id": "required", "phase": "departure", "name": "Required", "frequencyMhz": 123.4]]
            navigation["operationalContext"] = context
        case .duplicatePhaseFrequency:
            var phases = try required(execution["frequenciesByPhase"] as? [String: Any])
            var values = try required(phases["departure"] as? [[String: Any]]); values.append(values[0]); phases["departure"] = values; execution["frequenciesByPhase"] = phases
        case .unknownExecutionProperty:
            execution["invented"] = true
        }
        object["navigation"] = navigation
        object["execution"] = execution
    }

    private func mutateFirstLeg(_ execution: inout [String: Any], mutation: (inout [String: Any]) throws -> Void) throws {
        var legs = try required(execution["legs"] as? [[String: Any]])
        try mutation(&legs[0]); execution["legs"] = legs
    }

    private func makeTwoLegPlan(navigation: inout [String: Any], execution: inout [String: Any]) throws {
        var route = try required(navigation["route"] as? [String: Any])
        var waypoints = try required(route["waypoints"] as? [[String: Any]])
        var third = waypoints[1]
        let thirdID = "00000000-0000-4000-8000-000000000020"
        third["id"] = thirdID
        third["position"] = ["latitude": 0.03, "longitude": 0.01]
        waypoints.append(third); route["waypoints"] = waypoints
        let firstID = try required(waypoints[0]["id"] as? String)
        let secondWaypointID = try required(waypoints[1]["id"] as? String)
        route["waypointOrder"] = [firstID, secondWaypointID, thirdID]
        var sourceLegs = try required(route["legs"] as? [[String: Any]])
        var second = sourceLegs[0]
        let secondID = "00000000-0000-4000-8000-000000000021"
        second["id"] = secondID; second["departureWaypointId"] = secondWaypointID; second["arrivalWaypointId"] = thirdID
        sourceLegs.append(second); route["legs"] = sourceLegs; navigation["route"] = route
        var legs = try required(execution["legs"] as? [[String: Any]])
        var resolved = legs[0]; resolved["legId"] = secondID; legs.append(resolved); execution["legs"] = legs
    }

    private func required<T>(_ value: T?) throws -> T {
        guard let value else { throw FPLNavV7ValidationError(path: "test", reason: "fixture shape") }
        return value
    }
}
