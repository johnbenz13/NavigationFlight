import SwiftUI

struct RepeatingActionButton<Label: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Label

    @State private var pressStartedAt: Date?
    @State private var actionCount = 1

    var body: some View {
        Button {
            for _ in 0..<actionCount {
                action()
            }
            pressStartedAt = nil
            actionCount = 1
        } label: {
            label()
        }
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: 30,
            pressing: updatePressState,
            perform: {}
        )
    }

    private func updatePressState(_ isPressing: Bool) {
        if isPressing {
            pressStartedAt = .now
            actionCount = 1
        } else if let pressStartedAt {
            let heldDuration = Date.now.timeIntervalSince(pressStartedAt)
            if heldDuration >= 0.35 {
                actionCount = 1 + Int((heldDuration - 0.35) / 0.1)
            }
        }
    }
}
