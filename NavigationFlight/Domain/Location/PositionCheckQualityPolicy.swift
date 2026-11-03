import Foundation

nonisolated struct PositionCheckQuality: Equatable, Sendable {
    enum GuidanceEligibility: Equatable, Sendable {
        case eligible
        case ineligible
    }

    enum PositionIneligibilityReason: Equatable, Sendable {
        case stale
        case invalidAccuracy
        case insufficientAccuracy
        case outOfOrder
    }

    enum PositionEligibility: Equatable, Sendable {
        case eligible
        case ineligible(PositionIneligibilityReason)
    }

    let position: PositionEligibility
    let guidance: GuidanceEligibility
}

nonisolated struct PositionCheckQualityPolicy: Sendable {
    func classify(
        _ sample: AircraftLocationSample,
        receivedAt: Date,
        lastAcceptedObservation: Date?
    ) -> PositionCheckQuality {
        let guidance = guidanceEligibility(for: sample)
        if let lastAcceptedObservation, sample.observedAt < lastAcceptedObservation {
            return PositionCheckQuality(position: .ineligible(.outOfOrder), guidance: .ineligible)
        }
        if receivedAt.timeIntervalSince(sample.observedAt) > 5 {
            return PositionCheckQuality(position: .ineligible(.stale), guidance: .ineligible)
        }
        if sample.horizontalAccuracyMeters <= 0 {
            return PositionCheckQuality(position: .ineligible(.invalidAccuracy), guidance: .ineligible)
        }
        if sample.horizontalAccuracyMeters > 100 {
            return PositionCheckQuality(position: .ineligible(.insufficientAccuracy), guidance: .ineligible)
        }

        return PositionCheckQuality(position: .eligible, guidance: guidance)
    }

    private func guidanceEligibility(
        for sample: AircraftLocationSample
    ) -> PositionCheckQuality.GuidanceEligibility {
        guard let speed = sample.groundSpeedMetersPerSecond,
              speed >= 5,
              let speedAccuracy = sample.speedAccuracyMetersPerSecond,
              speedAccuracy >= 0,
              let course = sample.trueCourseDegrees,
              course >= 0,
              course < 360,
              let courseAccuracy = sample.courseAccuracyDegrees,
              courseAccuracy >= 0,
              courseAccuracy <= 20 else {
            return .ineligible
        }

        return .eligible
    }
}
