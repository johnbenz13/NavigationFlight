import Foundation

nonisolated struct PhysicalFlightDetectionPolicy: Equatable, Sendable {
    let maximumHorizontalAccuracyMeters: Double
    let maximumSpeedAccuracyMetersPerSecond: Double
    let groundMovementSpeedMetersPerSecond: Double
    let groundMovementWindow: Duration
    let candidateInterruptionTolerance: Duration
    let takeoffSpeedMetersPerSecond: Double
    let takeoffAltitudeGainMeters: Double
    let takeoffWindow: Duration
    let landingSpeedMetersPerSecond: Double
    let landingAltitudeToleranceMeters: Double
    let landingWindow: Duration
    let stoppedSpeedMetersPerSecond: Double
    let stoppedWindow: Duration
    let provisionalTimeout: Duration
    let airborneLaunchWindow: Duration
}

extension PhysicalFlightDetectionPolicy {
    nonisolated static let production = PhysicalFlightDetectionPolicy(
        maximumHorizontalAccuracyMeters: 50,
        maximumSpeedAccuracyMetersPerSecond: 3,
        groundMovementSpeedMetersPerSecond: 3,
        groundMovementWindow: .seconds(20),
        candidateInterruptionTolerance: .seconds(3),
        takeoffSpeedMetersPerSecond: 25,
        takeoffAltitudeGainMeters: 30,
        takeoffWindow: .seconds(10),
        landingSpeedMetersPerSecond: 15,
        landingAltitudeToleranceMeters: 45,
        landingWindow: .seconds(30),
        stoppedSpeedMetersPerSecond: 1.5,
        stoppedWindow: .seconds(60),
        provisionalTimeout: .seconds(600),
        airborneLaunchWindow: .seconds(15)
    )
}

