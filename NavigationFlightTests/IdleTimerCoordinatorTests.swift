import Foundation
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Idle timer coordinator")
struct IdleTimerCoordinatorTests {
    @Test("Accepted Flight ready state disables the system idle timer")
    func acceptedFlightReadyStateKeepsDisplayAwake() {
        let recorder = RecordingIdleTimerController()
        let coordinator = IdleTimerCoordinator(controller: recorder)

        coordinator.synchronize(isAcceptedFlightInProgress: true)

        #expect(recorder.recordedValues == [true])
    }

    @Test("Accepted Flight ready state derives keep-awake eligibility")
    func acceptedReadyFlightIsInProgress() throws {
        var cockpit = CockpitFeatureState()
        try cockpit.accept(try flightPlan())

        #expect(cockpit.isAcceptedFlightInProgress)
    }

    @Test("Keep-awake spans ready, active, and between-leg ready until final completion")
    func acceptedFlightLifecycle() throws {
        let recorder = RecordingIdleTimerController()
        let coordinator = IdleTimerCoordinator(controller: recorder)
        var cockpit = CockpitFeatureState(progressionPolicy: .manualNextLeg)
        try cockpit.accept(try twoLegFlightPlan())

        coordinator.synchronize(isAcceptedFlightInProgress: cockpit.isAcceptedFlightInProgress)
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1_000))
        coordinator.synchronize(isAcceptedFlightInProgress: cockpit.isAcceptedFlightInProgress)
        try cockpit.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 1_100))
        coordinator.synchronize(isAcceptedFlightInProgress: cockpit.isAcceptedFlightInProgress)
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1_200))
        coordinator.synchronize(isAcceptedFlightInProgress: cockpit.isAcceptedFlightInProgress)
        try cockpit.reachCurrentWaypoint(at: Date(timeIntervalSince1970: 1_300))
        coordinator.synchronize(isAcceptedFlightInProgress: cockpit.isAcceptedFlightInProgress)

        #expect(cockpit.flight?.legState == .completed)
        #expect(recorder.recordedValues == [true, false])
    }

    @Test("Browsing without an accepted Flight never disables the idle timer")
    func browsingDoesNotKeepDisplayAwake() {
        let recorder = RecordingIdleTimerController()
        let coordinator = IdleTimerCoordinator(controller: recorder)
        let appState = AppFeatureState(selectedAppSection: .flightPlans)

        coordinator.synchronize(
            isAcceptedFlightInProgress: appState.cockpit.isAcceptedFlightInProgress
        )

        #expect(recorder.recordedValues == [false])
    }

    @Test("Accepted Flight replacement stays awake and teardown restores the idle timer")
    func acceptedFlightReplacementAndTeardown() throws {
        let recorder = RecordingIdleTimerController()
        let coordinator = IdleTimerCoordinator(controller: recorder)
        let plan = try flightPlan()
        var appState = AppFeatureState()

        _ = try appState.loadFlightPlan(
            LibraryFlightPlan(flightPlan: plan, importedAt: .distantPast),
            flightID: UUID()
        )
        coordinator.synchronize(
            isAcceptedFlightInProgress: appState.cockpit.isAcceptedFlightInProgress
        )
        _ = try appState.loadUpdatedFlightPlan(
            LibraryFlightPlan(flightPlan: plan, importedAt: .distantPast),
            flightID: UUID()
        )
        coordinator.synchronize(
            isAcceptedFlightInProgress: appState.cockpit.isAcceptedFlightInProgress
        )
        coordinator.teardown()

        #expect(recorder.recordedValues == [true, false])
    }

    @Test("Abandonment or replacement by a non-Flight flow restores the idle timer")
    func leavingAcceptedFlightLifecycle() {
        let recorder = RecordingIdleTimerController()
        let coordinator = IdleTimerCoordinator(controller: recorder)

        coordinator.synchronize(isAcceptedFlightInProgress: true)
        coordinator.synchronize(isAcceptedFlightInProgress: false)

        #expect(recorder.recordedValues == [true, false])
    }

    private func flightPlan() throws -> FlightPlan {
        let bundle = Bundle(for: IdleTimerFixtureLocator.self)
        let nested = bundle.url(
            forResource: "editor-wind",
            withExtension: "fplnav",
            subdirectory: "Fixtures/FPLNav/V7/Editor"
        )
        let url = try #require(nested ?? bundle.url(forResource: "editor-wind", withExtension: "fplnav"))
        return try FPLNavDecoder().decode(Data(contentsOf: url))
    }

    private func twoLegFlightPlan() throws -> FlightPlan {
        let plan = try flightPlan()
        let planned = try #require(plan.plannedNavigation.plannedNavigation)
        let plannedNavigation = PlannedNavigation(
            calculationVersion: planned.calculationVersion,
            altitudeReference: planned.altitudeReference,
            legs: planned.legs + planned.legs,
            annotations: planned.annotations,
            vorDmeReferences: planned.vorDmeReferences,
            frequenciesByPhase: planned.frequenciesByPhase,
            defaultMode: planned.defaultMode
        )
        return FlightPlan(
            id: plan.id,
            title: plan.title,
            createdAt: plan.createdAt,
            modifiedAt: plan.modifiedAt,
            parameters: plan.parameters,
            waypoints: plan.waypoints,
            legs: plan.legs + plan.legs,
            identificationPoints: plan.identificationPoints,
            altitudeChanges: plan.altitudeChanges,
            frequencyChanges: plan.frequencyChanges,
            vorDmeReferences: plan.vorDmeReferences,
            operationalContext: plan.operationalContext,
            plannedNavigation: .eligible(plannedNavigation)
        )
    }
}

private final class IdleTimerFixtureLocator {}

@MainActor
private final class RecordingIdleTimerController: IdleTimerControlling {
    private(set) var recordedValues: [Bool] = []

    var isIdleTimerDisabled: Bool = false {
        didSet {
            recordedValues.append(isIdleTimerDisabled)
        }
    }
}
