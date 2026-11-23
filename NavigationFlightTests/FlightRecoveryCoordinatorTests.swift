import Foundation
import os
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Flight recovery coordination")
struct FlightRecoveryCoordinatorTests {
    @Test("Reporting the scheduled departure starts or readies the saved first replacement leg",
          arguments: [false, true], [0.5, 1.0])
    func scheduledDepartureRespectsProgression(manual: Bool, fraction: Double) async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskFlightRecordingStore(rootDirectory: directory)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0,
                            executionMode: .noWind, progressionPolicy: manual ? .manualNextLeg : .automaticNextLeg)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(
            flight: started.flight, plan: plan, departureFraction: fraction, rejoinIndex: 1
        )
        let confirmed = try await engine.commit(.confirmPendingAmendment(
            amendment, plan: plan, at: time.addingTimeInterval(5), elapsed: .seconds(5)
        ))
        let map = try AviationMapPresentationFactory().makePresentation(flightPlan: plan, flight: confirmed.flight)
        let reportAt = time.addingTimeInterval(30)
        if fraction < 1 {
            await #expect(throws: PendingRouteAmendment.Validation.unavailableDeparture) {
                try await engine.commit(.reachCurrentWaypoint(
                    orderedActiveLegPointKeys: [], at: reportAt, elapsed: .seconds(30),
                    eventIDs: [UUID(), UUID(), UUID()], expectedLegID: plan.legs[0].id,
                    expectedTargetID: plan.legs[0].arrival.id
                ))
            }
        }
        let reach = RecordedNavigationCommand.reachCurrentWaypoint(
            orderedActiveLegPointKeys: map.identificationPoints.map(\.id), at: reportAt,
            elapsed: .seconds(30), eventIDs: [UUID(), UUID(), UUID()], expectedLegID: plan.legs[0].id,
            expectedTargetID: map.destinationTarget.id.targetID
        )
        let result = try await engine.commit(reach)
        let retried = try await engine.commit(reach)
        #expect(retried == result)
        #expect(result.flight.pendingRouteAmendment == nil)
        #expect(result.flight.legIDs[result.flight.activeLegIndex] == amendment.replacementLegs[0].id)
        #expect(result.flight.legTimings.first?.startedAt == time)
        #expect(result.flight.legTimings.first?.reachedAt == (fraction == 1 ? reportAt : nil))
        #expect(result.flight.legState == (manual ? .ready : .active))
        #expect(result.flight.legStartedAt == (manual ? nil : reportAt))
        let journal = try await store.readSnapshot(id: started.recording.id)
        #expect(journal.events.filter { $0.payload == .waypointReached(legID: plan.legs[0].id) }.count
            == (fraction == 1 ? 1 : 0))

        let recovery = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(40) })
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(
            id: started.recording.id, at: time.addingTimeInterval(40), elapsed: .seconds(40), eventID: UUID()
        )
        #expect(recovered.flight == result.flight)
        #expect(recovered.cockpitContext == result.cockpitContext)
        if manual {
            let resumed = FlightRecordingEngine(
                store: store, recoveredFlight: recovered.flight, recoveredRecording: recovered.recording,
                recoveredCockpitContext: recovered.cockpitContext
            )
            let laterStart = time.addingTimeInterval(55)
            let replacement = try await resumed.promoteForStartLeg(
                at: laterStart, recordingID: started.recording.id, eventIDs: [UUID()], checklistSelection: .establishHeading
            )
            #expect(replacement.flight.legStartedAt == laterStart)
            #expect(replacement.cockpitContext?.checklists[amendment.replacementLegs[0].id]?.selection == .establishHeading)
        }

    }

    @Test("Start Now journals departure and starts immediately with Manual scheduled progression", arguments: [0.0, 0.5])
    func startNowAndFlyReplacementSuccessor(departureFraction: Double) async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let store = InMemoryFlightRecordingStore()
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0,
                            executionMode: .noWind, progressionPolicy: .manualNextLeg)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(
            flight: started.flight, plan: plan, departureFraction: departureFraction,
            rejoinIndex: 1, startNow: true, addVia: true
        )
        let startAt = time.addingTimeInterval(20)
        let command = RecordedNavigationCommand.startAmendmentNow(
            amendment, plan: plan, at: startAt, elapsed: .seconds(20), eventIDs: [UUID(), UUID()]
        )
        let active = try await engine.commit(command, checklistSelection: .establishHeading)
        #expect(active.flight.legStartedAt == startAt)
        #expect(active.flight.legTimings.first?.reachedAt == nil)
        #expect(active.flight.legTimings.first?.actualElapsedDuration == 20)
        #expect(active.flight.legTimings.first?.amendmentDepartureAt == startAt)
        if departureFraction == 0 {
            #expect(amendment.retainedDeparturePointIDs.isEmpty)
            #expect(active.flight.identificationPointTimings.isEmpty)
        }
        #expect(active.cockpitContext?.checklists[amendment.replacementLegs[0].id]?.selection == .establishHeading)
        let map = try AviationMapPresentationFactory().makePresentation(flightPlan: plan, flight: active.flight)
        #expect(map.activeLeg?.id == amendment.replacementLegs[0].id)
        #expect(map.nextLegPreview?.id == amendment.replacementLegs[1].id)
        #expect(map.identificationPoints.isEmpty)
        #expect(map.minuteMarkers.isEmpty)
        #expect(map.driftReferenceArms.isEmpty)
        let cues = try CockpitOperationalCueProjector().project(flightPlan: plan, flight: active.flight, at: startAt)
        #expect(cues.currentAltitude.value == 2_500)
        #expect(cues.frequencies.first?.frequency.frequencyMHz == 123.5)
        #expect(cues.dueEvents.contains(.frequency(amendment.replacementLegs[0].id)))
        let adapter = CockpitPresentationAdapter()
        let replacement = try adapter.makePresentation(
            flightPlan: plan, legIndex: active.flight.activeLegIndex, mode: .noWind, flight: active.flight
        )
        #expect(replacement.magneticHeadingDegrees == 87)
        #expect(replacement.legDurationSeconds == 200)
        #expect(replacement.frequencyPlan.entries.first?.frequencyMHz == 123.50)
        #expect(cues.communicationPlan.entries.first?.role == "Advisory")
        let nextProjection = try adapter.makeNextLegPreparation(flightPlan: plan, flight: active.flight)
        let next = try #require(nextProjection)
        #expect(next.direction == .heading(104))
        #expect(next.origin == amendment.replacementLegs[0].to.name)
        #expect(try adapter.makePreviousLegSummary(flightPlan: plan, flight: active.flight) == nil)

        let amendedID = active.flight.activeLegID
        let revised = try await engine.commit(.reviseHeading(
            legID: amendedID, baselineDegrees: 87, committedDegrees: 88,
            at: time.addingTimeInterval(22), elapsed: .seconds(22), eventID: UUID()
        ))
        #expect(revised.flight.pilotHeadingState(for: amendedID)?.operationalDegrees == 88)
        let revisedETA = try await engine.commit(.reviseETA(
            target: map.destinationTarget.id, plannedElapsedSeconds: 200, committedSeconds: 205,
            at: time.addingTimeInterval(23), elapsed: .seconds(23), eventID: UUID()
        ))
        #expect(revisedETA.flight.committedPilotETA(targetKey: map.destinationTarget.id) == 205)
        let ready = try await engine.commit(.reachCurrentWaypoint(
            orderedActiveLegPointKeys: [], at: time.addingTimeInterval(30), elapsed: .seconds(30),
            eventIDs: [UUID()], expectedLegID: map.destinationTarget.id.legID
        ))
        #expect(ready.flight.activeLegID == amendment.replacementLegs[1].id)
        #expect(ready.flight.legStartedAt == nil)
        let previousProjection = try adapter.makePreviousLegSummary(flightPlan: plan, flight: ready.flight)
        let previous = try #require(previousProjection)
        #expect(previous.targets.first?.id == map.destinationTarget.id)
        #expect(previous.revisedETASeconds == 205)
        #expect(previous.headingHistory.operationalDegrees == 88)
        #expect(ready.flight.pilotHeadingState(for: ready.flight.activeLegID) == nil)
        #expect(try adapter.makeNextLegPreparation(flightPlan: plan, flight: ready.flight) == nil)

        let second = try await engine.promoteForStartLeg(
            at: time.addingTimeInterval(40), recordingID: started.recording.id, eventIDs: [UUID()], checklistSelection: .none
        )
        #expect(second.flight.legStartedAt == time.addingTimeInterval(40))
        #expect(second.cockpitContext?.checklists[amendment.replacementLegs[1].id]?.selection == StartChecklistSelection.none)
        let secondCues = try CockpitOperationalCueProjector().project(
            flightPlan: plan, flight: second.flight, at: time.addingTimeInterval(40)
        )
        #expect(secondCues.currentAltitude.value == 2_500)
        #expect(secondCues.frequencies.first?.frequency.frequencyMHz == 123.5)
        #expect(secondCues.dueEvents.isEmpty)

        let journal = try await store.readSnapshot(id: started.recording.id)
        #expect(journal.events.filter { $0.payload == .waypointReached(legID: plan.legs[0].id) }.isEmpty)
        let recovery = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(50) })
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(
            id: started.recording.id, at: time.addingTimeInterval(50), elapsed: .seconds(50), eventID: UUID()
        )
        #expect(recovered.flight == second.flight)
        #expect(recovered.cockpitContext == second.cockpitContext)
    }

    @Test("Ordinary Reach restores the retained route and survives disk recovery",
          arguments: [false, true], [0, 1, 2, 3])
    func rejoinRetainedRoute(manual: Bool, scenario: Int) async throws {
        let isPartway = scenario == 0 || scenario == 3
        let isWind = scenario == 3
        let source = try retainedRouteFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let failReachCompanion = OSAllocatedUnfairLock(initialState: false)
        let store = DiskFlightRecordingStore(rootDirectory: directory, beforeAppend: { event in
            guard case .waypointReached = event.payload else { return }
            if failReachCompanion.withLock({ armed in defer { armed = false }; return armed }) {
                throw CocoaError(.fileWriteUnknown)
            }
        })
        let flight = Flight(
            flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0,
            executionMode: isWind ? .wind : .noWind, progressionPolicy: manual ? .manualNextLeg : .automaticNextLeg
        )
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(
            flight: started.flight, plan: plan, departureFraction: 0.25,
            rejoinIndex: scenario == 2 ? 1 : 0, rejoinFraction: isPartway ? 0.5 : 1, startNow: true
        )
        let replacement = try await engine.commit(.startAmendmentNow(
            amendment, plan: plan, at: time.addingTimeInterval(10), elapsed: .seconds(10), eventIDs: [UUID(), UUID()]
        ))
        let approach = try AviationMapPresentationFactory().makePresentation(flightPlan: plan, flight: replacement.flight)
        let originalHeading = try await engine.commit(.reviseHeading(
            legID: replacement.flight.activeLegID, baselineDegrees: 87, committedDegrees: 88,
            at: time.addingTimeInterval(20), elapsed: .seconds(20), eventID: UUID()
        ))
        #expect(originalHeading.flight.pilotHeadingState(for: replacement.flight.activeLegID)?.operationalDegrees == 88)
        _ = try await engine.commit(.reviseETA(
            target: approach.destinationTarget.id, plannedElapsedSeconds: 200, committedSeconds: 205,
            at: time.addingTimeInterval(21), elapsed: .seconds(21), eventID: UUID()
        ))
        let reportAt = time.addingTimeInterval(40)
        let reach = RecordedNavigationCommand.reachCurrentWaypoint(
            orderedActiveLegPointKeys: [], at: reportAt, elapsed: .seconds(40),
            eventIDs: [UUID(), UUID(), UUID()], expectedLegID: approach.destinationTarget.id.legID,
            expectedTargetID: approach.destinationTarget.id.targetID
        )
        await #expect(throws: PendingRouteAmendment.Validation.invalidGeometry) {
            try await engine.commit(.reachCurrentWaypoint(
                orderedActiveLegPointKeys: [], at: reportAt, elapsed: .seconds(40),
                eventIDs: [UUID(), UUID(), UUID()], expectedLegID: approach.destinationTarget.id.legID,
                expectedTargetID: UUID()
            ))
        }
        let beforeReach = try await store.readSnapshot(id: started.recording.id)
        failReachCompanion.withLock { $0 = true }
        await #expect(throws: FlightRecordingStoreError.self) {
            try await engine.commit(reach, checklistSelection: .establishHeading)
        }
        #expect(try await store.readSnapshot(id: started.recording.id).events == beforeReach.events)
        #expect(await engine.snapshot().flight.activeLegID == replacement.flight.activeLegID)
        let rejoined = try await engine.commit(reach, checklistSelection: .establishHeading)
        let retried = try await engine.commit(reach, checklistSelection: .establishHeading)
        #expect(retried == rejoined)
        #expect(rejoined.flight.legTimings.last(where: { $0.legID == replacement.flight.activeLegID })?.reachedAt == reportAt)
        #expect(rejoined.flight.identificationPointTimings == replacement.flight.identificationPointTimings)

        if scenario == 2 {
            #expect(rejoined.flight.legState == .completed)
            #expect(rejoined.recording.navigationState == .reachedFinalWaypoint)
            let summary = try CockpitPresentationAdapter().makePreviousLegSummary(flightPlan: plan, flight: rejoined.flight)
            #expect(summary?.targets.last?.id == approach.destinationTarget.id)
        } else {
            let map = try AviationMapPresentationFactory().makePresentation(flightPlan: plan, flight: rejoined.flight)
            #expect(map.activeLeg?.from == approach.activeLeg?.to)
            #expect(rejoined.flight.legState == (manual ? .ready : .active))
            #expect(rejoined.flight.legStartedAt == (manual ? nil : reportAt))
            #expect(rejoined.cockpitContext?.checklists[rejoined.flight.activeLegID]?.selection
                    == (manual ? nil : .establishHeading))
            if isPartway {
                #expect(rejoined.flight.activeLegID != plan.legs[0].id)
                #expect(map.plannedDurationSeconds == (isWind ? 421 : 360))
                let presentation = try CockpitPresentationAdapter().makePresentation(
                    flightPlan: plan, legIndex: rejoined.flight.activeLegIndex,
                    mode: rejoined.flight.executionMode, flight: rejoined.flight
                )
                #expect(presentation.cumulativeDurationSeconds == (isWind ? 831 : 740))
                #expect(map.identificationPoints.map(\.id.identificationPointID)
                        == plan.identificationPoints.suffix(2).map(\.id))
                #expect(map.identificationPoints.allSatisfy { $0.id.legID == rejoined.flight.activeLegID })
                #expect(map.identificationPoints.map(\.plannedElapsedSeconds) == (isWind ? [1, 210] : [1, 180]))
                #expect(map.endpointReferences.map(\.id) == [plan.vorDmeReferences[1].id])
                #expect(rejoined.flight.pilotHeadingState(for: rejoined.flight.activeLegID) == nil)
                #expect(rejoined.flight.pilotHeadingState(for: replacement.flight.activeLegID)?.operationalDegrees == 88)
                #expect(rejoined.flight.committedPilotETA(targetKey: map.destinationTarget.id) == nil)
                #expect(rejoined.flight.committedPilotETA(targetKey: approach.destinationTarget.id) == 205)
                let projector = CockpitOperationalCueProjector()
                let initial = try projector.project(flightPlan: plan, flight: rejoined.flight, at: reportAt)
                #expect(initial.currentAltitude.value == 3_200)
                #expect(initial.nextAltitude?.target.value == 2_500)
                #expect(initial.communicationPlan.compactEntries.map(\.frequencyMHz) == [124.25, 124.75])
                #expect(initial.communicationPlan.compactEntries.first?.state == .current)
                #expect(initial.communicationPlan.entries.allSatisfy { $0.frequencyMHz != 123.75 })
                #expect(initial.dueEvents.isEmpty)
                if !manual {
                    let firstDue = try projector.project(
                        flightPlan: plan, flight: rejoined.flight, at: reportAt.addingTimeInterval(1)
                    )
                    #expect(firstDue.communicationPlan.compactEntries.first?.frequencyMHz == 124.75)
                    #expect(firstDue.dueEvents == [.frequency(plan.frequencyChanges[2].id)])
                    let later = try projector.project(
                        flightPlan: plan, flight: rejoined.flight, at: reportAt.addingTimeInterval(isWind ? 168 : 144)
                    )
                    #expect(later.communicationPlan.compactEntries.first?.frequencyMHz == 120.5)
                    #expect(later.dueEvents == [.frequency(plan.frequencyChanges[3].id)])
                    let checklist = try CockpitPresentationAdapter().makeLegStartChecklist(flightPlan: plan, flight: rejoined.flight)
                    #expect(checklist?.plannedAltitudeFeetMsl == 3_200)
                }
            } else {
                #expect(rejoined.flight.activeLegID == plan.legs[1].id)
                let cues = try CockpitOperationalCueProjector().project(flightPlan: plan, flight: rejoined.flight, at: reportAt)
                let startFrequency = try #require(cues.communicationPlan.compactEntries.first)
                #expect(startFrequency.frequencyMHz == 126.55)
                #expect(startFrequency.state == (manual ? .atStart : .current))
                #expect(cues.dueEvents.contains(.frequency(plan.frequencyChanges[4].id)) == !manual)
            }
        }

        let recovery = FlightRecoveryCoordinator(
            store: DiskFlightRecordingStore(rootDirectory: directory), now: { time.addingTimeInterval(50) }
        )
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(
            id: started.recording.id, at: time.addingTimeInterval(50), elapsed: .seconds(50), eventID: UUID()
        )
        #expect(recovered.flight == rejoined.flight)
        #expect(recovered.cockpitContext == rejoined.cockpitContext)
        #expect(recovered.recording.navigationState == rejoined.recording.navigationState)
        let resumed = FlightRecordingEngine(
            store: store, recoveredFlight: recovered.flight, recoveredRecording: recovered.recording,
            recoveredCockpitContext: recovered.cockpitContext
        )
        if scenario == 2 {
            let completed = try await resumed.commit(.completeNavigation(
                at: time.addingTimeInterval(51), elapsed: .seconds(51), eventID: UUID()
            ))
            #expect(completed.recording.navigationState == .complete)
        } else if manual {
            let startAt = time.addingTimeInterval(70)
            let active = try await resumed.promoteForStartLeg(
                at: startAt, recordingID: started.recording.id, eventIDs: [UUID()], checklistSelection: .tzeKivun
            )
            #expect(active.flight.legStartedAt == startAt)
            #expect(active.cockpitContext?.checklists[active.flight.activeLegID]?.selection == .tzeKivun)
        }
    }

    private func retainedRouteFixtureData() throws -> Data {
        var document = try #require(JSONSerialization.jsonObject(with: twoLegFixtureData()) as? [String: Any])
        var navigation = try #require(document["navigation"] as? [String: Any])
        var execution = try #require(document["execution"] as? [String: Any])
        var legs = try #require(execution["legs"] as? [[String: Any]])
        var timing = try #require(legs[0]["noWind"] as? [String: Any])
        timing["plannedDurationSeconds"] = 720
        legs[0]["noWind"] = timing
        var wind = try #require(legs[0]["withWind"] as? [String: Any])
        wind["plannedDurationSeconds"] = 841
        legs[0]["withWind"] = wind
        execution["legs"] = legs

        let sourcePoints = try #require(navigation["identificationPoints"] as? [[String: Any]])
        let sourcePoint = try #require(sourcePoints.first)
        let sourcePointID = try #require(sourcePoint["id"] as? String)
        let sourceFrequencies = try #require(navigation["radioFrequencyChanges"] as? [[String: Any]])
        let sourceFrequency = try #require(sourceFrequencies.first)
        let sourceFrequencyID = try #require(sourceFrequency["id"] as? String)
        var phases = try #require(execution["frequenciesByPhase"] as? [String: [[String: Any]]])
        var routeFrequencies = try #require(phases["en-route"])
        let routeFrequency = try #require(routeFrequencies.first)
        let sourceAnnotations = try #require(execution["annotations"] as? [[String: Any]])
        var annotations = sourceAnnotations.map { annotation -> [String: Any] in
            var row = annotation
            if let original = annotation["noWindTimeFromLegStartSeconds"] as? Int {
                row["noWindTimeFromLegStartSeconds"] = original * 18
                row["withWindTimeFromLegStartSeconds"] = original * 21
            }
            return row
        }

        func annotation(for sourceID: String, id: String, progress: Double) throws -> [String: Any] {
            var row = try #require(sourceAnnotations.first { ($0["entityId"] as? String) == sourceID })
            row["entityId"] = id
            // Use a chart symbol displaced well behind rejoin to verify membership by source attachment.
            row["position"] = ["latitude": 0.001, "longitude": 0.003]
            row["noWindTimeFromLegStartSeconds"] = Int((720 * progress).rounded())
            row["withWindTimeFromLegStartSeconds"] = Int((841 * progress).rounded())
            return row
        }

        var points = sourcePoints
        for fraction in [0.5, 0.5015, 0.75] {
            var point = sourcePoint
            let id = UUID().uuidString.lowercased()
            point["id"] = id
            point["legProgress"] = fraction
            point["lateralOffsetMetres"] = 500
            points.append(point)
            annotations.append(try annotation(for: sourcePointID, id: id, progress: fraction))
        }
        var frequencies: [[String: Any]] = []
        for (fraction, mhz) in [(0.1, 123.75), (0.5, 124.25), (0.5001, 124.75)] {
            var change = sourceFrequency
            let id = UUID().uuidString.lowercased()
            change["id"] = id
            change["legProgress"] = fraction
            change["frequencyMhz"] = mhz
            frequencies.append(change)
            var entry = routeFrequency
            entry["id"] = "route:\(id)"
            entry["frequencyMhz"] = mhz
            routeFrequencies.append(entry)
            annotations.append(try annotation(for: sourceFrequencyID, id: id, progress: fraction))
        }
        let successorID = try #require(legs[1]["legId"] as? String)
        let successorFrequencyID = UUID().uuidString.lowercased()
        var successorChange = sourceFrequency
        successorChange["id"] = successorFrequencyID
        successorChange["legId"] = successorID
        successorChange["legProgress"] = 0
        successorChange["frequencyMhz"] = 126.55
        var successorEntry = routeFrequency
        successorEntry["id"] = "route:\(successorFrequencyID)"
        successorEntry["frequencyMhz"] = 126.55
        routeFrequencies.append(successorEntry)
        var successorAnnotation = try annotation(for: sourceFrequencyID, id: successorFrequencyID, progress: 0)
        successorAnnotation["legId"] = successorID
        annotations.append(successorAnnotation)
        navigation["identificationPoints"] = points
        navigation["radioFrequencyChanges"] = frequencies + sourceFrequencies + [successorChange]
        phases["en-route"] = routeFrequencies
        execution["annotations"] = annotations
        execution["frequenciesByPhase"] = phases
        document["navigation"] = navigation
        document["execution"] = execution
        return try JSONSerialization.data(withJSONObject: document)
    }

    @Test("An omitted first-leg frequency keeps the first listed source reference across phases")
    func amendmentKeepsListedFrequencyReference() async throws {
        let source = try fixtureData()
        let decoded = try FPLNavDecoder().decode(source)
        let planned = try #require(decoded.plannedNavigation.plannedNavigation)
        let reference = PlannedFrequency(
            id: "route-reference", name: "Synthetic reference", role: nil,
            frequency: .init(value: 124.75), source: .user
        )
        let plan = FlightPlan(
            id: decoded.id, title: decoded.title, createdAt: decoded.createdAt, modifiedAt: decoded.modifiedAt,
            parameters: decoded.parameters, waypoints: decoded.waypoints, legs: decoded.legs,
            identificationPoints: decoded.identificationPoints, altitudeChanges: decoded.altitudeChanges,
            frequencyChanges: [], vorDmeReferences: [], operationalContext: decoded.operationalContext,
            plannedNavigation: .eligible(.init(
                calculationVersion: planned.calculationVersion, altitudeReference: planned.altitudeReference,
                legs: planned.legs, annotations: planned.annotations, vorDmeReferences: [],
                frequenciesByPhase: [.enRoute: [reference]], defaultMode: planned.defaultMode
            ))
        )
        let time = Date(timeIntervalSince1970: 10_000)
        let store = InMemoryFlightRecordingStore()
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(flight: started.flight, plan: plan, startNow: true)
        let departed = try await engine.commit(.startAmendmentNow(
            amendment, plan: plan, at: time.addingTimeInterval(10), elapsed: .seconds(10), eventIDs: [UUID(), UUID()]
        ))
        let cues = try CockpitOperationalCueProjector().project(
            flightPlan: plan, flight: departed.flight, at: time.addingTimeInterval(10)
        )
        #expect(cues.frequencies.first?.frequency.frequencyMHz == reference.frequency.value)
        #expect(cues.dueEvents.isEmpty)
    }

    @Test("Failure writing an arrival companion preserves the pending route and identical retry commits once")
    func scheduledDepartureDoesNotPublishPartialJournal() async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let shouldFail = OSAllocatedUnfairLock(initialState: true)
        let store = DiskFlightRecordingStore(rootDirectory: directory, beforeAppend: { event in
            guard case .waypointReached = event.payload else { return }
            if shouldFail.withLock({ failing in defer { failing = false }; return failing }) {
                throw CocoaError(.fileWriteUnknown)
            }
        })
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(
            flight: started.flight, plan: plan, departureFraction: 1, rejoinIndex: 1
        )
        let pending = try await engine.commit(.confirmPendingAmendment(
            amendment, plan: plan, at: time.addingTimeInterval(5), elapsed: .seconds(5)
        ))
        let map = try AviationMapPresentationFactory().makePresentation(flightPlan: plan, flight: pending.flight)
        let reportAt = time.addingTimeInterval(30)
        let ids = [UUID(), UUID(), UUID()]
        let command = RecordedNavigationCommand.reachCurrentWaypoint(
            orderedActiveLegPointKeys: map.identificationPoints.map(\.id), at: reportAt,
            elapsed: .seconds(30), eventIDs: ids, expectedLegID: map.destinationTarget.id.legID,
            expectedTargetID: map.destinationTarget.id.targetID
        )
        await #expect(throws: FlightRecordingStoreError.self) { try await engine.commit(command) }
        #expect(await engine.snapshot().flight == pending.flight)
        let failed = try await store.readSnapshot(id: started.recording.id)
        #expect(failed.events.allSatisfy { !ids.contains($0.id) })
        let applied = try await engine.commit(command)
        #expect(applied.eventIDs == ids)
        let saved = try await store.readSnapshot(id: started.recording.id)
        #expect(saved.events.suffix(3).map(\.id) == ids)
    }

    @Test("A later partway departure leaves the preceding leg operational and shortens the manually started successor")
    func pendingAmendmentOnLaterLeg() async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let store = InMemoryFlightRecordingStore()
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0,
                            executionMode: .noWind, progressionPolicy: .manualNextLeg)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(flight: started.flight, plan: plan, departureIndex: 1)
        let confirmed = try await engine.commit(.confirmPendingAmendment(
            amendment, plan: plan, at: time.addingTimeInterval(5), elapsed: .seconds(5)
        ))
        let firstMap = try AviationMapPresentationFactory().makePresentation(flightPlan: plan, flight: confirmed.flight)
        #expect(firstMap.destinationTarget.id.targetID == plan.legs[0].arrival.id)
        let preparedPreview = try CockpitPresentationAdapter().makeNextLegPreparation(
            flightPlan: plan, flight: confirmed.flight
        )
        let preview = try #require(preparedPreview)
        #expect(preview.destination == amendment.departureStop?.name)
        #expect(preview.plannedDurationSeconds == amendment.departurePlannedElapsedSeconds)
        let ready = try await engine.commit(.reachCurrentWaypoint(
            orderedActiveLegPointKeys: firstMap.identificationPoints.map(\.id), at: time.addingTimeInterval(12),
            elapsed: .seconds(12), eventIDs: [UUID()]
        ))
        #expect(ready.flight.legState == .ready)
        #expect(ready.flight.activeLegIndex == 1)
        #expect(ready.flight.legStartedAt == nil)
        let second = try await engine.promoteForStartLeg(
            at: time.addingTimeInterval(15), recordingID: started.recording.id, eventIDs: [UUID()]
        )
        #expect(second.flight.legStartedAt == time.addingTimeInterval(15))
        let secondMap = try AviationMapPresentationFactory().makePresentation(flightPlan: plan, flight: second.flight)
        #expect(secondMap.destinationTarget.id.targetID == amendment.departureStop?.id)
        #expect(secondMap.destinationTarget.id.targetID != plan.legs[1].arrival.id)
    }

    @Test("Cancel and original reach publish once, reopen, and undo as one operation", arguments: [false, true])
    func pendingAmendmentOriginalReach(manual: Bool) async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let fail = OSAllocatedUnfairLock(initialState: true)
        let store = DiskFlightRecordingStore(rootDirectory: directory, beforeAppend: { event in
            if case .waypointReached = event.payload, fail.withLock({ value in
                defer { value = false }
                return value
            }) { throw CocoaError(.fileWriteUnknown) }
        })
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0,
                            executionMode: .noWind, progressionPolicy: manual ? .manualNextLeg : .automaticNextLeg)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(flight: started.flight, plan: plan)
        let pending = try await engine.commit(.confirmPendingAmendment(
            amendment, plan: plan, at: time.addingTimeInterval(5), elapsed: .seconds(5)
        ))
        let original = try #require(pending.flight.originalDestinationReport(in: plan))
        #expect(original.targetID == plan.legs[0].arrival.id)
        let cancelID = UUID()
        let reachID = UUID()
        let automaticID = UUID()
        let command = RecordedNavigationCommand.managePendingAmendment(
            .reportOriginalDestination(original, reachEventID: reachID, automaticEventID: automaticID),
            plan: plan, at: time.addingTimeInterval(10), elapsed: .seconds(10), eventID: cancelID
        )
        let pendingJournal = try await store.readSnapshot(id: started.recording.id)
        await #expect(throws: FlightRecordingStoreError.self) { try await engine.commit(command) }
        #expect(await engine.snapshot().flight == pending.flight)
        #expect(try await store.readSnapshot(id: started.recording.id).events == pendingJournal.events)
        let reached = try await engine.commit(command)
        #expect(try await engine.commit(command) == reached)
        #expect(reached.flight.pendingRouteAmendment == nil)
        #expect(reached.flight.activeLegIndex == 1)
        #expect(reached.flight.legState == (manual ? .ready : .active))
        #expect(reached.flight.legStartedAt == (manual ? nil : time.addingTimeInterval(10)))
        let reachedJournal = try await store.readSnapshot(id: started.recording.id)
        #expect(reachedJournal.events.suffix(manual ? 2 : 3).map(\.id) ==
                (manual ? [cancelID, reachID] : [cancelID, reachID, automaticID]))
        let verificationStore = InMemoryFlightRecordingStore(packageResults: [.available(reachedJournal)])
        let verifier = FlightRecoveryCoordinator(store: verificationStore, now: { time.addingTimeInterval(14) })
        await verifier.bootstrap()
        let recovered = try await verifier.continueFlight(
            id: started.recording.id, at: time.addingTimeInterval(14), elapsed: .seconds(14), eventID: UUID()
        )
        #expect(recovered.flight == reached.flight)
        #expect(recovered.recording.navigationState == (manual ? .ready : .active))
        if manual {
            let restoredEngine = FlightRecordingEngine(
                store: verificationStore, recoveredFlight: recovered.flight, recoveredRecording: recovered.recording,
                recoveredCockpitContext: recovered.cockpitContext
            )
            let next = try await restoredEngine.promoteForStartLeg(
                at: time.addingTimeInterval(14), recordingID: recovered.recording.id, eventIDs: [UUID()]
            )
            #expect(next.flight.legStartedAt == time.addingTimeInterval(14))
        } else {
            let truncated = FlightRecordingReadSnapshot(
                recording: reachedJournal.recording, events: Array(reachedJournal.events.dropLast())
            )
            let invalidStore = InMemoryFlightRecordingStore(packageResults: [.available(truncated)])
            let invalidRecovery = FlightRecoveryCoordinator(store: invalidStore, now: { time.addingTimeInterval(14) })
            await #expect(throws: FlightRecoveryError.invalidJournal) {
                try await invalidRecovery.continueFlight(
                    id: started.recording.id, at: time.addingTimeInterval(14), elapsed: .seconds(14), eventID: UUID()
                )
            }
        }
        let undo = try await engine.commit(.undoReach(
            originalEventID: reachID, restoredFlight: pending.flight,
            at: time.addingTimeInterval(15), elapsed: .seconds(15), eventID: UUID()
        ), context: pending.cockpitContext)
        #expect(undo.flight == pending.flight)
        #expect(undo.recording.navigationState == .active)
        let recovery = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(16) })
        await recovery.bootstrap()
        let reopened = try await recovery.continueFlight(
            id: started.recording.id, at: time.addingTimeInterval(16), elapsed: .seconds(16), eventID: UUID()
        )
        #expect(reopened.flight == pending.flight)
    }

    @Test("Replacement keeps the old pending amendment until confirmation, and cancellation restores the original timer")
    func pendingAmendmentReplacementAndCancellation() async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskFlightRecordingStore(rootDirectory: directory)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let originalIdentity = try await engine.commit(.identifyDestination(
            at: time.addingTimeInterval(3), elapsed: .seconds(3), eventID: UUID(), targetID: plan.legs[0].arrival.id
        ))
        let amendment = try makePendingAmendment(flight: originalIdentity.flight, plan: plan)
        let pending = try await engine.commit(.confirmPendingAmendment(
            amendment, plan: plan, at: time.addingTimeInterval(5), elapsed: .seconds(5)
        ))

        let route = try #require(pending.flight.routeForAmendment(in: plan))
        let draft = RouteAmendmentDraft(replacing: amendment, on: route)
        #expect(draft.reviewLegs(on: route).first?.values?.durationSeconds == 200)
        let replacement = try PendingRouteAmendment(id: UUID(), draft: draft, flight: pending.flight, route: route, replacing: amendment.id)
        #expect(await engine.snapshot().flight.pendingRouteAmendment == amendment)
        let replaced = try await engine.commit(.managePendingAmendment(
            .replace(expectedPendingID: amendment.id, amendment: replacement),
            plan: plan, at: time.addingTimeInterval(7), elapsed: .seconds(7), eventID: replacement.id
        ))
        #expect(replaced.flight.pendingRouteAmendment == replacement)
        #expect(replaced.flight.destinationIdentifiedAt == nil)
        let stale = try #require(pending.flight.originalDestinationReport(in: plan))
        await #expect(throws: PendingRouteAmendment.Validation.stalePendingAmendment) {
            try await engine.commit(.managePendingAmendment(
                .reportOriginalDestination(stale, reachEventID: UUID(), automaticEventID: UUID()),
                plan: plan, at: time.addingTimeInterval(8), elapsed: .seconds(8), eventID: UUID()
            ))
        }
        let sameAnchor = PendingAmendmentOriginalDestination(
            amendmentID: replacement.id, legID: plan.legs[0].id, targetID: try #require(replacement.departureStop?.id)
        )
        await #expect(throws: PendingRouteAmendment.Validation.stalePendingAmendment) {
            try await engine.commit(.managePendingAmendment(
                .reportOriginalDestination(sameAnchor, reachEventID: UUID(), automaticEventID: UUID()),
                plan: plan, at: time.addingTimeInterval(8), elapsed: .seconds(8), eventID: UUID()
            ))
        }
        let cancelled = try await engine.commit(.managePendingAmendment(
            .cancel(expectedPendingID: replacement.id), plan: plan,
            at: time.addingTimeInterval(9), elapsed: .seconds(9), eventID: UUID()
        ))
        #expect(cancelled.flight == originalIdentity.flight)
        let reopen = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(12) })
        await reopen.bootstrap()
        let recovered = try await reopen.continueFlight(
            id: started.recording.id, at: time.addingTimeInterval(12), elapsed: .seconds(12), eventID: UUID()
        )
        #expect(recovered.flight == cancelled.flight)
    }

    @Test("Pending management, ordinary Undo, activation and retained rejoin replay together",
          arguments: [0.5, 1.0])
    func managedAmendmentRejoinsAndKeepsDraftingAvailable(rejoinFraction: Double) async throws {
        let source = try retainedRouteFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let zero = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskFlightRecordingStore(rootDirectory: directory)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: zero, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(
            flight: started.flight, plan: plan, departureFraction: 0.25, rejoinFraction: rejoinFraction
        )
        let pending = try await engine.commit(.confirmPendingAmendment(
            amendment, plan: plan, at: zero.addingTimeInterval(2), elapsed: .seconds(2)
        ))
        let report = try #require(pending.flight.originalDestinationReport(in: plan))
        let reachID = UUID()
        let cancelled = try await engine.commit(.managePendingAmendment(
            .reportOriginalDestination(report, reachEventID: reachID, automaticEventID: UUID()), plan: plan,
            at: zero.addingTimeInterval(5), elapsed: .seconds(5), eventID: UUID()
        ))
        #expect(cancelled.flight.activeLegID == plan.legs[1].id)
        let restored = try await engine.commit(.undoReach(
            originalEventID: reachID, restoredFlight: pending.flight,
            at: zero.addingTimeInterval(6), elapsed: .seconds(6), eventID: UUID()
        ), context: pending.cockpitContext)
        #expect(restored.flight == pending.flight)
        let originalRoute = try #require(restored.flight.routeForAmendment(in: plan))
        let replacement = try PendingRouteAmendment(
            id: UUID(), draft: RouteAmendmentDraft(replacing: amendment, on: originalRoute),
            flight: restored.flight, route: originalRoute, replacing: amendment.id
        )
        let replaced = try await engine.commit(.managePendingAmendment(
            .replace(expectedPendingID: amendment.id, amendment: replacement), plan: plan,
            at: zero.addingTimeInterval(7), elapsed: .seconds(7), eventID: replacement.id
        ))
        let departureTarget = try AviationMapPresentationFactory().makePresentation(
            flightPlan: plan, flight: replaced.flight
        ).destinationTarget.id
        let departed = try await engine.commit(.reachCurrentWaypoint(
            orderedActiveLegPointKeys: [], at: zero.addingTimeInterval(10), elapsed: .seconds(10),
            eventIDs: [UUID(), UUID(), UUID()], expectedLegID: departureTarget.legID,
            expectedTargetID: departureTarget.targetID
        ))
        let rejoinTarget = try AviationMapPresentationFactory().makePresentation(
            flightPlan: plan, flight: departed.flight
        ).destinationTarget.id
        let joined = try await engine.commit(.reachCurrentWaypoint(
            orderedActiveLegPointKeys: [], at: zero.addingTimeInterval(20), elapsed: .seconds(20),
            eventIDs: [UUID(), UUID(), UUID()], expectedLegID: rejoinTarget.legID, expectedTargetID: rejoinTarget.targetID
        ))
        #expect(joined.flight.pendingRouteAmendment == nil)
        #expect(joined.flight.activatedRouteAmendment?.amendment.id == replacement.id)
        #expect(joined.flight.activeLegID != departed.flight.activeLegID)
        let route = try #require(joined.flight.routeForAmendment(in: plan))
        #expect(route.legs.map(\.id) == joined.flight.legIDs)
        let retained = route.legs[joined.flight.activeLegIndex]
        #expect(retained.departure.id == replacement.replacementLegs.last?.to.id)
        if rejoinFraction < 1 {
            #expect(retained.id == joined.flight.activatedRouteAmendment?.splitLegID)
            #expect(route.originalLeg(retained.id)?.durationSeconds == 360)
            #expect(route.identificationPoints.filter { $0.legID == retained.id }.count == 2)
        } else {
            #expect(retained == plan.legs[1])
        }

        let fresh = try await store.readSnapshot(id: started.recording.id)
        #expect(fresh.events.filter { $0.id == reachID }.count == 1)
        #expect(fresh.events.contains { $0.payload == .pendingRouteAmendmentReplaced(previousID: amendment.id, amendment: replacement) })
        let rejoin = try #require(departed.flight.amendmentRejoin)
        #expect(fresh.events.contains { $0.payload == .routeAmendmentRejoined(rejoin) })
        let recovery = FlightRecoveryCoordinator(
            store: DiskFlightRecordingStore(rootDirectory: directory), now: { zero.addingTimeInterval(25) }
        )
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(
            id: started.recording.id, at: zero.addingTimeInterval(25), elapsed: .seconds(25), eventID: UUID()
        )
        #expect(recovered.flight == joined.flight)
        #expect(recovered.cockpitContext == joined.cockpitContext)
        var cockpit = CockpitFeatureState()
        cockpit.restore(flightPlan: plan, flight: recovered.flight, sourceData: source, cockpitContext: recovered.cockpitContext)
        cockpit.updateRouteAmendment(.open)
        let newDraft = try #require(cockpit.routeAmendmentDraft)
        #expect(newDraft.step == .departure)
        let departure = route.anchor(at: recovered.flight.activeLegIndex, fraction: 0.5)
        cockpit.updateRouteAmendment(.chooseAnchor(departure))
        #expect(cockpit.routeAmendmentDraft?.departure == departure)
        #expect(cockpit.flight == recovered.flight)
        #expect(!PendingRouteAmendment.canConfirm(departure, flight: recovered.flight, route: route, startNow: false))
    }

    @Test("A draft on the activated route preserves its geometry, inputs and existing flight")
    func draftAfterActivationUsesRemainingRoute() async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let store = InMemoryFlightRecordingStore()
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(flight: started.flight, plan: plan, rejoinIndex: 1, startNow: true, addVia: true)
        let activated = try await engine.commit(.startAmendmentNow(
            amendment, plan: plan, at: time.addingTimeInterval(10), elapsed: .seconds(10), eventIDs: [UUID(), UUID()]
        ))
        let beforeDraft = try await store.readSnapshot(id: started.recording.id)
        var state = CockpitFeatureState()
        state.restore(flightPlan: plan, flight: activated.flight, sourceData: source, cockpitContext: activated.cockpitContext)
        let route = try #require(state.routeForAmendment)
        #expect(route.legs.map(\.id) == activated.flight.legIDs)
        let boundary = route.anchor(at: activated.flight.activeLegIndex, fraction: 0)
        #expect(route.firstAvailable == boundary)
        #expect(route.contains(boundary))
        #expect(route.contains(route.anchor(at: 0, fraction: 0.5)) == false)
        #expect(route.originalLeg(activated.flight.activeLegID)?.durationSeconds == 200)
        #expect(route.legs[0].arrival.id == amendment.departureStop?.id)
        let departure = route.anchor(at: activated.flight.activeLegIndex, fraction: 0.5)
        let rejoin = route.anchor(at: activated.flight.activeLegIndex + 1, fraction: 1)
        state.updateRouteAmendment(.open)
        state.updateRouteAmendment(.chooseAnchor(departure))
        state.updateRouteAmendment(.chooseRejoin)
        state.updateRouteAmendment(.chooseAnchor(rejoin))
        state.updateRouteAmendment(.confirmRejoin)
        state.updateRouteAmendment(.review)
        let initialDraft = try #require(state.routeAmendmentDraft)
        #expect(initialDraft.step == .review)
        let proposed = try #require(initialDraft.reviewLegs(on: route).first)
        state.updateRouteAmendment(.editLeg(proposed.id))
        state.updateRouteAmendment(.editLegField(.heading, "093"))
        state.updateRouteAmendment(.editLegField(.minutes, "02"))
        state.updateRouteAmendment(.editLegField(.seconds, "30"))
        state.updateRouteAmendment(.saveLegValues)
        state.updateRouteAmendment(.pause)
        #expect(state.routeAmendmentDraft?.isPaused == true)
        state.updateRouteAmendment(.resume)
        let resumed = try #require(state.routeAmendmentDraft)
        #expect(resumed.departure == departure)
        #expect(resumed.rejoin == rejoin)
        #expect(resumed.reviewLegs(on: route).first?.values?.headingMagnetic == 93)
        #expect(resumed.reviewLegs(on: route).first?.values?.durationSeconds == 150)
        #expect(state.flight == activated.flight)
        #expect(try await store.readSnapshot(id: started.recording.id).events == beforeDraft.events)
        #expect(throws: PendingRouteAmendment.Validation.unavailableDeparture) {
            try PendingRouteAmendment(id: UUID(), draft: resumed, flight: activated.flight, route: route)
        }
    }

    @Test("A pending amendment is invisible until its writer finishes and queued checkpoints preserve it", .timeLimit(.minutes(1)))
    func pendingAmendmentSerializesWithCheckpoint() async throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let disk = DiskFlightRecordingStore(rootDirectory: directory)
        let store = SuspendedPresentationRecordingStore(base: disk)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(flight: started.flight, plan: plan)
        await store.suspendNextAppend()
        let confirmation = Task {
            try await engine.commit(.confirmPendingAmendment(
                amendment, plan: plan, at: time.addingTimeInterval(5), elapsed: .seconds(5)
            ))
        }
        await store.waitUntilSuspended()
        let duringWrite = await engine.snapshot()
        #expect(duringWrite.flight.pendingRouteAmendment == nil)
        let checkpointAt = time.addingTimeInterval(6)
        let checkpoint = Task { try await engine.checkpoint(recordingID: started.recording.id, at: checkpointAt) }
        await store.release()
        let confirmed = try await confirmation.value
        try await checkpoint.value
        let snapshot = try await disk.readSnapshot(id: started.recording.id)
        #expect(snapshot.recording.lastRecoveryCheckpointAt == checkpointAt)
        #expect(snapshot.events.last?.payload == .pendingRouteAmendmentConfirmed(amendment))
        #expect(snapshot.events.last?.cockpitContext == confirmed.cockpitContext)
    }

    @Test("Track samples and checkpointing survive an uncertain route write and refused replacement")
    func pendingAmendmentUncertainWriteRetainsRecording() async throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let disk = DiskFlightRecordingStore(rootDirectory: directory, afterRouteInstall: {
            throw CocoaError(.fileWriteUnknown)
        })
        let store = SuspendedPresentationRecordingStore(base: disk)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let seedEngine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await seedEngine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let now = OSAllocatedUnfairLock(initialState: time)
        let coordinator = FlightRecordingCoordinator(
            store: store, wallClockNow: { now.withLock { $0 } }, recoveryCheckpointInterval: 0.25
        )
        await coordinator.restore(RecoveredFlight(
            flightPlan: plan, flight: started.flight, recording: started.recording, cockpitContext: started.cockpitContext
        ))
        let amendment = try makePendingAmendment(flight: started.flight, plan: plan)
        let confirm = RecordedNavigationCommand.confirmPendingAmendment(
            amendment, plan: plan, at: time.addingTimeInterval(5), elapsed: .seconds(5)
        )
        await store.failNextRouteRead()
        await #expect(throws: FlightRecordingEngine.EngineError.routeOutcomeUncertain) {
            try await coordinator.commitNavigation(confirm)
        }
        #expect(coordinator.snapshot.flight.pendingRouteAmendment == nil)
        await #expect(throws: FlightRecordingStoreError.self) {
            try await coordinator.prepareForFlightReplacement(
                at: time.addingTimeInterval(6), eventIDs: [UUID(), UUID()]
            )
        }

        let first = time.addingTimeInterval(7)
        let resumed = time.addingTimeInterval(9)
        let afterWriteGap = time.addingTimeInterval(11)
        await coordinator.handleLocationEvent(amendmentTrackEvent(at: first))
        #expect(coordinator.effectiveStatus == .recording)
        await coordinator.handleLocationEvent(.signalLost)
        #expect(coordinator.effectiveStatus == .gpsGap)
        await coordinator.handleLocationEvent(amendmentTrackEvent(at: resumed))
        #expect(coordinator.effectiveStatus == .gpsResumed)
        await store.failNextTrackAppend()
        await coordinator.handleLocationEvent(amendmentTrackEvent(at: time.addingTimeInterval(10)))
        #expect(coordinator.effectiveStatus == .recordingDegraded)
        await coordinator.handleLocationEvent(amendmentTrackEvent(at: afterWriteGap))

        let recordingID = started.recording.id
        let pending = try await disk.readSnapshot(id: recordingID)
        #expect(Set(pending.trackSegments.map { $0.samples.map(\.observedAt) }) == Set([[first], [resumed], [afterWriteGap]]))
        #expect(pending.events.map(\.id) == started.eventIDs + [amendment.id])
        #expect(pending.recording.closure == nil)

        let confirmed = try await coordinator.commitNavigation(confirm)
        #expect(confirmed.flight.pendingRouteAmendment == amendment)
        let checkpoint = time.addingTimeInterval(12)
        now.withLock { $0 = checkpoint }
        let stop = ContinuousClock.now.advanced(by: .seconds(2))
        while try await disk.readSnapshot(id: recordingID).recording.lastRecoveryCheckpointAt != checkpoint,
              ContinuousClock.now < stop {
            try await Task.sleep(for: .milliseconds(10))
        }
        let final = try await disk.readSnapshot(id: recordingID)
        await coordinator.disarm()
        #expect(final.recording.lastRecoveryCheckpointAt == checkpoint)
        #expect(final.events.filter { $0.id == amendment.id }.count == 1)
    }

    @Test("Checkpoint expiry uses the newest durable amendment or track activity")
    func pendingAmendmentCheckpointExpiryUsesDurableActivity() async throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let store = InMemoryFlightRecordingStore()
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        await engine.arm()
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let recordingID = started.recording.id
        let amendment = try makePendingAmendment(flight: started.flight, plan: plan)
        let amendmentTime = time.addingTimeInterval(200)
        _ = try await engine.commit(.confirmPendingAmendment(amendment, plan: plan, at: amendmentTime, elapsed: .seconds(200)))
        let window = started.recording.recoveryWindowSeconds
        let beforeAmendmentExpiry = try await engine.expireRecoveryCheckpoint(
            recordingID: recordingID, at: amendmentTime.addingTimeInterval(window - 1)
        )
        #expect(beforeAmendmentExpiry == nil)

        let sampleTime = time.addingTimeInterval(250)
        _ = await engine.ingest(amendmentTrackEvent(at: sampleTime), monotonicTime: .seconds(250))
        let beforeTrackExpiry = try await engine.expireRecoveryCheckpoint(
            recordingID: recordingID, at: sampleTime.addingTimeInterval(window - 1)
        )
        #expect(beforeTrackExpiry == nil)
        let closed = try await engine.expireRecoveryCheckpoint(
            recordingID: recordingID, at: sampleTime.addingTimeInterval(window)
        )
        #expect(closed?.closure?.closedAt == sampleTime)
        #expect(closed?.closure?.cause == .recoveryExpired)
    }

    private func amendmentTrackEvent(at time: Date) -> LocationSourceEvent {
        let sample = AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32, longitudeDegrees: 34.8),
            observedAt: time,
            horizontalAccuracyMeters: 10,
            altitudeMeters: nil,
            verticalAccuracyMeters: nil,
            trueCourseDegrees: nil,
            courseAccuracyDegrees: nil,
            groundSpeedMetersPerSecond: nil,
            speedAccuracyMetersPerSecond: nil
        )
        return .sample(sample, receivedAt: time)
    }

    @Test("A saved partway departure retains timing, changes the target and recovers the same route", arguments: [false, true])
    func pendingAmendmentDiskRecovery(loseAcknowledgment: Bool) async throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskFlightRecordingStore(rootDirectory: directory, afterRouteInstall: {
            if loseAcknowledgment { throw CocoaError(.fileWriteUnknown) }
        })
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let capturedPlan = RecordedFlightPlanSnapshot(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        let engine = FlightRecordingEngine(store: store, flight: flight, flightPlanSnapshot: capturedPlan)
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let originallyIdentified = try await engine.commit(.identifyDestination(
            at: time.addingTimeInterval(10), elapsed: .seconds(10), eventID: UUID()
        ))
        let initialMap = try AviationMapPresentationFactory().makePresentation(flightPlan: plan, flight: started.flight)
        let amendment = try makePendingAmendment(flight: originallyIdentified.flight, plan: plan)
        let command = RecordedNavigationCommand.confirmPendingAmendment(
            amendment, plan: plan, at: time.addingTimeInterval(20), elapsed: .seconds(20)
        )
        let confirmed = try await engine.commit(command)
        let retry = try await engine.commit(command)
        #expect(confirmed == retry)
        #expect(confirmed.flight.legStartedAt == time)
        #expect(confirmed.flight.destinationIdentifiedAt == nil)
        #expect(confirmed.flight.legTimings.first?.destinationIdentifiedAt == time.addingTimeInterval(10))
        let map = try AviationMapPresentationFactory().makePresentation(flightPlan: plan, flight: confirmed.flight)
        #expect(map.destinationTarget.id.targetID == amendment.departureStop?.id)
        #expect(map.destinationTarget.id != initialMap.destinationTarget.id)
        #expect(map.plannedDurationSeconds == Int((Double(initialMap.plannedDurationSeconds) / 2).rounded()))
        #expect(map.activeLeg?.to != initialMap.activeLeg?.to)
        #expect(map.activeLeg?.id == initialMap.activeLeg?.id)

        await #expect(throws: PendingRouteAmendment.Validation.departureRequiresAmendmentActivation) {
            try await engine.commit(.reachCurrentWaypoint(
                orderedActiveLegPointKeys: [], at: time.addingTimeInterval(25), elapsed: .seconds(25), eventIDs: [UUID(), UUID()]
            ))
        }
        let identified = try await engine.commit(.identifyDestination(
            at: time.addingTimeInterval(30), elapsed: .seconds(30), eventID: UUID(), targetID: map.destinationTarget.id.targetID
        ))
        let reopened = DiskFlightRecordingStore(rootDirectory: directory)
        let snapshot = try await reopened.readSnapshot(id: started.recording.id)
        #expect(snapshot.recording.sourceSchemaVersion == 4)
        #expect(snapshot.recording.flightPlanSnapshot.sourceData == source)
        #expect(snapshot.events.filter { $0.id == amendment.id }.count == 1)
        #expect(snapshot.trackSegments.isEmpty)
        let recovery = FlightRecoveryCoordinator(store: reopened, now: { time.addingTimeInterval(40) })
        await recovery.bootstrap()
        guard case .single(let candidate) = recovery.state else { Issue.record("Expected recoverable flight"); return }
        let recovered = try await recovery.continueFlight(
            id: candidate.id, at: time.addingTimeInterval(40), elapsed: .seconds(40), eventID: UUID()
        )
        #expect(recovered.flight == identified.flight)
        #expect(recovered.cockpitContext == identified.cockpitContext)
        var state = CockpitFeatureState()
        state.restore(flightPlan: recovered.flightPlan, flight: recovered.flight, sourceData: source, cockpitContext: recovered.cockpitContext)
        #expect(state.routeAmendmentDraft == nil)
        #expect(state.flight?.pendingRouteAmendment == amendment)
    }

    @Test("A failed first install exposes the old route and an identical retry can commit")
    func pendingAmendmentRetryAfterInterruptedUpgrade() async throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let failureCount = OSAllocatedUnfairLock(initialState: 0)
        let disk = DiskFlightRecordingStore(rootDirectory: directory, beforeAppend: { event in
            guard case .pendingRouteAmendmentConfirmed = event.payload else { return }
            let fail = failureCount.withLock { count in
                count += 1
                return count == 1
            }
            if fail { throw CocoaError(.fileWriteUnknown) }
        })
        let time = Date(timeIntervalSince1970: 10_000)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let engine = FlightRecordingEngine(
            store: disk, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(flight: started.flight, plan: plan)
        let confirm = RecordedNavigationCommand.confirmPendingAmendment(
            amendment, plan: plan, at: time.addingTimeInterval(10), elapsed: .seconds(10)
        )
        await #expect(throws: FlightRecordingStoreError.self) { try await engine.commit(confirm) }
        let unchanged = await engine.snapshot()
        #expect(unchanged.flight.pendingRouteAmendment == nil)
        let interrupted = try await DiskFlightRecordingStore(rootDirectory: directory).readSnapshot(id: started.recording.id)
        #expect(!interrupted.events.contains { $0.id == amendment.id })
        #expect(interrupted.recording.sourceSchemaVersion == 4)
        let committed = try await engine.commit(confirm)
        #expect(committed.flight.pendingRouteAmendment == amendment)
        let journal = try await disk.readSnapshot(id: started.recording.id)
        #expect(journal.events.filter { $0.id == amendment.id }.count == 1)
    }

    @Test("Readable but invalid committed geometry can be closed through recovery")
    func invalidPendingAmendmentEndsIncomplete() async throws {
        let time = Date(timeIntervalSince1970: 10_000)
        let original = try recoveryFixture(recordingID: UUID(), startedAt: time)
        let source = try #require(original.recording.flightPlanSnapshot.sourceData)
        let plan = try FPLNavDecoder().decode(source)
        var unrelated = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        try unrelated.startLeg(at: time)
        let amendment = try makePendingAmendment(flight: unrelated, plan: plan)
        let event = RecordedFlightEvent(
            id: amendment.id, sequence: UInt64(original.events.count), occurredAt: time.addingTimeInterval(5),
            elapsed: .seconds(5), origin: .pilot, payload: .pendingRouteAmendmentConfirmed(amendment)
        )
        var recording = original.recording.restoring(navigationState: original.recording.navigationState, nextEventSequence: event.sequence + 1)
        recording.sourceSchemaVersion = 4
        let store = InMemoryFlightRecordingStore(packageResults: [
            .available(.init(recording: recording, events: original.events + [event]))
        ])
        let recovery = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(15) })
        await recovery.bootstrap()
        guard case .amendmentUnavailable(let candidate, _) = recovery.state else {
            Issue.record("Expected unavailable confirmed route")
            return
        }
        try await recovery.endAsIncomplete(
            id: candidate.id, at: time.addingTimeInterval(15), elapsed: .seconds(15), eventIDs: [UUID(), UUID()]
        )
        let closed = try await store.readSnapshot(id: candidate.id)
        #expect(closed.recording.closure?.outcome == .incomplete)
        #expect(closed.events.contains(event))
        #expect(closed.recording.flightPlanSnapshot.sourceData == source)
    }

    @Test("A malformed Reach Undo cannot conceal a committed amendment during recovery")
    func undoLinkToConfirmationFailsClosed() async throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 10_000)
        let store = InMemoryFlightRecordingStore()
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let engine = FlightRecordingEngine(
            store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: flight.legIDs, sourceData: source)
        )
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let amendment = try makePendingAmendment(flight: started.flight, plan: plan)
        let confirmed = try await engine.commit(.confirmPendingAmendment(
            amendment, plan: plan, at: time.addingTimeInterval(2), elapsed: .seconds(2)
        ))
        let malformedUndo = RecordedFlightEvent(
            id: UUID(), sequence: confirmed.recording.nextEventSequence,
            occurredAt: time.addingTimeInterval(3), elapsed: .seconds(3),
            origin: .pilot, payload: .reachUndone(originalEventID: amendment.id),
            cockpitContext: confirmed.cockpitContext
        )
        try await store.appendEvent(malformedUndo, recordingID: confirmed.recording.id, synchronize: true)

        let restart = time.addingTimeInterval(4)
        let recovery = FlightRecoveryCoordinator(store: store, now: { restart })
        await recovery.bootstrap()
        guard case .amendmentUnavailable(let candidate, _) = recovery.state else {
            Issue.record("A readable journal with an invalid amendment undo must be unavailable")
            return
        }
        #expect(candidate.id == confirmed.recording.id)
        await #expect(throws: FlightRecoveryError.invalidJournal) {
            try await recovery.continueFlight(
                id: candidate.id, at: restart, elapsed: .seconds(4), eventID: UUID()
            )
        }
        let persisted = try await store.readSnapshot(id: candidate.id)
        #expect(persisted.events.last?.id == malformedUndo.id)
        #expect(persisted.events.contains { $0.id == amendment.id })
    }

    private func makePendingAmendment(
        flight: Flight, plan: FlightPlan, departureIndex: Int = 0,
        departureFraction: Double = 0.5, rejoinIndex: Int? = nil, rejoinFraction: Double = 1, startNow: Bool = false, addVia: Bool = false
    ) throws -> PendingRouteAmendment {
        let route = try #require(flight.routeForAmendment(in: plan))
        let departure = route.anchor(at: departureIndex, fraction: departureFraction)
        let end = route.anchor(at: rejoinIndex ?? departureIndex, fraction: rejoinFraction)
        var draft = RouteAmendmentDraft(flightID: flight.id, mode: .manual)
        draft.update(.chooseAnchor(departure), route: route)
        if addVia {
            let via = route.coordinate(at: departure)
            draft.update(.plot(.init(position: .init(
                latitudeDegrees: via.latitudeDegrees + 0.02, longitudeDegrees: via.longitudeDegrees + 0.02
            ))), route: route)
        }
        draft.update(.chooseRejoin, route: route)
        draft.update(.chooseAnchor(end), route: route)
        draft.update(.confirmRejoin, route: route)
        draft.update(.review, route: route)
        let legs = draft.reviewLegs(on: route)
        #expect(legs.count == (addVia ? 2 : 1))
        for (index, leg) in legs.enumerated() {
            draft.update(.editLeg(leg.id), route: route)
            draft.update(.editLegField(.heading, index == 0 ? "087" : "104"), route: route)
            draft.update(.editLegField(.minutes, "3"), route: route)
            draft.update(.editLegField(.seconds, "20"), route: route)
            if addVia && index == 0 {
                draft.update(.editLegField(.altitude, "2500"), route: route)
                draft.update(.editLegField(.frequency, "123.50"), route: route)
            }
            draft.update(.saveLegValues, route: route)
        }
        return try PendingRouteAmendment(id: UUID(), draft: draft, flight: flight, route: route, startNow: startNow)
    }

    @Test("Bootstrap expires a recording whose captured recovery window elapsed")
    func bootstrapExpiresStaleRecording() async throws {
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let snapshot = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "10101010-0000-0000-0000-000000000001")),
            startedAt: startedAt
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(301) },
            defaultRecoveryWindow: 300
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .reconciledExpired(count: 1))
        let stored = try await store.readSnapshot(id: snapshot.recording.id)
        #expect(stored.recording.closure?.outcome == .incomplete)
        #expect(stored.recording.closure?.cause == .recoveryExpired)
        #expect(stored.recording.closure?.closedAt == startedAt)
    }

    @Test("The exact recovery cutoff is expired and cannot be continued")
    func exactCutoffIsExpired() async throws {
        let startedAt = Date(timeIntervalSince1970: 2_000)
        let snapshot = try recoveryFixture(recordingID: UUID(), startedAt: startedAt)
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(300) },
            defaultRecoveryWindow: 300
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .reconciledExpired(count: 1))
    }

    @Test("A future durable timestamp fails closed")
    func futureEvidenceFailsClosed() async throws {
        let startedAt = Date(timeIntervalSince1970: 3_000)
        let snapshot = try recoveryFixture(recordingID: UUID(), startedAt: startedAt)
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(-1) },
            defaultRecoveryWindow: 300
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .failure(.corrupt(id: snapshot.recording.id)))
    }

    @Test("Continue revalidates freshness at command time")
    func continueRevalidatesFreshness() async throws {
        let startedAt = Date(timeIntervalSince1970: 4_000)
        let snapshot = try recoveryFixture(recordingID: UUID(), startedAt: startedAt)
        let clock = MutableDate(value: startedAt.addingTimeInterval(299))
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { clock.value },
            defaultRecoveryWindow: 300
        )
        await coordinator.bootstrap()
        guard case .single = coordinator.state else {
            Issue.record("Expected a fresh recovery candidate")
            return
        }
        clock.value = startedAt.addingTimeInterval(300)

        await #expect(throws: FlightRecoveryError.recoveryExpired) {
            _ = try await coordinator.continueFlight(
                id: snapshot.recording.id,
                at: clock.value,
                elapsed: .seconds(300),
                eventID: UUID()
            )
        }
    }

    @Test("A durable checkpoint extends eligibility without relaunch refreshing it")
    func checkpointDefinesFreshness() async throws {
        let startedAt = Date(timeIntervalSince1970: 5_000)
        let original = try recoveryFixture(recordingID: UUID(), startedAt: startedAt)
        let checkpoint = startedAt.addingTimeInterval(250)
        let snapshot = FlightRecordingReadSnapshot(
            recording: original.recording.restoringRecoveryCheckpoint(at: checkpoint),
            events: original.events
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(500) }
        )

        await coordinator.bootstrap()

        guard case .single(let candidate) = coordinator.state else {
            Issue.record("Expected checkpoint-backed recovery")
            return
        }
        #expect(candidate.id == snapshot.recording.id)
    }

    @Test("Each Flight keeps the recovery window captured when recording began")
    func capturedRecoveryWindowControlsEligibility() async throws {
        let sourceData = try fixtureData()
        let plan = try FPLNavDecoder().decode(sourceData)
        let startedAt = Date(timeIntervalSince1970: 6_000)
        let promotion = try FlightRecording.promoteForStartLeg(
            id: UUID(),
            flightID: UUID(),
            flightPlanSnapshot: RecordedFlightPlanSnapshot(
                id: plan.id,
                title: plan.title,
                legIDs: plan.legs.map(\.id),
                sourceData: sourceData
            ),
            legID: plan.legs[0].id,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()],
            recoveryWindowSeconds: 60
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(
            FlightRecordingReadSnapshot(recording: promotion.recording, events: promotion.events)
        )])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(60) },
            defaultRecoveryWindow: 300
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .reconciledExpired(count: 1))
    }

    @Test("Bootstrap presents every recoverable package without selecting one")
    func bootstrapPresentsRecoverablePackagesWithoutSelection() async throws {
        let first = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001")),
            startedAt: Date(timeIntervalSince1970: 2_000)
        )
        let second = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002")),
            startedAt: Date(timeIntervalSince1970: 1_900)
        )
        let unsupportedID = try #require(UUID(uuidString: "CCCCCCCC-0000-0000-0000-000000000003"))
        let store = InMemoryFlightRecordingStore(packageResults: [
            .available(second),
            .corrupt(id: nil),
            .unsupported(id: unsupportedID, schemaVersion: 99),
            .available(first)
        ])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { Date(timeIntervalSince1970: 2_001) }
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .selectionRequired([
            RecoveryCandidate(
                recordingID: first.recording.id,
                flightPlanTitle: first.recording.flightPlanSnapshot.title,
                startedAt: first.recording.startedAt,
                lastActivityAt: first.recording.startedAt,
                expiresAt: first.recording.startedAt.addingTimeInterval(300)
            ),
            RecoveryCandidate(
                recordingID: second.recording.id,
                flightPlanTitle: second.recording.flightPlanSnapshot.title,
                startedAt: second.recording.startedAt,
                lastActivityAt: second.recording.startedAt,
                expiresAt: second.recording.startedAt.addingTimeInterval(300)
            )
        ]))
        #expect(coordinator.unavailablePackages == [
            .unsupported(id: unsupportedID, schemaVersion: 99),
            .corrupt(id: nil)
        ])
        #expect(coordinator.selectedRecordingID == nil)

        _ = try await coordinator.continueFlight(
            id: first.recording.id,
            at: Date(timeIntervalSince1970: 2_002),
            elapsed: .seconds(2),
            eventID: UUID()
        )
        let superseded = try await store.readSnapshot(id: second.recording.id)
        #expect(superseded.recording.closure?.cause == .supersededDuringRecovery)
    }

    @Test("Bootstrap does not offer Continue for a package without an immutable Flight Plan")
    func bootstrapRejectsPackageWithoutImmutableFlightPlan() async throws {
        let snapshot = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "ACACACAC-0000-0000-0000-000000000008")),
            startedAt: Date(timeIntervalSince1970: 2_000),
            includesSourceData: false
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { Date(timeIntervalSince1970: 2_001) }
        )

        await coordinator.bootstrap()

        #expect(coordinator.state == .failure(.corrupt(id: snapshot.recording.id)))
        #expect(coordinator.unavailablePackages == [.corrupt(id: snapshot.recording.id)])
    }

    @Test("Ending a recovery appends its incomplete closure before removing the launch gate")
    func endAsIncompleteIsDurable() async throws {
        let snapshot = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "DDDDDDDD-0000-0000-0000-000000000004")),
            startedAt: Date(timeIntervalSince1970: 1_000)
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { Date(timeIntervalSince1970: 1_001) }
        )
        await coordinator.bootstrap()

        try await coordinator.endAsIncomplete(
            id: snapshot.recording.id,
            at: Date(timeIntervalSince1970: 1_120),
            elapsed: .seconds(120),
            eventIDs: [
                #require(UUID(uuidString: "EEEEEEEE-0000-0000-0000-000000000005")),
                #require(UUID(uuidString: "FFFFFFFF-0000-0000-0000-000000000006"))
            ]
        )

        let stored = try await store.readSnapshot(id: snapshot.recording.id)
        #expect(stored.events.last?.payload == .recordingClosed(
            outcome: .incomplete,
            cause: .endedDuringRecovery
        ))
        #expect(stored.recording.closure?.outcome == .incomplete)
        #expect(coordinator.state == .none)
    }

    @Test("Recovery elapsed time rebases from persisted monotonic time, not wall clock")
    func elapsedTimeUsesPersistedMonotonicBasis() async throws {
        let snapshot = try recoveryFixture(
            recordingID: #require(UUID(uuidString: "ABABABAB-0000-0000-0000-000000000007")),
            startedAt: Date(timeIntervalSince1970: 50_000)
        )
        let uptime = MutableUptime(value: 10)
        let store = InMemoryFlightRecordingStore(packageResults: [.available(snapshot)])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            monotonicUptime: { uptime.value },
            now: { Date(timeIntervalSince1970: 50_001) }
        )

        await coordinator.bootstrap()
        uptime.value = 17.5

        #expect(coordinator.rebasedElapsed(for: snapshot.recording.id) == .seconds(7.5))
    }

    @Test("Continue restores the captured Flight Plan and active leg before opening Cockpit")
    func continueRestoresCapturedPlanAndActiveLeg() async throws {
        let sourceData = try fixtureData()
        let plan = try FPLNavDecoder().decode(sourceData)
        let startedAt = Date(timeIntervalSince1970: 1_000)
        let flight = Flight(
            id: UUID(),
            flightPlanID: plan.id,
            legIDs: plan.legs.map(\.id),
            activeLegIndex: 0,
            executionMode: try #require(plan.plannedNavigation.plannedNavigation?.defaultMode)
        )
        let promotion = try FlightRecording.promoteForStartLeg(
            id: UUID(),
            flightID: flight.id,
            flightPlanSnapshot: RecordedFlightPlanSnapshot(
                id: plan.id,
                title: plan.title,
                legIDs: plan.legs.map(\.id),
                sourceData: sourceData
            ),
            legID: plan.legs[0].id,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()]
        )
        let store = InMemoryFlightRecordingStore(packageResults: [.available(
            FlightRecordingReadSnapshot(recording: promotion.recording, events: promotion.events)
        )])
        let coordinator = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(119) }
        )
        await coordinator.bootstrap()

        let recovered = try await coordinator.continueFlight(
            id: promotion.recording.id,
            at: startedAt.addingTimeInterval(120),
            elapsed: .seconds(120),
            eventID: UUID()
        )

        #expect(recovered.flightPlan == plan)
        #expect(recovered.flight.id == flight.id)
        #expect(recovered.flight.activeLegIndex == 0)
        #expect(recovered.flight.legState == .active)
        #expect(recovered.flight.legStartedAt == startedAt)
        var appState = AppFeatureState(selectedAppSection: .settings)
        appState.restoreRecoveredFlight(recovered, sourceData: sourceData)
        #expect(appState.selectedAppSection == .cockpit)
        #expect(appState.cockpit.flight == recovered.flight)
        #expect(appState.cockpit.flightPlan == plan)
        #expect(appState.cockpit.pendingReachUndo == nil)
        #expect(appState.positionCheckPermissionEducation == .completed)
        let runtimeCoordinator = FlightRecordingCoordinator(store: store)
        await runtimeCoordinator.restore(recovered)
        #expect(runtimeCoordinator.snapshot.flight == recovered.flight)
        #expect(runtimeCoordinator.snapshot.recording == recovered.recording)
        #expect(runtimeCoordinator.status == .recordingGPSUnavailable)
        let stored = try await store.readSnapshot(id: promotion.recording.id)
        #expect(stored.events.last?.payload == .recoveryContinued)
        #expect(coordinator.state == .none)
    }

    @Test("Replay restores committed navigation facts and excludes transient editors and undo")
    func replayRestoresCommittedNavigationFacts() async throws {
        let sourceData = try fixtureData()
        let plan = try FPLNavDecoder().decode(sourceData)
        let startedAt = Date(timeIntervalSince1970: 2_000)
        let finalLegIndex = plan.legs.index(before: plan.legs.endIndex)
        let flight = Flight(
            id: UUID(),
            flightPlanID: plan.id,
            legIDs: plan.legs.map(\.id),
            activeLegIndex: finalLegIndex,
            executionMode: .noWind
        )
        let snapshot = RecordedFlightPlanSnapshot(
            id: plan.id,
            title: plan.title,
            legIDs: plan.legs.map(\.id),
            sourceData: sourceData
        )
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(
            store: store,
            flight: flight,
            flightPlanSnapshot: snapshot
        )
        var committed = try await engine.promoteForStartLeg(
            at: startedAt,
            recordingID: UUID(),
            eventIDs: [UUID(), UUID()]
        )
        committed = try await engine.commit(.identifyDestination(
            at: startedAt.addingTimeInterval(10),
            elapsed: .seconds(10),
            eventID: UUID()
        ))
        let legID = plan.legs[finalLegIndex].id
        let destinationTarget = NavigationTimingTargetKey(
            legID: legID,
            kind: .destination,
            targetID: plan.legs[finalLegIndex].arrival.id
        )
        committed = try await engine.commit(.reviseETA(
            target: destinationTarget,
            plannedElapsedSeconds: 600,
            committedSeconds: 720,
            at: startedAt.addingTimeInterval(20),
            elapsed: .seconds(20),
            eventID: UUID()
        ))
        committed = try await engine.commit(.reviseHeading(
            legID: legID,
            baselineDegrees: 90,
            committedDegrees: 105,
            at: startedAt.addingTimeInterval(30),
            elapsed: .seconds(30),
            eventID: UUID()
        ))
        let pointKeys = plan.identificationPoints
            .filter { $0.legID == legID }
            .map { IdentificationPointKey(legID: legID, identificationPointID: $0.id) }
        for (index, key) in pointKeys.enumerated() {
            committed = try await engine.commit(.reachIdentificationPoint(
                key: key,
                orderedActiveLegPointKeys: pointKeys,
                at: startedAt.addingTimeInterval(TimeInterval(40 + index)),
                elapsed: .seconds(40 + index),
                eventID: UUID(),
                nextETATarget: nil,
                nextETAPlannedElapsedSeconds: nil
            ))
        }
        committed = try await engine.commit(.reachCurrentWaypoint(
            orderedActiveLegPointKeys: pointKeys,
            at: startedAt.addingTimeInterval(100),
            elapsed: .seconds(100),
            eventIDs: [UUID(), UUID()]
        ))
        committed = try await engine.commit(.completeNavigation(
            at: startedAt.addingTimeInterval(110),
            elapsed: .seconds(110),
            eventID: UUID()
        ))
        let persisted = try await store.readSnapshot(id: committed.recording.id)
        let recovery = FlightRecoveryCoordinator(
            store: store,
            now: { startedAt.addingTimeInterval(119) }
        )
        await recovery.bootstrap()

        let recovered = try await recovery.continueFlight(
            id: committed.recording.id,
            at: startedAt.addingTimeInterval(120),
            elapsed: .seconds(120),
            eventID: UUID()
        )

        #expect(recovered.flight == committed.flight)
        #expect(recovered.recording.physicalState == persisted.recording.physicalState)
        #expect(recovered.recording.navigationState == .complete)
        #expect(recovered.flight.pilotETAState(targetKey: destinationTarget)?.isEditing == false)
        #expect(recovered.flight.pilotHeadingState(for: legID)?.isEditing == false)
        let runtime = FlightRecordingCoordinator(store: store)
        await runtime.restore(recovered)
        try await runtime.prepareForFlightReplacement(
            at: startedAt.addingTimeInterval(130),
            eventIDs: [UUID(), UUID()]
        )
        let displaced = try await store.readSnapshot(id: recovered.recording.id)
        #expect(displaced.recording.closure?.outcome == .incomplete)
    }

    private func recoveryFixture(
        recordingID: UUID,
        startedAt: Date,
        includesSourceData: Bool = true
    ) throws -> FlightRecordingReadSnapshot {
        let sourceData = try fixtureData()
        let plan = try FPLNavDecoder().decode(sourceData)
        let flightID = UUID()
        let snapshot = RecordedFlightPlanSnapshot(
            id: plan.id,
            title: plan.title,
            legIDs: plan.legs.map(\.id),
            sourceData: includesSourceData ? sourceData : nil
        )
        let promotion = try FlightRecording.promoteForStartLeg(
            id: recordingID,
            flightID: flightID,
            flightPlanSnapshot: snapshot,
            legID: plan.legs[0].id,
            startedAt: startedAt,
            eventIDs: [UUID(), UUID()]
        )
        return FlightRecordingReadSnapshot(
            recording: promotion.recording,
            events: promotion.events
        )
    }

    @Test("Schema 3 captures checklist identity, review and explicit absence through disk recovery", arguments: StartChecklistSelection.allCases)
    func checklistDiskRecovery(_ selection: StartChecklistSelection) async throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskFlightRecordingStore(rootDirectory: directory)
        let engine = FlightRecordingEngine(store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: plan.legs.map(\.id), sourceData: source))
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(),
                                                         eventIDs: [UUID(), UUID()], checklistSelection: selection)
        var context = try #require(started.cockpitContext)
        let legID = flight.legIDs[0]
        if selection != .none { context.checklists[legID]?.reviewState = .noted }
        context.checklists[legID]?.presentationState = .collapsed
        try await engine.recordPresentation(context, at: time.addingTimeInterval(1))
        let snapshot = try await store.readSnapshot(id: started.recording.id)
        #expect(snapshot.recording.sourceSchemaVersion == 3)
        let recovery = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(2) })
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(id: started.recording.id, at: time.addingTimeInterval(2), elapsed: .seconds(2), eventID: UUID())
        #expect(recovered.cockpitContext == context)
        var cockpit = CockpitFeatureState()
        cockpit.restore(flightPlan: plan, flight: recovered.flight, sourceData: source, cockpitContext: recovered.cockpitContext)
        #expect(cockpit.legStartChecklists[legID]?.selection == selection)
        #expect((cockpit.activeLegStartChecklist == nil) == (selection == .none))
    }

    @Test("Queued presentation snapshots cannot replace arrival or undo context on disk",
          .timeLimit(.minutes(1)), arguments: StartChecklistSelection.allCases, [false, true])
    func queuedPresentationRecovery(_ selection: StartChecklistSelection, undo: Bool) async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let disk = DiskFlightRecordingStore(rootDirectory: directory)
        let store = SuspendedPresentationRecordingStore(base: disk)
        let engine = FlightRecordingEngine(store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: plan.legs.map(\.id), sourceData: source))
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(),
            eventIDs: [UUID(), UUID()], checklistSelection: selection)
        var original = try #require(started.cockpitContext)
        let firstID = flight.legIDs[0]
        if selection != .none { original.checklists[firstID]?.reviewState = .noted }
        original.checklists[firstID]?.presentationState = .collapsed
        try await engine.recordPresentation(original, at: time.addingTimeInterval(1))
        var stale = try #require(started.cockpitContext)
        stale.areDriftLinesVisible = false
        let arrival = RecordedNavigationCommand.reachCurrentWaypoint(orderedActiveLegPointKeys: [],
            at: time.addingTimeInterval(2), elapsed: .seconds(2), eventIDs: [UUID(), UUID()])
        let successor: StartChecklistSelection = selection == .none ? .establishHeading : .none
        let command: RecordedNavigationCommand
        if undo {
            let arrived = try await engine.commit(arrival, context: original, checklistSelection: successor)
            // Both the successor snapshot and a pre-arrival snapshot are stale after undo.
            stale = try #require(arrived.cockpitContext)
            stale.areDriftLinesVisible = false
            command = .undoReach(originalEventID: arrived.eventIDs[0], restoredFlight: started.flight,
                at: time.addingTimeInterval(3), elapsed: .seconds(3), eventID: UUID())
        } else {
            command = arrival
        }
        await store.suspendNextAppend()
        let navigation = Task { try await engine.commit(command, context: original, checklistSelection: successor) }
        await store.waitUntilSuspended()
        let retained = stale
        let presentation = Task { try await engine.recordPresentation(retained, at: time.addingTimeInterval(4)) }
        // Observe the actual gate waiter rather than relying on scheduling or a delay.
        while await engine.queuedMutationCount == 0 { await Task.yield() }
        await store.release()
        let committed = try await navigation.value
        #expect(try await presentation.value == false)
        let expected = try #require(committed.cockpitContext)
        #expect(expected.navigationGeneration != original.navigationGeneration)
        // Even matching pre-arrival values must not regain authority after undo (ABA).
        if undo {
            #expect(try await engine.recordPresentation(try #require(started.cockpitContext),
                at: time.addingTimeInterval(5)) == false)
        }
        let stored = try await disk.readSnapshot(id: started.recording.id)
        #expect(stored.events.last?.cockpitContext == expected)
        #expect(stored.events.last?.payload != .cockpitPresentationChanged)
        if undo {
            #expect(expected == original)
            #expect(expected.checklists[flight.legIDs[1]] == nil)
        } else {
            #expect(expected.checklists[flight.legIDs[1]]?.selection == successor)
        }
        // A current-generation UI edit still persists through the projection.
        var cockpit = CockpitFeatureState()
        cockpit.restore(flightPlan: plan, flight: committed.flight, sourceData: source, cockpitContext: expected)
        cockpit.toggleDriftLines()
        let current = try #require(cockpit.recordingCockpitContext)
        #expect(current.navigationGeneration == expected.navigationGeneration)
        #expect(try await engine.recordPresentation(current, at: time.addingTimeInterval(6)))
        let recovery = FlightRecoveryCoordinator(store: DiskFlightRecordingStore(rootDirectory: directory),
            now: { time.addingTimeInterval(7) })
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(id: started.recording.id,
            at: time.addingTimeInterval(7), elapsed: .seconds(7), eventID: UUID())
        #expect(recovered.flight.activeLegIndex == committed.flight.activeLegIndex)
        #expect(recovered.cockpitContext == current)
        #expect(recovered.cockpitContext?.checklists == expected.checklists)
    }

    @Test("Heading revision clears a failed Noted warning only when it saves the current checklist",
          arguments: [false, true])
    func headingAfterFailedChecklistSave(_ suppliesCurrentContext: Bool) async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let time = Date(timeIntervalSince1970: 10_000)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskFlightRecordingStore(rootDirectory: directory, beforeAppend: { event in
            if event.payload == .cockpitPresentationChanged { throw CocoaError(.fileWriteNoPermission) }
        })
        let coordinator = FlightRecordingCoordinator(store: store)
        let started = try await coordinator.startLeg(flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: plan.legs.map(\.id), sourceData: source),
            at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let legID = flight.legIDs[0]
        var memory = try #require(started.cockpitContext)
        memory.checklists[legID]?.reviewState = .noted
        memory.checklists[legID]?.presentationState = .collapsed
        await coordinator.recordPresentation(memory, at: time.addingTimeInterval(1))
        #expect(coordinator.presentationWriteFailed)
        let revised = try await coordinator.commitNavigation(.reviseHeading(legID: legID,
            baselineDegrees: 100, committedDegrees: 105, at: time.addingTimeInterval(2),
            elapsed: .seconds(2), eventID: UUID()), context: suppliesCurrentContext ? memory : nil)
        #expect(coordinator.presentationWriteFailed == !suppliesCurrentContext)
        #expect(revised.flight.pilotHeadingState(for: legID)?.operationalDegrees == 105)
        let expectedReview: LegStartChecklistCapture.ReviewState = suppliesCurrentContext ? .noted : .pending
        let disk = try await store.readSnapshot(id: started.recording.id)
        #expect(disk.events.last?.cockpitContext?.checklists[legID]?.reviewState == expectedReview)
        let recovery = FlightRecoveryCoordinator(store: DiskFlightRecordingStore(rootDirectory: directory),
            now: { time.addingTimeInterval(3) })
        await recovery.bootstrap()
        let restored = try await recovery.continueFlight(id: started.recording.id,
            at: time.addingTimeInterval(3), elapsed: .seconds(3), eventID: UUID())
        #expect(restored.cockpitContext?.checklists[legID]?.reviewState == expectedReview)
        #expect(restored.cockpitContext?.checklists[legID]?.presentationState ==
            (suppliesCurrentContext ? .collapsed : .expanded))
        #expect(restored.flight.pilotHeadingState(for: legID)?.operationalDegrees == 105)
    }

    @Test("Mismatched and missing required schema 3 context fail recovery", arguments: [false, true])
    func corruptChecklistContext(_ missing: Bool) async throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        let time = Date(timeIntervalSince1970: 20_000)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0, executionMode: .noWind)
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: plan.legs.map(\.id), sourceData: source))
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()])
        let snapshot = try await store.readSnapshot(id: started.recording.id)
        var events = snapshot.events
        for index in events.indices {
            events[index].cockpitContext = missing ? nil : RecordingCockpitContext(flightID: UUID(), checklists: [:], areDriftLinesVisible: true)
        }
        let corruptStore = InMemoryFlightRecordingStore(packageResults: [.available(.init(recording: snapshot.recording, events: events))])
        let recovery = FlightRecoveryCoordinator(store: corruptStore, now: { time.addingTimeInterval(1) })
        await recovery.bootstrap()
        #expect(recovery.state == .failure(.corrupt(id: snapshot.recording.id)))
    }

    @Test("Captured choices survive rerenders and never fabricate acknowledgements", arguments: StartChecklistSelection.allCases)
    func capturedStateAndAdapter(_ selection: StartChecklistSelection) throws {
        let source = try fixtureData()
        let plan = try FPLNavDecoder().decode(source)
        var cockpit = CockpitFeatureState()
        try cockpit.accept(plan)
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1000), checklistSelection: selection)
        let flight = try #require(cockpit.flight)
        let captured = try #require(cockpit.legStartChecklists[flight.legIDs[0]])
        let rendered = try CockpitPresentationAdapter().makeLegStartChecklist(flightPlan: plan, flight: flight, captured: captured)
        #expect(rendered?.template.id == (selection == .none ? nil : selection.rawValue))
        cockpit.installCommittedFlight(flight)
        #expect(cockpit.legStartChecklists[flight.legIDs[0]]?.selection == selection)
        cockpit.noteLegStartChecklist()
        if selection == .none {
            #expect(cockpit.activeLegStartChecklist == nil)
            #expect(!cockpit.hasChecklistAcknowledgements)
            #expect(cockpit.legStartChecklists[flight.legIDs[0]]?.reviewState == .pending)
        } else {
            #expect(cockpit.activeLegStartChecklist?.reviewState == .noted)
        }
        var corrupt = captured
        corrupt.definitionRevision = 2
        #expect(throws: FlightRecoveryError.invalidJournal) {
            try RecordingCockpitContext(flightID: flight.id, checklists: [captured.legID: corrupt], areDriftLinesVisible: true)
                .validate(flightID: flight.id, legIDs: flight.legIDs)
        }
    }

    @Test("A schema upgrade interrupted before its first context record preserves legacy recovery")
    func interruptedLegacyContextUpgrade() async throws {
        let time = Date(timeIntervalSince1970: 30_000)
        let fixture = try recoveryFixture(recordingID: UUID(), startedAt: time)
        let directory = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = DiskFlightRecordingStore(rootDirectory: directory)
        try await store.create(.init(recording: fixture.recording, events: fixture.events))
        let manifestURL = directory.appending(path: fixture.recording.id.uuidString.lowercased()).appending(path: "manifest.json")
        var manifest = try FlightRecordingCoding.decoder.decode(FlightRecordingManifestDTO.self, from: Data(contentsOf: manifestURL))
        manifest.schemaVersion = 3
        manifest.progressionPolicy = .automatic
        manifest.cockpitContextStartSequence = UInt64(fixture.events.count)
        try FlightRecordingCoding.encoder.encode(manifest).write(to: manifestURL, options: .atomic)
        let recovery = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(1) })
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(id: fixture.recording.id,
            at: time.addingTimeInterval(1), elapsed: .seconds(1), eventID: UUID())
        var cockpit = CockpitFeatureState()
        cockpit.restore(flightPlan: recovered.flightPlan, flight: recovered.flight,
                        sourceData: fixture.recording.flightPlanSnapshot.sourceData, cockpitContext: recovered.cockpitContext)
        #expect(cockpit.activeLegStartChecklist?.selection == .tzeKivun)
        #expect(cockpit.activeLegStartChecklist?.reviewState == .pending)
        await recovery.bootstrap()
        if case .single = recovery.state {} else { Issue.record("Legacy recovery must remain available after continuation") }
    }

    @Test("Schema 3 replays the captured Manual policy independently of defaults")
    func capturedManualPolicyRecovery() async throws {
        let source = try twoLegFixtureData()
        let plan = try FPLNavDecoder().decode(source)
        #expect(plan.legs.count > 1)
        let time = Date(timeIntervalSince1970: 40_000)
        let flight = Flight(flightPlanID: plan.id, legIDs: plan.legs.map(\.id), activeLegIndex: 0,
                            executionMode: .noWind, progressionPolicy: .manualNextLeg)
        let store = InMemoryFlightRecordingStore()
        let engine = FlightRecordingEngine(store: store, flight: flight,
            flightPlanSnapshot: .init(id: plan.id, title: plan.title, legIDs: plan.legs.map(\.id), sourceData: source))
        let started = try await engine.promoteForStartLeg(at: time, recordingID: UUID(), eventIDs: [UUID(), UUID()], checklistSelection: .none)
        _ = try await engine.commit(.reachCurrentWaypoint(orderedActiveLegPointKeys: [],
            at: time.addingTimeInterval(1), elapsed: .seconds(1), eventIDs: [UUID()]))
        let recovery = FlightRecoveryCoordinator(store: store, now: { time.addingTimeInterval(2) })
        await recovery.bootstrap()
        let recovered = try await recovery.continueFlight(id: started.recording.id,
            at: time.addingTimeInterval(2), elapsed: .seconds(2), eventID: UUID())
        #expect(recovered.flight.progressionPolicy == .manualNextLeg)
        #expect(recovered.flight.legState == .ready)
        #expect(recovered.flight.activeLegIndex == 1)
        #expect(recovered.cockpitContext?.checklists[flight.legIDs[0]]?.selection == StartChecklistSelection.none)
        #expect(recovered.cockpitContext?.checklists[flight.legIDs[1]] == nil)
    }

    private func fixtureData() throws -> Data {
        let bundle = Bundle(for: FlightRecoveryFixtureLocator.self)
        let nested = bundle.url(
            forResource: "representative-v7",
            withExtension: "fplnav",
            subdirectory: "Fixtures/FPLNav/V7/Official"
        )
        return try Data(contentsOf: #require(
            nested ?? bundle.url(forResource: "representative-v7", withExtension: "fplnav")
        ))
    }

    private func twoLegFixtureData() throws -> Data {
        var object = try #require(JSONSerialization.jsonObject(with: fixtureData()) as? [String: Any])
        var navigation = try #require(object["navigation"] as? [String: Any])
        var route = try #require(navigation["route"] as? [String: Any])
        var waypoints = try #require(route["waypoints"] as? [[String: Any]])
        var order = try #require(route["waypointOrder"] as? [String])
        var legs = try #require(route["legs"] as? [[String: Any]])
        var waypoint = try #require(waypoints.last)
        let waypointID = UUID().uuidString
        waypoint["id"] = waypointID
        waypoint["position"] = ["latitude": 0.03, "longitude": 0.01]
        waypoints.append(waypoint)
        var leg = try #require(legs.last)
        let legID = UUID().uuidString
        leg["id"] = legID
        let departureID = try #require(order.last)
        leg["departureWaypointId"] = departureID
        leg["arrivalWaypointId"] = waypointID
        legs.append(leg)
        order.append(waypointID)
        route["waypoints"] = waypoints
        route["waypointOrder"] = order
        route["legs"] = legs
        navigation["route"] = route
        object["navigation"] = navigation
        var execution = try #require(object["execution"] as? [String: Any])
        var resolved = try #require(execution["legs"] as? [[String: Any]])
        var resolvedLeg = try #require(resolved.last)
        resolvedLeg["legId"] = legID
        resolved.append(resolvedLeg)
        execution["legs"] = resolved
        object["execution"] = execution
        return try JSONSerialization.data(withJSONObject: object)
    }
}

