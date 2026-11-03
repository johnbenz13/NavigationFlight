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

    @Test("Choosing a Flight Plan from empty Cockpit changes only app selection")
    func chooseFlightPlanIntentPreservesChildState() {
        var state = AppFeatureState(selectedAppSection: .cockpit)
        let originalCockpit = state.cockpit
        let originalFlightPlans = state.flightPlans

        state.handleCockpitIntent(.chooseFlightPlan)

        #expect(state.selectedAppSection == .flightPlans)
        #expect(state.cockpit == originalCockpit)
        #expect(state.flightPlans == originalFlightPlans)
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

    @Test("Duplicate Flight change requests cannot replace the pending decision")
    func duplicateFlightChangePreservesPendingDecision() throws {
        let originalPlan = try flightPlan()
        var cockpit = CockpitFeatureState()
        try cockpit.accept(originalPlan)
        try cockpit.startLeg(at: Date(timeIntervalSince1970: 1_000))
        var state = AppFeatureState(selectedAppSection: .flightPlans, cockpit: cockpit)
        let firstPendingID = try #require(UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000001"))
        let secondPendingID = try #require(UUID(uuidString: "AAAAAAAA-0000-0000-0000-000000000002"))
        let firstFlightID = try #require(UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000001"))
        let secondFlightID = try #require(UUID(uuidString: "BBBBBBBB-0000-0000-0000-000000000002"))
        let firstRecord = LibraryFlightPlan(flightPlan: originalPlan, importedAt: .distantPast)
        let secondRecord = LibraryFlightPlan(
            flightPlan: copy(originalPlan, id: UUID()),
            importedAt: .distantPast
        )

        _ = try state.loadFlightPlan(firstRecord, flightID: firstFlightID, pendingID: firstPendingID)
        let duplicateDecision = try state.loadFlightPlan(
            secondRecord,
            flightID: secondFlightID,
            pendingID: secondPendingID
        )

        #expect(duplicateDecision == .confirmationRequired(try #require(state.pendingFlightChange)))
        #expect(state.pendingFlightChange?.id == firstPendingID)
        #expect(state.pendingFlightChange?.candidateCockpit.flight?.id == firstFlightID)
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

    @Test("Inspection selection resolves from the last successful records by stable ID")
    func inspectionSelectionResolvesFromRecords() throws {
        let record = LibraryFlightPlan(flightPlan: try flightPlan(), importedAt: .distantPast)
        var state = FlightPlansFeatureState()
        let requestID = UUID()
        state.beginLoading(requestID: requestID)
        _ = state.completeLoading(requestID: requestID, records: [record], error: nil)

        state.selectRecord(id: record.id)

        #expect(state.selectedRecordID == record.id)
        #expect(state.selectedRecord == record)
    }

    @Test("Successful refresh clears an inspection removed from the library")
    func refreshClearsRemovedInspection() throws {
        let record = LibraryFlightPlan(flightPlan: try flightPlan(), importedAt: .distantPast)
        var state = FlightPlansFeatureState()
        let initialRequestID = UUID()
        state.beginLoading(requestID: initialRequestID)
        _ = state.completeLoading(requestID: initialRequestID, records: [record], error: nil)
        state.selectRecord(id: record.id)

        let refreshRequestID = UUID()
        state.beginLoading(requestID: refreshRequestID)
        _ = state.completeLoading(requestID: refreshRequestID, records: [], error: nil)

        #expect(state.selectedRecordID == nil)
        #expect(state.selectedRecord == nil)
    }

    @Test("New import proposal requests commit of the exact proposal")
    func newImportProposalRequestsCommit() throws {
        let requestID = try #require(UUID(uuidString: "88888888-8888-8888-8888-888888888888"))
        let proposalID = try #require(UUID(uuidString: "99999999-9999-9999-9999-999999999999"))
        let plan = try flightPlan()
        let importedAt = Date(timeIntervalSince1970: 2_000_000_000)
        let prepared = PreparedImport(
            record: StoredFlightPlan(
                id: plan.id,
                modifiedAt: plan.modifiedAt,
                importedAt: importedAt,
                sourceData: Data("fixture".utf8),
                storageSchemaVersion: StoredFlightPlan.currentStorageSchemaVersion
            ),
            flightPlan: plan
        )
        let proposal = ImportProposal.new(prepared)
        var state = FlightPlansFeatureState()

        let didBegin = state.beginImport(requestID: requestID)
        #expect(didBegin)
        let decision = state.completeImportPreparation(
            requestID: requestID,
            proposalID: proposalID,
            proposal: proposal
        )

        #expect(decision == .commit(proposalID: proposalID))
        #expect(state.pendingImport == PendingFlightPlanImport(id: proposalID, proposal: proposal))
        #expect(state.records.isEmpty)
        #expect(state.inFlightRequestID == nil)
    }

    @Test("Same revision reports already imported without commit or row mutation")
    func sameRevisionDoesNotCommit() throws {
        let requestID = UUID()
        let proposalID = UUID()
        let existing = LibraryFlightPlan(flightPlan: try flightPlan(), importedAt: .distantPast)
        var state = FlightPlansFeatureState()
        state.beginLoading(requestID: UUID())
        let loadID = try #require(state.inFlightRequestID)
        _ = state.completeLoading(requestID: loadID, records: [existing], error: nil)
        _ = state.beginImport(requestID: requestID)

        let decision = state.completeImportPreparation(
            requestID: requestID,
            proposalID: proposalID,
            proposal: .sameRevision(existing: existing)
        )

        #expect(decision == .some(.none))
        #expect(state.pendingImport == nil)
        #expect(state.records == [existing])
        #expect(state.presentation == .alreadyImported(title: existing.flightPlan.title))
    }

    @Test("Loaded badge requires matching Flight Plan identity and revision")
    func loadedBadgeMatchesIdentityAndRevision() throws {
        let plan = try flightPlan()
        let record = LibraryFlightPlan(flightPlan: plan, importedAt: .distantPast)
        let differentRevision = FlightPlan(
            id: plan.id,
            title: plan.title,
            createdAt: plan.createdAt,
            modifiedAt: plan.modifiedAt.addingTimeInterval(1),
            parameters: plan.parameters,
            waypoints: plan.waypoints,
            legs: plan.legs,
            identificationPoints: plan.identificationPoints,
            altitudeChanges: plan.altitudeChanges,
            frequencyChanges: plan.frequencyChanges,
            vorDmeReferences: plan.vorDmeReferences,
            operationalContext: plan.operationalContext,
            plannedNavigation: plan.plannedNavigation
        )

        #expect(record.isLoaded(in: plan))
        #expect(record.isLoaded(in: differentRevision) == false)
        #expect(record.isLoaded(in: nil) == false)
    }

    @Test("Inspection with no loaded Flight offers only Load in Cockpit")
    func inspectionWithoutLoadedFlight() throws {
        let record = LibraryFlightPlan(flightPlan: try flightPlan(), importedAt: .distantPast)

        let presentation = FlightPlanInspectionPresentation(inspected: record, loadedFlightPlan: nil)

        #expect(presentation.primaryAction == .loadInCockpit)
        #expect(presentation.secondaryActions.isEmpty)
    }

    @Test("Inspection of the loaded revision offers return and restart")
    func inspectionOfLoadedRevision() throws {
        let plan = try flightPlan()
        let record = LibraryFlightPlan(flightPlan: plan, importedAt: .distantPast)

        let presentation = FlightPlanInspectionPresentation(inspected: record, loadedFlightPlan: plan)

        #expect(presentation.primaryAction == .returnToCockpit)
        #expect(presentation.secondaryActions == [.restartFlight])
    }

    @Test("Inspection of a saved update offers return, update, and restart")
    func inspectionOfSavedUpdate() throws {
        let loadedPlan = try flightPlan()
        let savedPlan = copy(
            loadedPlan,
            modifiedAt: loadedPlan.modifiedAt.addingTimeInterval(60)
        )
        let record = LibraryFlightPlan(flightPlan: savedPlan, importedAt: .distantPast)

        let presentation = FlightPlanInspectionPresentation(inspected: record, loadedFlightPlan: loadedPlan)

        #expect(presentation.primaryAction == .returnToCockpit)
        #expect(presentation.secondaryActions == [.loadUpdatedPlan, .restartFlight])
    }

    @Test("Inspection of a different Flight Plan offers only Load in Cockpit")
    func inspectionOfDifferentPlan() throws {
        let loadedPlan = try flightPlan()
        let inspectedPlan = copy(loadedPlan, id: UUID())
        let record = LibraryFlightPlan(flightPlan: inspectedPlan, importedAt: .distantPast)

        let presentation = FlightPlanInspectionPresentation(inspected: record, loadedFlightPlan: loadedPlan)

        #expect(presentation.primaryAction == .loadInCockpit)
        #expect(presentation.secondaryActions.isEmpty)
    }

    @Test("Restart pins the loaded snapshot while update loads the saved revision")
    func restartAndUpdateUseDistinctSnapshots() throws {
        let loadedPlan = try flightPlan()
        let savedUpdate = copy(
            loadedPlan,
            modifiedAt: loadedPlan.modifiedAt.addingTimeInterval(60)
        )
        let updateRecord = LibraryFlightPlan(flightPlan: savedUpdate, importedAt: .distantPast)
        var cockpit = CockpitFeatureState()
        try cockpit.accept(loadedPlan)
        var restartState = AppFeatureState(selectedAppSection: .flightPlans, cockpit: cockpit)
        var updateState = restartState

        _ = try restartState.restartFlight(flightID: UUID())
        _ = try updateState.loadUpdatedFlightPlan(updateRecord, flightID: UUID())

        #expect(restartState.cockpit.flightPlan == loadedPlan)
        #expect(updateState.cockpit.flightPlan == savedUpdate)
        #expect(restartState.cockpit.flight?.legStartedAt == nil)
        #expect(updateState.cockpit.flight?.legStartedAt == nil)
    }

    @Test("Newer and older replacements wait for explicit confirmation")
    func replacementsWaitForConfirmation() throws {
        let plan = try flightPlan()
        let prepared = PreparedImport(
            record: StoredFlightPlan(
                id: plan.id,
                modifiedAt: plan.modifiedAt,
                importedAt: .now,
                sourceData: Data(),
                storageSchemaVersion: StoredFlightPlan.currentStorageSchemaVersion
            ),
            flightPlan: plan
        )
        let replacement = PreparedReplacement(
            candidate: prepared,
            expectedModifiedAt: plan.modifiedAt.addingTimeInterval(-1)
        )

        for proposal in [ImportProposal.replaceNewer(replacement), .replaceOlder(replacement)] {
            var state = FlightPlansFeatureState()
            let requestID = UUID()
            let proposalID = UUID()
            _ = state.beginImport(requestID: requestID)

            let decision = state.completeImportPreparation(
                requestID: requestID,
                proposalID: proposalID,
                proposal: proposal
            )

            #expect(decision == .confirmation(proposalID: proposalID))
            #expect(state.pendingImport?.proposal == proposal)
            #expect(state.inFlightRequestID == nil)
        }
    }

    @Test("Import failure preserves the last successful list and rejects stale completion")
    func importFailurePreservesRecords() throws {
        let existing = LibraryFlightPlan(flightPlan: try flightPlan(), importedAt: .distantPast)
        var state = FlightPlansFeatureState()
        let loadID = UUID()
        state.beginLoading(requestID: loadID)
        _ = state.completeLoading(requestID: loadID, records: [existing], error: nil)
        let requestID = UUID()
        _ = state.beginImport(requestID: requestID)

        let staleCompletion = state.failImport(requestID: UUID(), failure: .storageFailure)
        #expect(staleCompletion == false)
        #expect(state.inFlightRequestID == requestID)
        let acceptedCompletion = state.failImport(requestID: requestID, failure: .storageFailure)
        #expect(acceptedCompletion)
        #expect(state.records == [existing])
        #expect(state.presentation == .failure(.storageFailure))
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

    private func copy(
        _ plan: FlightPlan,
        id: UUID? = nil,
        modifiedAt: Date? = nil
    ) -> FlightPlan {
        FlightPlan(
            id: id ?? plan.id,
            title: plan.title,
            createdAt: plan.createdAt,
            modifiedAt: modifiedAt ?? plan.modifiedAt,
            parameters: plan.parameters,
            waypoints: plan.waypoints,
            legs: plan.legs,
            identificationPoints: plan.identificationPoints,
            altitudeChanges: plan.altitudeChanges,
            frequencyChanges: plan.frequencyChanges,
            vorDmeReferences: plan.vorDmeReferences,
            operationalContext: plan.operationalContext,
            plannedNavigation: plan.plannedNavigation
        )
    }
}
