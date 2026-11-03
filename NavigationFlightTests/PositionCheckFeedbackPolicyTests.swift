import Testing
@testable import NavigationFlight

@Suite("Position Check accessibility feedback")
@MainActor
struct PositionCheckFeedbackPolicyTests {
    private let policy = PositionCheckFeedbackPolicy()

    @Test("Accepted activation announces once and requests one haptic")
    func acceptedActivation() {
        let feedback = policy.feedback(
            previous: presentation(status: .ready),
            current: presentation(status: .active, remainingSeconds: 10),
            activationAccepted: true
        )

        #expect(feedback.announcement == "Position Check active. 10 seconds remaining.")
        #expect(feedback.playsAcceptanceHaptic)
    }

    @Test("Countdown announcements are restrained to approved milestones", arguments: [
        (9, nil), (5, "Position Check. 5 seconds remaining."),
        (4, nil), (3, "Position Check. 3 seconds remaining."),
        (2, nil), (1, "Position Check. 1 second remaining.")
    ])
    func countdownMilestones(seconds: Int, expected: String?) {
        let feedback = policy.feedback(
            previous: presentation(status: .active, remainingSeconds: seconds + 1),
            current: presentation(status: .active, remainingSeconds: seconds)
        )

        #expect(feedback.announcement == expected)
        #expect(!feedback.playsAcceptanceHaptic)
    }

    @Test("Only materially changed rounded guidance is announced")
    func roundedGuidanceChanges() {
        let previous = presentation(
            status: .active,
            recovery: .guidance(course: "064°M", time: "~1:20", distance: "1.2 NM")
        )
        let unchanged = policy.feedback(previous: previous, current: previous)
        let changed = policy.feedback(
            previous: previous,
            current: presentation(
                status: .active,
                recovery: .guidance(course: "067°M", time: "~1:30", distance: "1.3 NM")
            )
        )

        #expect(unchanged.announcement == nil)
        #expect(changed.announcement == "Rejoin active leg. Suggested magnetic course 067°M. Rejoin in ~1:30.")
    }

    @Test("GPS loss and dismissal produce distinct announcements")
    func lossAndDismissal() {
        let active = presentation(status: .active, remainingSeconds: 7)
        let lost = presentation(status: .signalLost)

        #expect(policy.feedback(previous: active, current: lost).announcement == "GPS signal lost. Position and guidance cleared.")
        #expect(policy.feedback(previous: lost, current: presentation(status: .ready)).announcement == "Position Check dismissed.")
    }

    @Test("Control accessibility separates label, value, and action hint")
    func controlSemantics() {
        let ready = presentation(status: .ready)
        #expect(ready.accessibilityLabel == "Position Check, Ready")
        #expect(ready.accessibilityValue == "GPS Ready")
        #expect(ready.accessibilityHint.contains("Hold for approximately one second"))
        #expect(ready.accessibilityHint.contains("temporary GPS disclosure"))
    }

    private func presentation(
        status: PositionCheckPresentation.Status,
        remainingSeconds: Int? = nil,
        recovery: PositionCheckPresentation.Recovery? = nil
    ) -> PositionCheckPresentation {
        PositionCheckPresentation(
            status: status,
            statusLabel: status == .ready ? "READY" : status == .signalLost ? "GPS LOST" : "ACTIVE",
            title: "Position Check",
            detail: status == .ready ? "GPS Ready" : "Tap to end",
            explanation: "",
            remedy: status == .ready ? "Hold for approximately one second" : "Tap to end",
            systemImage: "location.fill",
            isHoldEligible: true,
            recovery: recovery,
            remainingSeconds: remainingSeconds
        )
    }
}
