import Foundation
import Testing
@testable import NavigationFlight

@Suite("Cockpit presentation state")
struct CockpitPresentationStateTests {
    @Test("Map interaction reveals quick focus controls for four seconds")
    func interactionStartsVisibilityWindow() {
        let interactionTime = Date(timeIntervalSince1970: 1_000)
        var state = CockpitPresentationState()

        state.mapInteractionOccurred(at: interactionTime)

        #expect(state.areQuickFocusControlsVisible)
        #expect(state.quickFocusHideDeadline == interactionTime.addingTimeInterval(4))
    }

    @Test("Quick focus controls hide at the four-second deadline")
    func controlsHideAtDeadline() {
        let interactionTime = Date(timeIntervalSince1970: 2_000)
        var state = CockpitPresentationState()
        state.mapInteractionOccurred(at: interactionTime)

        state.hideQuickFocusControlsIfExpired(at: interactionTime.addingTimeInterval(3.999))
        #expect(state.areQuickFocusControlsVisible)

        state.hideQuickFocusControlsIfExpired(at: interactionTime.addingTimeInterval(4))
        #expect(!state.areQuickFocusControlsVisible)
        #expect(state.quickFocusHideDeadline == nil)
    }

    @Test("A later map interaction replaces the quick focus deadline")
    func interactionReplacesDeadline() {
        let firstInteraction = Date(timeIntervalSince1970: 3_000)
        let secondInteraction = firstInteraction.addingTimeInterval(2)
        var state = CockpitPresentationState()
        state.mapInteractionOccurred(at: firstInteraction)

        state.mapInteractionOccurred(at: secondInteraction)
        state.hideQuickFocusControlsIfExpired(at: firstInteraction.addingTimeInterval(4))

        #expect(state.areQuickFocusControlsVisible)
        #expect(state.quickFocusHideDeadline == secondInteraction.addingTimeInterval(4))
    }

