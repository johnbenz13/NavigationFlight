import SwiftUI

struct AppTabEnvironment: ViewModifier {
    @Binding var placement: TabBarPlacement?
    let contentTextSize: DynamicTypeSize
    @Environment(\.tabBarPlacement) private var currentPlacement

    func body(content: Content) -> some View {
        content
            .environment(\.dynamicTypeSize, contentTextSize)
            .task(id: currentPlacement) {
                guard !Task.isCancelled, placement != currentPlacement else { return }
                placement = currentPlacement
            }
    }
}
