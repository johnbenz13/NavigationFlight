import Foundation

enum CockpitMapTool: CaseIterable, Equatable, Sendable {
    case showFullRoute
    case toggleDriftLines
    case chartLayers
    case inspectFlightPlan
}

enum CockpitDisclosure: Equatable, Sendable {
    case mapTools
    case frequencyPlan
}

struct CockpitPresentationState: Equatable, Sendable {
    static let quickFocusVisibilityDuration: TimeInterval = 4

    private(set) var areQuickFocusControlsVisible = false
    private(set) var quickFocusHideDeadline: Date?
    private(set) var activeDisclosure: CockpitDisclosure?

    var isMapToolsPresented: Bool {
        activeDisclosure == .mapTools
    }

    var isFrequencyPlanPresented: Bool {
        activeDisclosure == .frequencyPlan
    }

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
        setDisclosure(.mapTools, isPresented: isPresented)
    }

    mutating func setFrequencyPlanPresented(_ isPresented: Bool) {
        setDisclosure(.frequencyPlan, isPresented: isPresented)
    }

    private mutating func setDisclosure(_ disclosure: CockpitDisclosure, isPresented: Bool) {
        if isPresented {
            activeDisclosure = disclosure
        } else if activeDisclosure == disclosure {
            activeDisclosure = nil
        }
    }
}
