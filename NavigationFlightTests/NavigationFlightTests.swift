//
//  NavigationFlightTests.swift
//  NavigationFlightTests
//
//  Created by Jonathan Bensaid on 10/10/2026.
//

import Foundation
import Testing
import UIKit
@testable import NavigationFlight

private final class FixtureLocator {}

struct NavigationFlightTests {
    @Test func flightsHaveDistinctIdentityAndShareTheirSourceFlightPlanIdentity() throws {
        let flightPlan = try FPLNavDecoder().decode(try representativeData())
        let firstFlightID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let secondFlightID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))

        let firstFlight = Flight(
            id: firstFlightID,
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        let secondFlight = Flight(
            id: secondFlightID,
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )

        #expect(firstFlight.id != secondFlight.id)
        #expect(firstFlight.flightPlanID == flightPlan.id)
        #expect(secondFlight.flightPlanID == flightPlan.id)
    }

    @Test(arguments: [
        (-721, 359), (-360, 360), (-1, 359), (0, 360), (360, 360), (361, 1), (721, 1)
    ])
    func headingNormalization(input: Int, expected: Int) {
        #expect(Flight.normalizedHeading(input) == expected)
    }

    @Test func pilotHeadingHistoryAndLegLifecycleAreScoped() throws {
        let firstLegID = UUID()
        let secondLegID = UUID()
        let pointID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [firstLegID, secondLegID],
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: startedAt)

        flight.openPilotHeadingEditor(baselineDegrees: 81)
        flight.adjustPilotHeading(by: 4)
        flight.commitPilotHeading()
        flight.openPilotHeadingEditor(baselineDegrees: 81)
        flight.adjustPilotHeading(by: 2)
        flight.commitPilotHeading()
        flight.openPilotHeadingEditor(baselineDegrees: 81)
        flight.adjustPilotHeading(by: 2)

        let pointKey = IdentificationPointKey(legID: firstLegID, identificationPointID: pointID)
        try flight.reachIdentificationPoint(
            key: pointKey,
            orderedActiveLegPointKeys: [pointKey],
            at: startedAt.addingTimeInterval(60)
        )
        let afterPoint = try #require(flight.pilotHeadingState(for: firstLegID))
        #expect(afterPoint.commits.map(\.degrees) == [85, 87])
        #expect(afterPoint.operationalDegrees == 87)
        #expect(afterPoint.draftDegrees == 89)
        #expect(afterPoint.isEditing)

        try flight.reachCurrentWaypoint(
            orderedActiveLegPointKeys: [pointKey],
            at: startedAt.addingTimeInterval(120)
        )
        let completed = try #require(flight.pilotHeadingState(for: firstLegID))
        #expect(completed.commits.map(\.degrees) == [85, 87])
        #expect(completed.operationalDegrees == 87)
        #expect(completed.draftDegrees == 87)
        #expect(!completed.isEditing)
        #expect(flight.pilotHeadingState(for: secondLegID) == nil)

        flight.openPilotHeadingEditor(baselineDegrees: 143)
        let successor = try #require(flight.pilotHeadingState(for: secondLegID))
        #expect(successor.baselineDegrees == 143)
        #expect(successor.draftDegrees == 143)
        #expect(successor.commits.isEmpty)
    }

    @Test func representativeV5MapsIntoDomain() throws {
        let flightPlan = try FPLNavDecoder().decode(try representativeData())

        #expect(flightPlan.title == "Coastal training navigation")
        #expect(flightPlan.waypoints.map(\.name) == ["BAZRA", "Visual checkpoint"])
        #expect(flightPlan.legs.count == 1)
        #expect(flightPlan.legs[0].departure.id == flightPlan.waypoints[0].id)
        #expect(flightPlan.legs[0].arrival.id == flightPlan.waypoints[1].id)
        #expect(flightPlan.waypoints[0].position == WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.5))
        #expect(flightPlan.waypoints[1].plannedAltitude == AltitudeFeet(value: 3500))

        // V5 explicitly distinguishes east-positive magnetic variation and true wind direction.
        #expect(flightPlan.parameters.magneticVariationEast == Degrees(value: 5))
        #expect(flightPlan.operationalContext.defaultWind?.directionFromTrue == Degrees(value: 270))

        #expect(flightPlan.identificationPoints[0].progress == LegProgress(fraction: 0.4))
        #expect(flightPlan.altitudeChanges.map(\.targetAltitude.value) == [4000, 2500, 3200])
        #expect(flightPlan.frequencyChanges[0].service.name == "Tel Aviv Control")
        #expect(flightPlan.frequencyChanges[0].frequency == FrequencyMHz(value: 120.5))
        #expect(flightPlan.vorDmeReferences.count == 2)
        #expect(flightPlan.vorDmeReferences[0].calculation == .automatic)
        #expect(
            flightPlan.vorDmeReferences[1].calculation
                == .manual(radial: Degrees(value: 270), distance: NauticalMiles(value: 12.4))
        )
        #expect(flightPlan.operationalContext.departureAerodrome?.icao == "LLHZ")
        #expect(flightPlan.operationalContext.arrivalAerodrome?.localCode == "LLMG")
        #expect(flightPlan.plannedNavigation == .unavailableLegacyFormat(version: 5))
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

        let flightPlan = try FPLNavDecoder().decode(try JSONSerialization.data(withJSONObject: object))
        #expect(flightPlan.waypoints.count == 2)
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

        let flightPlan = try FPLNavDecoder().decode(try JSONSerialization.data(withJSONObject: object))
        #expect(flightPlan.altitudeChanges[0].anchor == .legProgress(LegProgress(fraction: 0.25)))
        #expect(flightPlan.frequencyChanges[0].progress == LegProgress(fraction: 0.25))
    }

    @Test func officialV7MapsSavedExecutionWithoutRecalculation() throws {
        var object = try fixtureJSONObject("representative-v7", directory: "V7/Official")
        var plannedNavigation = try #require(object["execution"] as? [String: Any])
        var legs = try #require(plannedNavigation["legs"] as? [[String: Any]])
        legs[0]["trueCourseDegrees"] = 123.456789
        legs[0]["distanceNauticalMiles"] = 9.87654321
        legs[0]["initialAltitudeFeetMsl"] = 4100
        var withWind = try #require(legs[0]["withWind"] as? [String: Any])
        withWind["trueHeadingDegrees"] = 222.25
        legs[0]["withWind"] = withWind
        plannedNavigation["legs"] = legs
        var references = try #require(plannedNavigation["vorDmeReferences"] as? [[String: Any]])
        references[0]["magneticRadialFromDegrees"] = 17.125
        references[0]["slantRangeNauticalMiles"] = 8.7654321
        plannedNavigation["vorDmeReferences"] = references
        object["execution"] = plannedNavigation

        let flightPlan = try decode(object)
        let saved = try eligiblePlannedNavigation(flightPlan)
        #expect(saved.calculationVersion == "synthetic-conformance-1")
        #expect(saved.altitudeReference == .msl)
        #expect(saved.legs[0].trueCourse.value == 123.456789)
        #expect(saved.legs[0].groundDistance.value == 9.87654321)
        #expect(saved.legs[0].initialAltitudeMsl.value == 4100)
        #expect(flightPlan.waypoints[0].plannedAltitude.value == 2000)
        #expect(saved.legs[0].withWind?.trueHeading.value == 222.25)
        #expect(saved.vorDmeReferences[0].magneticRadialFrom.value == 17.125)
        #expect(saved.vorDmeReferences[0].slantRange.value == 8.7654321)
        #expect(saved.legs[0].noWind.groundSpeed == Knots(value: 90))
    }

    @Test(arguments: ["editor-wind", "editor-no-wind", "editor-calm"])
    func editorV7VectorsDecode(_ name: String) throws {
        let flightPlan = try FPLNavDecoder().decode(try fixtureData(name, directory: "V7/Editor"))
        let plannedNavigation = try eligiblePlannedNavigation(flightPlan)
        #expect(plannedNavigation.legs.count == 1)
        #expect(plannedNavigation.annotations.count == 5)
        #expect(plannedNavigation.vorDmeReferences.count == 2)
        #expect(plannedNavigation.legs[0].initialAltitudeMsl.value == 3000)
        #expect(flightPlan.waypoints[0].plannedAltitude.value == 3000)
        #expect(flightPlan.waypoints[1].plannedAltitude.value == 3500)
        #expect(flightPlan.altitudeChanges.map(\.targetAltitude.value) == [4000, 2500, 3200])
        #expect(plannedNavigation.annotations[0].position.longitudeDegrees == 34.58082289823876)
        #expect(plannedNavigation.annotations[0].noWindTimeFromLegStartSeconds == 238)
        #expect(plannedNavigation.vorDmeReferences[1].source == .manual)
        #expect(plannedNavigation.vorDmeReferences[0].slantRange.value == 20.08342967034671)
        #expect(plannedNavigation.vorDmeReferences[1].magneticRadialFrom.value == 270)
        #expect(plannedNavigation.vorDmeReferences[1].slantRange.value == 12.4)
        #expect(plannedNavigation.frequenciesByPhase[.departure]?.map(\.id) == [
            "user:handoff-override", "vor-dme:00000000-0000-4000-8000-00000000000a",
            "catalog:herzlia:secondary", "catalog:herzlia:cpt"
        ])
        #expect(plannedNavigation.frequenciesByPhase[.departure]?.first?.role == "Override")

        if name == "editor-no-wind" {
            #expect(plannedNavigation.defaultMode == .noWind)
            #expect(plannedNavigation.legs[0].withWind == nil)
            #expect(plannedNavigation.annotations[0].withWindTimeFromLegStartSeconds == nil)
        } else {
            #expect(plannedNavigation.defaultMode == .wind)
            #expect(plannedNavigation.legs[0].withWind != nil)
            #expect(plannedNavigation.annotations[0].withWindTimeFromLegStartSeconds == (name == "editor-wind" ? 222 : 238))
        }
        if name == "editor-wind" {
            #expect(plannedNavigation.legs[0].withWind?.effectiveWind == Wind(directionFromTrue: .init(value: 250), speed: .init(value: 8)))
            #expect(plannedNavigation.legs[0].withWind?.windCorrection.value == -2.395800157284725)
        }
        if name == "editor-calm" {
            #expect(plannedNavigation.legs[0].withWind?.effectiveWind.speed.value == 0)
            #expect(plannedNavigation.legs[0].withWind?.trueHeading.value == plannedNavigation.legs[0].trueCourse.value)
        }
    }

    @Test func validEmptyV7IsDecodedButNotFlightEligible() throws {
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
        var plannedNavigation = try #require(object["execution"] as? [String: Any])
        plannedNavigation["legs"] = []
        plannedNavigation["annotations"] = []
        plannedNavigation["vorDmeReferences"] = []
        plannedNavigation["frequenciesByPhase"] = ["departure": [], "en-route": [], "arrival": []]
        object["execution"] = plannedNavigation

        let flightPlan = try decode(object)
        #expect(!flightPlan.plannedNavigation.isFlightEligible)
        guard case .emptyPlan(let saved) = flightPlan.plannedNavigation else { Issue.record("Expected empty V7 execution"); return }
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
        let flightPlan = try FPLNavDecoder().decode(try fixtureData(name, directory: "V7/Editor"))
        let plannedNavigation = try eligiblePlannedNavigation(flightPlan)
        let adapter = CockpitPresentationAdapter()
        let noWind = try adapter.makePresentation(flightPlan: flightPlan, legIndex: 0, mode: .noWind)

        #expect(noWind.magneticCourseDegrees == 35.23764544187969)
        #expect(noWind.magneticHeadingDegrees == nil)
        #expect(noWind.groundSpeedKnots == 95)
        #expect(noWind.legDurationSeconds == 596)
        #expect(noWind.initialAltitudeFeetMsl == 3000)
        #expect(noWind.destinationCrossingAltitudeFeet == 3500)
        #expect(noWind.routeEvents[0].id == plannedNavigation.annotations[0].entityID)
        #expect(noWind.routeEvents[0].entityIDs == [plannedNavigation.annotations[0].entityID, plannedNavigation.annotations[3].entityID])
        #expect(noWind.routeEvents[0].kinds == [.identificationPoint, .altitudeChange])
        #expect(noWind.routeEvents[0].position == plannedNavigation.annotations[0].position)
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
                try adapter.makePresentation(flightPlan: flightPlan, legIndex: 0, mode: .wind)
            }
        } else {
            let wind = try adapter.makePresentation(flightPlan: flightPlan, legIndex: 0, mode: .wind)
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
        let flightPlanID = UUID()
        let legIDs = [UUID(), UUID(), UUID()]
        let flight = Flight(
            flightPlanID: flightPlanID,
            legIDs: legIDs,
            activeLegIndex: 2,
            executionMode: .wind
        )

        #expect(flight.flightPlanID == flightPlanID)
        #expect(flight.legIDs == legIDs)
        #expect(flight.activeLegIndex == 2)
        #expect(flight.executionMode == .wind)
        #expect(flight.legState == .ready)
        #expect(flight.legStartedAt == nil)
    }

    @Test func startingLegRecordsTimestampAndDerivesElapsedTime() throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .noWind
        )

        try flight.startLeg(at: startedAt)
        #expect(flight.legState == .active)
        #expect(flight.legStartedAt == startedAt)
        #expect(try #require(flight.elapsedTime(at: startedAt.addingTimeInterval(37))) == 37)
    }

    @Test func startingActiveLegDoesNotReplaceOriginalTimestamp() throws {
        let originalStart = Date(timeIntervalSince1970: 1_000)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .wind
        )

        try flight.startLeg(at: originalStart)
        #expect(throws: Flight.TransitionError.legAlreadyStarted(0)) {
            try flight.startLeg(at: originalStart.addingTimeInterval(20))
        }
        #expect(flight.legStartedAt == originalStart)
    }

    @Test func startingLegDoesNotMutateImportedPlannedNavigation() throws {
        let flightPlan = try FPLNavDecoder().decode(
            try fixtureData("editor-wind", directory: "V7/Editor")
        )
        let originalFlight = flightPlan
        let originalPlannedNavigation = try eligiblePlannedNavigation(flightPlan)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: originalPlannedNavigation.defaultMode
        )

        try flight.startLeg(at: Date(timeIntervalSince1970: 1_000))

        #expect(flightPlan == originalFlight)
        #expect(try eligiblePlannedNavigation(flightPlan) == originalPlannedNavigation)
        #expect(flight.executionMode == originalPlannedNavigation.defaultMode)
    }

    @Test func featureStartIsAtomicAndPreservesOriginalStartAfterDuplicateCommand() throws {
        let flightPlan = try twoLegFlight()
        let originalStart = Date(timeIntervalSince1970: 1_000)
        var state = CockpitFeatureState()
        try state.accept(flightPlan)

        try state.startLeg(at: originalStart)
        let startedState = state

        #expect(throws: Flight.TransitionError.legAlreadyStarted(0)) {
            try state.startLeg(at: originalStart.addingTimeInterval(20))
        }
        #expect(state == startedState)
        #expect(state.flight?.legTimings.count == 1)
        #expect(state.flight?.legStartedAt == originalStart)
        #expect(state.activeLegStartChecklist?.legID == flightPlan.legs[0].id)
    }

    @Test func positionCheckLifecycleNeverMutatesFlightContracts() throws {
        let flightPlan = try twoLegFlight()
        var cockpit = CockpitFeatureState()
        try cockpit.accept(flightPlan)
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1_000))
        let authoritativeFlight = try #require(cockpit.flight)
        let sample = AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.8),
            observedAt: Date(timeIntervalSince1970: 1_001),
            horizontalAccuracyMeters: 35,
            trueCourseDegrees: 72,
            courseAccuracyDegrees: 5,
            groundSpeedMetersPerSecond: 40,
            speedAccuracyMetersPerSecond: 1
        )

        let active = PositionCheckState.idle.transition(
            .holdCompleted(availability: .ready(sample), restoration: .empty),
            now: .zero
        ).state
        _ = active.transition(
            .locationAvailabilityChanged(.unavailable(.signalLost)),
            now: .seconds(2)
        )
        let acquiring = PositionCheckState.idle.transition(
            .holdCompleted(availability: .acquiring, restoration: .empty),
            now: .seconds(3)
        ).state
        let request = try #require(acquiring.acquisitionRequest)
        _ = acquiring.transition(.deadlineReached(request.generation), now: .seconds(13))
        _ = active.transition(.end, now: .seconds(4))

        #expect(cockpit.flight == authoritativeFlight)
        #expect(cockpit.flight?.activeLegIndex == 0)
        #expect(cockpit.flight?.legStartedAt == Date(timeIntervalSince1970: 1_000))
    }

    @Test func elapsedTimeIncludesIntervalsWithoutUITimerUpdates() throws {
        let startedAt = Date(timeIntervalSince1970: 10_000)
        let returnedToForegroundAt = startedAt.addingTimeInterval(187)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .noWind
        )

        try flight.startLeg(at: startedAt)

        #expect(flight.elapsedTime(at: returnedToForegroundAt) == 187)
        #expect(flight.legStartedAt == startedAt)
    }

    @Test func automaticWaypointProgressionUsesOneAtomicTimestamp() throws {
        let legIDs = [UUID(), UUID()]
        let startedAt = Date(timeIntervalSince1970: 36_000)
        let reachedAt = Date(timeIntervalSince1970: 36_314)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: legIDs,
            activeLegIndex: 0,
            executionMode: .noWind,
            progressionPolicy: .automaticNextLeg
        )

        try flight.startLeg(at: startedAt)
        try flight.reachCurrentWaypoint(at: reachedAt)

        #expect(flight.activeLegIndex == 1)
        #expect(flight.legState == .active)
        #expect(flight.legTimings[0].legID == legIDs[0])
        #expect(flight.legTimings[0].reachedAt == reachedAt)
        #expect(flight.legTimings[0].actualElapsedDuration == 314)
        #expect(flight.legTimings[1].startedAt == reachedAt)
        #expect(flight.legTimings[0].reachedAt == flight.legTimings[1].startedAt)
        #expect(flight.legStartedAt == reachedAt)
    }

    @Test func destinationIdentificationRecordsOnceWithoutChangingActiveTiming() throws {
        let startedAt = Date(timeIntervalSince1970: 100)
        let identifiedAt = Date(timeIntervalSince1970: 140)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID(), UUID()],
            activeLegIndex: 0,
            executionMode: .wind
        )
        try flight.startLeg(at: startedAt)

        try flight.identifyDestination(at: identifiedAt)

        #expect(flight.destinationIdentifiedAt == identifiedAt)
        #expect(flight.legTimings[0].destinationIdentifiedAt == identifiedAt)
        #expect(flight.legStartedAt == startedAt)
        #expect(flight.elapsedTime(at: Date(timeIntervalSince1970: 175)) == 75)
        #expect(flight.activeLegIndex == 0)
        #expect(flight.legState == .active)
        #expect(throws: Flight.TransitionError.destinationAlreadyIdentified(0)) {
            try flight.identifyDestination(at: Date(timeIntervalSince1970: 160))
        }
        #expect(flight.destinationIdentifiedAt == identifiedAt)
    }

    @Test func reachingWithoutIdentificationDoesNotFabricateIdentification() throws {
        let reachedAt = Date(timeIntervalSince1970: 200)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID(), UUID()],
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: Date(timeIntervalSince1970: 100))

        try flight.reachCurrentWaypoint(at: reachedAt)

        #expect(flight.legTimings[0].destinationIdentifiedAt == nil)
        #expect(flight.legTimings[0].reachedAt == reachedAt)
        #expect(flight.legTimings[1].startedAt == reachedAt)
    }

    @Test func identifyThenReachPreservesDistinctObservationsAndActualETA() throws {
        let startedAt = Date(timeIntervalSince1970: 100)
        let identifiedAt = Date(timeIntervalSince1970: 140)
        let reachedAt = Date(timeIntervalSince1970: 175)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: startedAt)

        try flight.identifyDestination(at: identifiedAt)
        try flight.reachCurrentWaypoint(at: reachedAt)

        let timing = try #require(flight.legTimings.first)
        #expect(timing.destinationIdentifiedAt == identifiedAt)
        #expect(timing.reachedAt == reachedAt)
        #expect(timing.actualElapsedDuration == 75)
        #expect(flight.legState == .completed)
        #expect(flight.legStartedAt == startedAt)
    }

    @Test func manualWaypointProgressionWaitsForASecondStartTimestamp() throws {
        let reachedAt = Date(timeIntervalSince1970: 36_314)
        let secondStart = Date(timeIntervalSince1970: 36_400)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID(), UUID()],
            activeLegIndex: 0,
            executionMode: .wind,
            progressionPolicy: .manualNextLeg
        )

        try flight.startLeg(at: Date(timeIntervalSince1970: 36_000))
        try flight.reachCurrentWaypoint(at: reachedAt)

        #expect(flight.activeLegIndex == 1)
        #expect(flight.legState == .ready)
        #expect(flight.legStartedAt == nil)
        #expect(flight.legTimings.count == 1)

        try flight.startLeg(at: secondStart)
        #expect(flight.legState == .active)
        #expect(flight.legStartedAt == secondStart)
    }

    @Test func waypointCannotBeReachedWhileReady() {
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .noWind
        )

        #expect(throws: Flight.TransitionError.legNotActive) {
            try flight.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 100))
        }
        #expect(flight.legTimings.isEmpty)
    }

    @Test func duplicateFinalWaypointDoesNotOverwriteRecordedTimestamp() throws {
        let reachedAt = Date(timeIntervalSince1970: 200)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: Date(timeIntervalSince1970: 100))
        try flight.reachCurrentWaypoint(at: reachedAt)

        #expect(throws: Flight.TransitionError.waypointAlreadyReached(0)) {
            try flight.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 300))
        }
        #expect(flight.legTimings[0].reachedAt == reachedAt)
        #expect(flight.activeLegIndex == 0)
        #expect(flight.legState == .completed)
    }

    @Test func progressionDoesNotMutateImportedPlannedNavigation() throws {
        let flightPlan = try twoLegFlight()
        let originalFlight = flightPlan
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )

        try flight.startLeg(at: Date(timeIntervalSince1970: 100))
        try flight.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 200))

        #expect(flightPlan == originalFlight)
        #expect(flight.activeLegIndex == 1)
    }

    @Test func cockpitFeatureStateAdvancesPresentationInManualMode() throws {
        let flightPlan = try twoLegFlight()
        var state = CockpitFeatureState(progressionPolicy: .manualNextLeg)
        try state.accept(flightPlan)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))
        try state.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 200))

        let flight = try #require(state.flight)
        let cockpit = try CockpitPresentationAdapter().makePresentation(
            flightPlan: flightPlan,
            legIndex: state.selectedLegIndex,
            mode: state.mode
        )
        let map = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: flight
        )

        #expect(state.selectedLegIndex == 1)
        #expect(flight.legState == .ready)
        #expect(flight.legStartedAt == nil)
        #expect(cockpit.origin == flightPlan.legs[1].departure.name)
        #expect(cockpit.destination == flightPlan.legs[1].arrival.name)
        #expect(map.activeLeg?.id == flightPlan.legs[1].id)
        #expect(map.nextLegPreview == nil)
        #expect(map.readyFocusTarget == map.activeLeg?.from)
    }

    @Test func nextLegPreparationUsesSavedResolvedValuesAndIsAbsentOnFinalLeg() throws {
        let flightPlan = try twoLegFlight()
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let adapter = CockpitPresentationAdapter()

        let next = try #require(try adapter.makeNextLegPreparation(flightPlan: flightPlan, flight: flight))
        #expect(next.legIndex == 1)
        #expect(next.direction == .heading(355))
        #expect(next.initialAltitudeFeetMsl == 2000)
        #expect(next.immediateAltitudeFeetMsl == nil)
        #expect(next.immediateFrequencyChange == nil)

        try flight.startLeg(at: Date(timeIntervalSince1970: 100))
        try flight.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 140))
        #expect(try adapter.makeNextLegPreparation(flightPlan: flightPlan, flight: flight) == nil)
    }

    @Test func nextLegPreparationLabelsSavedCourseWhenNoHeadingExists() throws {
        let flightPlan = try twoLegFlight()
        let flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )

        let next = try #require(
            try CockpitPresentationAdapter().makeNextLegPreparation(flightPlan: flightPlan, flight: flight)
        )
        #expect(next.direction == .course(355))
    }

    @Test func nextLegPreparationUsesExplicitSavedStartChanges() throws {
        let flightPlan = try twoLegFlight(withImmediateChanges: true)
        let flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )

        let next = try #require(
            try CockpitPresentationAdapter().makeNextLegPreparation(flightPlan: flightPlan, flight: flight)
        )
        #expect(next.immediateAltitudeFeetMsl == 1500)
        #expect(next.immediateFrequencyChange == .init(service: "Next Control", frequencyMHz: 120.6))
    }

    @Test func previousLegSummaryUsesSavedValuesAndSessionTiming() throws {
        let flightPlan = try summaryFlight()
        let originalFlight = flightPlan
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let adapter = CockpitPresentationAdapter()
        #expect(try adapter.makePreviousLegSummary(flightPlan: flightPlan, flight: flight) == nil)

        try flight.startLeg(at: Date(timeIntervalSince1970: 1_000))
        try flight.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 1_375))
        let summary = try #require(try adapter.makePreviousLegSummary(flightPlan: flightPlan, flight: flight))

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
        #expect(summary.targets.map(\.name) == ["IP1", flightPlan.legs[0].arrival.name])
        if case .passedWithoutReport = summary.targets[0].outcome {
            // Expected: completing the leg retains no fabricated actual ETA for an unreported point.
        } else {
            Issue.record("Expected the unreported target to be passed without report")
        }
        #expect(summary.targets.allSatisfy { $0.referenceETADisclosures.isEmpty })
        #expect(summary.headingHistory.baselineDegrees == 355)
        #expect(summary.headingHistory.commits.isEmpty)
        #expect(summary.headingHistory.operationalDegrees == 355)
        #expect(flightPlan == originalFlight)
    }

    @Test func previousLegHistoryProjectsTargetsETACommitOrderDisclosuresAndHeadingCommits() throws {
        let flightPlan = try FPLNavDecoder().decode(try fixtureData("editor-wind", directory: "V7/Editor"))
        let start = Date(timeIntervalSince1970: 10_000)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let map = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        let points = map.identificationPoints
        let first = try #require(points.first)
        let reported = try #require(points.last)
        let target = NavigationTimingTargetKey(
            legID: reported.id.legID,
            kind: .identificationPoint,
            targetID: reported.id.identificationPointID
        )

        try flight.startLeg(at: start)
        flight.initializePilotETA(targetKey: target, plannedElapsedSeconds: reported.plannedElapsedSeconds)
        flight.adjustPilotETA(targetKey: target, by: 5)
        flight.commitPilotETA(targetKey: target)
        flight.beginEditingPilotETA(targetKey: target)
        flight.adjustPilotETA(targetKey: target, by: 5)
        flight.commitPilotETA(targetKey: target)
        let didShowReference = flight.showPilotETACheck(
            targetKey: target,
            observationKey: first.id,
            plannedObservationElapsed: TimeInterval(first.plannedElapsedSeconds),
            actualObservationElapsed: TimeInterval(first.plannedElapsedSeconds + 10),
            plannedTargetElapsed: TimeInterval(reported.plannedElapsedSeconds)
        )
        #expect(didShowReference)
        flight.openPilotHeadingEditor(baselineDegrees: 355)
        flight.adjustPilotHeading(by: 2)
        flight.commitPilotHeading()
        flight.openPilotHeadingEditor(baselineDegrees: 355)
        flight.adjustPilotHeading(by: 3)
        flight.commitPilotHeading()
        try flight.reachIdentificationPoint(
            key: reported.id,
            orderedActiveLegPointKeys: points.map(\.id),
            at: start.addingTimeInterval(TimeInterval(reported.plannedElapsedSeconds + 14))
        )
        try flight.reachCurrentWaypoint(
            at: start.addingTimeInterval(TimeInterval(map.plannedDurationSeconds + 8))
        )

        let summary = try #require(
            try CockpitPresentationAdapter().makePreviousLegSummary(flightPlan: flightPlan, flight: flight)
        )
        #expect(summary.targets.map(\.name) == points.map(\.name) + [flightPlan.legs[0].arrival.name])
        let initialRevision = IdentificationPointTimingCalculator.roundToNearestFiveSeconds(
            reported.plannedElapsedSeconds
        )
        #expect(summary.targets.last(where: { $0.id == target })?.revisedETACommits == [
            initialRevision + 5,
            initialRevision + 10
        ])
        #expect(summary.targets.last(where: { $0.id == target })?.referenceETADisclosures.count == 1)
        if case .reached(let actual, let difference) = summary.targets[0].outcome {
            #expect(actual == reported.plannedElapsedSeconds + 14)
            #expect(difference == actual - (initialRevision + 10))
        } else {
            Issue.record("Expected the reported target to retain actual ETA and signed difference")
        }
        #expect(summary.headingHistory.commits == [357, 360])
        #expect(summary.headingHistory.operationalDegrees == 360)
    }

    @Test func previousLegSummaryUsesCompletedLegRevisedDestinationETAAsComparisonBasis() throws {
        let flightPlan = try summaryFlight()
        let originalFlight = flightPlan
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let target = NavigationTimingTargetKey(
            legID: flightPlan.legs[0].id,
            kind: .destination,
            targetID: flightPlan.legs[0].arrival.id
        )
        flight.initializePilotETA(targetKey: target, plannedElapsedSeconds: 382)
        for _ in 0..<4 { flight.adjustPilotETA(targetKey: target, by: 5) }
        flight.commitPilotETA(targetKey: target)
        try flight.startLeg(at: Date(timeIntervalSince1970: 1_000))
        try flight.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 1_407))

        let summary = try #require(
            try CockpitPresentationAdapter().makePreviousLegSummary(flightPlan: flightPlan, flight: flight)
        )
        #expect(summary.plannedDurationSeconds == 382)
        #expect(summary.revisedETASeconds == 400)
        #expect(summary.actualDurationSeconds == 407)
        #expect(summary.deltaSeconds == 7)
        #expect(CockpitPresentationFormatter.signedDuration(summary.deltaSeconds) == "+00:07")
        #expect(flightPlan == originalFlight)
    }

    @Test func previousLegSummaryOnlyExposesMostRecentlyCompletedLeg() throws {
        let flightPlan = try twoLegFlight()
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        try flight.startLeg(at: Date(timeIntervalSince1970: 100))
        try flight.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 140))
        try flight.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 180))

        let summary = try #require(
            try CockpitPresentationAdapter().makePreviousLegSummary(flightPlan: flightPlan, flight: flight)
        )
        #expect(summary.legIndex == 1)
        #expect(summary.origin == flightPlan.legs[1].departure.name)
        #expect(summary.destination == flightPlan.legs[1].arrival.name)
    }

    @Test func advancingToSecondLegPreservesFirstLegRevisedETAHistoricalComparison() throws {
        let flightPlan = try twoLegFlight()
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let map = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        let planned = map.destinationTarget.plannedElapsedSeconds
        flight.initializePilotETA(targetKey: map.destinationTarget.id, plannedElapsedSeconds: planned)
        flight.adjustPilotETA(targetKey: map.destinationTarget.id, by: 10)
        flight.commitPilotETA(targetKey: map.destinationTarget.id)
        let revised = try #require(flight.committedPilotETA(targetKey: map.destinationTarget.id))
        let start = Date(timeIntervalSince1970: 2_000)
        try flight.startLeg(at: start)
        try flight.reachCurrentWaypoint(at: start.addingTimeInterval(TimeInterval(revised + 2)))

        #expect(flight.activeLegIndex == 1)
        let summary = try #require(
            try CockpitPresentationAdapter().makePreviousLegSummary(flightPlan: flightPlan, flight: flight)
        )
        #expect(summary.legIndex == 0)
        #expect(summary.plannedDurationSeconds == planned)
        #expect(summary.revisedETASeconds == revised)
        #expect(summary.actualDurationSeconds == revised + 2)
        #expect(summary.deltaSeconds == 2)
    }

    @Test func startingFirstLegCreatesPendingChecklistWithoutChangingTimingOrPlannedNavigation() throws {
        let flightPlan = try twoLegFlight()
        let originalFlight = flightPlan
        let startedAt = Date(timeIntervalSince1970: 1_000)
        var state = CockpitFeatureState()
        try state.accept(flightPlan)

        try state.startLeg(at: startedAt)

        let checklist = try #require(state.activeLegStartChecklist)
        #expect(checklist.legID == flightPlan.legs[0].id)
        #expect(checklist.reviewState == .pending)
        #expect(checklist.presentationState == .expanded)
        #expect(checklist.phaseState == .available)
        #expect(state.flight?.legStartedAt == startedAt)
        #expect(state.flight?.elapsedTime(at: startedAt.addingTimeInterval(17)) == 17)
        #expect(state.flightPlan == originalFlight)
    }

    @Test func builtInLegStartTemplateDefinesTzeKivunAndGamadWithoutFlightValues() throws {
        let template = LegStartChecklistTemplate.tzeKivun
        let gamad = try #require(template.cruiseSection)
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

    @Test func bundledLegStartTemplatesAreValidatedAndEquivalent() throws {
        let templates = LegStartChecklistTemplate.bundled

        #expect(templates.map(\.id) == [
            "tze-kivun-gamad",
            "establish-heading-cruise-check"
        ])
        for template in templates {
            #expect(try template.validated() == template)
            #expect(template.sections.flatMap(\.items).map(\.kind) == [
                .timer, .direction, .altitude, .speedAndEngine, .reporting
            ])
        }
        #expect(templates[0].layoutDirection == .rightToLeft)
        #expect(templates[1].layoutDirection == .leftToRight)
        #expect(templates[1].displayName == "Establish Heading")
        #expect(templates[1].cruiseSection?.title == "CRUISE CHECK")
        #expect(templates[1].item(.reporting)?.instruction == "What is the next report?")
    }

    @Test(arguments: [false, true])
    func waypointIdentificationHidesChecklistWithoutChangingReviewOrTiming(wasNoted: Bool) throws {
        let flightPlan = try twoLegFlight()
        let originalFlight = flightPlan
        let start = Date(timeIntervalSince1970: 100)
        let identified = Date(timeIntervalSince1970: 125)
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        try state.startLeg(at: start)
        if wasNoted {
            state.noteLegStartChecklist()
        }

        try state.identifyDestination(at: identified)

        let checklist = try #require(state.activeLegStartChecklist)
        #expect(checklist.phaseState == .hiddenForPhase)
        #expect(checklist.reviewState == (wasNoted ? .noted : .pending))
        #expect(state.flight?.destinationIdentifiedAt == identified)
        #expect(state.flight?.legStartedAt == start)
        #expect(state.flight?.elapsedTime(at: Date(timeIntervalSince1970: 140)) == 40)
        #expect(state.flightPlan == originalFlight)
        state.reopenLegStartChecklist()
        #expect(state.activeLegStartChecklist?.phaseState == .hiddenForPhase)
    }

    @Test func reachedNowHidesPendingChecklistWithoutFabricatingNoted() throws {
        let flightPlan = try twoLegFlight()
        var state = CockpitFeatureState(progressionPolicy: .manualNextLeg)
        try state.accept(flightPlan)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))

        try state.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 140))

        let firstLegChecklist = try #require(state.legStartChecklists[flightPlan.legs[0].id])
        #expect(firstLegChecklist.phaseState == .hiddenForPhase)
        #expect(firstLegChecklist.reviewState == .pending)
        #expect(state.activeLegStartChecklist == nil)
    }

    @Test func previousDrawerCollapseDoesNotAcknowledgeChecklist() throws {
        let flightPlan = try twoLegFlight()
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))

        state.collapseLegStartChecklist()

        #expect(state.activeLegStartChecklist?.presentationState == .collapsed)
        #expect(state.activeLegStartChecklist?.reviewState == .pending)
        #expect(state.activeLegStartChecklist?.phaseState == .available)
    }

    @Test func automaticProgressionCreatesFreshPendingChecklistForNewLeg() throws {
        let flightPlan = try twoLegFlight()
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))
        state.noteLegStartChecklist()

        try state.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 140))

        let checklist = try #require(state.activeLegStartChecklist)
        #expect(checklist.legID == flightPlan.legs[1].id)
        #expect(checklist.reviewState == .pending)
        #expect(checklist.presentationState == .expanded)
        #expect(state.legStartChecklists[flightPlan.legs[0].id]?.reviewState == .noted)
        #expect(state.legStartChecklists[flightPlan.legs[0].id]?.phaseState == .hiddenForPhase)
        #expect(state.flight?.legStartedAt == Date(timeIntervalSince1970: 140))
    }

    @Test func manualProgressionWaitsUntilStartBeforeCreatingChecklist() throws {
        let flightPlan = try twoLegFlight()
        var state = CockpitFeatureState(progressionPolicy: .manualNextLeg)
        try state.accept(flightPlan)
        try state.startLeg(at: Date(timeIntervalSince1970: 100))
        state.noteLegStartChecklist()

        try state.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 140))
        #expect(state.flight?.legState == .ready)
        #expect(state.activeLegStartChecklist == nil)
        #expect(state.legStartChecklists[flightPlan.legs[1].id] == nil)

        try state.startLeg(at: Date(timeIntervalSince1970: 150))
        #expect(state.activeLegStartChecklist?.legID == flightPlan.legs[1].id)
        #expect(state.activeLegStartChecklist?.reviewState == .pending)
        #expect(state.flight?.legStartedAt == Date(timeIntervalSince1970: 150))
    }

    @Test func checklistCollapseReopenAndNotedAreScopedToActiveLeg() throws {
        let flightPlan = try twoLegFlight()
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
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
        let flightPlan = try twoLegFlight()
        let originalFlight = flightPlan
        let start = Date(timeIntervalSince1970: 200)
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        try state.startLeg(at: start)

        state.collapseLegStartChecklist()
        state.reopenLegStartChecklist()
        state.noteLegStartChecklist()

        #expect(state.flight?.legStartedAt == start)
        #expect(state.flight?.elapsedTime(at: start.addingTimeInterval(42)) == 42)
        #expect(state.flightPlan == originalFlight)
    }

    @Test func checklistUsesOnlySavedDirectionAltitudeAndContractSupportedIAS() throws {
        let flightPlan = try twoLegFlight()
        var noWindSession = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try noWindSession.startLeg(at: Date(timeIntervalSince1970: 100))

        let noWind = try #require(
            try CockpitPresentationAdapter().makeLegStartChecklist(
                flightPlan: flightPlan,
                flight: noWindSession
            )
        )
        #expect(noWind.direction == .course(355))
        #expect(noWind.plannedAltitudeFeetMsl == 2000)
        #expect(noWind.plannedIndicatedAirspeedKnots == nil)
        #expect(noWind.template == .tzeKivun)

        let english = try #require(
            try CockpitPresentationAdapter().makeLegStartChecklist(
                flightPlan: flightPlan,
                flight: noWindSession,
                template: .establishHeading
            )
        )
        #expect(english.template == .establishHeading)
        #expect(english.direction == .course(355))
        #expect(english.plannedAltitudeFeetMsl == 2000)
        #expect(english.plannedIndicatedAirspeedKnots == nil)

        var windSession = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        try windSession.startLeg(at: Date(timeIntervalSince1970: 100))
        let wind = try #require(
            try CockpitPresentationAdapter().makeLegStartChecklist(
                flightPlan: flightPlan,
                flight: windSession
            )
        )
        #expect(wind.direction == .heading(355))
    }

    @Test func cockpitFeatureStateLoadsAtomicallyAndPreservesModeWhileBrowsing() throws {
        let flightPlan = try twoLegFlight()
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
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
        let flightPlan = try FPLNavFileLoader().load(url)
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        #expect(state.flightPlan?.title == "Synthetic Editor V7 wind handoff")
    }

    @Test func cockpitAdapterPresentsTheSelectedResolvedLegAndOnlySumsSavedTime() throws {
        let flightPlan = try twoLegFlight()
        let presentation = try CockpitPresentationAdapter().makePresentation(
            flightPlan: flightPlan,
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
        let flightPlan = try twoLegFlight()
        let originalFlight = flightPlan
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 1,
            executionMode: .wind
        )

        let presentation = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: flight
        )

        #expect(presentation.waypoints.map(\.name) == flightPlan.waypoints.map(\.name))
        #expect(presentation.legs.map(\.id) == flightPlan.legs.map(\.id))
        #expect(presentation.activeLegIndex == flight.activeLegIndex)
        #expect(presentation.activeLeg?.id == flightPlan.legs[1].id)
        #expect(presentation.nextLegPreview == nil)
        #expect(presentation.readyFocusTarget == presentation.activeLeg?.from)
        #expect(presentation.activeFocusTarget == presentation.activeLeg?.to)
        #expect(presentation.plannedDurationSeconds == 40)
        #expect(presentation.plannedDurationText == "00:40")
        #expect(presentation.minuteMarkers.isEmpty)
        #expect(flightPlan == originalFlight)

        try flight.startLeg(at: Date(timeIntervalSince1970: 1_000))
        let activePresentation = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: flight
        )
        #expect(activePresentation == presentation)
        #expect(flightPlan == originalFlight)
    }

    @Test func mapPresentationSelectsBeginningOfFollowingLeg() throws {
        let flightPlan = try twoLegFlight()
        let flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )

        let presentation = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: flight
        )

        #expect(presentation.activeLeg?.id == flightPlan.legs[0].id)
        #expect(presentation.nextLegPreview?.id == flightPlan.legs[1].id)
        #expect(presentation.nextLegPreview?.from == presentation.activeLeg?.to)
        #expect(presentation.readyFocusTarget?.latitude == flightPlan.legs[0].departure.position.latitudeDegrees)
        #expect(presentation.activeFocusTarget?.longitude == flightPlan.legs[0].arrival.position.longitudeDegrees)
    }

    @Test func destinationIdentificationDoesNotChangeMapPresentation() throws {
        let flightPlan = try twoLegFlight()
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        try flight.startLeg(at: Date(timeIntervalSince1970: 100))
        let before = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)

        try flight.identifyDestination(at: Date(timeIntervalSince1970: 120))
        let after = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)

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

    @Test func selectedMapCalloutRepresentsOnlyOneOperationalTarget() {
        let legID = UUID()
        let pointID = UUID()
        let waypointID = UUID()
        let pointKey = IdentificationPointKey(legID: legID, identificationPointID: pointID)
        let targetKey = NavigationTimingTargetKey(
            legID: legID,
            kind: .destination,
            targetID: waypointID
        )

        var selection: SelectedMapCallout? = .identificationPoint(pointKey)
        #expect(selection == .identificationPoint(pointKey))

        selection = .timingTarget(targetKey)
        #expect(selection == .timingTarget(targetKey))
        #expect(selection != .identificationPoint(pointKey))

        selection = nil
        #expect(selection == nil)
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
        #expect(style.activeLegColor == UIColor(red: 8 / 255, green: 99 / 255, blue: 235 / 255, alpha: 1))
        #expect(style.primaryActionColor == UIColor(red: 0, green: 107 / 255, blue: 199 / 255, alpha: 1))
        #expect(style.checklistHeadingColor == UIColor(red: 0, green: 97 / 255, blue: 191 / 255, alpha: 1))
        #expect(style.defaultEtaCalloutOffset.x <= -160)
        #expect(style.defaultVORDMECalloutOffset.x == -148)
        #expect(style.defaultVORDMECalloutOffset.y == 50)
        #expect(abs(style.identificationPointCollapsedCalloutBackgroundOpacity - 0.72) < 0.001)
        #expect(abs(style.identificationPointExpandedCalloutBackgroundOpacity - 0.90) < 0.001)
        #expect(style.identificationPointColor != style.currentLegAccentColor)
        #expect(style.identificationPointColor != style.identificationPointReachedColor)
        #expect(style.defaultIdentificationPointCalloutOffset.x > 0)
        #expect(style.defaultIdentificationPointCalloutOffset.y == 0)
        #expect(style.identificationPointEllipseFillOpacity == 1)
        #expect(style.identificationPointEllipseOutlineOpacity >= 0.9)
    }

    @Test func movingIdentificationLabelKeepsResolvedEllipseAnchorAndPlanUnchanged() throws {
        let flightPlan = try FPLNavDecoder().decode(try fixtureData("editor-wind", directory: "V7/Editor"))
        let originalFlight = flightPlan
        let flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let presentation = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        let point = try #require(presentation.identificationPoints.first)
        let initial = AviationMapVisualStyle.default.defaultIdentificationPointCalloutOffset
        let moved = initial.translated(x: 85, y: 35)

        #expect(initial.x != 0)
        #expect(moved != initial)
        #expect(point.coordinate == presentation.identificationPoints.first?.coordinate)
        #expect(point.plannedElapsedSeconds == presentation.identificationPoints.first?.plannedElapsedSeconds)
        #expect(flightPlan == originalFlight)
    }

    @Test func committedETAPropagatesToMapPresentationWithoutMutatingFlight() throws {
        let flightPlan = try FPLNavDecoder().decode(try fixtureData("editor-wind", directory: "V7/Editor"))
        let originalFlight = flightPlan
        let destinationID = try #require(flightPlan.legs.first?.arrival.id)
        let legID = try #require(flightPlan.legs.first?.id)
        let targetKey = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: destinationID)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        flight.initializePilotETA(targetKey: targetKey, plannedElapsedSeconds: 556)
        flight.adjustPilotETA(targetKey: targetKey, by: 25)

        let beforeCommit = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        #expect(beforeCommit.destinationTarget.committedETASeconds == nil)
        #expect(beforeCommit.destinationTarget.plannedElapsedSeconds == 556)

        flight.commitPilotETA(targetKey: targetKey)
        let afterCommit = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        #expect(afterCommit.destinationTarget.committedETASeconds == 580)
        #expect(afterCommit.destinationTarget.plannedElapsedSeconds == 556)
        #expect(flightPlan == originalFlight)
        #expect(flight.legTimings.isEmpty)
        #expect(flight.activeLegIndex == 0)
        #expect(flight.legState == .ready)
    }

    @Test func movingEtaCalloutOffsetDoesNotMoveDestinationOrPlannedNavigation() throws {
        let flightPlan = try twoLegFlight()
        let originalFlight = flightPlan
        let flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let presentation = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: flight
        )
        let destination = try #require(presentation.activeFocusTarget)
        let initial = AviationMapVisualStyle.default.defaultEtaCalloutOffset
        let moved = initial.translated(x: 42, y: -18)

        #expect(moved == AviationMapCalloutOffset(x: initial.x + 42, y: initial.y - 18))
        #expect(presentation.activeFocusTarget == destination)
        #expect(flightPlan == originalFlight)
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
        let flightPlan = try FPLNavDecoder().decode(try fixtureData("editor-wind", directory: "V7/Editor"))
        let pointID = try #require(flightPlan.identificationPoints.first?.id)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        try flight.startLeg(at: Date(timeIntervalSince1970: 1_000))

        let presentation = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)

        #expect(presentation.identificationPoints.map(\.id.identificationPointID) == flightPlan.identificationPoints.map(\.id))
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
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: legIDs,
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: startedAt)

        try flight.reachIdentificationPoint(
            key: keyA,
            orderedActiveLegPointKeys: [keyA, keyB],
            at: reachedA
        )
        try flight.reachIdentificationPoint(
            key: keyB,
            orderedActiveLegPointKeys: [keyA, keyB],
            at: reachedB
        )

        #expect(flight.identificationPointTiming(for: keyA)?.reachedAt == reachedA)
        #expect(flight.actualLegElapsedDuration(atIdentificationPoint: keyA) == 173)
        #expect(flight.identificationPointTiming(for: keyB)?.reachedAt == reachedB)
        #expect(flight.identificationPointTimings.count == 2)
        #expect(flight.activeLegIndex == 0)
        #expect(flight.legState == .active)
        #expect(flight.legStartedAt == startedAt)
        #expect(flight.elapsedTime(at: startedAt.addingTimeInterval(300)) == 300)
        #expect(throws: Flight.TransitionError.identificationPointAlreadyReached(pointA)) {
            try flight.reachIdentificationPoint(
                key: keyA,
                orderedActiveLegPointKeys: [keyA, keyB],
                at: startedAt.addingTimeInterval(400)
            )
        }
        #expect(flight.identificationPointTiming(for: keyA)?.reachedAt == reachedA)
    }

    @Test func reportingLaterIdentificationPointPassesEarlierFuturePointsAtomically() throws {
        let legID = UUID()
        let keys = (0..<3).map { _ in
            IdentificationPointKey(legID: legID, identificationPointID: UUID())
        }
        let targetKey = NavigationTimingTargetKey(
            legID: legID,
            kind: .identificationPoint,
            targetID: keys[1].identificationPointID
        )
        let start = Date(timeIntervalSince1970: 50_000)
        let report = start.addingTimeInterval(208)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [legID],
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)
        flight.initializePilotETA(targetKey: targetKey, plannedElapsedSeconds: 200)
        flight.adjustPilotETA(targetKey: targetKey, by: 5)
        flight.commitPilotETA(targetKey: targetKey)
        flight.beginEditingPilotETA(targetKey: targetKey)
        flight.adjustPilotETA(targetKey: targetKey, by: 10)

        try flight.reachIdentificationPoint(
            key: keys[1],
            orderedActiveLegPointKeys: keys,
            at: report
        )

        #expect(flight.identificationPointState(for: keys[0]) == .passedWithoutReport)
        #expect(flight.identificationPointTiming(for: keys[0])?.reachedAt == nil)
        #expect(flight.actualLegElapsedDuration(atIdentificationPoint: keys[0]) == nil)
        #expect(flight.identificationPointState(for: keys[1]) == .reached(report))
        #expect(flight.actualLegElapsedDuration(atIdentificationPoint: keys[1]) == 208)
        #expect(flight.identificationPointState(for: keys[2]) == .future)
        let retainedETA = try #require(flight.pilotETAState(targetKey: targetKey))
        #expect(retainedETA.committedSeconds == 205)
        #expect(retainedETA.draftSeconds == 205)
        #expect(retainedETA.isEditing == false)

        flight.beginEditingPilotETA(targetKey: targetKey)
        flight.adjustPilotETA(targetKey: targetKey, by: 5)
        #expect(flight.pilotETAState(targetKey: targetKey) == retainedETA)
    }

    @Test(arguments: [
        Flight.ProgressionPolicy.automaticNextLeg,
        Flight.ProgressionPolicy.manualNextLeg
    ])
    func destinationReachPassesEveryRemainingIdentificationPointAtomically(
        progressionPolicy: Flight.ProgressionPolicy
    ) throws {
        let legIDs = [UUID(), UUID()]
        let keys = (0..<3).map { _ in
            IdentificationPointKey(legID: legIDs[0], identificationPointID: UUID())
        }
        let committedTarget = NavigationTimingTargetKey(
            legID: legIDs[0],
            kind: .identificationPoint,
            targetID: keys[1].identificationPointID
        )
        let transientTarget = NavigationTimingTargetKey(
            legID: legIDs[0],
            kind: .identificationPoint,
            targetID: keys[2].identificationPointID
        )
        let destinationTarget = NavigationTimingTargetKey(
            legID: legIDs[0],
            kind: .destination,
            targetID: UUID()
        )
        let start = Date(timeIntervalSince1970: 80_000)
        let firstReport = start.addingTimeInterval(100)
        let destinationReport = start.addingTimeInterval(300)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: legIDs,
            activeLegIndex: 0,
            executionMode: .noWind,
            progressionPolicy: progressionPolicy
        )
        try flight.startLeg(at: start)
        try flight.reachIdentificationPoint(
            key: keys[0],
            orderedActiveLegPointKeys: keys,
            at: firstReport
        )
        flight.initializePilotETA(targetKey: committedTarget, plannedElapsedSeconds: 200)
        flight.adjustPilotETA(targetKey: committedTarget, by: 5)
        flight.commitPilotETA(targetKey: committedTarget)
        flight.beginEditingPilotETA(targetKey: committedTarget)
        flight.adjustPilotETA(targetKey: committedTarget, by: 10)
        flight.initializePilotETA(targetKey: transientTarget, plannedElapsedSeconds: 250)
        flight.initializePilotETA(targetKey: destinationTarget, plannedElapsedSeconds: 300)

        try flight.reachCurrentWaypoint(
            orderedActiveLegPointKeys: keys,
            at: destinationReport
        )

        #expect(flight.identificationPointState(for: keys[0]) == .reached(firstReport))
        #expect(flight.identificationPointState(for: keys[1]) == .passedWithoutReport)
        #expect(flight.identificationPointState(for: keys[2]) == .passedWithoutReport)
        #expect(flight.actualLegElapsedDuration(atIdentificationPoint: keys[1]) == nil)
        #expect(flight.actualLegElapsedDuration(atIdentificationPoint: keys[2]) == nil)
        #expect(flight.pilotETAState(targetKey: committedTarget)?.committedSeconds == 205)
        #expect(flight.pilotETAState(targetKey: committedTarget)?.draftSeconds == 205)
        #expect(flight.pilotETAState(targetKey: committedTarget)?.isEditing == false)
        #expect(flight.pilotETAState(targetKey: transientTarget) == nil)
        #expect(flight.pilotETAState(targetKey: destinationTarget) == nil)
        #expect(flight.legTimings[0].reachedAt == destinationReport)
        #expect(flight.activeLegIndex == 1)
        switch progressionPolicy {
        case .automaticNextLeg:
            #expect(flight.legState == .active)
            #expect(flight.legStartedAt == destinationReport)
        case .manualNextLeg:
            #expect(flight.legState == .ready)
            #expect(flight.legStartedAt == nil)
        }
    }

    @Test func finalDestinationReachPassesRemainingPointsWithoutStartingSuccessor() throws {
        let legID = UUID()
        let keys = (0..<2).map { _ in
            IdentificationPointKey(legID: legID, identificationPointID: UUID())
        }
        let start = Date(timeIntervalSince1970: 90_000)
        let report = start.addingTimeInterval(240)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [legID],
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)

        try flight.reachCurrentWaypoint(
            orderedActiveLegPointKeys: keys,
            at: report
        )

        #expect(keys.allSatisfy { flight.identificationPointState(for: $0) == .passedWithoutReport })
        #expect(flight.identificationPointTimings.allSatisfy { $0.reachedAt == nil })
        #expect(flight.legState == .completed)
        #expect(flight.activeLegIndex == 0)
        #expect(flight.legTimings.count == 1)
        #expect(flight.legTimings[0].reachedAt == report)
    }

    @Test func invalidDestinationReachContextDoesNotMutateSession() throws {
        let legID = UUID()
        let start = Date(timeIntervalSince1970: 100_000)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [legID],
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)
        let before = flight
        let wrongLegPoint = IdentificationPointKey(
            legID: UUID(),
            identificationPointID: UUID()
        )

        #expect(throws: Flight.TransitionError.invalidIdentificationPointOrder) {
            try flight.reachCurrentWaypoint(
                orderedActiveLegPointKeys: [wrongLegPoint],
                at: start.addingTimeInterval(60)
            )
        }
        #expect(flight == before)
    }

    @Test func rejectedIdentificationPointReportsDoNotMutateState() throws {
        let legID = UUID()
        let key = IdentificationPointKey(legID: legID, identificationPointID: UUID())
        let wrongLegKey = IdentificationPointKey(legID: UUID(), identificationPointID: UUID())
        let start = Date(timeIntervalSince1970: 60_000)
        var flight = Flight(
            flightPlanID: UUID(),
            legIDs: [legID],
            activeLegIndex: 0,
            executionMode: .noWind
        )
        try flight.startLeg(at: start)

        let beforeWrongLeg = flight
        #expect(throws: Flight.TransitionError.identificationPointWrongLeg(wrongLegKey.identificationPointID)) {
            try flight.reachIdentificationPoint(
                key: wrongLegKey,
                orderedActiveLegPointKeys: [wrongLegKey],
                at: start.addingTimeInterval(10)
            )
        }
        #expect(flight == beforeWrongLeg)

        try flight.reachIdentificationPoint(
            key: key,
            orderedActiveLegPointKeys: [key],
            at: start.addingTimeInterval(20)
        )
        let beforeDuplicate = flight
        #expect(throws: Flight.TransitionError.identificationPointAlreadyReached(key.identificationPointID)) {
            try flight.reachIdentificationPoint(
                key: key,
                orderedActiveLegPointKeys: [key],
                at: start.addingTimeInterval(30)
            )
        }
        #expect(flight == beforeDuplicate)
    }

    @Test func featureAndMapPresentationProjectPassedReachedAndFutureOutcomes() throws {
        let flightPlan = try flightWithThreeIdentificationPoints()
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        let start = Date(timeIntervalSince1970: 70_000)
        try state.startLeg(at: start)
        let before = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: try #require(state.flight)
        )
        #expect(before.identificationPoints.map(\.status) == [.future, .future, .future])

        try state.reachIdentificationPoint(
            key: before.identificationPoints[1].id,
            mapPresentation: before,
            at: start.addingTimeInterval(150)
        )

        let after = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: try #require(state.flight)
        )
        #expect(after.identificationPoints.map(\.status) == [
            .passedWithoutReport,
            .reached,
            .future
        ])
        #expect(after.identificationPoints[0].operationalState.canMarkReached == false)
        #expect(after.identificationPoints[0].operationalState.canEditETA == false)
        #expect(state.flight?.actualLegElapsedDuration(
            atIdentificationPoint: after.identificationPoints[0].id
        ) == nil)
        #expect(state.flight?.actualLegElapsedDuration(
            atIdentificationPoint: after.identificationPoints[1].id
        ) == 150)
    }

    @Test func identificationPointReachUndoRestoresCompleteAtomicSnapshot() throws {
        let flightPlan = try flightWithThreeIdentificationPoints()
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        let start = Date(timeIntervalSince1970: 70_000)
        try state.startLeg(at: start)
        let map = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: try #require(state.flight)
        )
        let etaTarget = map.destinationTarget
        state.openPilotETAEditor(target: etaTarget)
        state.adjustPilotETA(targetKey: etaTarget.id, by: 15)
        state.openPilotHeadingEditor(baselineDegrees: 81)
        state.adjustPilotHeading(by: 4)
        state.commitPilotHeading()
        let expectedSession = try #require(state.flight)
        let restoration = CockpitRestoration(
            camera: AviationMapCameraState(
                center: .init(latitude: 32.1, longitude: 34.8),
                zoomLevel: 10.5,
                direction: 123,
                pitch: 37
            ),
            isCameraUserControlled: true,
            selectedCallout: .identificationPoint(map.identificationPoints[1].id),
            focusRequest: AviationMapFocusRequest(mode: .overview)
        )

        try state.reachIdentificationPoint(
            key: map.identificationPoints[1].id,
            mapPresentation: map,
            cockpitRestoration: restoration,
            at: start.addingTimeInterval(150)
        )
        #expect(state.flight?.identificationPointState(for: map.identificationPoints[0].id) == .passedWithoutReport)

        let restored = state.undoMostRecentReach(at: start.addingTimeInterval(169))
        #expect(restored == restoration)
        #expect(state.flight == expectedSession)
        #expect(state.flight?.identificationPointState(for: map.identificationPoints[0].id) == .future)
        #expect(state.flight?.identificationPointState(for: map.identificationPoints[1].id) == .future)
        #expect(state.pendingReachUndo == nil)
    }

    @Test func reachUndoUsesStrictWallClockDeadlineAndPassiveActionsPreserveIt() throws {
        let flightPlan = try flightWithThreeIdentificationPoints()
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        let start = Date(timeIntervalSince1970: 80_000)
        try state.startLeg(at: start)
        let map = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: try #require(state.flight)
        )
        try state.reachIdentificationPoint(
            key: map.identificationPoints[0].id,
            mapPresentation: map,
            at: start.addingTimeInterval(10)
        )
        let pending = try #require(state.pendingReachUndo)

        state.toggleDriftLines()
        state.collapseLegStartChecklist()
        #expect(state.pendingReachUndo == pending)
        #expect(state.availableReachUndo(at: start.addingTimeInterval(29.999)) != nil)
        #expect(state.availableReachUndo(at: start.addingTimeInterval(30)) == nil)
        #expect(state.undoMostRecentReach(at: start.addingTimeInterval(30)) == nil)
    }

    @Test func rejectedReachPreservesUndoWhileSuccessfulFlightStateCommitInvalidatesIt() throws {
        let flightPlan = try flightWithThreeIdentificationPoints()
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        let start = Date(timeIntervalSince1970: 90_000)
        try state.startLeg(at: start)
        let map = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: try #require(state.flight)
        )
        let point = map.identificationPoints[0]
        try state.reachIdentificationPoint(key: point.id, mapPresentation: map, at: start.addingTimeInterval(10))
        let beforeRejected = state

        #expect(throws: Flight.TransitionError.identificationPointAlreadyReached(point.id.identificationPointID)) {
            try state.reachIdentificationPoint(key: point.id, mapPresentation: map, at: start.addingTimeInterval(11))
        }
        #expect(state == beforeRejected)

        let target = map.destinationTarget
        state.openPilotETAEditor(target: target)
        state.adjustPilotETA(targetKey: target.id, by: 15)
        state.commitPilotETA(targetKey: target.id)
        #expect(state.pendingReachUndo == nil)
    }

    @Test(arguments: [
        Flight.ProgressionPolicy.automaticNextLeg,
        Flight.ProgressionPolicy.manualNextLeg
    ])
    func arrivalReachUndoRestoresAtomicSnapshotAcrossProgressionPolicies(
        progressionPolicy: Flight.ProgressionPolicy
    ) throws {
        let flightPlan = try twoLegFlight()
        var state = CockpitFeatureState(progressionPolicy: progressionPolicy)
        try state.accept(flightPlan)
        let start = Date(timeIntervalSince1970: 100_000)
        let arrival = start.addingTimeInterval(300)
        try state.startLeg(at: start)
        state.noteLegStartChecklist()

        let map = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: try #require(state.flight)
        )
        state.openPilotETAEditor(target: map.destinationTarget)
        state.adjustPilotETA(targetKey: map.destinationTarget.id, by: 15)
        state.commitPilotETA(targetKey: map.destinationTarget.id)
        state.openPilotHeadingEditor(baselineDegrees: 81)
        state.adjustPilotHeading(by: 6)
        state.commitPilotHeading()

        let expectedSession = try #require(state.flight)
        let expectedChecklists = state.legStartChecklists
        let restoration = CockpitRestoration(
            camera: AviationMapCameraState(
                center: .init(latitude: 32.31, longitude: 34.87),
                zoomLevel: 11.25,
                direction: 147,
                pitch: 28
            ),
            isCameraUserControlled: true,
            selectedCallout: .timingTarget(map.destinationTarget.id),
            focusRequest: AviationMapFocusRequest(mode: .waypoint)
        )

        try state.reachCurrentWaypoint(cockpitRestoration: restoration, at: arrival)

        let progressed = try #require(state.flight)
        #expect(state.pendingReachUndo?.kind.label == "Leg 1 arrival reached")
        #expect(progressed.activeLegIndex == 1)
        #expect(state.selectedLegIndex == 1)
        switch progressionPolicy {
        case .automaticNextLeg:
            #expect(progressed.legState == .active)
            #expect(progressed.legStartedAt == arrival)
            #expect(state.activeLegStartChecklist != nil)
        case .manualNextLeg:
            #expect(progressed.legState == .ready)
            #expect(progressed.legStartedAt == nil)
            #expect(state.activeLegStartChecklist == nil)
        }

        let restored = state.undoMostRecentReach(at: arrival.addingTimeInterval(19))

        #expect(restored == restoration)
        #expect(state.flight == expectedSession)
        #expect(state.legStartChecklists == expectedChecklists)
        #expect(state.selectedLegIndex == 0)
        #expect(state.flight?.legState == .active)
        #expect(state.flight?.legStartedAt == start)
        #expect(state.flight?.elapsedTime(at: arrival.addingTimeInterval(19)) == 319)
        #expect(state.pendingReachUndo == nil)
    }

    @Test func finalNavigationCompletionUndoRestoresActiveFinalLeg() throws {
        let flightPlan = try twoLegFlight()
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        let firstStart = Date(timeIntervalSince1970: 110_000)
        let finalStart = firstStart.addingTimeInterval(200)
        try state.startLeg(at: firstStart)
        try state.reachCurrentWaypoint(at: finalStart)
        state.commitPilotHeading()
        let finalMap = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: try #require(state.flight)
        )
        state.openPilotETAEditor(target: finalMap.destinationTarget)
        state.adjustPilotETA(targetKey: finalMap.destinationTarget.id, by: 10)
        let expectedSession = try #require(state.flight)
        let expectedChecklists = state.legStartChecklists
        let restoration = CockpitRestoration(
            camera: AviationMapCameraState(
                center: .init(latitude: 32.4, longitude: 34.9),
                zoomLevel: 10,
                direction: 93,
                pitch: 0
            ),
            isCameraUserControlled: true,
            selectedCallout: .timingTarget(finalMap.destinationTarget.id),
            focusRequest: AviationMapFocusRequest(mode: .waypoint)
        )
        let finalArrival = finalStart.addingTimeInterval(240)

        try state.reachCurrentWaypoint(cockpitRestoration: restoration, at: finalArrival)
        #expect(state.pendingReachUndo?.kind.label == "Final arrival reached")
        #expect(state.flight?.legState == .completed)
        #expect(state.flight?.activeLegIndex == 1)

        #expect(state.undoMostRecentReach(at: finalArrival.addingTimeInterval(10)) == restoration)
        #expect(state.flight == expectedSession)
        #expect(state.legStartChecklists == expectedChecklists)
        #expect(state.selectedLegIndex == 1)
        #expect(state.flight?.legState == .active)
        #expect(state.flight?.legStartedAt == finalStart)
    }

    @Test func arrivalUndoExpiresAcrossBackgroundTimeAndLaterSuccessorActivityInvalidatesIt() throws {
        let flightPlan = try twoLegFlight()
        let start = Date(timeIntervalSince1970: 120_000)
        let arrival = start.addingTimeInterval(300)

        var automatic = CockpitFeatureState()
        try automatic.accept(flightPlan)
        try automatic.startLeg(at: start)
        try automatic.reachCurrentWaypoint(at: arrival)
        #expect(automatic.availableReachUndo(at: arrival.addingTimeInterval(19.999)) != nil)
        #expect(automatic.availableReachUndo(at: arrival.addingTimeInterval(20)) == nil)
        #expect(automatic.undoMostRecentReach(at: arrival.addingTimeInterval(45)) == nil)

        var manual = CockpitFeatureState(progressionPolicy: .manualNextLeg)
        try manual.accept(flightPlan)
        try manual.startLeg(at: start)
        try manual.reachCurrentWaypoint(at: arrival)
        #expect(manual.pendingReachUndo != nil)
        try manual.startLeg(at: arrival.addingTimeInterval(5))
        #expect(manual.pendingReachUndo == nil)
        #expect(manual.undoMostRecentReach(at: arrival.addingTimeInterval(6)) == nil)
    }

    @Test func driftReferenceGeometryUsesConfiguredAngleAndResolvedEndpoints() throws {
        let from = AviationMapCoordinate(latitude: 32.0, longitude: 34.0)
        let to = AviationMapCoordinate(latitude: 32.1, longitude: 34.2)
        let shallow = AviationMapGeometry.driftReferenceArms(from: from, to: to, angleDegrees: 5)
        let configured = AviationMapGeometry.driftReferenceArms(from: from, to: to, angleDegrees: 10)

        #expect(configured.count == 2)
        #expect(configured[0].from == from)
        #expect(configured[1].from == to)
        #expect(configured[0].to != configured[1].to)
        #expect(configured[0].to != shallow[0].to)

        let midpoint = AviationMapCoordinate(
            latitude: (from.latitude + to.latitude) / 2,
            longitude: (from.longitude + to.longitude) / 2
        )
        let trackEast = to.longitude - from.longitude
        let trackNorth = to.latitude - from.latitude
        let departureSide = trackEast * (configured[0].to.latitude - midpoint.latitude)
            - trackNorth * (configured[0].to.longitude - midpoint.longitude)
        let arrivalSide = trackEast * (configured[1].to.latitude - midpoint.latitude)
            - trackNorth * (configured[1].to.longitude - midpoint.longitude)
        #expect(departureSide * arrivalSide < 0)

        let flightPlan = try twoLegFlight(withIdentificationPointsOnBothLegs: false)
        let flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .noWind
        )
        let presentation = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: flight
        )
        let activeLeg = try #require(presentation.activeLeg)
        let expected = AviationMapGeometry.driftReferenceArms(
            from: activeLeg.from,
            to: activeLeg.to,
            angleDegrees: flightPlan.parameters.driftAngle.value
        )
        #expect(presentation.driftReferenceArms == expected)
    }

    @Test func driftVisibilityIsCurrentFlightPresentationState() throws {
        let flightPlan = try twoLegFlight(withIdentificationPointsOnBothLegs: false)
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        #expect(state.areDriftLinesVisible)

        state.toggleDriftLines()
        #expect(!state.areDriftLinesVisible)
        try state.startLeg(at: Date(timeIntervalSince1970: 1_000))
        try state.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 1_100))
        #expect(!state.areDriftLinesVisible)

        try state.accept(flightPlan)
        #expect(state.areDriftLinesVisible)
    }

    @Test func timingAndReachChangesDoNotAlterActiveLegDriftGeometry() throws {
        let flightPlan = try flightWithThreeIdentificationPoints()
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        let start = Date(timeIntervalSince1970: 2_000)
        try state.startLeg(at: start)
        let initial = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: try #require(state.flight)
        )
        let target = initial.currentETATarget
        state.openPilotETAEditor(target: target)
        state.adjustPilotETA(targetKey: target.id, by: 15)
        state.commitPilotETA(targetKey: target.id)
        try state.reachIdentificationPoint(
            key: initial.identificationPoints[0].id,
            mapPresentation: initial,
            at: start.addingTimeInterval(60)
        )
        let changed = try AviationMapPresentationFactory().makePresentation(
            flightPlan: flightPlan,
            flight: try #require(state.flight)
        )

        #expect(changed.driftReferenceArms == initial.driftReferenceArms)
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
            destinationTarget: .init(id: destinationKey, name: "Destination", plannedElapsedSeconds: 338, committedETASeconds: nil),
            driftReferenceArms: []
        )

        #expect(presentation.nextETATarget(after: pointAKey)?.id.targetID == pointB)
        let completedPoints = points.map {
            AviationMapIdentificationPoint(id: $0.id, name: $0.name, coordinate: $0.coordinate, plannedElapsedSeconds: $0.plannedElapsedSeconds, isReached: true, committedETASeconds: nil)
        }
        let completedPresentation = AviationMapPresentation(
            waypoints: [], legs: [], activeLegIndex: 0, nextLegPreview: nil,
            endpointReferences: [], plannedDurationSeconds: 338, minuteMarkers: [],
            identificationPoints: completedPoints,
            destinationTarget: presentation.destinationTarget,
            driftReferenceArms: []
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
        var flight = Flight(
            flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )

        flight.initializePilotETA(targetKey: targetID, plannedElapsedSeconds: plan)
        #expect(flight.pilotETAState(targetKey: targetID)?.draftSeconds == 340)
        #expect(flight.committedPilotETA(targetKey: targetID) == nil)
        flight.adjustPilotETA(targetKey: targetID, by: 5)
        #expect(flight.pilotETAState(targetKey: targetID)?.draftSeconds == 345)
        #expect(flight.committedPilotETA(targetKey: targetID) == nil)
        flight.commitPilotETA(targetKey: targetID)
        #expect(flight.committedPilotETA(targetKey: targetID) == 345)
        #expect(flight.pilotETAState(targetKey: targetID)?.isEditing == false)
        _ = flight.showPilotETACheck(
            targetKey: targetID,
            observationKey: .init(legID: legID, identificationPointID: UUID()),
            plannedObservationElapsed: 100,
            actualObservationElapsed: 101,
            plannedTargetElapsed: 338
        )
        #expect(flight.pilotETAState(targetKey: targetID)?.isCheckResultVisible == true)
        flight.beginEditingPilotETA(targetKey: targetID)
        #expect(flight.pilotETAState(targetKey: targetID)?.draftSeconds == 345)
        #expect(flight.pilotETAState(targetKey: targetID)?.isCheckResultVisible == false)
        flight.adjustPilotETA(targetKey: targetID, by: 5)
        #expect(flight.committedPilotETA(targetKey: targetID) == 345)
        #expect(flight.pilotETAState(targetKey: targetID)?.draftSeconds == 350)
        flight.commitPilotETA(targetKey: targetID)
        #expect(flight.committedPilotETA(targetKey: targetID) == 350)

        var earlierSession = Flight(
            flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )
        earlierSession.initializePilotETA(targetKey: targetID, plannedElapsedSeconds: plan)
        earlierSession.adjustPilotETA(targetKey: targetID, by: -5)
        #expect(earlierSession.pilotETAState(targetKey: targetID)?.draftSeconds == 335)
        #expect(earlierSession.committedPilotETA(targetKey: targetID) == nil)
        #expect(plan == 338)
    }

    @Test func pilotETAMinimumUsesExactAndRoundedRunningTimerFloors() {
        #expect(Flight.pilotETAMinimumSeconds(currentElapsedSeconds: 170) == 170)
        #expect(Flight.pilotETAMinimumSeconds(currentElapsedSeconds: 172) == 175)
    }

    @Test func pilotETADecrementStopsAtCurrentRunningTimerFloor() {
        let legID = UUID()
        let target = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: UUID())
        var flight = Flight(
            flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )

        flight.initializePilotETA(
            targetKey: target,
            plannedElapsedSeconds: 200,
            currentElapsedSeconds: 172
        )
        for _ in 0..<20 {
            flight.adjustPilotETA(targetKey: target, by: -5, currentElapsedSeconds: 172)
        }

        #expect(flight.pilotETAState(targetKey: target)?.draftSeconds == 175)
    }

    @Test func stalePilotETADraftReturnsTypedErrorAndRemainsOpenWithoutCommit() {
        let legID = UUID()
        let target = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: UUID())
        var flight = Flight(
            flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )
        flight.initializePilotETA(
            targetKey: target,
            plannedElapsedSeconds: 175,
            currentElapsedSeconds: 170
        )

        let error = flight.commitPilotETA(targetKey: target, currentElapsedSeconds: 176)

        #expect(error == .staleDraft(minimumSeconds: 180))
        #expect(flight.pilotETAState(targetKey: target)?.isEditing == true)
        #expect(flight.pilotETAState(targetKey: target)?.validationError == error)
        #expect(flight.pilotETACommitHistory(targetKey: target).isEmpty)
    }

    @Test func repeatedPilotETACommitsRetainOrderedHistoryAndCancelPreservesIt() {
        let legID = UUID()
        let target = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: UUID())
        var flight = Flight(
            flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )
        flight.initializePilotETA(targetKey: target, plannedElapsedSeconds: 200)
        flight.commitPilotETA(targetKey: target)
        flight.beginEditingPilotETA(targetKey: target)
        flight.adjustPilotETA(targetKey: target, by: 5)
        flight.commitPilotETA(targetKey: target)
        flight.beginEditingPilotETA(targetKey: target)
        flight.adjustPilotETA(targetKey: target, by: 5)
        flight.cancelPilotETAEditing(targetKey: target)

        #expect(flight.pilotETACommitHistory(targetKey: target).map(\.seconds) == [200, 205])
        #expect(flight.committedPilotETA(targetKey: target) == 205)
        #expect(flight.pilotETAState(targetKey: target)?.draftSeconds == 205)
        #expect(flight.pilotETAState(targetKey: target)?.isEditing == false)
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
        var flight = Flight(
            flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )

        flight.initializePilotETA(targetKey: destination, plannedElapsedSeconds: 256)
        flight.initializePilotETA(targetKey: identification, plannedElapsedSeconds: 190)
        flight.adjustPilotETA(targetKey: destination, by: 5)
        flight.commitPilotETA(targetKey: destination)

        #expect(flight.pilotETAState(targetKey: destination)?.draftSeconds == 260)
        #expect(flight.pilotETAState(targetKey: destination)?.committedSeconds == 260)
        #expect(flight.pilotETAState(targetKey: destination)?.checkDisclosures.isEmpty == true)
        #expect(flight.pilotETAState(targetKey: identification)?.draftSeconds == 190)
        #expect(flight.pilotETAState(targetKey: identification)?.committedSeconds == nil)
        _ = flight.showPilotETACheck(
            targetKey: destination,
            observationKey: observation,
            plannedObservationElapsed: 100,
            actualObservationElapsed: 101,
            plannedTargetElapsed: 256
        )
        #expect(flight.pilotETAState(targetKey: destination)?.isCheckResultVisible == true)
        flight.beginEditingPilotETA(targetKey: destination)
        #expect(flight.pilotETAState(targetKey: destination)?.isCheckResultVisible == false)
        #expect(flight.pilotETAState(targetKey: destination)?.draftSeconds == 260)
    }

    @Test func unreachedIdentificationPointWithoutAmendmentKeepsReachPrimaryAndETASecondary() {
        let point = AviationMapIdentificationPoint(
            id: .init(legID: UUID(), identificationPointID: UUID()),
            name: "Identification Point 1",
            coordinate: .init(latitude: 0, longitude: 0),
            plannedElapsedSeconds: 94,
            isReached: false,
            committedETASeconds: nil
        )

        #expect(point.operationalState.isReached == false)
        #expect(point.operationalState.canMarkReached)
        #expect(point.operationalState.canEditETA)
        #expect(point.operationalState.operationalETASeconds == 94)
    }

    @Test func unreachedIdentificationPointWithRevisedETAKeepsReachPrimary() {
        let point = AviationMapIdentificationPoint(
            id: .init(legID: UUID(), identificationPointID: UUID()),
            name: "Identification Point 1",
            coordinate: .init(latitude: 0, longitude: 0),
            plannedElapsedSeconds: 94,
            isReached: false,
            committedETASeconds: 95
        )

        #expect(point.operationalState.isReached == false)
        #expect(point.operationalState.canMarkReached)
        #expect(point.operationalState.canEditETA)
        #expect(point.operationalState.operationalETASeconds == 95)
        #expect(point.operationalState.plannedElapsedSeconds == 94)
    }

    @Test func settingIdentificationPointETADoesNotReachOrProgressTheLeg() throws {
        let legID = UUID()
        let pointID = UUID()
        let targetKey = NavigationTimingTargetKey(
            legID: legID,
            kind: .identificationPoint,
            targetID: pointID
        )
        let startedAt = Date(timeIntervalSince1970: 12_000)
        var flight = Flight(
            flightPlanID: UUID(), legIDs: [legID, UUID()], activeLegIndex: 0, executionMode: .noWind
        )
        try flight.startLeg(at: startedAt)

        flight.initializePilotETA(targetKey: targetKey, plannedElapsedSeconds: 94)
        flight.adjustPilotETA(targetKey: targetKey, by: 5)
        flight.commitPilotETA(targetKey: targetKey)

        #expect(flight.committedPilotETA(targetKey: targetKey) == 100)
        #expect(flight.identificationPointTiming(for: .init(legID: legID, identificationPointID: pointID)) == nil)
        #expect(flight.legStartedAt == startedAt)
        #expect(flight.activeLegIndex == 0)
        #expect(flight.legState == .active)
    }

    @Test func reachingIdentificationPointAfterETARevisionRecordsReachAndPreservesRevision() throws {
        let flightPlan = try twoLegFlight(withIdentificationPointsOnBothLegs: true)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let startedAt = Date(timeIntervalSince1970: 13_000)
        let reachedAt = startedAt.addingTimeInterval(17)
        try flight.startLeg(at: startedAt)
        let before = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        let point = try #require(before.identificationPoints.first)
        let targetKey = NavigationTimingTargetKey(
            legID: point.id.legID,
            kind: .identificationPoint,
            targetID: point.id.identificationPointID
        )
        flight.initializePilotETA(targetKey: targetKey, plannedElapsedSeconds: point.plannedElapsedSeconds)
        flight.adjustPilotETA(targetKey: targetKey, by: 5)
        flight.commitPilotETA(targetKey: targetKey)
        let revised = try #require(flight.committedPilotETA(targetKey: targetKey))

        try flight.reachIdentificationPoint(
            key: point.id,
            orderedActiveLegPointKeys: before.identificationPoints.map(\.id),
            at: reachedAt
        )

        #expect(flight.identificationPointTiming(for: point.id)?.reachedAt == reachedAt)
        #expect(flight.committedPilotETA(targetKey: targetKey) == revised)
        let after = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        let reachedPoint = try #require(after.identificationPoints.first)
        #expect(reachedPoint.isReached)
        #expect(reachedPoint.operationalState.canMarkReached == false)
    }

    @Test func legTwoIdentificationPointRevisionDoesNotImplyReachAndRemainsLegScoped() throws {
        let flightPlan = try twoLegFlight(withIdentificationPointsOnBothLegs: true)
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let startedAt = Date(timeIntervalSince1970: 14_000)
        try flight.startLeg(at: startedAt)
        try flight.reachCurrentWaypoint(at: startedAt.addingTimeInterval(40))
        let presentation = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        let point = try #require(presentation.identificationPoints.first)
        let key = NavigationTimingTargetKey(
            legID: point.id.legID,
            kind: .identificationPoint,
            targetID: point.id.identificationPointID
        )
        flight.initializePilotETA(targetKey: key, plannedElapsedSeconds: point.plannedElapsedSeconds)
        flight.adjustPilotETA(targetKey: key, by: 5)
        flight.commitPilotETA(targetKey: key)

        let revisedPresentation = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        let revisedPoint = try #require(revisedPresentation.identificationPoints.first)
        #expect(revisedPoint.id.legID == flightPlan.legs[1].id)
        #expect(revisedPoint.isReached == false)
        #expect(revisedPoint.operationalState.canMarkReached)
        #expect(revisedPoint.committedETASeconds == flight.committedPilotETA(targetKey: key))
        #expect(flight.identificationPointTiming(for: revisedPoint.id) == nil)
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
            ),
            driftReferenceArms: []
        )

        #expect(presentation.nextETATarget(after: first)?.id == expected)
        #expect(presentation.timingTarget(for: expected)?.id == expected)
    }

    @Test func directTargetEditorReusesShortcutStateAndKeepsItsObservationSource() throws {
        let flightPlan = try twoLegFlight(withIdentificationPointsOnBothLegs: true)
        var state = CockpitFeatureState()
        try state.accept(flightPlan)
        try state.startLeg(at: Date(timeIntervalSince1970: 10_000))
        let flight = try #require(state.flight)
        let presentation = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        let point = try #require(presentation.identificationPoints.first)
        let target = try #require(presentation.nextETATarget(after: point.id))
        try state.reachIdentificationPoint(
            key: point.id,
            mapPresentation: presentation,
            at: Date(timeIntervalSince1970: 10_015)
        )
        state.adjustPilotETA(targetKey: target.id, by: 5)
        state.commitPilotETA(targetKey: target.id)
        state.openPilotETAEditor(target: target)

        let etaState = try #require(state.flight?.pilotETAState(targetKey: target.id))
        #expect(etaState.checkDisclosures.isEmpty)
        #expect(etaState.isEditing == false)
        #expect(etaState.draftSeconds == etaState.committedSeconds)
    }

    @Test func consecutiveLegIdentificationPointStateIsIsolated() throws {
        let flightPlan = try twoLegFlight(withIdentificationPointsOnBothLegs: true)
        let originalFlight = flightPlan
        var flight = Flight(
            flightPlanID: flightPlan.id,
            legIDs: flightPlan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: .wind
        )
        let start = Date(timeIntervalSince1970: 40_000)
        try flight.startLeg(at: start)

        let firstPresentation = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        let firstPoint = try #require(firstPresentation.identificationPoints.first)
        #expect(firstPresentation.identificationPoints.count == 1)
        #expect(firstPoint.name == "IP1")
        let firstTarget = firstPresentation.destinationTarget.id
        let firstOffset = AviationMapCalloutOffset(x: 91, y: -63)
        let storedOffsets = [firstPoint.id: firstOffset]

        try flight.reachIdentificationPoint(
            key: firstPoint.id,
            orderedActiveLegPointKeys: firstPresentation.identificationPoints.map(\.id),
            at: start.addingTimeInterval(16)
        )
        flight.initializePilotETA(targetKey: firstTarget, plannedElapsedSeconds: 40)
        flight.adjustPilotETA(targetKey: firstTarget, by: 5)
        flight.commitPilotETA(targetKey: firstTarget)
        _ = flight.showPilotETACheck(
            targetKey: firstTarget,
            observationKey: firstPoint.id,
            plannedObservationElapsed: TimeInterval(firstPoint.plannedElapsedSeconds),
            actualObservationElapsed: 16,
            plannedTargetElapsed: 40
        )
        try flight.identifyDestination(at: start.addingTimeInterval(35))
        try flight.reachCurrentWaypoint(at: start.addingTimeInterval(40))

        let secondPresentation = try AviationMapPresentationFactory().makePresentation(flightPlan: flightPlan, flight: flight)
        let secondPoint = try #require(secondPresentation.identificationPoints.first)
        #expect(secondPresentation.identificationPoints.count == 1)
        #expect(secondPoint.name == "IP1")
        #expect(firstPoint.id != secondPoint.id)
        #expect(firstPoint.id.legID != secondPoint.id.legID)
        #expect(secondPoint.isReached == false)
        #expect(secondPoint.committedETASeconds == nil)
        #expect(storedOffsets[secondPoint.id] == nil)
        #expect(flight.pilotETAState(targetKey: secondPresentation.destinationTarget.id) == nil)
        #expect(flight.pilotETAState(targetKey: firstTarget)?.committedSeconds == 45)
        #expect(flight.pilotETAState(targetKey: firstTarget)?.isCheckResultVisible == true)
        #expect(flight.identificationPointTiming(for: firstPoint.id) != nil)
        #expect(flight.identificationPointTiming(for: secondPoint.id) == nil)
        #expect(Set(secondPresentation.identificationPoints.map(\.id.legID)) == [flightPlan.legs[1].id])
        #expect(flightPlan == originalFlight)
    }

    @Test func checkDisclosureRoundsOnlyAfterFullPrecisionCalculationAndNeverChangesRevision() {
        let legID = UUID()
        let target = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: UUID())
        let observation = IdentificationPointKey(legID: legID, identificationPointID: UUID())
        var flight = Flight(
            flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )
        flight.initializePilotETA(targetKey: target, plannedElapsedSeconds: 100)
        flight.adjustPilotETA(targetKey: target, by: 5)
        flight.commitPilotETA(targetKey: target)

        let requested = flight.showPilotETACheck(
            targetKey: target,
            observationKey: observation,
            plannedObservationElapsed: 3,
            actualObservationElapsed: 2,
            plannedTargetElapsed: 100
        )

        #expect(requested)
        #expect(flight.committedPilotETA(targetKey: target) == 105)
        #expect(flight.pilotETAState(targetKey: target)?.latestCheckDisclosure?.referenceSeconds == 67)
    }

    @Test func checkSelectsLatestReachedPredecessorAtRequestTime() throws {
        let legID = UUID()
        let first = IdentificationPointKey(legID: legID, identificationPointID: UUID())
        let second = IdentificationPointKey(legID: legID, identificationPointID: UUID())
        let destination = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: UUID())
        let start = Date(timeIntervalSince1970: 1_000)
        var flight = Flight(
            flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )
        try flight.startLeg(at: start)
        try flight.reachIdentificationPoint(
            key: first,
            orderedActiveLegPointKeys: [first, second],
            at: start.addingTimeInterval(10)
        )
        flight.initializePilotETA(targetKey: destination, plannedElapsedSeconds: 100)
        flight.commitPilotETA(targetKey: destination)
        try flight.reachIdentificationPoint(
            key: second,
            orderedActiveLegPointKeys: [first, second],
            at: start.addingTimeInterval(20)
        )

        #expect(flight.latestEligibleTimingObservation(
            before: destination,
            orderedPointKeys: [first, second]
        ) == second)
    }

    @Test func hidingCheckPreservesRequestedHistoryAndNeverRequestedCheckHasNone() {
        let legID = UUID()
        let target = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: UUID())
        let observation = IdentificationPointKey(legID: legID, identificationPointID: UUID())
        var flight = Flight(
            flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )
        flight.initializePilotETA(targetKey: target, plannedElapsedSeconds: 100)
        flight.commitPilotETA(targetKey: target)
        #expect(flight.pilotETAState(targetKey: target)?.checkDisclosures.isEmpty == true)

        _ = flight.showPilotETACheck(
            targetKey: target,
            observationKey: observation,
            plannedObservationElapsed: 50,
            actualObservationElapsed: 51,
            plannedTargetElapsed: 100
        )
        flight.hidePilotETACheck(targetKey: target)

        #expect(flight.pilotETAState(targetKey: target)?.isCheckResultVisible == false)
        #expect(flight.pilotETAState(targetKey: target)?.checkDisclosures.map(\.referenceSeconds) == [102])
    }

    @Test func invalidCheckTimingProducesNoPartialMutation() {
        let legID = UUID()
        let target = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: UUID())
        var flight = Flight(
            flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind
        )
        flight.initializePilotETA(targetKey: target, plannedElapsedSeconds: 100)
        flight.commitPilotETA(targetKey: target)
        let before = flight

        let requested = flight.showPilotETACheck(
            targetKey: target,
            observationKey: .init(legID: legID, identificationPointID: UUID()),
            plannedObservationElapsed: 0,
            actualObservationElapsed: 20,
            plannedTargetElapsed: 100
        )

        #expect(!requested)
        #expect(flight == before)
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

    private func decode(_ object: [String: Any]) throws -> FlightPlan {
        try FPLNavDecoder().decode(JSONSerialization.data(withJSONObject: object))
    }

    private func eligiblePlannedNavigation(_ flightPlan: FlightPlan) throws -> PlannedNavigation {
        guard case .eligible(let plannedNavigation) = flightPlan.plannedNavigation else {
            throw FPLNavV7ValidationError(path: "execution", reason: "expected eligible execution")
        }
        return plannedNavigation
    }

    private func emptyV7Flight() throws -> FlightPlan {
        var object = try fixtureJSONObject("representative-v7", directory: "V7/Official")
        var navigation = try #require(object["navigation"] as? [String: Any])
        var route = try #require(navigation["route"] as? [String: Any])
        route["waypointOrder"] = []; route["waypoints"] = []; route["legs"] = []
        navigation["route"] = route
        navigation["identificationPoints"] = []; navigation["altitudeChanges"] = []
        navigation["radioFrequencyChanges"] = []; navigation["vorDmeReferences"] = []
        object["navigation"] = navigation
        var plannedNavigation = try #require(object["execution"] as? [String: Any])
        plannedNavigation["legs"] = []; plannedNavigation["annotations"] = []; plannedNavigation["vorDmeReferences"] = []
        plannedNavigation["frequenciesByPhase"] = ["departure": [], "en-route": [], "arrival": []]
        object["execution"] = plannedNavigation
        return try decode(object)
    }

    private func twoLegFlight(
        withImmediateChanges: Bool = false,
        withIdentificationPointsOnBothLegs: Bool = false
    ) throws -> FlightPlan {
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
        var plannedNavigation = try #require(object["execution"] as? [String: Any])
        var legs = try #require(plannedNavigation["legs"] as? [[String: Any]])
        var resolved = legs[0]; resolved["legId"] = secondID
        legs.append(resolved); plannedNavigation["legs"] = legs
        if withIdentificationPointsOnBothLegs {
            let pointID = "00000000-0000-4000-8000-000000000024"
            var points = try #require(navigation["identificationPoints"] as? [[String: Any]])
            var point = points[0]
            point["id"] = pointID
            point["legId"] = secondID
            points.append(point)
            navigation["identificationPoints"] = points

            var annotations = try #require(plannedNavigation["annotations"] as? [[String: Any]])
            var annotation = annotations[0]
            annotation["entityId"] = pointID
            annotation["legId"] = secondID
            annotation["position"] = ["latitude": 0.023, "longitude": 0.006]
            annotations.append(annotation)
            plannedNavigation["annotations"] = annotations
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
            var annotations = try #require(plannedNavigation["annotations"] as? [[String: Any]])
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
            plannedNavigation["annotations"] = annotations
            var frequenciesByPhase = try #require(plannedNavigation["frequenciesByPhase"] as? [String: Any])
            var enRoute = try #require(frequenciesByPhase["en-route"] as? [[String: Any]])
            enRoute.append([
                "id": "route:\(frequencyID)",
                "name": "Next Control",
                "frequencyMhz": 120.6,
                "source": "route"
            ])
            frequenciesByPhase["en-route"] = enRoute
            plannedNavigation["frequenciesByPhase"] = frequenciesByPhase
        }
        object["navigation"] = navigation
        object["execution"] = plannedNavigation
        return try decode(object)
    }

    private func flightWithThreeIdentificationPoints() throws -> FlightPlan {
        var object = try fixtureJSONObject("representative-v7", directory: "V7/Official")
        var navigation = try #require(object["navigation"] as? [String: Any])
        var points = try #require(navigation["identificationPoints"] as? [[String: Any]])
        let originalPoint = try #require(points.first)
        let legID = try #require(originalPoint["legId"] as? String)
        var plannedNavigation = try #require(object["execution"] as? [String: Any])
        var annotations = try #require(plannedNavigation["annotations"] as? [[String: Any]])
        let originalPointID = try #require(originalPoint["id"] as? String)
        let sourceAnnotation = try #require(annotations.first {
            $0["entityId"] as? String == originalPointID
        })
        let sourceAnnotationIndex = try #require(annotations.firstIndex {
            $0["entityId"] as? String == originalPointID
        })
        annotations[sourceAnnotationIndex]["noWindTimeFromLegStartSeconds"] = 10
        if sourceAnnotation["withWindTimeFromLegStartSeconds"] != nil {
            annotations[sourceAnnotationIndex]["withWindTimeFromLegStartSeconds"] = 10
        }

        for (offset, pointID) in [
            "00000000-0000-4000-8000-000000000030",
            "00000000-0000-4000-8000-000000000031"
        ].enumerated() {
            var point = originalPoint
            point["id"] = pointID
            point["legId"] = legID
            points.append(point)

            var annotation = sourceAnnotation
            annotation["entityId"] = pointID
            annotation["legId"] = legID
            annotation["noWindTimeFromLegStartSeconds"] = (offset + 2) * 10
            if sourceAnnotation["withWindTimeFromLegStartSeconds"] != nil {
                annotation["withWindTimeFromLegStartSeconds"] = (offset + 2) * 10
            }
            annotations.append(annotation)
        }
        navigation["identificationPoints"] = points
        plannedNavigation["annotations"] = annotations
        object["navigation"] = navigation
        object["execution"] = plannedNavigation
        return try decode(object)
    }

    private func summaryFlight() throws -> FlightPlan {
        var object = try fixtureJSONObject("representative-v7", directory: "V7/Official")
        var plannedNavigation = try #require(object["execution"] as? [String: Any])
        var legs = try #require(plannedNavigation["legs"] as? [[String: Any]])
        var leg = legs[0]
        var noWind = try #require(leg["noWind"] as? [String: Any])
        noWind["plannedDurationSeconds"] = 382
        leg["noWind"] = noWind
        var withWind = try #require(leg["withWind"] as? [String: Any])
        withWind["plannedDurationSeconds"] = 382
        leg["withWind"] = withWind
        legs[0] = leg
        plannedNavigation["legs"] = legs
        object["execution"] = plannedNavigation
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
        var plannedNavigation = try required(object["execution"] as? [String: Any])
        switch self {
        case .missingLeg:
            plannedNavigation["legs"] = []
        case .duplicateLeg:
            var legs = try required(plannedNavigation["legs"] as? [[String: Any]])
            legs.append(legs[0]); plannedNavigation["legs"] = legs
        case .reorderedLeg:
            try makeTwoLegPlan(navigation: &navigation, plannedNavigation: &plannedNavigation)
            var legs = try required(plannedNavigation["legs"] as? [[String: Any]])
            legs.swapAt(0, 1); plannedNavigation["legs"] = legs
        case .missingAnnotation:
            var values = try required(plannedNavigation["annotations"] as? [[String: Any]])
            values.removeLast(); plannedNavigation["annotations"] = values
        case .duplicateAnnotation:
            var values = try required(plannedNavigation["annotations"] as? [[String: Any]])
            values[1] = values[0]; plannedNavigation["annotations"] = values
        case .missingReference:
            var values = try required(plannedNavigation["vorDmeReferences"] as? [[String: Any]])
            values.removeLast(); plannedNavigation["vorDmeReferences"] = values
        case .duplicateReference:
            var values = try required(plannedNavigation["vorDmeReferences"] as? [[String: Any]])
            values[1] = values[0]; plannedNavigation["vorDmeReferences"] = values
        case .invalidCourse:
            try mutateFirstLeg(&plannedNavigation) { $0["trueCourseDegrees"] = 360 }
        case .invalidDuration:
            try mutateFirstLeg(&plannedNavigation) { leg in
                var timing = try required(leg["noWind"] as? [String: Any]); timing["plannedDurationSeconds"] = 0; leg["noWind"] = timing
            }
        case .invalidAnnotationTime:
            var values = try required(plannedNavigation["annotations"] as? [[String: Any]])
            values[0]["noWindTimeFromLegStartSeconds"] = 41; plannedNavigation["annotations"] = values
        case .absentWind:
            try mutateFirstLeg(&plannedNavigation) { $0.removeValue(forKey: "withWind") }
        case .unexpectedWind:
            var presentation = try required(navigation["presentation"] as? [String: Any])
            var log = try required(presentation["navigationLog"] as? [String: Any]); log["windEnabled"] = false
            presentation["navigationLog"] = log; navigation["presentation"] = presentation
        case .mismatchedWind:
            try mutateFirstLeg(&plannedNavigation) { leg in
                var wind = try required(leg["withWind"] as? [String: Any])
                wind["effectiveWind"] = ["directionFromTrueDegrees": 90, "speedKnots": 1]; leg["withWind"] = wind
            }
        case .missingAutomaticElevation:
            var values = try required(plannedNavigation["vorDmeReferences"] as? [[String: Any]])
            values[0].removeValue(forKey: "stationElevationFeetMsl"); plannedNavigation["vorDmeReferences"] = values
        case .inconsistentManualValues:
            var values = try required(plannedNavigation["vorDmeReferences"] as? [[String: Any]])
            values[1]["slantRangeNauticalMiles"] = 12.5; plannedNavigation["vorDmeReferences"] = values
        case .invalidFrequency:
            var phases = try required(plannedNavigation["frequenciesByPhase"] as? [String: Any])
            var values = try required(phases["departure"] as? [[String: Any]])
            values[0]["frequencyMhz"] = 1000; phases["departure"] = values; plannedNavigation["frequenciesByPhase"] = phases
        case .missingRouteFrequency:
            var phases = try required(plannedNavigation["frequenciesByPhase"] as? [String: Any]); phases["en-route"] = []; plannedNavigation["frequenciesByPhase"] = phases
        case .missingUserFrequency:
            var context = try required(navigation["operationalContext"] as? [String: Any])
            context["frequencyEntries"] = [["id": "required", "phase": "departure", "name": "Required", "frequencyMhz": 123.4]]
            navigation["operationalContext"] = context
        case .duplicatePhaseFrequency:
            var phases = try required(plannedNavigation["frequenciesByPhase"] as? [String: Any])
            var values = try required(phases["departure"] as? [[String: Any]]); values.append(values[0]); phases["departure"] = values; plannedNavigation["frequenciesByPhase"] = phases
        case .unknownExecutionProperty:
            plannedNavigation["invented"] = true
        }
        object["navigation"] = navigation
        object["execution"] = plannedNavigation
    }

    private func mutateFirstLeg(_ plannedNavigation: inout [String: Any], mutation: (inout [String: Any]) throws -> Void) throws {
        var legs = try required(plannedNavigation["legs"] as? [[String: Any]])
        try mutation(&legs[0]); plannedNavigation["legs"] = legs
    }

    private func makeTwoLegPlan(navigation: inout [String: Any], plannedNavigation: inout [String: Any]) throws {
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
        var legs = try required(plannedNavigation["legs"] as? [[String: Any]])
        var resolved = legs[0]; resolved["legId"] = secondID; legs.append(resolved); plannedNavigation["legs"] = legs
    }

    private func required<T>(_ value: T?) throws -> T {
        guard let value else { throw FPLNavV7ValidationError(path: "test", reason: "fixture shape") }
        return value
    }
}
