import SwiftUI

struct RootView: View {
    @State private var appState: AppFeatureState
    private let flightPlanLibrary: FlightPlanLibrary
    private let flightPlanFileReader = FlightPlanFileReader()
    private let debugLibrarySeedData: [Data]
    private let debugImportData: Data?

    init() {
        let defaultLibraryDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appending(path: "FlightPlans", directoryHint: .isDirectory)
            ?? URL.temporaryDirectory.appending(path: "NavigationFlight-FlightPlans", directoryHint: .isDirectory)
        let libraryDirectory: URL
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let libraryID = environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] {
            libraryDirectory = URL.temporaryDirectory.appending(path: libraryID, directoryHint: .isDirectory)
        } else {
            libraryDirectory = defaultLibraryDirectory
        }
        let shouldFailStorage = environment["NAVIGATION_FLIGHT_UI_TEST_STORAGE_FAILURE"] == "1"
        debugLibrarySeedData = environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_PLANS"]?
            .split(separator: ",")
            .compactMap { Data(base64Encoded: String($0)) } ?? []
        debugImportData = environment["NAVIGATION_FLIGHT_UI_TEST_IMPORT_PLAN"]
            .flatMap { Data(base64Encoded: $0) }
#else
        libraryDirectory = defaultLibraryDirectory
        debugLibrarySeedData = []
        debugImportData = nil
#endif
        let store: any FlightPlanStore
#if DEBUG
        store = DiskFlightPlanStore(
            rootDirectory: libraryDirectory,
            beforeInstall: { _ in
                if shouldFailStorage {
                    throw FlightPlanStoreError.operationFailed(id: nil)
                }
            }
        )
#else
        store = DiskFlightPlanStore(rootDirectory: libraryDirectory)
#endif
        flightPlanLibrary = FlightPlanLibrary(
            store: store
        )
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
        if let encoded = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_LOADED_PLAN"],
           let data = Data(base64Encoded: encoded),
           let flightPlan = try? FPLNavDecoder().decode(data) {
            try? cockpit.accept(flightPlan)
            selectedAppSection = .flightPlans
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
                FlightPlansFeatureView(
                    state: Binding(
                        get: { appState.flightPlans },
                        set: { appState.updateFlightPlans($0) }
                    ),
                    library: flightPlanLibrary,
                    fileReader: flightPlanFileReader,
                    loadedFlightPlan: appState.cockpit.flightPlan,
                    debugSeedData: debugLibrarySeedData,
                    debugImportData: debugImportData
                )
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
