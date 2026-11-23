import SwiftUI
#if DEBUG
import os
#endif

struct RootView: View {
    private let settingsController: SettingsController
    @State private var appState: AppFeatureState
    @State private var tabBarPlacement: TabBarPlacement?
    @State private var moreDestination = MoreDestination.root
    private let chartUpdates: AIPChartUpdates
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    private let chartSnapshotStore: ChartSnapshotStore
    @State private var chartSnapshot: ChartSnapshot?
    @State private var hasLoadedChartSnapshot = false
#if DEBUG && targetEnvironment(simulator)
    @State private var installedChartFixtureEdition: String?
#endif

    private var chartCatalog: ChartCatalog? { chartSnapshot?.catalog }
    private var chartResources: ChartResources { chartSnapshot?.resources ?? .bundled }
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

    init(settingsController: SettingsController, chartSnapshotStore: ChartSnapshotStore, chartUpdates: AIPChartUpdates) {
        self.settingsController = settingsController
        self.chartSnapshotStore = chartSnapshotStore
        self.chartUpdates = chartUpdates
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
#if targetEnvironment(simulator)
        if environment["NAVIGATION_FLIGHT_UI_TEST_INITIAL_SECTION"] == "downloads",
           environment["NAVIGATION_FLIGHT_UI_TEST_DOWNLOADS"] != nil,
           environment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] != nil {
            selectedAppSection = .settings
            _moreDestination = State(initialValue: .downloads)
        }
#endif
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
                failReadOnCall: environment["NAVIGATION_FLIGHT_UI_TEST_EXPORT_PREPARATION_FAILURE"] == "1"
                    ? 2
                    : nil,
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
                      plan.plannedNavigation.plannedNavigation != nil {
                let count = recoveryState == "multiple" ? 2 : 1
                packageResults = (0..<count).compactMap { index in
                    let startedAt = Date.now.addingTimeInterval(TimeInterval(-60 - (index * 60)))
                    let flight = Flight(
                        flightPlanID: plan.id,
                        legIDs: plan.legs.map(\.id),
                        activeLegIndex: 0,
                        executionMode: .noWind
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
                    if recoveryState == "invalid-amendment" {
                        return Self.makeUnavailableAmendmentFixture(
                            plan: plan, sourceData: data, promotion: promotion
                        )
                    }
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
            let routeSaveAttempts = OSAllocatedUnfairLock(initialState: 0)
            let routeManagementFailure = OSAllocatedUnfairLock(initialState:
                environment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_MANAGEMENT_FAILURE"] == "1"
            )
            let amendmentFixture = environment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_CONFIRMATION"] == "1"
            recordingStore = DiskFlightRecordingStore(rootDirectory: recordingDirectory, beforeAppend: { event in
                if amendmentFixture, case .pendingRouteAmendmentConfirmed = event.payload {
                    let first = routeSaveAttempts.withLock { count in
                        count += 1
                        return count == 1
                    }
                    if first {
                        Thread.sleep(forTimeInterval: 3)
                        throw FlightRecordingStoreError.operationFailed(id: nil)
                    }
                }
                if case .pendingRouteAmendmentCancelled = event.payload, routeManagementFailure.withLock({ fail in
                    defer { fail = false }
                    return fail
                }) {
                    throw FlightRecordingStoreError.operationFailed(id: nil)
                }
                if ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_PRESENTATION_FAILURE"] == "1",
                   event.payload == .cockpitPresentationChanged {
                    throw FlightRecordingStoreError.operationFailed(id: nil)
                }
            })
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
            if !settingsController.isReady || !hasLoadedChartSnapshot {
                ProgressView("Loading…")
            } else if flightRecoveryCoordinator.state == .none {
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
        .onChange(of: appState.cockpit.recordingCockpitContext) { _, context in
            guard let context else { return }
            Task { await flightRecordingCoordinator.recordPresentation(context) }
        }
        .task {
#if DEBUG && targetEnvironment(simulator)
            if ChartSnapshotUITestFixture.blocksNetwork {
                do {
                    try await ChartSnapshotUITestFixture.verifyNetworkIsBlocked()
                } catch {
                    preconditionFailure("Chart test HTTP isolation failed: \(error)")
                }
            }
            if ChartSnapshotUITestFixture.isEnabled, installedChartFixtureEdition == nil {
                await installChartFixture("A")
            }
#endif
            let snapshot = await chartSnapshotStore.currentSnapshot()
            guard !Task.isCancelled else { return }
            updateChartSnapshot(snapshot)
            chartUpdates.observeInstalled(snapshot)
            hasLoadedChartSnapshot = true
            chartUpdates.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active && hasLoadedChartSnapshot { chartUpdates.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            chartUpdates.cancel()
        }
#if DEBUG && targetEnvironment(simulator)
        .task(id: scenePhase) {
            if scenePhase == .active, installedChartFixtureEdition == "A",
               appState.chartLibrary.presentedChartID != nil {
                await installChartFixture("B")
            }
        }
#endif
        .task {
            await settingsController.bootstrap()
            if flightRecoveryCoordinator.state == .loading {
                await flightRecoveryCoordinator.bootstrap()
            }
        }
    }

    private var appShell: some View {
        TabView(selection: appSectionSelection) {
            Tab(value: AppFeatureState.AppSection.cockpit) {
                CockpitFeatureView(
                    state: Binding(
                        get: { appState.cockpit },
                        set: { appState.updateCockpit($0) }
                    ),
                    locationService: locationService,
                    positionCheckTiming: positionCheckTiming,
                    isSectionSelected: appState.selectedAppSection == .cockpit,
                    recordingCoordinator: flightRecordingCoordinator,
                    checklistSelection: { settingsController.preferences.startChecklist },
                    amendmentMode: { settingsController.preferences.routeAmendmentMode },
                    chartCatalog: chartCatalog,
                    chartResources: chartResources,
                    shouldSimulateRecordingDegradation: shouldSimulateRecordingDegradation,
                    onIntent: handleCockpitIntent
                )
                .modifier(AppTabEnvironment(placement: $tabBarPlacement, contentTextSize: dynamicTypeSize))
            } label: {
                cockpitTabLabel
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
                .modifier(AppTabEnvironment(placement: $tabBarPlacement, contentTextSize: dynamicTypeSize))
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
                        : GPXExporter(
                            preparationDelay: ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_EXPORT_DELAY"] == "1"
                                ? .seconds(5)
                                : .zero
                        ),
                    diagnosticExporter: ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_EXPORT_FAILURE"] == "1"
                        ? DiagnosticBundleExporter(temporaryDirectory: URL(fileURLWithPath: "/dev/null"))
                        : DiagnosticBundleExporter(
                            preparationDelay: ProcessInfo.processInfo.environment["NAVIGATION_FLIGHT_UI_TEST_EXPORT_DELAY"] == "1"
                                ? .seconds(5)
                                : .zero
                        )
                )
                .modifier(AppTabEnvironment(placement: $tabBarPlacement, contentTextSize: dynamicTypeSize))
            }

            Tab("Charts", systemImage: "document", value: AppFeatureState.AppSection.charts) {
                ChartLibraryView(
                    catalog: chartCatalog,
                    state: $appState.chartLibrary,
                    onUpdate: chartUpdates.offer == nil ? nil : { openMore(.downloads) }
                )
                    .modifier(AppTabEnvironment(placement: $tabBarPlacement, contentTextSize: dynamicTypeSize))
            }

            Tab("More", systemImage: "ellipsis", value: AppFeatureState.AppSection.settings) {
                Group {
                    switch moreDestination {
                    case .root:
                        MoreSectionsView(hasUpdate: chartUpdates.offer != nil) {
                            moreDestination = .downloads
                        } onSettings: {
                            moreDestination = .settings
                        }
                    case .downloads:
                        AIPDownloadsView(updates: chartUpdates) {
                            moreDestination = .root
                        } onOpenCharts: {
                            appState.selectAppSection(.charts)
                        }
                    case .settings:
                        SettingsFeatureView(controller: settingsController, onBackToMore: { moreDestination = .root })
                    }
                }
                .modifier(AppTabEnvironment(placement: $tabBarPlacement, contentTextSize: dynamicTypeSize))
            }
            .badge(chartUpdates.offer == nil ? nil : Text(verbatim: "•"))
        }
        .tabViewStyle(.sidebarAdaptable)
        .defaultAdaptableTabBarPlacement(dynamicTypeSize.isAccessibilitySize ? .sidebar : .automatic)
        .dynamicTypeSize(tabBarTextSize)
        .fullScreenCover(item: chartSelection, onDismiss: {
            appState.chartLibrary.didDismissChart()
        }) { presentation in
            ChartViewer(
                selection: presentation.selection,
                catalog: presentation.snapshot.catalog,
                resources: presentation.snapshot.resources
            ) {
                appState.chartLibrary.presentedChartID = nil
            }
#if DEBUG && targetEnvironment(simulator)
            .environment(\.installedChartFixtureEdition, installedChartFixtureEdition)
#endif
        }
        .task(id: appState.selectedAppSection) {
            guard appState.selectedAppSection == .charts else { return }
            let snapshot = await chartSnapshotStore.currentSnapshot()
            guard !Task.isCancelled, appState.selectedAppSection == .charts,
                  appState.chartLibrary.presentedChartID == nil else { return }
            updateChartSnapshot(snapshot)
            chartUpdates.observeInstalled(snapshot)
        }
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
                locationHub: locationService,
                context: appState.cockpit.recordingCockpitContext
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
        let debriefHasNoPosition = ProcessInfo.processInfo.environment[
            "NAVIGATION_FLIGHT_UI_TEST_DEBRIEF_NO_POSITION"
        ] == "1"
        let usesShortDebrief = ProcessInfo.processInfo.environment[
            "NAVIGATION_FLIGHT_UI_TEST_SHORT_DEBRIEF"
        ] == "1"
        let usesUnreliableCourse = ProcessInfo.processInfo.environment[
            "NAVIGATION_FLIGHT_UI_TEST_UNRELIABLE_COURSE"
        ] == "1"
        let completedFlightDuration = usesShortDebrief
            ? 1
            : DebriefQAFlightTrack.duration(for: plan.title) ?? 3_960
        let completedRecordingID = UUID(
            uuid: (3, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3)
        )
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
                completedRecordingID,
                plan.title,
                -86_400,
                FlightRecordingClosure(
                    outcome: .complete,
                    cause: .automatic,
                    closedAt: baseDate.addingTimeInterval(-86_400 + completedFlightDuration),
                    elapsed: .seconds(completedFlightDuration),
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
            let isCompletedFixture = definition.id == completedRecordingID
            let realDebriefSamples = DebriefQAFlightTrack.samples(
                startedAt: startedAt,
                planTitle: plan.title
            )
            let samples = if isCompletedFixture, let realDebriefSamples {
                usesUnreliableCourse ? Self.withUnreliableCourse(realDebriefSamples) : realDebriefSamples
            } else {
                [
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
                        barometricAltitudeMeters: isCompletedFixture ? 490 : nil,
                        deviceHeadingDegrees: isCompletedFixture ? 88 : nil,
                        deviceHeadingAccuracyDegrees: isCompletedFixture ? 3 : nil
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
                        barometricAltitudeMeters: isCompletedFixture ? 1_270 : nil,
                        deviceHeadingDegrees: isCompletedFixture ? 92 : nil,
                        deviceHeadingAccuracyDegrees: isCompletedFixture ? 3 : nil
                    ),
                ]
            }
            let trackSegments: [RecordedTrackSegment]
            if definition.coverage == .unavailable || (isCompletedFixture && debriefHasNoPosition) {
                trackSegments = []
            } else if definition.coverage == .partial, samples.count > 1 {
                trackSegments = [
                    RecordedTrackSegment(id: UUID(), samples: [samples[0]]),
                    RecordedTrackSegment(id: UUID(), samples: [samples[samples.count - 1]]),
                ]
            } else {
                trackSegments = [RecordedTrackSegment(id: UUID(), samples: samples)]
            }
            let reviewBounds = samples.dropFirst().reduce(
                into: (
                    minimumLatitude: samples[0].coordinate.latitudeDegrees,
                    maximumLatitude: samples[0].coordinate.latitudeDegrees,
                    minimumLongitude: samples[0].coordinate.longitudeDegrees,
                    maximumLongitude: samples[0].coordinate.longitudeDegrees
                )
            ) { bounds, sample in
                bounds.minimumLatitude = min(bounds.minimumLatitude, sample.coordinate.latitudeDegrees)
                bounds.maximumLatitude = max(bounds.maximumLatitude, sample.coordinate.latitudeDegrees)
                bounds.minimumLongitude = min(bounds.minimumLongitude, sample.coordinate.longitudeDegrees)
                bounds.maximumLongitude = max(bounds.maximumLongitude, sample.coordinate.longitudeDegrees)
            }
            let reviewEventCoordinate = WGS84Coordinate(
                latitudeDegrees: (reviewBounds.minimumLatitude + reviewBounds.maximumLatitude) / 2,
                longitudeDegrees: (reviewBounds.minimumLongitude + reviewBounds.maximumLongitude) / 2
            )
            let reviewEventDate = startedAt.addingTimeInterval(completedFlightDuration / 2)
            let events = if isCompletedFixture {
                promotion.events + [
                    RecordedFlightEvent(
                        id: UUID(uuid: (7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7)),
                        sequence: 2,
                        occurredAt: startedAt.addingTimeInterval(completedFlightDuration / 2),
                        elapsed: .seconds(completedFlightDuration / 2),
                        origin: .pilot,
                        payload: .positionCheckEnded(
                            outcome: .disclosed(
                                sample: .init(
                                    coordinate: reviewEventCoordinate,
                                    observedAt: reviewEventDate,
                                    horizontalAccuracyMeters: 5
                                )
                            )
                        )
                    ),
                ]
            } else {
                promotion.events
            }
            return .available(FlightRecordingReadSnapshot(
                recording: recording,
                events: events,
                trackSegments: trackSegments,
                approximateSizeBytes: definition.size
            ))
        } + [
            .unsupported(
                id: UUID(uuid: (7, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 7)),
                schemaVersion: 99
            ),
            .corrupt(id: UUID(uuid: (6, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 6))),
        ]
        return (packages, definitions.first?.id)
    }

    private static func withUnreliableCourse(_ samples: [RecordedTrackSample]) -> [RecordedTrackSample] {
        samples.enumerated().map { index, sample in
            RecordedTrackSample(
                coordinate: sample.coordinate,
                observedAt: sample.observedAt,
                horizontalAccuracyMeters: sample.horizontalAccuracyMeters,
                altitudeMeters: sample.altitudeMeters,
                verticalAccuracyMeters: sample.verticalAccuracyMeters,
                groundSpeedMetersPerSecond: index == 0 ? 40 : 0.5,
                speedAccuracyMetersPerSecond: sample.speedAccuracyMetersPerSecond,
                courseDegrees: index == 0 ? 87 : nil,
                courseAccuracyDegrees: index == 0 ? 3 : nil,
                barometricAltitudeMeters: sample.barometricAltitudeMeters,
                deviceHeadingDegrees: sample.deviceHeadingDegrees,
                deviceHeadingAccuracyDegrees: sample.deviceHeadingAccuracyDegrees
            )
        }
    }
#endif

#if DEBUG
    private static func makeUnavailableAmendmentFixture(
        plan: FlightPlan, sourceData: Data, promotion: FlightRecordingPromotion
    ) -> FlightRecordingPackageResult? {
        let startedAt = promotion.recording.startedAt
        var otherFlight = CockpitFeatureState()
        do {
            try otherFlight.accept(plan, sourceData: sourceData)
            try otherFlight.startLeg(at: startedAt)
            otherFlight.prepareAmendmentConfirmationFixture()
            guard let flight = otherFlight.flight, let route = otherFlight.routeForAmendment,
                  let draft = otherFlight.routeAmendmentDraft else { return nil }
            let amendment = try PendingRouteAmendment(id: UUID(), draft: draft, flight: flight, route: route)
            var recording = promotion.recording
            let event = try recording.confirmPendingAmendment(
                amendment, at: startedAt.addingTimeInterval(1), elapsed: .seconds(1)
            )
            recording.sourceSchemaVersion = 4
            return .available(.init(recording: recording, events: promotion.events + [event]))
        } catch {
            return nil
        }
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

    private var tabBarTextSize: DynamicTypeSize {
        // When the iPad sidebar is collapsed, keep all primary tabs visible.
        // The content of each tab still uses the device's full text size.
        if tabBarPlacement == .topBar && dynamicTypeSize.isAccessibilitySize {
            return .large
        }
        return dynamicTypeSize
    }

    private enum MoreDestination { case root, downloads, settings }

    private func openMore(_ destination: MoreDestination) {
        guard appState.canSwitchAppSection else { return }
        moreDestination = destination
        appState.selectAppSection(.settings)
    }

    private struct PresentedChart: Identifiable {
        let selection: ChartSelection
        let snapshot: ChartSnapshot

        var id: String { selection.id }
    }

#if DEBUG && targetEnvironment(simulator)
    private func installChartFixture(_ edition: String) async {
        do {
            try await ChartSnapshotUITestFixture.install(edition, in: chartSnapshotStore)
            installedChartFixtureEdition = edition
        } catch {
            assertionFailure("Chart edition fixture \(edition) failed to install: \(error)")
        }
    }
#endif

    private var chartSelection: Binding<PresentedChart?> {
        Binding(
            get: {
                guard let id = appState.chartLibrary.presentedChartID, let chartSnapshot,
                      let selection = chartSnapshot.catalog.selection(for: id) else { return nil }
                return PresentedChart(selection: selection, snapshot: chartSnapshot)
            },
            set: { appState.chartLibrary.presentedChartID = $0?.id }
        )
    }

    private func updateChartSnapshot(_ snapshot: ChartSnapshot?) {
        guard snapshot?.pin != chartSnapshot?.pin
                || snapshot?.resources.bundleRoot != chartSnapshot?.resources.bundleRoot else { return }
        guard let snapshot else {
            chartSnapshot = nil
            return
        }
#if DEBUG
        let environment = ProcessInfo.processInfo.environment
        let chartCatalog = environment["NAVIGATION_FLIGHT_UI_TEST_EMPTY_CHART_AERODROME"]
            .map { snapshot.catalog.fixtureWithoutCharts(for: $0) } ?? snapshot.catalog
        let resources = ChartResources(
            bundleRoot: snapshot.resources.bundleRoot,
            unreadableChartID: environment["NAVIGATION_FLIGHT_UI_TEST_UNREADABLE_CHART"]
        )
        let visibleSnapshot = ChartSnapshot(pin: snapshot.pin, catalog: chartCatalog, resources: resources)
#else
        let visibleSnapshot = snapshot
#endif
        chartSnapshot = visibleSnapshot
        appState.chartLibrary.reconcile(with: visibleSnapshot.catalog)
    }

    private var appSectionSelection: Binding<AppFeatureState.AppSection> {
        Binding(
            get: { appState.selectedAppSection },
            set: { selection in
                guard selection != appState.selectedAppSection, appState.canSwitchAppSection else { return }
                appState.selectAppSection(selection)
            }
        )
    }

    private var cockpitTabLabel: some View {
        let indicator = CockpitActivityIndicator(
            isNavigationActive: appState.cockpit.flight?.legState == .active,
            recordingStatus: flightRecordingCoordinator.effectiveStatus
        )
        return HStack(spacing: 5) {
            Label("Cockpit", systemImage: "airplane")
            switch indicator {
            case .none:
                EmptyView()
            case .active:
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
            case .warning:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color.orange)
                    .imageScale(.small)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(indicator.accessibilityLabel))
        .accessibilityIdentifier("cockpit-tab")
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
