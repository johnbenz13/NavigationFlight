import Foundation

nonisolated struct SettingsLoadResult: Equatable, Sendable {
    let preferences: AppPreferences
}
