import SwiftUI

struct RootView: View {
    @State private var appState: AppFeatureState
    @State private var idleTimerCoordinator: IdleTimerCoordinator
    @State private var flightRecordingCoordinator: FlightRecordingCoordinator
    @State private var flightRecoveryCoordinator: FlightRecoveryCoordinator
    private let flightPlanLibrary: FlightPlanLibrary
    private let flightRecordingLibrary: FlightRecordingLibrary
    private let flightPlanFileReader = FlightPlanFileReader()
    private let debugLibrarySeedData: [Data]
    private let debugImportData: Data?
    private let debugShouldFailFlightChange: Bool
    private let locationService: AircraftLocationService
    private let positionCheckTiming: PositionCheckTiming
    private let shouldPresentPositionCheckEducation: Bool
    private let shouldSimulateRecordingDegradation: Bool
    private let debugRecordingStatus: RecordingStatus?
    private let debugFlightsActiveRecordingID: UUID?

    init() {
        let defaultLibraryDirectory = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?.appending(path: "FlightPlans", directoryHint: .isDirectory)
            ?? URL.temporaryDirectory.appending(path: "NavigationFlight-FlightPlans", directoryHint: .isDirectory)
        let libraryDirectory: URL
        let recordingDirectory: URL
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if let libraryID = environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] {
            libraryDirectory = URL.temporaryDirectory.appending(path: libraryID, directoryHint: .isDirectory)
            recordingDirectory = URL.temporaryDirectory.appending(
                path: "\(libraryID)-recordings",
                directoryHint: .isDirectory
            )
        } else {
            libraryDirectory = defaultLibraryDirectory
            recordingDirectory = defaultLibraryDirectory.deletingLastPathComponent()
                .appending(path: "Flights", directoryHint: .isDirectory)
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
        shouldSimulateRecordingDegradation = environment["NAVIGATION_FLIGHT_UI_TEST_RECORDING_DEGRADATION"] == "1"
        debugRecordingStatus = switch environment["NAVIGATION_FLIGHT_UI_TEST_RECORDING_STATUS"] {
        case "gps-gap": .gpsGap
        case "gps-resumed": .gpsResumed
        case "recording": .recording
        case "partial": .partialRecording
        case "landed": .landedAwaitingStop
        case "corrected": .physicalPhaseCorrected
        case "low-storage": .recordingLowStorage
        case "closed-complete": .closedComplete
        case "closed-incomplete": .closedIncomplete
        default: nil
        }
        if let seconds = environment["NAVIGATION_FLIGHT_UI_TEST_POSITION_CHECK_DURATION"].flatMap(Double.init) {
            positionCheckTiming = PositionCheckTiming(
                acquisitionDuration: .seconds(seconds),
                disclosureDuration: .seconds(seconds)
            )
        } else {
            positionCheckTiming = .standard
        }
        if let fixtureName = environment["NAVIGATION_FLIGHT_UI_TEST_POSITION_CHECK_STATE"],
           let fixture = PositionCheckFixtureScenario(rawValue: fixtureName) {
            let delay = environment["NAVIGATION_FLIGHT_UI_TEST_POSITION_CHECK_FIXTURE_DELAY"]
                .flatMap(Double.init)
                .map(Duration.seconds) ?? .seconds(6)
            locationService = AircraftLocationService(
                source: PositionCheckFixtureSource(scenario: fixture, followUpDelay: delay)
            )
        } else {
            locationService = AircraftLocationService(source: CoreLocationAircraftLocationSource.shared)
        }
#else
        libraryDirectory = defaultLibraryDirectory
        recordingDirectory = defaultLibraryDirectory.deletingLastPathComponent()
            .appending(path: "Flights", directoryHint: .isDirectory)
        debugLibrarySeedData = []
        debugImportData = nil
        debugShouldFailFlightChange = false
        shouldPresentPositionCheckEducation = true
        shouldSimulateRecordingDegradation = false
        debugRecordingStatus = nil
        positionCheckTiming = .standard
        locationService = AircraftLocationService(source: CoreLocationAircraftLocationSource.shared)
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
            try? cockpit.accept(flightPlan, sourceData: data)
            selectedAppSection = .cockpit
        }
        if let encoded = ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_LOADED_PLAN"],
           let data = Data(base64Encoded: encoded),
           let flightPlan = try? FPLNavDecoder().decode(data) {
            try? cockpit.accept(flightPlan, sourceData: data)
            if ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_PROTECTED_FLIGHT"] == "1" {
                try? cockpit.startLeg(at: Date(timeIntervalSince1970: 1_000))
            }
            selectedAppSection = .flightPlans
        }
        if environment["NAVIGATION_FLIGHT_UI_TEST_INITIAL_SECTION"] == "flights" {
            selectedAppSection = .flights
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
        _idleTimerCoordinator = State(
            initialValue: IdleTimerCoordinator(controller: UIApplicationIdleTimerController())
        )
        let recordingStore: any FlightRecordingStore
#if DEBUG
        if let flightsState = environment["NAVIGATION_FLIGHT_UI_TEST_FLIGHTS_STATE"] {
            let fixture = Self.makeFlightsFixture(
                state: flightsState,
                sourceData: environment["NAVIGATION_FLIGHT_UI_TEST_PLAN"].flatMap {
                    Data(base64Encoded: $0)
                }
            )
            recordingStore = InMemoryFlightRecordingStore(
                failure: environment["NAVIGATION_FLIGHT_UI_TEST_DELETE_FAILURE"] == "1" ? .remove : nil,
                packageResults: fixture.packages
            )
            debugFlightsActiveRecordingID = fixture.activeRecordingID
        } else if let recoveryState = environment["NAVIGATION_FLIGHT_UI_TEST_RECOVERY_STATE"] {
            var packageResults: [FlightRecordingPackageResult] = []
            if recoveryState == "unsupported" {
                packageResults = [.unsupported(id: UUID(), schemaVersion: 99)]
            } else if recoveryState == "corrupt" {
                packageResults = [.corrupt(id: UUID())]
            } else if let encoded = environment["NAVIGATION_FLIGHT_UI_TEST_PLAN"],
                      let data = Data(base64Encoded: encoded),
                      let plan = try? FPLNavDecoder().decode(data),
                      let mode = plan.plannedNavigation.plannedNavigation?.defaultMode {
                let count = recoveryState == "multiple" ? 2 : 1
                packageResults = (0..<count).compactMap { index in
                    let startedAt = Date.now.addingTimeInterval(TimeInterval(-60 - (index * 60)))
                    let flight = Flight(
                        flightPlanID: plan.id,
                        legIDs: plan.legs.map(\.id),
                        activeLegIndex: 0,
                        executionMode: mode
                    )
                    guard let promotion = try? FlightRecording.promoteForStartLeg(
                        id: UUID(),
                        flightID: flight.id,
                        flightPlanSnapshot: RecordedFlightPlanSnapshot(
                            id: plan.id,
                            title: index == 0 ? plan.title : "Paphos local",
                            legIDs: plan.legs.map(\.id),
                            sourceData: data
                        ),
                        legID: plan.legs[0].id,
                        startedAt: startedAt,
                        eventIDs: [UUID(), UUID()]
                    ) else { return nil }
                    return .available(FlightRecordingReadSnapshot(
                        recording: promotion.recording,
                        events: promotion.events
                    ))
                }
            }
            recordingStore = InMemoryFlightRecordingStore(packageResults: packageResults)
            debugFlightsActiveRecordingID = nil
        } else if environment["NAVIGATION_FLIGHT_UI_TEST_RECORDING_FAILURE"] == "1" {
            recordingStore = InMemoryFlightRecordingStore(failure: .create)
            debugFlightsActiveRecordingID = nil
        } else {
            recordingStore = DiskFlightRecordingStore(rootDirectory: recordingDirectory)
            debugFlightsActiveRecordingID = nil
        }
#else
        recordingStore = DiskFlightRecordingStore(rootDirectory: recordingDirectory)
        debugFlightsActiveRecordingID = nil
#endif
        _flightRecordingCoordinator = State(
            initialValue: FlightRecordingCoordinator(
                store: recordingStore,
                supplementalSensorSource: CoreMotionSupplementalSensorSource.shared
            )
        )
        flightRecordingLibrary = FlightRecordingLibrary(store: recordingStore)
        let recoveryCoordinator = FlightRecoveryCoordinator(store: recordingStore)
#if DEBUG
        if environment["NAVIGATION_FLIGHT_UI_TEST_FLIGHTS_STATE"] != nil {
            recoveryCoordinator.dismissUnavailableRecovery()
        }
#endif
        _flightRecoveryCoordinator = State(initialValue: recoveryCoordinator)
    }

    var body: some View {
        Group {
            if flightRecoveryCoordinator.state == .none {
                appShell
            } else {
                FlightRecoveryView(
                    state: flightRecoveryCoordinator.state,
                    onContinue: continueRecoveredFlight,
                    onEndIncomplete: endRecoveredFlightAsIncomplete,
                    onEndAll: endAllRecoveredFlightsAsIncomplete,
                    onDismissUnavailable: flightRecoveryCoordinator.dismissUnavailableRecovery
                )
            }
        }
        .task {
            if flightRecoveryCoordinator.state == .loading {
                await flightRecoveryCoordinator.bootstrap()
            }
        }
    }

    private var appShell: some View {
        TabView(selection: appSectionSelection) {
            Tab("Cockpit", systemImage: "airplane", value: AppFeatureState.AppSection.cockpit) {
                CockpitFeatureView(
                    state: Binding(
                        get: { appState.cockpit },
                        set: { appState.updateCockpit($0) }
                    ),
                    presentationRequestID: appState.cockpitPresentationRequestID,
                    locationService: locationService,
                    positionCheckTiming: positionCheckTiming,
                    isSectionSelected: appState.selectedAppSection == .cockpit,
                    recordingCoordinator: flightRecordingCoordinator,
                    shouldSimulateRecordingDegradation: shouldSimulateRecordingDegradation,
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

            Tab("Flights", systemImage: "clock.arrow.circlepath", value: AppFeatureState.AppSection.flights) {
                FlightsFeatureView(
                    state: Binding(
                        get: { appState.flights },
                        set: { appState.updateFlights($0) }
                    ),
                    library: flightRecordingLibrary,
                    activeRecordingID: flightRecordingCoordinator.activeRecordingID ?? debugFlightsActiveRecordingID,
                    onContinue: continueFlightFromLibrary,
                    exporter: ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_EXPORT_FAILURE"] == "1"
                        ? GPXExporter(temporaryDirectory: URL(fileURLWithPath: "/dev/null"))
                        : GPXExporter()
                )
            }

            Tab("Settings", systemImage: "gearshape", value: AppFeatureState.AppSection.settings) {
                SettingsFeatureView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .onAppear {
            synchronizeIdleTimer()
        }
        .onChange(of: appState.cockpit.isAcceptedFlightInProgress) { _, _ in
            synchronizeIdleTimer()
        }
        .task(id: appState.cockpit.flight?.id) {
            guard let flight = appState.cockpit.flight,
                  let flightPlan = appState.cockpit.flightPlan else {
                await flightRecordingCoordinator.disarm(locationHub: locationService)
                return
            }
            await flightRecordingCoordinator.arm(
                flight: flight,
                flightPlanSnapshot: RecordedFlightPlanSnapshot(
                    id: flightPlan.id,
                    title: flightPlan.title,
                    legIDs: flightPlan.legs.map(\.id),
                    sourceData: appState.cockpit.flightPlanSourceData
                ),
                locationHub: locationService
            )
#if DEBUG
            if let debugRecordingStatus {
                flightRecordingCoordinator.overrideStatusForTesting(debugRecordingStatus)
            }
#endif
        }
        .onDisappear {
            idleTimerCoordinator.teardown()
        }
        .alert(flightChangeConfirmationTitle, isPresented: flightChangeConfirmationPresented) {
            Button(flightChangeConfirmationAction, role: .destructive) {
                guard let id = appState.pendingFlightChange?.id else { return }
                Task {
                    do {
                        try await flightRecordingCoordinator.prepareForFlightReplacement(
                            at: .now,
                            eventIDs: [UUID(), UUID()]
                        )
                        if appState.confirmPendingFlightChange(id: id), shouldPresentPositionCheckEducation {
                            appState.presentPositionCheckPermissionEducation()
                        }
                    } catch {
                        appState.cancelPendingFlightChange(id: id)
                        var flightPlans = appState.flightPlans
                        flightPlans.presentFlightChangeFailure()
                        appState.updateFlightPlans(flightPlans)
                    }
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

    private func continueRecoveredFlight(id: UUID) {
        Task {
            do {
                let timestamp = Date.now
                let recovered = try await flightRecoveryCoordinator.continueFlight(
                    id: id,
                    at: timestamp,
                    elapsed: flightRecoveryCoordinator.rebasedElapsed(for: id),
                    eventID: UUID()
                )
                await flightRecordingCoordinator.restore(recovered)
                appState.restoreRecoveredFlight(
                    recovered,
                    sourceData: recovered.recording.flightPlanSnapshot.sourceData
                )
            } catch {
                await flightRecoveryCoordinator.bootstrap()
            }
        }
    }

    private func continueFlightFromLibrary(id: UUID) {
        if flightRecordingCoordinator.activeRecordingID == id || debugFlightsActiveRecordingID == id {
            appState.returnToCockpit()
        } else {
            continueRecoveredFlight(id: id)
        }
    }

#if DEBUG
    private static func makeFlightsFixture(
        state: String,
        sourceData: Data?
    ) -> (packages: [FlightRecordingPackageResult], activeRecordingID: UUID?) {
        guard state == "populated",
              let sourceData,
              let plan = try? FPLNavDecoder().decode(sourceData),
              let legID = plan.legs.first?.id else {
            return ([], nil)
        }
        let baseDate = Date(timeIntervalSince1970: 1_794_000_000)
        let definitions: [(
            id: UUID,
            title: String,
            startOffset: TimeInterval,
            closure: FlightRecordingClosure?,
            coverage: GPSCoverageState,
            size: Int64
        )] = [
            (
                UUID(uuid: (1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)),
                "Herzliya Coastal Navigation",
                0,
                nil,
                .available,
                4_800_000
            ),
            (
                UUID(uuid: (2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)),
                "Recovery Practice",
                -600,
                nil,
                .partial,
                3_600_000
            ),
            (
                UUID(uuid: (3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3)),
                "Jerusalem Corridor Practice",
                -86_400,
                FlightRecordingClosure(
                    outcome: .complete,
                    cause: .automatic,
                    closedAt: baseDate.addingTimeInterval(-82_440),
                    elapsed: .seconds(3_960),
                    landingEvidenceAvailable: true
                ),
                .available,
                4_100_000
            ),
            (
                UUID(uuid: (4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4)),
                "Northern Hills Training",
                -172_800,
                FlightRecordingClosure(
                    outcome: .incomplete,
                    cause: .automatic,
                    closedAt: baseDate.addingTimeInterval(-169_920),
                    elapsed: .seconds(2_880),
                    landingEvidenceAvailable: true
                ),
                .partial,
                2_700_000
            ),
            (
                UUID(uuid: (5, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 5)),
                "Action-only Training",
                -259_200,
                FlightRecordingClosure(
                    outcome: .incomplete,
                    cause: .manual,
                    closedAt: baseDate.addingTimeInterval(-257_400),
                    elapsed: .seconds(1_800),
                    landingEvidenceAvailable: false
                ),
                .unavailable,
                900_000
            ),
        ]
        let packages = definitions.compactMap { definition -> FlightRecordingPackageResult? in
            let startedAt = baseDate.addingTimeInterval(definition.startOffset)
            guard let promotion = try? FlightRecording.promoteForStartLeg(
                id: definition.id,
                flightID: UUID(),
                flightPlanSnapshot: RecordedFlightPlanSnapshot(
                    id: plan.id,
                    title: definition.title,
                    legIDs: plan.legs.map(\.id),
                    sourceData: sourceData
                ),
                legID: legID,
                startedAt: startedAt,
                eventIDs: [UUID(), UUID()]
            ) else { return nil }
            var recording = promotion.recording.restoring(gpsCoverage: definition.coverage)
            if let closure = definition.closure {
                recording = recording.restoring(closure: closure)
            }
            let evidenceEnd = definition.closure?.closedAt ?? startedAt.addingTimeInterval(3_600)
            let firstSegmentID = UUID()
            let firstSegment = RecordedTrackSegment(id: firstSegmentID, samples: [
                RecordedTrackSample(
                    coordinate: WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.8),
                    observedAt: startedAt,
                    horizontalAccuracyMeters: 5,
                    altitudeMeters: 500,
                    verticalAccuracyMeters: 5,
                    groundSpeedMetersPerSecond: 42,
                    speedAccuracyMetersPerSecond: 1,
                    courseDegrees: 90,
                    courseAccuracyDegrees: 2,
                    barometricAltitudeMeters: definition.title == "Jerusalem Corridor Practice" ? 490 : nil,
                    deviceHeadingDegrees: definition.title == "Jerusalem Corridor Practice" ? 88 : nil,
                    deviceHeadingAccuracyDegrees: definition.title == "Jerusalem Corridor Practice" ? 3 : nil
                ),
                RecordedTrackSample(
                    coordinate: WGS84Coordinate(latitudeDegrees: 32.1, longitudeDegrees: 34.9),
                    observedAt: evidenceEnd,
                    horizontalAccuracyMeters: 5,
                    altitudeMeters: 1_280,
                    verticalAccuracyMeters: 5,
                    groundSpeedMetersPerSecond: 44,
                    speedAccuracyMetersPerSecond: 1,
                    courseDegrees: 90,
                    courseAccuracyDegrees: 2,
                    barometricAltitudeMeters: definition.title == "Jerusalem Corridor Practice" ? 1_270 : nil,
                    deviceHeadingDegrees: definition.title == "Jerusalem Corridor Practice" ? 92 : nil,
                    deviceHeadingAccuracyDegrees: definition.title == "Jerusalem Corridor Practice" ? 3 : nil
                ),
            ])
            let trackSegments = definition.coverage == .unavailable ? [] : [firstSegment]
            return .available(FlightRecordingReadSnapshot(
                recording: recording,
                events: promotion.events,
                trackSegments: trackSegments,
                approximateSizeBytes: definition.size
            ))
        } + [
            .corrupt(id: UUID(uuid: (6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6))),
        ]
        return (packages, definitions.first?.id)
    }
#endif

    private func endRecoveredFlightAsIncomplete(id: UUID) {
        Task {
            let timestamp = Date.now
            do {
                try await flightRecoveryCoordinator.endAsIncomplete(
                    id: id,
                    at: timestamp,
                    elapsed: flightRecoveryCoordinator.rebasedElapsed(for: id),
                    eventIDs: [UUID(), UUID()]
                )
            } catch {
                await flightRecoveryCoordinator.bootstrap()
            }
        }
    }

    private func endAllRecoveredFlightsAsIncomplete() {
        Task {
            do {
                try await flightRecoveryCoordinator.endAllAsIncomplete()
            } catch {
                await flightRecoveryCoordinator.bootstrap()
            }
        }
    }

    private var appSectionSelection: Binding<AppFeatureState.AppSection> {
        Binding(
            get: { appState.selectedAppSection },
            set: { appState.selectAppSection($0) }
        )
    }

    private func synchronizeIdleTimer() {
        idleTimerCoordinator.synchronize(
            isAcceptedFlightInProgress: appState.cockpit.isAcceptedFlightInProgress
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
