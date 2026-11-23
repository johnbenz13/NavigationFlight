import SwiftUI

struct CockpitReachAvailability: ViewModifier {
    let allowsReach: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if allowsReach { content }
    }
}
