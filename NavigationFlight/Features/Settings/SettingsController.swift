import Foundation
import Observation

@MainActor
@Observable
final class SettingsController {
    struct FailedAttempt: Equatable {
        let id: UUID
        let change: PreferenceChange
    }

    private let store: any SettingsStore
    private var loading: Task<SettingsLoadResult, Never>?
    private var tail: Task<Void, Never>?
    private var newestRequestID: UUID?
    private(set) var preferences = AppPreferences()
    private(set) var isReady = false
    private(set) var failedAttempt: FailedAttempt?
    private(set) var completedRequestID: UUID?

    init(store: any SettingsStore) {
        self.store = store
    }

    func bootstrap() async {
        guard !isReady else { return }
        let task: Task<SettingsLoadResult, Never>
        if let loading { task = loading }
        else {
            let store = store
            task = Task { await store.load() }
            loading = task
        }
        let result = await task.value
        guard !isReady else { return }
        preferences = result.preferences
        isReady = true
        loading = nil
    }

    @discardableResult
    func change(_ change: PreferenceChange) -> UUID {
        let id = UUID()
        newestRequestID = id
        failedAttempt = nil
        let previous = tail
        // The controller, not the selector view, owns accepted writes through completion.
        tail = Task { [self] in
            await previous?.value
            await bootstrap()
            do {
                try await store.save(change)
                preferences.apply(change)
                if newestRequestID == id { completedRequestID = id }
            } catch {
                if newestRequestID == id { failedAttempt = FailedAttempt(id: id, change: change) }
            }
            if newestRequestID == id { tail = nil }
        }
        return id
    }

    func retry() {
        guard let failedAttempt else { return }
        change(failedAttempt.change)
    }

    func dismissFailure() { failedAttempt = nil }

    func waitForPendingChanges() async { await tail?.value }
}
