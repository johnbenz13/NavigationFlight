import SwiftUI

struct FlightPlansFeatureView: View {
    let state: FlightPlansFeatureState

    @State private var navigationPath = NavigationPath()
    @State private var scrollPosition: UUID?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                ContentUnavailableView {
                    Label("No flight plans yet", systemImage: "folder")
                } description: {
                    Text("Add a prepared .fplnav plan from Navigation Editor. Saved Flight Plans remain available offline.")
                }
                .frame(maxWidth: .infinity)
                .containerRelativeFrame(.vertical)
                .accessibilityIdentifier("empty-flight-plans")
            }
            .scrollPosition(id: $scrollPosition)
            .navigationTitle("Flight Plans")
        }
    }
}