    @Test("Map Tools exposes only lower-frequency map actions")
    func mapToolsActions() {
        #expect(CockpitMapTool.allCases == [
            .showFullRoute,
            .toggleDriftLines,
            .chartLayers,
            .inspectFlightPlan
        ])
    }

    @Test("Opening and closing Map Tools changes disclosure state only")
    func mapToolsDisclosureState() {
        var state = CockpitPresentationState()

        state.setMapToolsPresented(true)
        #expect(state.isMapToolsPresented)

        state.setMapToolsPresented(false)
        #expect(!state.isMapToolsPresented)
    }

    @Test("Frequency Plan opens exclusively and closes without mutating Flight")
    func frequencyPlanDisclosureState() {
        let flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID()],
            activeLegIndex: 0,
            executionMode: .wind
        )
        let originalFlight = flight
        var state = CockpitPresentationState()

        state.setMapToolsPresented(true)
        state.setFrequencyPlanPresented(true)

        #expect(state.activeDisclosure == .frequencyPlan)
        #expect(!state.isMapToolsPresented)
        #expect(state.isFrequencyPlanPresented)

        state.setFrequencyPlanPresented(false)

        #expect(state.activeDisclosure == nil)
        #expect(!state.isFrequencyPlanPresented)
        #expect(flight == originalFlight)
    }

    @Test("Checklist, Previous Leg, and Next Leg expand exclusively")
    func operationalDisclosuresExpandExclusively() {
        var state = CockpitPresentationState()

        state.setChecklistPresented(true)
        #expect(state.activeDisclosure == .checklist)

        state.setPreviousLegPresented(true)
        #expect(state.activeDisclosure == .previousLeg)
        #expect(!state.isChecklistPresented)

        state.setNextLegPresented(true)
        #expect(state.activeDisclosure == .nextLeg)
        #expect(!state.isPreviousLegPresented)
        #expect(state.isNextLegPresented)
    }

    @Test("Closing the Next Leg map preview restores active-leg map focus")
    func nextLegMapPreviewRestoresActiveLeg() {
        var state = CockpitPresentationState()

        state.setNextLegMapPreviewPresented(true)
        #expect(state.isNextLegMapPreviewPresented)
        #expect(state.mapFocusRequest?.mode == .nextLeg)

        state.setNextLegMapPreviewPresented(false)
        #expect(!state.isNextLegMapPreviewPresented)
        #expect(state.mapFocusRequest?.mode == .leg)
    }

    @Test("Whole-leg and destination recovery produce distinct map intents")
    func recoveryMapIntentsAreDistinct() {
        let wholeLeg = AviationMapFocusRequest(mode: .leg)
        let destination = AviationMapFocusRequest(mode: .waypoint)

        #expect(wholeLeg.mode == .leg)
        #expect(destination.mode == .waypoint)
        #expect(wholeLeg != destination)
    }

    @Test("Map presentation intents do not mutate Flight state")
    func presentationIntentsPreserveFlight() {
        let flight = Flight(
            flightPlanID: UUID(),
            legIDs: [UUID(), UUID()],
            activeLegIndex: 0,
            executionMode: .wind
        )
        let originalFlight = flight
        var presentation = CockpitPresentationState()

        presentation.mapInteractionOccurred(at: Date(timeIntervalSince1970: 4_000))
        presentation.setMapToolsPresented(true)
        _ = AviationMapFocusRequest(mode: .leg)
        _ = AviationMapFocusRequest(mode: .waypoint)

        #expect(flight == originalFlight)
    }

    @Test(
        "Progression results use the approved operational copy",
        arguments: [
            (CockpitProgressionNotice.automaticSuccessor("RAMAT"), "RAMAT reached · successor started", "Automatic progression · Undo restores the departing leg atomically."),
            (CockpitProgressionNotice.manualSuccessor("RAMAT"), "RAMAT reached · next leg ready", "Manual progression · no successor timing until Start next leg."),
            (CockpitProgressionNotice.navigationComplete, "Navigation complete", "Final leg recorded. No successor timer was started."),
            (CockpitProgressionNotice.rejected(.alreadyReportedReached), "Already reported reached", "No timing, target, focus, checklist, or history state changed.")
        ]
    )
    func progressionResultCopy(
        _ notice: CockpitProgressionNotice,
        _ title: String,
        _ detail: String
    ) {
        #expect(notice.title == title)
        #expect(notice.detail == detail)
    }

    @Test("Only successful reach results expose bounded undo")
    func progressionResultUndoAvailability() {
        #expect(CockpitProgressionNotice.automaticSuccessor("RAMAT").supportsUndo)
        #expect(CockpitProgressionNotice.manualSuccessor("RAMAT").supportsUndo)
        #expect(CockpitProgressionNotice.navigationComplete.supportsUndo)
        #expect(!CockpitProgressionNotice.rejected(.alreadyReportedReached).supportsUndo)
        #expect(!CockpitProgressionNotice.rejected(.undoExpired).supportsUndo)
        #expect(!CockpitProgressionNotice.rejected(.actionUnavailable).supportsUndo)
    }

    @Test("Arrival result selection follows progression policy and successor availability")
    func progressionResultSelection() {
        #expect(CockpitProgressionNotice.arrivalReached(
            waypoint: "RAMAT",
            progressionPolicy: .automaticNextLeg,
            hasSuccessor: true
        ) == .automaticSuccessor("RAMAT"))
        #expect(CockpitProgressionNotice.arrivalReached(
            waypoint: "RAMAT",
            progressionPolicy: .manualNextLeg,
            hasSuccessor: true
        ) == .manualSuccessor("RAMAT"))
        #expect(CockpitProgressionNotice.arrivalReached(
            waypoint: "RAMAT",
            progressionPolicy: .automaticNextLeg,
            hasSuccessor: false
        ) == .navigationComplete)
    }
}
