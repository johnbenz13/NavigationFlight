import Foundation

actor DiskSettingsStore: SettingsStore {
    private struct Envelope<Value: Codable>: Codable {
        let version: Int
        let value: Value
    }

    private var remainingFailures: Int
    private let directory: URL
    private let beforeWrite: @Sendable (PreferenceChange) throws -> Void

    init(directory: URL, failNextSaves: Int = 0, beforeWrite: @escaping @Sendable (PreferenceChange) throws -> Void = { _ in }) {
        remainingFailures = failNextSaves
        self.directory = directory
        self.beforeWrite = beforeWrite
    }

    func load() -> SettingsLoadResult {
        var preferences = AppPreferences()
        preferences.startChecklist = read("cockpit.startChecklist") ?? preferences.startChecklist
        preferences.showDriftLines = read("cockpit.showDriftLines") ?? preferences.showDriftLines
        preferences.progression = read("cockpit.progression") ?? preferences.progression
        preferences.recoveryWindow = read("recording.recoveryWindowSeconds") ?? preferences.recoveryWindow
        preferences.routeAmendmentMode = read(PreferenceChange.routeAmendmentMode(.manual).key)
            ?? preferences.routeAmendmentMode
        return SettingsLoadResult(preferences: preferences)
    }

    private func read<Value: Codable>(_ key: String) -> Value? {
        guard let data = try? Data(contentsOf: directory.appending(path: key + ".json")),
              let envelope = try? JSONDecoder().decode(Envelope<Value>.self, from: data),
              envelope.version == 1 else { return nil }
        return envelope.value
    }

    func save(_ change: PreferenceChange) throws {
        let data: Data
        switch change {
        case .startChecklist(let value): data = try encode(value)
        case .showDriftLines(let value): data = try encode(value)
        case .progression(let value): data = try encode(value)
        case .recoveryWindow(let value): data = try encode(value)
        case .routeAmendmentMode(let value): data = try encode(value)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if remainingFailures > 0 {
            remainingFailures -= 1
            throw CocoaError(.fileWriteNoPermission)
        }
        try beforeWrite(change)
        // Atomic writes use a sibling temporary file and leave the old file on failure.
        try data.write(to: directory.appending(path: change.key + ".json"), options: .atomic)
    }

    private func encode<Value: Codable>(_ value: Value) throws -> Data {
        try JSONEncoder().encode(Envelope(version: 1, value: value))
    }
}
