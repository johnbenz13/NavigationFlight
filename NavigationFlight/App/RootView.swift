import SwiftUI

struct RootView: View {
    @State private var appState: AppFeatureState
    private let flightPlanLibrary: FlightPlanLibrary
    private let flightPlanFileReader = FlightPlanFileReader()
    private let debugLibrarySeedData: [Data]
    private let debugImportData: Data?
    private let debugShouldFailFlightChange: Bool
    private let locationService: AircraftLocationService
    private let shouldPresentPositionCheckEducation: Bool

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
        let shouldFailRemoval = environment["NAVIGATION_FLIGHT_UI_TEST_REMOVAL_FAILURE"] == "1"
        debugLibrarySeedData = environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_PLANS"]?
            .split(separator: ",")
            .compactMap { Data(base64Encoded: String($0)) } ?? []
        debugImportData = environment["NAVIGATION_FLIGHT_UI_TEST_IMPORT_PLAN"]
            .flatMap { Data(base64Encoded: $0) }
        debugShouldFailFlightChange = environment["NAVIGATION_FLIGHT_UI_TEST_FLIGHT_CHANGE_FAILURE"] == "1"
        shouldPresentPositionCheckEducation = environment["NAVIGATION_FLIGHT_UI_TEST_POSITION_CHECK_EDUCATION"] == "1"
        if let fixture = environment["NAVIGATION_FLIGHT_UI_TEST_POSITION_CHECK_STATE"] {
            locationService = AircraftLocationService(source: FixtureAircraftLocationSource.make(state: fixture))
        } else {
            locationService = AircraftLocationService(source: CoreLocationAircraftLocationSource())
        }
#else
        libraryDirectory = defaultLibraryDirectory
        debugLibrarySeedData = []
        debugImportData = nil
        debugShouldFailFlightChange = false
        shouldPresentPositionCheckEducation = true
        locationService = AircraftLocationService(source: CoreLocationAircraftLocationSource())
#endif
        let store: any FlightPlanStore
#if DEBUG
        store = DiskFlightPlanStore(
            rootDirectory: libraryDirectory,
            beforeInstall: { _ in
                if shouldFailStorage {
                    throw FlightPlanStoreError.operationFailed(id: nil)
                }
            },
            beforeRemove: { id in
                if shouldFailRemoval {
                    throw FlightPlanStoreError.operationFailed(id: id)
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
            if ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_PROTECTED_FLIGHT"] == "1" {
                try? cockpit.startLeg(at: Date(timeIntervalSince1970: 1_000))
            }
            selectedAppSection = .flightPlans
        }
#endif
        var initialAppState = AppFeatureState(
            selectedAppSection: selectedAppSection,
            cockpit: cockpit
        )
        if shouldPresentPositionCheckEducation, cockpit.flight != nil {
            initialAppState.presentPositionCheckPermissionEducation()
        }
        _appState = State(initialValue: initialAppState)
    }