private final class FlightRecoveryFixtureLocator {}

@MainActor
private final class MutableUptime {
    var value: TimeInterval

    init(value: TimeInterval) {
        self.value = value
    }
}

@MainActor
private final class MutableDate {
    var value: Date

    init(value: Date) {
        self.value = value
    }
}

private actor SuspendedPresentationRecordingStore: FlightRecordingStore {
    let base: DiskFlightRecordingStore
    private var shouldSuspend = false
    private var shouldFailRouteRead = false
    private var shouldFailTrackAppend = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(base: DiskFlightRecordingStore) { self.base = base }

    func suspendNextAppend() { shouldSuspend = true }
    func failNextRouteRead() { shouldFailRouteRead = true }
    func failNextTrackAppend() { shouldFailTrackAppend = true }

    func waitUntilSuspended() async {
        guard releaseContinuation == nil else { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func release() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }

    private func suspendIfRequested() async {
        if shouldSuspend {
            shouldSuspend = false
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
                waiters.forEach { $0.resume() }
                waiters.removeAll()
            }
        }
    }

    func commitRouteTransaction(_ transaction: FlightRouteTransaction) async throws {
        await suspendIfRequested()
        try await base.commitRouteTransaction(transaction)
    }

    func routeTransactionIsCommitted(_ transaction: FlightRouteTransaction) async throws -> Bool {
        if shouldFailRouteRead {
            shouldFailRouteRead = false
            throw FlightRecordingStoreError.operationFailed(id: transaction.recordingID)
        }
        return try await base.routeTransactionIsCommitted(transaction)
    }

    func appendEvent(_ event: RecordedFlightEvent, recordingID: UUID, synchronize: Bool) async throws {
        await suspendIfRequested()
        try await base.appendEvent(event, recordingID: recordingID, synchronize: synchronize)
    }

    func create(_ seed: FlightRecordingSeed) async throws { try await base.create(seed) }
    func appendTrackBatch(_ batch: RecordedTrackBatch) async throws {
        if shouldFailTrackAppend {
            shouldFailTrackAppend = false
            throw FlightRecordingStoreError.operationFailed(id: batch.recordingID)
        }
        try await base.appendTrackBatch(batch)
    }
    func synchronizeTrack(recordingID: UUID) async throws { try await base.synchronizeTrack(recordingID: recordingID) }
    func updateRecoveryCheckpoint(recordingID: UUID, at timestamp: Date) async throws {
        try await base.updateRecoveryCheckpoint(recordingID: recordingID, at: timestamp)
    }
    func packages() async -> [FlightRecordingPackageResult] { await base.packages() }
    func readSnapshot(id: UUID) async throws -> FlightRecordingReadSnapshot { try await base.readSnapshot(id: id) }
    func close(id: UUID, closure: FlightRecordingClosure) async throws { try await base.close(id: id, closure: closure) }
    func remove(id: UUID) async throws { try await base.remove(id: id) }
}
