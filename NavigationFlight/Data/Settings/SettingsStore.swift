import Foundation

nonisolated protocol SettingsStore: Sendable {
    func load() async -> SettingsLoadResult
    func save(_ change: PreferenceChange) async throws
}

