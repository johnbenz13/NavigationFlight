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
}
