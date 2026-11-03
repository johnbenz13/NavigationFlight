import Foundation
import Testing
@testable import NavigationFlight

@MainActor
@Suite("Position Check coordinator")
struct PositionCheckCoordinatorTests {
    @Test("Disclosure expires at exactly ten elapsed seconds")
    func disclosureDeadline() async throws {
        let clock = ManualPositionCheckClock()
        let coordinator = makeCoordinator(clock: clock)
        coordinator.send(.holdCompleted(availability: .ready(sample()), restoration: .empty))

        await clock.advance(to: .seconds(9))
        #expect(coordinator.state.activeSession != nil)

        await clock.advance(to: .seconds(10))
        await Task.yield()
        #expect(coordinator.state == .idle)
    }

    @Test("Restart replaces rather than stacks the disclosure deadline")
    func restartReplacesDeadline() async throws {
        let clock = ManualPositionCheckClock()
        let coordinator = makeCoordinator(clock: clock)
        coordinator.send(.holdCompleted(availability: .ready(sample()), restoration: .empty))
        await clock.advance(to: .seconds(4))
        coordinator.send(.restartHoldCompleted(availability: .ready(sample()), restoration: .empty))

        await clock.advance(to: .seconds(10))
        #expect(coordinator.state.activeSession != nil)
        await clock.advance(to: .seconds(14))
        await Task.yield()
        #expect(coordinator.state == .idle)
    }

    @Test("Two coordinators own independent disclosure windows")
    func coordinatorsAreIndependent() async {
        let firstClock = ManualPositionCheckClock()
        let secondClock = ManualPositionCheckClock()
        let first = makeCoordinator(clock: firstClock)
        let second = makeCoordinator(clock: secondClock)
        first.send(.holdCompleted(availability: .ready(sample()), restoration: .empty))
        second.send(.holdCompleted(availability: .ready(sample()), restoration: .empty))

        first.send(.end)

        #expect(first.state == .idle)
        #expect(second.state.activeSession != nil)
    }

    @Test("Map restoration is requested once and only its matching acknowledgement clears it")
    func mapRestorationAcknowledgementIsGenerationBound() throws {
        let clock = ManualPositionCheckClock()
        let coordinator = makeCoordinator(clock: clock)
        coordinator.send(.holdCompleted(availability: .ready(sample()), restoration: .empty))

        coordinator.send(.locationAvailabilityChanged(.unavailable(.signalLost)))

        let command = try #require(coordinator.pendingMapRestoration)
        #expect(command.restoration == .empty)
        coordinator.acknowledgeMapRestoration(id: UUID())
        #expect(coordinator.pendingMapRestoration == command)
        coordinator.acknowledgeMapRestoration(id: command.id)
        #expect(coordinator.pendingMapRestoration == nil)
    }

    private func makeCoordinator(clock: ManualPositionCheckClock) -> PositionCheckCoordinator {
        PositionCheckCoordinator(
            now: { clock.now },
            sleepUntil: { deadline in try await clock.sleep(until: deadline) }
        )
    }

    private func sample() -> AircraftLocationSample {
        AircraftLocationSample(
            coordinate: WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.8),
            observedAt: Date(timeIntervalSince1970: 1_000),
            horizontalAccuracyMeters: 35,
            trueCourseDegrees: 72,
            courseAccuracyDegrees: 5,
            groundSpeedMetersPerSecond: 40,
            speedAccuracyMetersPerSecond: 1
        )
    }
}

@MainActor
private final class ManualPositionCheckClock: Sendable {
    private(set) var now: Duration = .zero
    private var sleepers: [(Duration, CheckedContinuation<Void, any Error>)] = []

    func sleep(until deadline: Duration) async throws {
        if deadline <= now { return }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                sleepers.append((deadline, continuation))
            }
        } onCancel: {
        }
    }

    func advance(to instant: Duration) async {
        now = instant
        let ready = sleepers.filter { $0.0 <= instant }
        sleepers.removeAll { $0.0 <= instant }
        ready.forEach { $0.1.resume() }
        await Task.yield()
    }
}
