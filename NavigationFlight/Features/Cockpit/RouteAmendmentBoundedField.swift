import SwiftUI

struct RouteAmendmentBoundedField<Content: View>: View {
    @Binding var text: String
    let accepts: (String) -> Bool
    @ViewBuilder let content: (Binding<String>) -> Content

    @State private var displayedText = ""

    var body: some View {
        content($displayedText)
            .onChange(of: text, initial: true) { _, accepted in
                displayedText = accepted
            }
            .onChange(of: displayedText) { _, proposed in
                // The native field keeps a rejected edit until its displayed value is written back.
                if accepts(proposed) {
                    if text != proposed { text = proposed }
                } else {
                    displayedText = text
                }
            }
    }
}
