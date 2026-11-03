import Foundation
import Observation

nonisolated struct PositionCheckMapRestorationCommand: Equatable, Sendable {
    let id: UUID
    let restoration: CockpitRestoration
}

@MainActor
@Observable
final class PositionCheckCoordinator {
    private(set) var state: PositionCheckState = .idle
    private(set) var remainingSeconds: Int?
    private(set) var pendingMapRestoration: PositionCheckMapRestorationCommand?

    private let now: @MainActor () -> Duration
    private let sleepUntil: @Sendable (Duration) async throws -> Void
    private let timing: PositionCheckTiming
    private var deadlineTask: Task<Void, Never>?

    init(
        now: @escaping @MainActor () -> Duration,
        sleepUntil: @escaping @Sendable (Duration) async throws -> Void,
        timing: PositionCheckTiming = .standard
    ) {
        self.now = now
        self.sleepUntil = sleepUntil
        self.timing = timing
    }

    convenience init(timing: PositionCheckTiming = .standard) {
        let clock = ContinuousClock()
        let origin = clock.now
        self.init(
            now: { origin.duration(to: clock.now) },
            sleepUntil: { deadline in
                let elapsed = origin.duration(to: clock.now)
                if deadline > elapsed {
                    try await clock.sleep(for: deadline - elapsed)
                }
            },
            timing: timing
        )
    }

    @discardableResult
    func send(_ intent: PositionCheckIntent) -> PositionCheckEffect {
        let transition = state.transition(intent, now: now(), timing: timing)
        state = transition.state
        remainingSeconds = state.activeSession.map { remainingSeconds(until: $0.deadline) }
        apply(transition.effect)
        return transition.effect
    }

    func recoveryOutcome(
        for availability: LocationAvailability,
        activeLeg: AviationMapLeg?,
        importedMagneticCourseDegrees: Double
    ) -> ActiveLegRecoveryOutcome? {
        guard state.activeSession != nil,
              case .ready(let sample) = availability,
              let activeLeg else { return nil }
        return ActiveLegRecoveryCalculator().calculate(
            sample: sample,
            legStart: WGS84Coordinate(
                latitudeDegrees: activeLeg.from.latitude,
                longitudeDegrees: activeLeg.from.longitude
            ),
            legEnd: WGS84Coordinate(
                latitudeDegrees: activeLeg.to.latitude,
                longitudeDegrees: activeLeg.to.longitude
            ),
            importedMagneticCourseDegrees: importedMagneticCourseDegrees
        )
    }

    func acknowledgeMapRestoration(id: UUID) {
        guard pendingMapRestoration?.id == id else { return }
        pendingMapRestoration = nil
    }

    private func apply(_ effect: PositionCheckEffect) {
        switch effect {
        case .none:
            break
        case .cancelDeadline:
            deadlineTask?.cancel()
            deadlineTask = nil
            remainingSeconds = nil
        case .endDisclosure(let restoration):
            deadlineTask?.cancel()
            deadlineTask = nil
            remainingSeconds = nil
            pendingMapRestoration = PositionCheckMapRestorationCommand(
                id: UUID(),
                restoration: restoration
            )
        case .scheduleDeadline(let generation, let deadline):
            deadlineTask?.cancel()
            pendingMapRestoration = nil
            deadlineTask = Task { [weak self, sleepUntil] in
                do {
                    while let self, self.now() < deadline {
                        let nextTick = min(deadline, self.now() + .seconds(1))
                        try await sleepUntil(nextTick)
                        guard !Task.isCancelled else { return }
                        self.remainingSeconds = self.remainingSeconds(until: deadline)
                    }
                    self?.send(.deadlineReached(generation))
                } catch {
                    return
                }
            }
        }
    }

    private func remainingSeconds(until deadline: Duration) -> Int {
        let remaining = max(.zero, deadline - now())
        let components = remaining.components
        let fractional = components.attoseconds > 0 ? 1 : 0
        return Int(components.seconds) + fractional
    }
}
