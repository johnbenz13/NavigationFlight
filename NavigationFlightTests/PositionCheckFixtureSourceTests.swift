import Foundation
import Testing
@testable import NavigationFlight

@Suite("Position Check fixture source")
struct PositionCheckFixtureSourceTests {
    @Test("Every approved fixture name decodes to a canonical scenario", arguments: [
        "ready", "acquiring", "permission-required", "unavailable",
        "recovery-available", "on-track", "position-only",
        "no-sensible-intercept", "extreme-displacement", "signal-loss",
        "permission-revoked"
    ])
    func decodesApprovedScenario(name: String) {
        #expect(PositionCheckFixtureScenario(rawValue: name) != nil)
    }

    @Test("Unknown fixture names fail closed")
    func rejectsUnknownScenario() {
        #expect(PositionCheckFixtureScenario(rawValue: "invented-state") == nil)
    }

    @Test("Signal loss emits a usable fix followed by loss without wall-clock sleeping")
    func signalLossSequence() async throws {
        let sleeper = RecordingFixtureSleeper()
        let source = PositionCheckFixtureSource(
            scenario: .signalLoss,
            observedAt: Date(timeIntervalSince1970: 1_000),
            followUpDelay: .seconds(1),
            sleep: { duration in await sleeper.record(duration) }
        )
        var iterator = source.updates().makeAsyncIterator()

        let first = try await iterator.next()
        let second = try await iterator.next()

        #expect(first?.sample != nil)
        #expect(second == .signalLost)
        #expect(await sleeper.durations == [.seconds(1)])
    }
}

private actor RecordingFixtureSleeper {
    private(set) var durations: [Duration] = []

    func record(_ duration: Duration) {
        durations.append(duration)
    }
}

private extension LocationSourceEvent {
    var sample: AircraftLocationSample? {
        guard case .sample(let sample, _) = self else { return nil }
        return sample
    }
}
