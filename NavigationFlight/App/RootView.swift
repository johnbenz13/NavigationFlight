import SwiftUI

struct RootView: View {
    @State private var appState: AppFeatureState

    init() {
        let progressionPolicy: Flight.ProgressionPolicy
        var selectedAppSection = AppFeatureState.AppSection.flightPlans
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
            selectedAppSection = .cockpit
        }
#endif
        _appState = State(initialValue: AppFeatureState(
            selectedAppSection: selectedAppSection,
            cockpit: cockpit
        ))
    }

    var body: some View {
        TabView(selection: appSectionSelection) {
            Tab("Cockpit", systemImage: "airplane", value: AppFeatureState.AppSection.cockpit) {
                CockpitFeatureView(
                    state: Binding(
                        get: { appState.cockpit },
                        set: { appState.updateCockpit($0) }
                    ),
                    onIntent: { appState.handleCockpitIntent($0) }
                )
            }

            Tab("Flight Plans", systemImage: "folder", value: AppFeatureState.AppSection.flightPlans) {
                FlightPlansFeatureView(state: appState.flightPlans)
            }

            Tab("Settings", systemImage: "gearshape", value: AppFeatureState.AppSection.settings) {
                SettingsFeatureView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
    }

    private var appSectionSelection: Binding<AppFeatureState.AppSection> {
        Binding(
            get: { appState.selectedAppSection },
            set: { appState.selectAppSection($0) }
        )
    }
}
