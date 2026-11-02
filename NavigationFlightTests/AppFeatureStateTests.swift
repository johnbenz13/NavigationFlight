import Foundation
import Testing
@testable import NavigationFlight

private final class AppFeatureFixtureLocator {}

@Suite("App feature state")
struct AppFeatureStateTests {
    @Test("Fresh launch selects Flight Plans with no active Flight")
    func freshLaunch() {
        let state = AppFeatureState()

        #expect(state.selectedAppSection == .flightPlans)
        #expect(state.cockpit.flight == nil)
        #expect(state.cockpit.flightPlan == nil)
        #expect(state.pendingFlightChange == nil)
    }

    @Test("Selecting an app section changes only selection")
    func selectionPreservesChildState() {
        var state = AppFeatureState()
        let originalCockpit = state.cockpit
        let originalFlightPlans = state.flightPlans

        state.selectAppSection(.settings)

        #expect(state.selectedAppSection == .settings)
        #expect(state.cockpit == originalCockpit)
        #expect(state.flightPlans == originalFlightPlans)
    }

    @Test("Section selection preserves active timing exactly")
    func selectionPreservesActiveTiming() throws {
        var cockpit = CockpitFeatureState()
        try cockpit.accept(try flightPlan())
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1_000))
        var state = AppFeatureState(selectedAppSection: .cockpit, cockpit: cockpit)
        let originalCockpit = state.cockpit

        state.selectAppSection(.flightPlans)

        #expect(state.cockpit == originalCockpit)
        #expect(state.cockpit.flight?.legStartedAt == Date(timeIntervalSince1970: 1_000))
    }

    @Test("Loading without protected work creates the injected ready Flight")
    func loadWithoutProtectedWork() throws {
        let plan = try flightPlan()
        let flightID = try #require(UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA"))
        let snapshot = LibraryFlightPlan(flightPlan: plan, importedAt: Date(timeIntervalSince1970: 100))
        var state = AppFeatureState()

        let decision = try state.loadFlightPlan(snapshot, flightID: flightID)

        #expect(decision == .loaded)
        #expect(state.selectedAppSection == .cockpit)
        #expect(state.cockpit.flightPlan == plan)
        #expect(state.cockpit.flight?.id == flightID)
        #expect(state.cockpit.flight?.legState == .ready)
        #expect(state.cockpit.flight?.legStartedAt == nil)
    }

    @Test("Recorded timing is protected pilot work")
    func recordedTimingIsProtected() throws {
        var cockpit = CockpitFeatureState()
        try cockpit.accept(try flightPlan())
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1_000))

        #expect(cockpit.hasProtectedPilotWork)
    }

    @Test("Focused Flight facts classify every protected domain category")
    func focusedProtectedFlightFacts() throws {
        let legID = try #require(UUID(uuidString: "88888888-8888-8888-8888-888888888888"))
        let pointID = try #require(UUID(uuidString: "99999999-9999-9999-9999-999999999999"))
        let targetID = try #require(UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE"))
        let startedAt = Date(timeIntervalSince1970: 1_000)

        var timing = Flight(flightPlanID: UUID(), legIDs: [legID], activeLegIndex: 0, executionMode: .noWind)
        try timing.startLeg(at: startedAt)
        #expect(timing.hasRecordedLegTiming)

        var outcome = timing
        let pointKey = IdentificationPointKey(legID: legID, identificationPointID: pointID)
        try outcome.reachIdentificationPoint(
            key: pointKey,
            orderedActiveLegPointKeys: [pointKey],
            at: startedAt.addingTimeInterval(10)
        )
        #expect(outcome.hasIdentificationPointOutcomes)

        var progress = timing
        try progress.reachCurrentWaypoint(at: startedAt.addingTimeInterval(20))
        #expect(progress.hasNavigationProgress)

        var revisions = timing
        let target = NavigationTimingTargetKey(legID: legID, kind: .destination, targetID: targetID)
        revisions.initializePilotETA(targetKey: target, plannedElapsedSeconds: 60)
        #expect(revisions.hasOpenPilotRevisionDrafts)
        revisions.commitPilotETA(targetKey: target)
        #expect(revisions.hasCommittedPilotRevisions)

        var heading = timing
        heading.openPilotHeadingEditor(baselineDegrees: 90)
        #expect(heading.hasOpenPilotRevisionDrafts)
        heading.commitPilotHeading()
        #expect(heading.hasCommittedPilotRevisions)
    }

    @Test("Checklist acknowledgement is a protected feature fact")
    func checklistAcknowledgementIsProtected() throws {
        var cockpit = CockpitFeatureState()
        try cockpit.accept(try flightPlan())
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1_000))
        cockpit.noteLegStartChecklist()

        #expect(cockpit.hasChecklistAcknowledgements)
        #expect(cockpit.hasProtectedPilotWork)
    }

    @Test("Presentation-only drift-line state is not protected")
    func presentationStateIsNotProtected() throws {
        let plan = try flightPlan()
        let snapshot = LibraryFlightPlan(flightPlan: plan, importedAt: .distantPast)
        var cockpit = CockpitFeatureState()
        try cockpit.accept(plan)
        cockpit.toggleDriftLines()
        var state = AppFeatureState(selectedAppSection: .cockpit, cockpit: cockpit)

        let decision = try state.loadFlightPlan(snapshot, flightID: UUID())

        #expect(decision == .loaded)
    }

    @Test("Ready leg and mode selection are not protected")
    func readySelectionIsNotProtected() throws {
        let plan = try twoLegFlightPlan()
        var cockpit = CockpitFeatureState()
        try cockpit.accept(plan)
        cockpit.selectNextLeg()
        cockpit.selectMode(.wind)

        #expect(cockpit.selectedLegIndex == 1)
        #expect(cockpit.hasProtectedPilotWork == false)
    }

    @Test("Protected replacement remains pending until matching confirmation")
    func protectedReplacementConfirmation() throws {
        let plan = try flightPlan()
        let originalFlightID = try #require(UUID(uuidString: "11111111-1111-1111-1111-111111111111"))
        let replacementFlightID = try #require(UUID(uuidString: "22222222-2222-2222-2222-222222222222"))
        let pendingID = try #require(UUID(uuidString: "33333333-3333-3333-3333-333333333333"))
        var cockpit = CockpitFeatureState()
        try cockpit.accept(plan, flightID: originalFlightID)
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1_000))
        var state = AppFeatureState(selectedAppSection: .flightPlans, cockpit: cockpit)
        let originalState = state

        let decision = try state.loadFlightPlan(
            LibraryFlightPlan(flightPlan: plan, importedAt: .distantPast),
            flightID: replacementFlightID,
            pendingID: pendingID
        )

        guard case .confirmationRequired(let pending) = decision else {
            Issue.record("Expected confirmation")
            return
        }
        #expect(pending.id == pendingID)
        #expect(state.cockpit == originalState.cockpit)
        #expect(state.selectedAppSection == originalState.selectedAppSection)
        let staleConfirmation = state.confirmPendingFlightChange(id: UUID())
        #expect(staleConfirmation == false)
        #expect(state.cockpit == originalState.cockpit)
        let confirmed = state.confirmPendingFlightChange(id: pendingID)
        #expect(confirmed)
        #expect(state.cockpit.flight?.id == replacementFlightID)
        #expect(state.cockpit.flight?.legState == .ready)
        #expect(state.selectedAppSection == .cockpit)
    }

    @Test("Matching cancellation clears only pending replacement")
    func pendingCancellation() throws {
        let plan = try flightPlan()
        var cockpit = CockpitFeatureState()
        try cockpit.accept(plan)
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1_000))
        var state = AppFeatureState(selectedAppSection: .settings, cockpit: cockpit)
        _ = try state.loadFlightPlan(
            LibraryFlightPlan(flightPlan: plan, importedAt: .distantPast),
            flightID: UUID()
        )
        let protectedState = state.cockpit
        let selection = state.selectedAppSection
        let pendingID = try #require(state.pendingFlightChange?.id)

        let staleCancellation = state.cancelPendingFlightChange(id: UUID())
        let cancelled = state.cancelPendingFlightChange(id: pendingID)
        #expect(staleCancellation == false)
        #expect(cancelled)
        #expect(state.pendingFlightChange == nil)
        #expect(state.cockpit == protectedState)
        #expect(state.selectedAppSection == selection)
    }

    @Test("Validation failure preserves the exact current state")
    func validationFailurePreservesState() throws {
        let plan = try flightPlan()
        var cockpit = CockpitFeatureState()
        try cockpit.accept(plan)
        var state = AppFeatureState(selectedAppSection: .settings, cockpit: cockpit)
        let original = state
        let invalidPlan = FlightPlan(
            id: plan.id,
            title: plan.title,
            createdAt: plan.createdAt,
            modifiedAt: plan.modifiedAt,
            parameters: plan.parameters,
            waypoints: plan.waypoints,
            legs: plan.legs,
            identificationPoints: plan.identificationPoints,
            altitudeChanges: plan.altitudeChanges,
            frequencyChanges: plan.frequencyChanges,
            vorDmeReferences: plan.vorDmeReferences,
            operationalContext: plan.operationalContext,
            plannedNavigation: .unavailableLegacyFormat(version: 5)
        )

        #expect(throws: CockpitPlanError.legacyPlan(version: 5)) {
            try state.loadFlightPlan(
                LibraryFlightPlan(flightPlan: invalidPlan, importedAt: .distantPast),
                flightID: UUID()
            )
        }
        #expect(state == original)
    }

    @Test("Library refresh or removal does not mutate loaded snapshot")
    func libraryChangesPreserveLoadedSnapshot() throws {
        let plan = try flightPlan()
        var cockpit = CockpitFeatureState()
        try cockpit.accept(plan)
        var flightPlans = FlightPlansFeatureState()
        let requestID = UUID()
        flightPlans.beginLoading(requestID: requestID)
        _ = flightPlans.completeLoading(requestID: requestID, records: [], error: nil)
        let state = AppFeatureState(cockpit: cockpit, flightPlans: flightPlans)

        #expect(state.flightPlans.records.isEmpty)
        #expect(state.cockpit.flightPlan == plan)
        #expect(state.cockpit.flight?.flightPlanID == plan.id)
    }

    @Test("Return preserves Flight while restart uses loaded snapshot and new identity")
    func returnAndRestart() throws {
        let plan = try flightPlan()
        let originalID = try #require(UUID(uuidString: "44444444-4444-4444-4444-444444444444"))
        let restartID = try #require(UUID(uuidString: "55555555-5555-5555-5555-555555555555"))
        var cockpit = CockpitFeatureState()
        try cockpit.accept(plan, flightID: originalID)
        var state = AppFeatureState(selectedAppSection: .flightPlans, cockpit: cockpit)

        state.returnToCockpit()
        #expect(state.cockpit.flight?.id == originalID)
        let decision = try state.restartFlight(flightID: restartID)
        #expect(decision == .loaded)
        #expect(state.cockpit.flight?.id == restartID)
        #expect(state.cockpit.flightPlan == plan)
        #expect(state.cockpit.flight?.legStartedAt == nil)
    }

    @Test("Stale Flight Plans completion cannot replace last successful records")
    func staleFlightPlansCompletion() throws {
        let firstRequest = try #require(UUID(uuidString: "66666666-6666-6666-6666-666666666666"))
        let secondRequest = try #require(UUID(uuidString: "77777777-7777-7777-7777-777777777777"))
        let record = LibraryFlightPlan(flightPlan: try flightPlan(), importedAt: .distantPast)
        var state = FlightPlansFeatureState()

        state.beginLoading(requestID: firstRequest)
        state.beginLoading(requestID: secondRequest)

        let staleCompletion = state.completeLoading(requestID: firstRequest, records: [record], error: nil)
        #expect(staleCompletion == false)
        #expect(state.records.isEmpty)
        #expect(state.isLoading)
        let acceptedCompletion = state.completeLoading(requestID: secondRequest, records: [record], error: nil)
        #expect(acceptedCompletion)
        #expect(state.records == [record])
        #expect(state.isLoading == false)
    }

    private func flightPlan() throws -> FlightPlan {
        let bundle = Bundle(for: AppFeatureFixtureLocator.self)
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
        let twoLegPlanned = PlannedNavigation(
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
            plannedNavigation: .eligible(twoLegPlanned)
        )
    }
}