    var body: some View {
        TabView(selection: appSectionSelection) {
            Tab("Cockpit", systemImage: "airplane", value: AppFeatureState.AppSection.cockpit) {
                CockpitFeatureView(
                    state: Binding(
                        get: { appState.cockpit },
                        set: { appState.updateCockpit($0) }
                    ),
                    presentationRequestID: appState.cockpitPresentationRequestID,
                    locationService: locationService,
                    isSectionSelected: appState.selectedAppSection == .cockpit,
                    onIntent: handleCockpitIntent
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
                    debugImportData: debugImportData,
                    onIntent: handleFlightPlansIntent
                )
            }

            Tab("Settings", systemImage: "gearshape", value: AppFeatureState.AppSection.settings) {
                SettingsFeatureView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .alert(flightChangeConfirmationTitle, isPresented: flightChangeConfirmationPresented) {
            Button(flightChangeConfirmationAction, role: .destructive) {
                guard let id = appState.pendingFlightChange?.id else { return }
                if appState.confirmPendingFlightChange(id: id), shouldPresentPositionCheckEducation {
                    appState.presentPositionCheckPermissionEducation()
                }
            }
            Button("Cancel", role: .cancel) {
                guard let id = appState.pendingFlightChange?.id else { return }
                appState.cancelPendingFlightChange(id: id)
            }
        } message: {
            Text(flightChangeConfirmationMessage)
        }
        .alert("Couldn’t load this Flight Plan", isPresented: flightChangeFailurePresented) {
            Button("Done") {
                var flightPlans = appState.flightPlans
                flightPlans.dismissPresentation()
                appState.updateFlightPlans(flightPlans)
            }
        } message: {
            Text("The current Flight and this inspection are unchanged.")
        }
        .fullScreenCover(isPresented: positionCheckEducationPresented) {
            PositionCheckPermissionEducationView(onIntent: handlePositionCheckPermissionIntent)
        }
    }

    private var appSectionSelection: Binding<AppFeatureState.AppSection> {
        Binding(
            get: { appState.selectedAppSection },
            set: { appState.selectAppSection($0) }
        )
    }

    private func handleFlightPlansIntent(_ intent: FlightPlansFeatureIntent) {
        if debugShouldFailFlightChange, intent != .returnToCockpit {
            var flightPlans = appState.flightPlans
            flightPlans.presentFlightChangeFailure()
            appState.updateFlightPlans(flightPlans)
            return
        }

        do {
            switch intent {
            case .loadInCockpit(let record):
                let decision = try appState.loadFlightPlan(record, flightID: UUID())
                presentPositionCheckEducationIfLoaded(decision)
            case .returnToCockpit:
                appState.returnToCockpit()
            case .loadUpdatedPlan(let record):
                let decision = try appState.loadUpdatedFlightPlan(record, flightID: UUID())
                presentPositionCheckEducationIfLoaded(decision)
            case .restartFlight:
                _ = try appState.restartFlight(flightID: UUID())
            }
        } catch {
            var flightPlans = appState.flightPlans
            flightPlans.presentFlightChangeFailure()
            appState.updateFlightPlans(flightPlans)
        }
    }

    private func handleCockpitIntent(_ intent: CockpitFeatureIntent) {
        switch intent {
        case .chooseFlightPlan:
            appState.chooseFlightPlanFromCockpit()
        case .restartFlight:
            do {
                _ = try appState.restartFlight(flightID: UUID())
            } catch {
                var flightPlans = appState.flightPlans
                flightPlans.presentFlightChangeFailure()
                appState.updateFlightPlans(flightPlans)
            }
        }
    }

    private var positionCheckEducationPresented: Binding<Bool> {
        Binding(
            get: { appState.positionCheckPermissionEducation == .presented },
            set: { _ in }
        )
    }

    private func presentPositionCheckEducationIfLoaded(_ decision: LoadFlightPlanDecision) {
        guard shouldPresentPositionCheckEducation, decision == .loaded else { return }
        appState.presentPositionCheckPermissionEducation()
    }

    private func handlePositionCheckPermissionIntent(_ intent: PositionCheckPermissionIntent) {
        guard let effect = appState.handlePositionCheckPermissionIntent(intent) else { return }
        switch effect {
        case .requestWhenInUseAuthorization:
            Task { await locationService.requestWhenInUseAuthorization() }
        case .openSystemSettings:
            break
        }
    }

    private var flightChangeConfirmationPresented: Binding<Bool> {
        Binding(
            get: { appState.pendingFlightChange != nil },
            set: { _ in }
        )
    }

    private var flightChangeConfirmationTitle: String {
        appState.pendingFlightChange?.kind == .restart
            ? "Restart this Flight?"
            : "End current Flight?"
    }

    private var flightChangeFailurePresented: Binding<Bool> {
        Binding(
            get: { appState.flightPlans.presentation == .flightChangeFailure },
            set: { _ in }
        )
    }

    private var flightChangeConfirmationAction: String {
        appState.pendingFlightChange?.kind == .restart ? "Restart" : "End & Load"
    }

    private var flightChangeConfirmationMessage: String {
        appState.pendingFlightChange?.kind == .restart
            ? "Recorded progress and pilot edits will be discarded."
            : "Loading this Flight Plan ends the current Flight and discards recorded progress and pilot edits."
    }
}
