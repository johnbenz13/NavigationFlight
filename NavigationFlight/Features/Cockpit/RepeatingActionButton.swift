import SwiftUI

struct RepeatingActionButton<Label: View>: View {
    let action: () -> Void
    let onSequenceEnded: (Int) -> Void
    @ViewBuilder let label: () -> Label

    @State private var repeatTask: Task<Void, Never>?
    @State private var stepsPerformed = 0
    @State private var repeatedDuringCurrentPress = false

    init(
        action: @escaping () -> Void,
        onSequenceEnded: @escaping (Int) -> Void = { _ in },
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.action = action
        self.onSequenceEnded = onSequenceEnded
        self.label = label
    }

    var body: some View {
        Button {
            if !repeatedDuringCurrentPress {
                action()
                onSequenceEnded(1)
            }
            repeatedDuringCurrentPress = false
            stepsPerformed = 0
        } label: {
            label()
        }
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: 30,
            pressing: updatePressState,
            perform: {}
        )
        .onDisappear {
            repeatTask?.cancel()
            repeatTask = nil
        }
    }

    private func updatePressState(_ isPressing: Bool) {
        if isPressing {
            repeatedDuringCurrentPress = false
            stepsPerformed = 0
            repeatTask?.cancel()
            repeatTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(350))
                while !Task.isCancelled {
                    repeatedDuringCurrentPress = true
                    stepsPerformed += 1
                    action()
                    try? await Task.sleep(for: .milliseconds(100))
                }
            }
        } else {
            repeatTask?.cancel()
            repeatTask = nil
            if stepsPerformed > 0 {
                onSequenceEnded(stepsPerformed)
            }
        }
    }
}
