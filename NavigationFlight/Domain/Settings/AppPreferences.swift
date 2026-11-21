import Foundation

nonisolated struct AppPreferences: Equatable, Sendable {
    var startChecklist: StartChecklistSelection = .tzeKivun
    var showDriftLines = true
    var progression: Progression = .automatic
    var recoveryWindow: RecoveryWindow = .fiveMinutes

    enum Progression: String, Codable, Sendable {
        case automatic
        case manual
    }

    enum RecoveryWindow: Int, Codable, CaseIterable, Sendable {
        case oneMinute = 60
        case twoMinutes = 120
        case fiveMinutes = 300
        case tenMinutes = 600
    }

    mutating func apply(_ change: PreferenceChange) {
        switch change {
        case .startChecklist(let value): startChecklist = value
        case .showDriftLines(let value): showDriftLines = value
        case .progression(let value): progression = value
        case .recoveryWindow(let value): recoveryWindow = value
        }
    }
}
