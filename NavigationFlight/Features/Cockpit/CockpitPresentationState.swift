import Foundation

enum CockpitMapTool: CaseIterable, Equatable, Sendable {
    case showFullRoute
    case toggleDriftLines
    case chartLayers
    case inspectFlightPlan
}

struct CockpitPresentationState: Equatable, Sendable {
    static let quickFocusVisibilityDuration: TimeInterval = 4

    private(set) var areQuickFocusControlsVisible = false
    private(set) var quickFocusHideDeadline: Date?
    private(set) var isMapToolsPresented = false

    mutating func mapInteractionOccurred(at date: Date) {
        areQuickFocusControlsVisible = true
        quickFocusHideDeadline = date.addingTimeInterval(Self.quickFocusVisibilityDuration)
    }

    mutating func hideQuickFocusControlsIfExpired(at date: Date) {
        guard let quickFocusHideDeadline, date >= quickFocusHideDeadline else { return }
        areQuickFocusControlsVisible = false
        self.quickFocusHideDeadline = nil
    }

    mutating func setMapToolsPresented(_ isPresented: Bool) {
        isMapToolsPresented = isPresented
    }
}
