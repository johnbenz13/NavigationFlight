import Foundation

nonisolated enum StartChecklistSelection: String, Codable, CaseIterable, Identifiable, Sendable {
    case tzeKivun = "tze-kivun-gamad"
    case establishHeading = "establish-heading-cruise-check"
    case none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tzeKivun: "צא כיוון"
        case .establishHeading: "Establish Heading"
        case .none: "No checklist"
        }
    }
}
