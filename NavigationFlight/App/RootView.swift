import SwiftUI

struct RootView: View {
    @State private var appState: AppFeatureState

    init() {
        let progressionPolicy: Flight.ProgressionPolicy
#if DEBUG
        progressionPolicy = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_PROGRESSION_POLICY"] == "manual"
            ? .manualNextLeg
            : .automaticNextLeg
#else
        progressionPolicy = .automaticNextLeg
#endif
        var cockpit = CockpitFeatureState(progressionPolicy: progressionPolicy)
#if DEBUG
        if let encoded = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_PLAN"],
           let data = Data(base64Encoded: encoded),
           let flightPlan = try? FPLNavDecoder().decode(data) {
            try? cockpit.accept(flightPlan)
        }
#endif
        _appState = State(initialValue: AppFeatureState(cockpit: cockpit))
    }

    var body: some View {
        CockpitFeatureView(state: Binding(
            get: { appState.cockpit },
            set: { appState.updateCockpit($0) }
        ))
    }
}
