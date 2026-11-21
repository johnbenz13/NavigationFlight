import SwiftUI

struct ObserveTabBarPlacement: ViewModifier {
    @Binding var placement: TabBarPlacement?
    @Environment(\.tabBarPlacement) private var currentPlacement

    func body(content: Content) -> some View {
        content.onChange(of: currentPlacement, initial: true) { _, current in
            placement = current
        }
    }
}