nonisolated struct PhysicalFlightDetector: Equatable, Sendable {
    enum Event: Equatable, Sendable {
        case groundMovementBegan
        case takeoffDetected
        case landingDetected
        case sustainedStopDetected
        case provisionalTimedOut
        case partialStartDetected
        case correction(previous: PhysicalFlightState, corrected: PhysicalFlightState)
    }

    private(set) var state = PhysicalFlightState.preparing

    private let policy: PhysicalFlightDetectionPolicy
    private var groundMovementCandidateStartedAt: Duration?
    private var groundMovementLastCredibleAt: Duration?
    private var airborneLaunchCandidateStartedAt: Duration?
    private var takeoffCandidateStartedAt: Duration?
    private var takeoffLastCredibleAt: Duration?
    private var contradictionCandidateStartedAt: Duration?
    private var landingCandidateStartedAt: Duration?
    private var landingLastCredibleAt: Duration?
    private var stoppedCandidateStartedAt: Duration?
    private var stoppedLastCredibleAt: Duration?
    private var provisionalStartedAt: Duration?
    private var groundReferenceAltitudeMeters: Double?

    init(policy: PhysicalFlightDetectionPolicy) {
        self.policy = policy
    }

    mutating func process(
        _ sample: AircraftLocationSample,
        monotonicTime: Duration
    ) -> [Event] {
        switch state {
        case .preparing:
            return processPreparing(sample, monotonicTime: monotonicTime)
        case .groundMovement:
            return processGroundMovement(sample, monotonicTime: monotonicTime)
        case .airborne:
            return processAirborne(sample, monotonicTime: monotonicTime)
        case .landedAwaitingStop:
            return processLandedAwaitingStop(sample, monotonicTime: monotonicTime)
        case .stopped, .unavailable:
            return []
        }
    }

    private mutating func processPreparing(
        _ sample: AircraftLocationSample,
        monotonicTime: Duration
    ) -> [Event] {
        if isCredibleAirborneSpeed(sample) {
            groundMovementCandidateStartedAt = nil
            guard let candidateStartedAt = airborneLaunchCandidateStartedAt else {
                airborneLaunchCandidateStartedAt = monotonicTime
                return []
            }
            guard monotonicTime - candidateStartedAt >= policy.airborneLaunchWindow else { return [] }
            state = .airborne
            airborneLaunchCandidateStartedAt = nil
            return [.partialStartDetected]
        }
        airborneLaunchCandidateStartedAt = nil

        guard isCredibleMovement(sample) else {
            if let lastCredibleAt = groundMovementLastCredibleAt,
               monotonicTime - lastCredibleAt <= policy.candidateInterruptionTolerance {
                return []
            }
            groundMovementCandidateStartedAt = nil
            groundMovementLastCredibleAt = nil
            return []
        }
        groundMovementLastCredibleAt = monotonicTime
        guard let candidateStartedAt = groundMovementCandidateStartedAt else {
            groundMovementCandidateStartedAt = monotonicTime
            groundReferenceAltitudeMeters = sample.altitudeMeters
            return []
        }
        guard monotonicTime - candidateStartedAt >= policy.groundMovementWindow else {
            return []
        }

        state = .groundMovement
        groundMovementCandidateStartedAt = nil
        groundMovementLastCredibleAt = nil
        provisionalStartedAt = monotonicTime
        return [.groundMovementBegan]
    }

    private mutating func processGroundMovement(
        _ sample: AircraftLocationSample,
        monotonicTime: Duration
    ) -> [Event] {
        if let provisionalStartedAt,
           monotonicTime - provisionalStartedAt >= policy.provisionalTimeout,
           !isCredibleMovement(sample) {
            state = .preparing
            self.provisionalStartedAt = nil
            takeoffCandidateStartedAt = nil
            groundReferenceAltitudeMeters = nil
            return [.provisionalTimedOut]
        }

        guard isCredibleTakeoff(sample) else {
            if let lastCredibleAt = takeoffLastCredibleAt,
               monotonicTime - lastCredibleAt <= policy.candidateInterruptionTolerance {
                return []
            }
            takeoffCandidateStartedAt = nil
            takeoffLastCredibleAt = nil
            return []
        }
        takeoffLastCredibleAt = monotonicTime
        guard let candidateStartedAt = takeoffCandidateStartedAt else {
            takeoffCandidateStartedAt = monotonicTime
            return []
        }
        guard monotonicTime - candidateStartedAt >= policy.takeoffWindow else { return [] }
        state = .airborne
        takeoffCandidateStartedAt = nil
        takeoffLastCredibleAt = nil
        return [.takeoffDetected]
    }

    private mutating func processAirborne(
        _ sample: AircraftLocationSample,
        monotonicTime: Duration
    ) -> [Event] {
        if isCredibleLanding(sample) {
            landingLastCredibleAt = monotonicTime
            guard let candidateStartedAt = landingCandidateStartedAt else {
                landingCandidateStartedAt = monotonicTime
                return []
            }
            guard monotonicTime - candidateStartedAt >= policy.landingWindow else { return [] }
            state = .landedAwaitingStop
            landingCandidateStartedAt = nil
            landingLastCredibleAt = nil
            contradictionCandidateStartedAt = nil
            return [.landingDetected]
        }
        if let lastCredibleAt = landingLastCredibleAt,
           monotonicTime - lastCredibleAt <= policy.candidateInterruptionTolerance {
            return []
        }
        landingCandidateStartedAt = nil
        landingLastCredibleAt = nil

        let contradictsTakeoff = !isCredibleMovement(sample)
            && (sample.altitudeMeters ?? .infinity) - (sample.verticalAccuracyMeters ?? 0)
                <= (groundReferenceAltitudeMeters ?? -.infinity) + policy.takeoffAltitudeGainMeters
        guard contradictsTakeoff else {
            contradictionCandidateStartedAt = nil
            return []
        }
        guard let candidateStartedAt = contradictionCandidateStartedAt else {
            contradictionCandidateStartedAt = monotonicTime
            return []
        }
        guard monotonicTime - candidateStartedAt >= policy.takeoffWindow else { return [] }
        state = .groundMovement
        contradictionCandidateStartedAt = nil
        provisionalStartedAt = monotonicTime
        return [.correction(previous: .airborne, corrected: .groundMovement)]
    }

    private mutating func processLandedAwaitingStop(
        _ sample: AircraftLocationSample,
        monotonicTime: Duration
    ) -> [Event] {
        guard isCrediblyStopped(sample) else {
            if let lastCredibleAt = stoppedLastCredibleAt,
               monotonicTime - lastCredibleAt <= policy.candidateInterruptionTolerance {
                return []
            }
            stoppedCandidateStartedAt = nil
            stoppedLastCredibleAt = nil
            return []
        }
        stoppedLastCredibleAt = monotonicTime
        guard let candidateStartedAt = stoppedCandidateStartedAt else {
            stoppedCandidateStartedAt = monotonicTime
            return []
        }
        guard monotonicTime - candidateStartedAt >= policy.stoppedWindow else { return [] }
        state = .stopped
        stoppedCandidateStartedAt = nil
        stoppedLastCredibleAt = nil
        return [.sustainedStopDetected]
    }

    private func isCredibleMovement(_ sample: AircraftLocationSample) -> Bool {
        guard sample.horizontalAccuracyMeters <= policy.maximumHorizontalAccuracyMeters,
              let speed = sample.groundSpeedMetersPerSecond,
              let speedAccuracy = sample.speedAccuracyMetersPerSecond,
              speedAccuracy <= policy.maximumSpeedAccuracyMetersPerSecond else {
            return false
        }
        return speed - speedAccuracy >= policy.groundMovementSpeedMetersPerSecond
    }

    private func isCredibleAirborneSpeed(_ sample: AircraftLocationSample) -> Bool {
        guard sample.horizontalAccuracyMeters <= policy.maximumHorizontalAccuracyMeters,
              let speed = sample.groundSpeedMetersPerSecond,
              let speedAccuracy = sample.speedAccuracyMetersPerSecond,
              speedAccuracy <= policy.maximumSpeedAccuracyMetersPerSecond else { return false }
        return speed - speedAccuracy >= policy.takeoffSpeedMetersPerSecond
    }

    private func isCredibleTakeoff(_ sample: AircraftLocationSample) -> Bool {
        guard isCredibleAirborneSpeed(sample),
              let altitude = sample.altitudeMeters,
              let verticalAccuracy = sample.verticalAccuracyMeters,
              let groundReferenceAltitudeMeters else { return false }
        return altitude - verticalAccuracy - groundReferenceAltitudeMeters >= policy.takeoffAltitudeGainMeters
    }

    private func isCredibleLanding(_ sample: AircraftLocationSample) -> Bool {
        guard sample.horizontalAccuracyMeters <= policy.maximumHorizontalAccuracyMeters,
              let speed = sample.groundSpeedMetersPerSecond,
              let speedAccuracy = sample.speedAccuracyMetersPerSecond,
              speedAccuracy <= policy.maximumSpeedAccuracyMetersPerSecond,
              let altitude = sample.altitudeMeters,
              let verticalAccuracy = sample.verticalAccuracyMeters,
              let groundReferenceAltitudeMeters else { return false }
        return speed + speedAccuracy <= policy.landingSpeedMetersPerSecond
            && altitude + verticalAccuracy <= groundReferenceAltitudeMeters + policy.landingAltitudeToleranceMeters
    }

    private func isCrediblyStopped(_ sample: AircraftLocationSample) -> Bool {
        guard sample.horizontalAccuracyMeters <= policy.maximumHorizontalAccuracyMeters,
              let speed = sample.groundSpeedMetersPerSecond,
              let speedAccuracy = sample.speedAccuracyMetersPerSecond,
              speedAccuracy <= policy.maximumSpeedAccuracyMetersPerSecond else { return false }
        return speed + speedAccuracy <= policy.stoppedSpeedMetersPerSecond
    }
}
