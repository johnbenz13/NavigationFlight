import Foundation

enum CockpitProgressionNotice: Equatable, Sendable {
    enum Rejection: Equatable, Sendable {
        case alreadyReportedReached
        case undoExpired
        case actionUnavailable
        case invalidTimestamp
    }

    case automaticSuccessor(String)
    case manualSuccessor(String)
    case navigationComplete
    case rejected(Rejection)

    var title: String {
        switch self {
        case .automaticSuccessor(let waypoint):
            "\(waypoint) reached · successor started"
        case .manualSuccessor(let waypoint):
            "\(waypoint) reached · next leg ready"
        case .navigationComplete:
            "Navigation complete"
        case .rejected(.alreadyReportedReached):
            "Already reported reached"
        case .rejected(.undoExpired):
            "Undo expired"
        case .rejected(.actionUnavailable):
            "Action unavailable"
        case .rejected(.invalidTimestamp):
            "Invalid report time"
        }
    }

    var detail: String {
        switch self {
        case .automaticSuccessor:
            "Automatic progression · Undo restores the departing leg atomically."
        case .manualSuccessor:
            "Manual progression · no successor timing until Start next leg."
        case .navigationComplete:
            "Final leg recorded. No successor timer was started."
        case .rejected(.alreadyReportedReached):
            "No timing, target, focus, checklist, or history state changed."
        case .rejected(.undoExpired):
            "The 20-second undo window has ended. Navigation state was not changed."
        case .rejected(.actionUnavailable):
            "This action is not available in the current navigation state."
        case .rejected(.invalidTimestamp):
            "The report time precedes the active leg start. Navigation state was not changed."
        }
    }

    var supportsUndo: Bool {
        switch self {
        case .automaticSuccessor, .manualSuccessor, .navigationComplete:
            true
        case .rejected:
            false
        }
    }

    static func arrivalReached(
        waypoint: String,
        progressionPolicy: Flight.ProgressionPolicy,
        hasSuccessor: Bool
    ) -> CockpitProgressionNotice {
        guard hasSuccessor else { return .navigationComplete }
        switch progressionPolicy {
        case .automaticNextLeg:
            return .automaticSuccessor(waypoint)
        case .manualNextLeg:
            return .manualSuccessor(waypoint)
        }
    }
}

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
