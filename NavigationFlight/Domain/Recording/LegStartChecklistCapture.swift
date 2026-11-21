import Foundation

nonisolated struct LegStartChecklistCapture: Codable, Equatable, Sendable {
    enum ReviewState: String, Codable, Equatable, Sendable {
        case pending
        case noted
    }

    enum PresentationState: String, Codable, Equatable, Sendable {
        case expanded
        case collapsed
    }

    enum PhaseState: String, Codable, Equatable, Sendable {
        case available
        case hiddenForPhase
    }

    let legID: UUID
    var selection: StartChecklistSelection = .tzeKivun
    var definitionRevision: Int = 1
    var reviewState: ReviewState
    var presentationState: PresentationState
    var phaseState: PhaseState
}
