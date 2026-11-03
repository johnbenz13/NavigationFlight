import Foundation

@MainActor
struct PositionCheckFeedback: Equatable, Sendable {
    let announcement: String?
    let playsAcceptanceHaptic: Bool
}

@MainActor
struct PositionCheckFeedbackPolicy: Sendable {
    func feedback(
        previous: PositionCheckPresentation?,
        current: PositionCheckPresentation,
        activationAccepted: Bool = false
    ) -> PositionCheckFeedback {
        if activationAccepted {
            let announcement = current.status == .requesting
                ? "Position Check accepted. Acquiring GPS."
                : "Position Check active. \(current.remainingSeconds ?? 10) seconds remaining."
            return PositionCheckFeedback(announcement: announcement, playsAcceptanceHaptic: true)
        }

        if current.status == .signalLost || current.detail == "GPS signal lost" {
            let wasLost = previous?.status == .signalLost || previous?.detail == "GPS signal lost"
            return PositionCheckFeedback(
                announcement: wasLost ? nil : "GPS signal lost. Position and guidance cleared.",
                playsAcceptanceHaptic: false
            )
        }

        if let previous, previous.status.isDisclosureState, !current.status.isDisclosureState {
            return PositionCheckFeedback(announcement: "Position Check dismissed.", playsAcceptanceHaptic: false)
        }

        if previous?.recovery != current.recovery,
           case .guidance(let course, let time, _) = current.recovery {
            return PositionCheckFeedback(
                announcement: "Rejoin active leg. Suggested magnetic course \(course). Rejoin in \(time).",
                playsAcceptanceHaptic: false
            )
        }

        let milestone = current.remainingSeconds.flatMap { seconds -> String? in
            guard previous?.remainingSeconds != seconds, [5, 3, 1].contains(seconds) else { return nil }
            let unit = seconds == 1 ? "second" : "seconds"
            return "Position Check. \(seconds) \(unit) remaining."
        }
        return PositionCheckFeedback(announcement: milestone, playsAcceptanceHaptic: false)
    }
}

private extension PositionCheckPresentation.Status {
    var isDisclosureState: Bool {
        self == .requesting || self == .active || self == .signalLost
    }
}
