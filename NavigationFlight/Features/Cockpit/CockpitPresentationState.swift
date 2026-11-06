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
    case checklist
    case previousLeg
    case nextLeg
}

struct CockpitPresentationState: Equatable, Sendable {
    static let quickFocusVisibilityDuration: TimeInterval = 4

    private(set) var areQuickFocusControlsVisible = false
    private(set) var quickFocusHideDeadline: Date?
    private(set) var activeDisclosure: CockpitDisclosure?
    private(set) var isNextLegMapPreviewPresented = false
    private(set) var mapFocusRequest: AviationMapFocusRequest?

    var isMapToolsPresented: Bool {
        activeDisclosure == .mapTools
    }

    var isFrequencyPlanPresented: Bool {
        activeDisclosure == .frequencyPlan
    }

    var isChecklistPresented: Bool { activeDisclosure == .checklist }
    var isPreviousLegPresented: Bool { activeDisclosure == .previousLeg }
    var isNextLegPresented: Bool { activeDisclosure == .nextLeg }

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

    mutating func setChecklistPresented(_ isPresented: Bool) {
        setDisclosure(.checklist, isPresented: isPresented)
    }

    mutating func setPreviousLegPresented(_ isPresented: Bool) {
        setDisclosure(.previousLeg, isPresented: isPresented)
    }

    mutating func setNextLegPresented(_ isPresented: Bool) {
        setDisclosure(.nextLeg, isPresented: isPresented)
        if !isPresented, isNextLegMapPreviewPresented {
            setNextLegMapPreviewPresented(false)
        }
    }

    mutating func setNextLegMapPreviewPresented(_ isPresented: Bool) {
        isNextLegMapPreviewPresented = isPresented
        mapFocusRequest = AviationMapFocusRequest(mode: isPresented ? .nextLeg : .leg)
    }

    private mutating func setDisclosure(_ disclosure: CockpitDisclosure, isPresented: Bool) {
        if isPresented {
            activeDisclosure = disclosure
        } else if activeDisclosure == disclosure {
            activeDisclosure = nil
        }
    }
}
