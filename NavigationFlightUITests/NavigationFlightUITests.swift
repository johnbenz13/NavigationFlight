//
//  NavigationFlightUITests.swift
//  NavigationFlightUITests
//
//  Created by Jonathan Bensaid on 10/10/2026.
//

import XCTest

final class NavigationFlightUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    private func openSettings(in app: XCUIApplication) {
        tab(named: "More", in: app).tap()
        let settings = app.buttons["more-settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
    }

    @MainActor
    func testChecklistSettingsSaveBackRelaunchAndFailureRetry() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = "settings-161-\(UUID().uuidString)"
        app.launch()
        openSettings(in: app)
        let row = app.buttons["settings-start-checklist"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["checklist-choice-none"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertEqual(row.value as? String, "No checklist")
        row.tap()
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertEqual(row.value as? String, "No checklist")
        app.terminate()
        app.launch()
        openSettings(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertEqual(row.value as? String, "No checklist")
        app.terminate()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_SETTINGS_FAILURE_ONCE"] = "1"
        app.launch()
        openSettings(in: app)
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["checklist-choice-establish-heading-cruise-check"].tap()
        XCTAssertTrue(app.staticTexts["settings-save-error"].waitForExistence(timeout: 3))
        XCTAssertEqual(row.value as? String, "No checklist")
        app.buttons["settings-retry"].tap()
        XCTAssertTrue(app.staticTexts["settings-save-error"].waitForNonExistence(timeout: 3))
        XCTAssertEqual(row.value as? String, "Establish Heading")
    }

    @MainActor
    func testNoChecklistStartAndRecoveryStayAbsent() throws {
        let app = launchCockpit(planData: try twoLegPlanData())
        openSettings(in: app)
        app.buttons["settings-start-checklist"].tap()
        app.buttons["checklist-choice-none"].tap()
        XCTAssertTrue(app.buttons["settings-start-checklist"].waitForExistence(timeout: 3))
        tab(named: "Cockpit", in: app).tap()
        app.buttons["start-leg"].tap()
        XCTAssertTrue(app.buttons["waypoint-identified"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["leg-start-checklist-chip"].exists)
        XCTAssertFalse(app.buttons["leg-start-checklist-noted"].exists)
        app.terminate()
        app.launch()
        XCTAssertTrue(app.buttons["Continue Flight"].waitForExistence(timeout: 5))
        app.buttons["Continue Flight"].tap()
        XCTAssertTrue(app.buttons["waypoint-identified"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["leg-start-checklist-chip"].exists)
        XCTAssertFalse(app.buttons["leg-start-checklist-noted"].exists)
        app.buttons["reached-now"].tap()
        XCTAssertTrue(app.buttons["waypoint-identified"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["leg-start-checklist-chip"].exists)
    }

    @MainActor
    func testSingleRecoveryRequiresChoiceAndContinueOpensRestoredCockpit() throws {
        let app = recoveryApp(state: "single", planData: try oneLegPlanData())

        XCTAssertTrue(app.staticTexts["Continue your flight?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue Flight"].exists)
        XCTAssertTrue(app.buttons["End as Incomplete"].exists)
        XCTAssertFalse(tab(named: "Cockpit", in: app).exists)

        app.buttons["Continue Flight"].tap()

        XCTAssertTrue(tab(named: "Cockpit", in: app).waitForExistence(timeout: 5))
        let status = app.buttons["recording-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Recording · No GPS")
        XCTAssertFalse(app.staticTexts["Continue your flight?"].exists)
    }

    @MainActor
    func testSingleRecoveryEndAsIncompleteRequiresConfirmation() throws {
        let app = recoveryApp(state: "single", planData: try oneLegPlanData())
        let endButton = app.buttons["End as Incomplete"]
        XCTAssertTrue(endButton.waitForExistence(timeout: 5))

        endButton.tap()

        XCTAssertTrue(app.staticTexts["End this Flight as incomplete?"].waitForExistence(timeout: 2))
        app.buttons.matching(identifier: "End as Incomplete").element(boundBy: 1).tap()
        XCTAssertTrue(tab(named: "Flight Plans", in: app).waitForExistence(timeout: 5))
    }

    @MainActor
    func testMultipleRecoveriesAreListedWithoutAutomaticSelection() throws {
        let app = recoveryApp(state: "multiple", planData: try oneLegPlanData())

        XCTAssertTrue(app.staticTexts["Choose a flight to continue"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["2 recoverable flights were found."].exists)
        XCTAssertTrue(app.buttons["Paphos local"].exists)
        XCTAssertFalse(tab(named: "Cockpit", in: app).exists)
    }

    @MainActor
    func testUnsupportedAndCorruptRecoveriesRemainExplicitLaunchStates() throws {
        let unsupported = recoveryApp(state: "unsupported", planData: nil)
        XCTAssertTrue(unsupported.staticTexts["Unsupported recording"].waitForExistence(timeout: 5))
        XCTAssertTrue(unsupported.buttons["Keep in Flights"].exists)
        unsupported.terminate()

        let corrupt = recoveryApp(state: "corrupt", planData: nil)
        XCTAssertTrue(corrupt.staticTexts["Recovery unavailable"].waitForExistence(timeout: 5))
        XCTAssertTrue(corrupt.buttons["Continue to App"].exists)
    }

    @MainActor
    func testFreshLaunchShellRoutesBetweenFixedAppSections() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launch()

        let cockpitTab = tab(named: "Cockpit", in: app)
        let flightPlansTab = tab(named: "Flight Plans", in: app)
        let flightsTab = tab(named: "Flights", in: app)
        let moreTab = tab(named: "More", in: app)
        XCTAssertTrue(cockpitTab.waitForExistence(timeout: 5))
        XCTAssertTrue(flightPlansTab.exists)
        XCTAssertTrue(flightsTab.exists)
        XCTAssertTrue(moreTab.exists)
        XCTAssertLessThan(cockpitTab.frame.minX, flightPlansTab.frame.minX)
        XCTAssertLessThan(flightPlansTab.frame.minX, flightsTab.frame.minX)
        XCTAssertLessThan(flightsTab.frame.minX, moreTab.frame.minX)
        XCTAssertTrue(flightPlansTab.isSelected)
        XCTAssertTrue(app.staticTexts["No flight plans yet"].exists)
        XCTAssertTrue(app.buttons["add-flight-plan"].exists)

        cockpitTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(cockpitTab.isSelected)
        let chooseFlightPlan = app.buttons["Choose a Flight Plan"]
        XCTAssertTrue(chooseFlightPlan.waitForExistence(timeout: 2))
        chooseFlightPlan.tap()
        XCTAssertTrue(flightPlansTab.isSelected)

        openSettings(in: app)
        XCTAssertTrue(app.buttons["settings-start-checklist"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testFlightsEmptyStateExplainsAutomaticPopulationWithoutImport() throws {
        let app = launchFlights(state: "empty")

        XCTAssertTrue(app.staticTexts["No recorded flights yet"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[
            "Load a Flight Plan in Cockpit. Recording starts automatically when movement and takeoff are detected."
        ].exists)
        XCTAssertFalse(app.buttons["add-flight-plan"].exists)
    }

    @MainActor
    func testFlightsPopulatedFixtureExposesAllRowStatesAndContinueActions() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())
        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'flights.row.'")
        )

        XCTAssertTrue(app.descendants(matching: .any)["flights.list"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flights.continue.'")).count, 2)
        var labels = rows.allElementsBoundByIndex.map(\.label)
        app.descendants(matching: .any)["flights.list"].swipeUp()
        labels.append(contentsOf: rows.allElementsBoundByIndex.map(\.label))
        app.descendants(matching: .any)["flights.list"].swipeUp()
        labels.append(contentsOf: rows.allElementsBoundByIndex.map(\.label))
        XCTAssertTrue(labels.contains { $0.contains("In Progress") && $0.contains("GPS available") })
        XCTAssertTrue(labels.contains { $0.contains("Recovery Required") && $0.contains("Partial GPS") })
        XCTAssertTrue(labels.contains { $0.contains("Complete") })
        XCTAssertTrue(labels.contains { $0.contains("Incomplete") && $0.contains("Partial GPS") })
        XCTAssertTrue(labels.contains { $0.contains("Manually Ended") && $0.contains("GPS unavailable") })
        XCTAssertTrue(labels.contains { $0.contains("Unavailable recording") && $0.contains("Unavailable") })
    }

    @MainActor
    func testFlightsRowsPreserveStatusMeaningAtAccessibilityTextSize() throws {
        let app = launchFlights(
            state: "populated",
            planData: try oneLegPlanData(),
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        let rows = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'flights.row.'")
        )

        XCTAssertTrue(rows.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(rows.allElementsBoundByIndex.allSatisfy { $0.label.isEmpty == false })
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flights.continue.'")).firstMatch.isHittable)
    }

    @MainActor
    func testFlightsUsesTwoRecentColumnsInIPadLandscape() throws {
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())
        defer {
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }
        let complete = app.descendants(matching: .any)["flights.row.03000000-0000-0000-0000-000000000003"]
        let incomplete = app.descendants(matching: .any)["flights.row.04000000-0000-0000-0000-000000000004"]

        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        XCTAssertTrue(incomplete.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(incomplete.frame.minX, complete.frame.maxX)
        XCTAssertEqual(incomplete.frame.midY, complete.frame.midY, accuracy: 2)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Issue 93 Flights iPad Landscape"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    @MainActor
    func testActiveFlightContinueRoutesToCockpit() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())
        let continueButton = app.buttons[
            "flights.continue.01000000-0000-0000-0000-000000000001"
        ]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 5))

        continueButton.tap()

        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))
        XCTAssertTrue(tab(named: "Cockpit", in: app).exists)
    }

    @MainActor
    func testCompleteFlightDetailShowsEvidenceAndClosedActions() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())

        openFlightDetail(id: "03000000-0000-0000-0000-000000000003", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.status"].label.contains("Complete"))
        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.summary"].exists)
        XCTAssertTrue(app.buttons["flight-detail.export"].exists)
        XCTAssertTrue(app.buttons["flight-detail.delete"].exists)
        let detail = app.descendants(matching: .any)["flight-detail.03000000-0000-0000-0000-000000000003"]
        for _ in 0..<3 where !app.descendants(matching: .any)["flight-detail.supplemental-evidence"].exists {
            detail.swipeUp()
        }
        let barometricAltitude = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Anchored barometric maximum'")
        ).firstMatch
        let deviceHeading = app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Latest device compass heading'")
        ).firstMatch
        XCTAssertTrue(barometricAltitude.label.contains("Anchored barometric maximum"))
        XCTAssertTrue(deviceHeading.label.contains("Latest device compass heading"))
        XCTAssertTrue(deviceHeading.label.contains("92° device-relative"))
        XCTAssertFalse(app.staticTexts["Aircraft heading"].exists)
        let availableScreenshot = XCTAttachment(screenshot: app.screenshot())
        availableScreenshot.name = "Issue 92 Supplemental Evidence Available"
        availableScreenshot.lifetime = .keepAlways
        add(availableScreenshot)
    }

    @MainActor
    func testCompletedFlightDebriefSynchronizesHistoricalControlsAndExits() throws {
        let app = launchFlights(state: "populated", planData: try debriefPlanData())
        openFlightDetail(id: "03000000-0000-0000-0000-000000000003", in: app)

        let debriefButton = app.buttons["flight-detail.debrief"]
        XCTAssertTrue(debriefButton.waitForExistence(timeout: 3))
        debriefButton.tap()

        XCTAssertTrue(app.descendants(matching: .any)["flight-debrief"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["flight-debrief.play-pause"].exists)
        XCTAssertTrue(app.sliders["flight-debrief.timeline"].exists)
        XCTAssertTrue(app.buttons["flight-debrief.rate"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["flight-debrief.compact-console"].exists)
        var analysisMode = app.buttons["Show analysis"]
        XCTAssertTrue(analysisMode.exists)
        analysisMode.tap()
        analysisMode = app.buttons["Hide analysis"]
        XCTAssertEqual(analysisMode.value as? String, "Full analysis")
        XCTAssertTrue(app.staticTexts["Flight parameters"].exists)
        analysisMode.tap()
        analysisMode = app.buttons["Show analysis"]
        XCTAssertEqual(analysisMode.value as? String, "Compact replay console")
        XCTAssertFalse(app.buttons["Start Leg"].exists)

        let timeline = app.sliders["flight-debrief.timeline"]
        if timeline.isHittable {
            timeline.adjust(toNormalizedSliderPosition: 0.5)
            XCTAssertGreaterThan(timeline.normalizedSliderPosition, 0.4)
        }

        app.buttons["flight-debrief.rate"].tap()
        app.buttons["×5"].tap()
        XCTAssertTrue(app.buttons["flight-debrief.rate"].label.contains("×5"))

        let event = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-debrief.event.'")
        ).firstMatch
        XCTAssertTrue(event.exists)
        event.tap()
        XCTAssertEqual(event.value as? String, "Selected")

        app.buttons["flight-debrief.fit-full-flight"].tap()
        let mapEvent = app.descendants(matching: .any)[
            "flight-debrief.map-event.07000000-0000-0000-0000-000000000007"
        ]
        XCTAssertTrue(mapEvent.waitForExistence(timeout: 5))
        let map = app.descendants(matching: .any)["flight-debrief.map-section"].firstMatch
        let targetEvent = app.buttons["flight-debrief.event.07000000-0000-0000-0000-000000000007"]
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.5)).tap()
        XCTAssertEqual(targetEvent.value as? String, "Selected")
        XCTAssertTrue(app.staticTexts["Position check ended"].exists)

        let orientation = app.buttons["flight-debrief.orientation"]
        orientation.tap()
        XCTAssertEqual(orientation.value as? String, "Track-up")
        map.swipeLeft()
        XCTAssertEqual(app.buttons["flight-debrief.free-look"].value as? String, "On")
        app.buttons["flight-debrief.recenter"].tap()
        XCTAssertEqual(app.buttons["flight-debrief.recenter"].value as? String, "Following aircraft")
        let driftLines = app.buttons["flight-debrief.drift-lines"]
        driftLines.tap()
        XCTAssertEqual(driftLines.value as? String, "Off")
        app.buttons["flight-debrief.fit-full-flight"].tap()
        XCTAssertEqual(app.buttons["flight-debrief.free-look"].value as? String, "On")

        app.buttons["flight-debrief.play-pause"].tap()
        XCTAssertTrue(app.buttons["flight-debrief.play-pause"].label.contains("Pause"))
        app.buttons["flight-debrief.play-pause"].tap()
        app.navigationBars.buttons.firstMatch.tap()

        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.status"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testCompletedFlightDebriefHandlesPlaybackEndAndMissingPosition() throws {
        let playbackApp = launchFlights(
            state: "populated",
            planData: try debriefPlanData(),
            debriefHasShortDuration: true
        )
        openFlightDetail(id: "03000000-0000-0000-0000-000000000003", in: playbackApp)
        playbackApp.buttons["flight-detail.debrief"].tap()
        XCTAssertTrue(playbackApp.descendants(matching: .any)["flight-debrief"].waitForExistence(timeout: 5))
        playbackApp.buttons["flight-debrief.rate"].tap()
        playbackApp.buttons["×5"].tap()
        playbackApp.buttons["flight-debrief.play-pause"].tap()
        let stoppedAtEnd = expectation(
            for: NSPredicate(format: "label == 'Play'"),
            evaluatedWith: playbackApp.buttons["flight-debrief.play-pause"]
        )
        wait(for: [stoppedAtEnd], timeout: 5)
        playbackApp.terminate()

        let noPositionApp = launchFlights(
            state: "populated",
            planData: try debriefPlanData(),
            debriefHasNoPosition: true
        )
        openFlightDetail(id: "03000000-0000-0000-0000-000000000003", in: noPositionApp)
        noPositionApp.buttons["flight-detail.debrief"].tap()
        let noPositionMessage = noPositionApp.staticTexts.matching(
            NSPredicate(format: "label CONTAINS 'No usable GPS track'")
        ).firstMatch
        XCTAssertTrue(noPositionMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(noPositionApp.staticTexts["Actions & phases"].exists)
        XCTAssertFalse(noPositionApp.buttons["flight-debrief.orientation"].exists)
        XCTAssertFalse(noPositionApp.buttons["flight-debrief.recenter"].exists)
        XCTAssertFalse(noPositionApp.buttons["flight-debrief.free-look"].exists)
        XCTAssertFalse(noPositionApp.buttons["flight-debrief.fit-full-flight"].exists)
        XCTAssertFalse(
            noPositionApp.buttons.matching(
                NSPredicate(format: "identifier BEGINSWITH 'flight-debrief.map-event.'")
            ).firstMatch.exists
        )
        noPositionApp.terminate()

        let unreliableCourseApp = launchFlights(
            state: "populated",
            planData: try debriefPlanData(),
            debriefHasUnreliableCourse: true
        )
        openFlightDetail(id: "03000000-0000-0000-0000-000000000003", in: unreliableCourseApp)
        unreliableCourseApp.buttons["flight-detail.debrief"].tap()
        XCTAssertTrue(unreliableCourseApp.descendants(matching: .any)["flight-debrief"].waitForExistence(timeout: 5))
        unreliableCourseApp.sliders["flight-debrief.timeline"].adjust(toNormalizedSliderPosition: 0.9)
        XCTAssertTrue(unreliableCourseApp.staticTexts["87"].exists)
    }

    @MainActor
    func testRetainedDebriefStatesPreserveAvailableEvidence() throws {
        try verifyDebriefState(
            id: "01000000-0000-0000-0000-000000000001",
            expectedText: "Flight recording is still active"
        )
        try verifyDebriefState(
            id: "02000000-0000-0000-0000-000000000002",
            expectedText: "This Flight is recoverable from a retained snapshot"
        )
        try verifyDebriefState(
            id: "04000000-0000-0000-0000-000000000004",
            expectedText: "GPS coverage is incomplete"
        )
        try verifyDebriefState(
            id: "05000000-0000-0000-0000-000000000005",
            expectedText: "No usable GPS track"
        )
        try verifyDebriefState(
            id: "07000000-0000-0000-0000-000000000007",
            expectedText: "This recording can’t be fully interpreted"
        )
        try verifyDebriefState(
            id: "06000000-0000-0000-0000-000000000006",
            expectedText: "This recording can’t be read"
        )
    }

    @MainActor
    private func verifyDebriefState(id: String, expectedText: String) throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())
        openFlightDetail(id: id, in: app)
        let debriefButton = app.buttons["flight-detail.debrief"]
        XCTAssertTrue(debriefButton.waitForExistence(timeout: 3))
        let isUnavailable = id == "07000000-0000-0000-0000-000000000007"
            || id == "06000000-0000-0000-0000-000000000006"
        let unavailableExportCopy = "Diagnostic and GPX export are unavailable for this recording."
        if isUnavailable {
            XCTAssertTrue(app.staticTexts[unavailableExportCopy].exists)
            XCTAssertFalse(app.buttons["flight-detail.export"].exists)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'can be exported separately'")).firstMatch.exists)
        }
        debriefButton.tap()
        let disclosure = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", expectedText)
        ).firstMatch
        XCTAssertTrue(
            disclosure.waitForExistence(timeout: 5),
            "Expected retained-state disclosure \(expectedText). UI: \(app.debugDescription)"
        )
        if id == "04000000-0000-0000-0000-000000000004" {
            XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'GPS coverage Partial'")).firstMatch.exists)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'GPS coverage 100' ")).firstMatch.exists)
        }
        if isUnavailable {
            XCTAssertTrue(app.staticTexts[unavailableExportCopy].exists)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'may still be exported'")).firstMatch.exists)
        }
        app.terminate()
    }

    @MainActor
    func testLLMZCompletedFlightUsesMatchingRecordedTrack() throws {
        let app = launchFlights(
            state: "populated",
            planData: try realFlightPlanData(named: "llhz-llmz")
        )
        openFlightDetail(id: "03000000-0000-0000-0000-000000000003", in: app)
        app.buttons["flight-detail.debrief"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["flight-debrief"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["שפיים → עין גדי"].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '1:26:26'")
        ).firstMatch.exists)
    }

    @MainActor
    func testIncompleteFlightDetailOffersPartialExport() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())

        openFlightDetail(id: "04000000-0000-0000-0000-000000000004", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.status"].label.contains("Incomplete"))
        XCTAssertEqual(app.buttons["flight-detail.export"].label, "Export Flight")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'can be exported separately'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Diagnostic and GPX export are unavailable for this recording."].exists)
    }

    @MainActor
    func testClosedFlightExportsAndShareCancellationReturnsToRetryableResult() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())
        openFlightDetail(id: "03000000-0000-0000-0000-000000000003", in: app)

        app.buttons["flight-detail.export"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-export.choice"].waitForExistence(timeout: 3))
        app.buttons["flight-export.diagnostic"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["flight-export.result"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["flight-export.filename"].label.hasSuffix(".nflightbundle"))
        let share = app.buttons["flight-export.share"]
        XCTAssertTrue(share.isHittable)
        share.tap()
        let dismissRegion = app.otherElements["PopoverDismissRegion"]
        XCTAssertTrue(dismissRegion.waitForExistence(timeout: 5))
        dismissRegion.tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-export.result"].waitForExistence(timeout: 3))
        let dismissed = expectation(
            for: NSPredicate(format: "isHittable == true"),
            evaluatedWith: share
        )
        wait(for: [dismissed], timeout: 5)
    }

    @MainActor
    func testExportFailureExplainsNoFileWasSharedAndOffersRetry() throws {
        let app = launchFlights(
            state: "populated",
            planData: try oneLegPlanData(),
            exportFailure: true
        )
        openFlightDetail(id: "03000000-0000-0000-0000-000000000003", in: app)

        app.buttons["flight-detail.export"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-export.choice"].waitForExistence(timeout: 3))
        app.buttons["flight-export.diagnostic"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["flight-export.failure"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Export Couldn’t Be Completed"].exists)
        XCTAssertTrue(app.staticTexts["Storage became unavailable while assembling the bundle."].exists)
        XCTAssertTrue(app.buttons["Try Again"].exists)
    }

    @MainActor
    func testActivePreparationFailureRetryReturnsThroughSnapshotDisclosure() throws {
        let app = launchFlights(
            state: "populated",
            planData: try oneLegPlanData(),
            exportPreparationFailure: true
        )
        openFlightDetail(id: "01000000-0000-0000-0000-000000000001", in: app)

        app.buttons["flight-detail.export"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-export.choice"].waitForExistence(timeout: 3))
        app.buttons["flight-export.diagnostic"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-export.failure"].waitForExistence(timeout: 5))

        app.buttons["Try Again"].tap()

        XCTAssertTrue(app.staticTexts["Export Active Recording?"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH 'Snapshot ·'")
        ).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["flight-export.provisional-disclosure"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["flight-export.result"].exists)
    }

    @MainActor
    func testDiagnosticExportCancellationReturnsToRetryableFlightDetail() throws {
        let app = launchFlights(
            state: "populated",
            planData: try oneLegPlanData(),
            exportDelay: true
        )
        openFlightDetail(id: "03000000-0000-0000-0000-000000000003", in: app)

        app.buttons["flight-detail.export"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-export.choice"].waitForExistence(timeout: 3))
        app.buttons["flight-export.diagnostic"].tap()

        let progress = app.staticTexts["Preparing Diagnostic Bundle"]
        XCTAssertTrue(progress.waitForExistence(timeout: 3))
        app.buttons["flight-export.cancel-progress"].tap()
        XCTAssertTrue(progress.waitForNonExistence(timeout: 3))
        XCTAssertTrue(app.buttons["flight-detail.export"].isHittable)

        app.buttons["flight-detail.export"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-export.choice"].waitForExistence(timeout: 3))
        app.buttons["flight-export.diagnostic"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-export.result"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testGPXExportUsesTrackSpecificProgressCopy() throws {
        let app = launchFlights(
            state: "populated",
            planData: try oneLegPlanData(),
            exportDelay: true
        )
        openFlightDetail(id: "03000000-0000-0000-0000-000000000003", in: app)

        app.buttons["flight-detail.export"].tap()
        XCTAssertTrue(app.buttons["flight-export.gpx"].waitForExistence(timeout: 3))
        app.buttons["flight-export.gpx"].tap()

        XCTAssertTrue(app.staticTexts["Preparing GPX Track"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Preparing Diagnostic Bundle"].exists)
        app.buttons["flight-export.cancel-progress"].tap()
    }

    @MainActor
    func testActiveFlightDetailIsReadOnlyAndContinuable() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())

        openFlightDetail(id: "01000000-0000-0000-0000-000000000001", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.status"].label.contains("In Progress"))
        XCTAssertTrue(app.buttons["flight-detail.continue"].exists)
        XCTAssertTrue(app.buttons["flight-detail.export"].exists)
        XCTAssertFalse(app.buttons["flight-detail.delete"].exists)
    }

    @MainActor
    func testActiveSnapshotDisclosurePreservesActiveFlightStatus() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())
        openFlightDetail(id: "01000000-0000-0000-0000-000000000001", in: app)

        app.buttons["flight-detail.export"].tap()
        XCTAssertTrue(app.buttons["flight-export.diagnostic"].waitForExistence(timeout: 3))
        app.buttons["flight-export.diagnostic"].tap()

        XCTAssertTrue(app.staticTexts["Export Active Recording?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Snapshot ·")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["This snapshot is provisional: duration, track, events, and outcome may change."].exists)
        app.buttons["flight-export.cancel-snapshot"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.status"].label.contains("In Progress"))
        XCTAssertTrue(app.buttons["flight-detail.continue"].isHittable)
        XCTAssertFalse(app.buttons["flight-detail.delete"].exists)
    }

    @MainActor
    func testActionOnlyFlightOffersDiagnosticExportWithoutGPX() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())

        openFlightDetail(id: "05000000-0000-0000-0000-000000000005", in: app)

        XCTAssertTrue(app.staticTexts["Unavailable"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["0 km"].exists)
        XCTAssertTrue(app.buttons["flight-detail.export"].exists)
        app.buttons["flight-detail.export"].tap()
        XCTAssertTrue(app.buttons["flight-export.diagnostic"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["flight-export.gpx"].exists)
        app.buttons["flight-export.cancel"].tap()
        XCTAssertTrue(app.buttons["flight-detail.delete"].exists)
        let detail = app.descendants(matching: .any)["flight-detail.05000000-0000-0000-0000-000000000005"]
        for _ in 0..<3 where !app.descendants(matching: .any)["flight-detail.supplemental-evidence"].exists {
            detail.swipeUp()
        }
        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.supplemental-evidence"].exists)
        XCTAssertTrue(app.staticTexts["Best-effort device evidence; not authoritative aircraft altitude or heading."].exists)
        let unavailableScreenshot = XCTAttachment(screenshot: app.screenshot())
        unavailableScreenshot.name = "Issue 92 Supplemental Evidence Unavailable"
        unavailableScreenshot.lifetime = .keepAlways
        add(unavailableScreenshot)
    }

    @MainActor
    func testClosedFlightDeletionCancellationPreservesTheNamedFlight() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())
        let id = "03000000-0000-0000-0000-000000000003"
        openFlightDetail(id: id, in: app)

        app.buttons["flight-detail.delete"].tap()

        XCTAssertTrue(app.staticTexts["Delete Jerusalem Corridor Practice?"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts[
            "This permanently removes the GPS track and navigation event history from this device."
        ].exists)
        let confirmationScreenshot = XCTAttachment(screenshot: app.screenshot())
        confirmationScreenshot.name = "Issue 91 Delete Confirmation"
        confirmationScreenshot.lifetime = .keepAlways
        add(confirmationScreenshot)
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.\(id)"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testConfirmedClosedFlightDeletionReturnsToListAfterRemoval() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())
        let id = "03000000-0000-0000-0000-000000000003"
        openFlightDetail(id: id, in: app)
        app.buttons["flight-detail.delete"].tap()

        app.buttons["Delete"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["flights.list"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["flights.row.\(id)"].exists)
    }

    @MainActor
    func testFailedDeletionPreservesDetailAndOffersRetry() throws {
        let app = launchFlights(
            state: "populated",
            planData: try oneLegPlanData(),
            deletionFailure: true
        )
        let id = "03000000-0000-0000-0000-000000000003"
        openFlightDetail(id: id, in: app)
        app.buttons["flight-detail.delete"].tap()

        app.buttons["Delete"].tap()

        XCTAssertTrue(app.alerts["Couldn’t delete Jerusalem Corridor Practice"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[
            "The recording and all of its files remain on this device. Try deleting it again."
        ].exists)
        XCTAssertTrue(app.alerts.firstMatch.buttons["Retry"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.\(id)"].exists)
    }

    @MainActor
    func testCorruptRecordingRemainsDeletable() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())
        let id = "06000000-0000-0000-0000-000000000006"
        openFlightDetail(id: id, in: app)

        XCTAssertTrue(app.staticTexts["Track unavailable"].exists)
        XCTAssertTrue(app.staticTexts["Deletion remains available."].exists)
        XCTAssertTrue(app.buttons["flight-detail.delete"].isHittable)
        let unavailableScreenshot = XCTAttachment(screenshot: app.screenshot())
        unavailableScreenshot.name = "Issue 91 Unavailable Recording"
        unavailableScreenshot.lifetime = .keepAlways
        add(unavailableScreenshot)
    }

    @MainActor
    func testFreshLaunchShowsEmptyFlightPlans() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launch()
        XCTAssertTrue(app.staticTexts["No flight plans yet"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Add a prepared .fplnav plan from Navigation Editor. Saved Flight Plans remain available offline."].exists)
        XCTAssertTrue(app.buttons["add-flight-plan"].exists)
    }

    @MainActor
    func testPopulatedFlightPlansShowsRowHierarchyAndLoadedRevisionBadge() throws {
        let data = try oneLegPlanData()
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let project = try XCTUnwrap(object["project"] as? [String: Any])
        let title = try XCTUnwrap(project["title"] as? String)
        let id = try XCTUnwrap(project["id"] as? String)
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_PLANS"] = data.base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LOADED_PLAN"] = data.base64EncodedString()
        app.launch()

        let row = app.buttons["flight-plan-row-\(id.uppercased())"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains(title))
        XCTAssertTrue(row.label.contains("Loaded in Cockpit"))
        XCTAssertTrue(app.staticTexts["Most recently imported"].exists)
        XCTAssertTrue(app.buttons["add-flight-plan"].exists)
    }

    @MainActor
    func testAccessibilityTextKeepsPopulatedFlightPlanMeaningAndActionsReachable() throws {
        let data = try oneLegPlanData()
        let title = try projectTitle(in: data)
        let app = launchFlightPlans(
            seedData: [data],
            loadedPlanData: data,
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )

        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains(title))
        XCTAssertTrue(row.label.contains("Loaded in Cockpit"))
        XCTAssertTrue(app.buttons["add-flight-plan"].isHittable)
    }

    @MainActor
    func testCanonicalReviewPresentsFrequencyAndRouteDetailsAsSheets() throws {
        let data = try oneLegPlanData()
        let app = launchFlightPlans(seedData: [data], loadedPlanData: data)
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let frequency = app.buttons["flight-plan-frequency-disclosure"]
        XCTAssertTrue(frequency.waitForExistence(timeout: 5))
        frequency.tap()
        XCTAssertTrue(app.staticTexts["frequency-plan-title"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["close-frequency-plan"].isHittable)
        app.buttons["close-frequency-plan"].tap()

        let route = app.buttons["flight-plan-route-disclosure"]
        XCTAssertTrue(route.waitForExistence(timeout: 3))
        route.tap()
        XCTAssertTrue(app.staticTexts["Route details"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["close-route-details"].isHittable)
        app.buttons["close-route-details"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-plan-inspection"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testListInspectionLoadCreatesReadyFlightInCockpit() throws {
        let data = try oneLegPlanData()
        let title = try projectTitle(in: data)
        let app = launchFlightPlans(seedData: [data])
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        row.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 2))
        let load = app.buttons["load-in-cockpit"]
        XCTAssertTrue(load.exists)

        load.tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["cockpit-time"].label.contains("Running"))
    }

    @MainActor
    func testReturnToCockpitAndBackRetainsInspection() throws {
        let data = try oneLegPlanData()
        let title = try projectTitle(in: data)
        let app = launchFlightPlans(seedData: [data], loadedPlanData: data)
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let returnButton = app.buttons["return-to-cockpit"]
        XCTAssertTrue(returnButton.waitForExistence(timeout: 2))
        XCTAssertEqual(returnButton.label, "Continue to Cockpit")
        XCTAssertTrue(app.staticTexts["Keeps the current Flight and returns to the cockpit without changing timing or progress."].exists)
        XCTAssertTrue(app.staticTexts["Flight Actions"].exists)
        XCTAssertEqual(app.buttons["restart-flight"].label, "Restart Flight…")
        XCTAssertTrue(app.staticTexts["Creates a new ready Flight from this Flight Plan. Existing progress or edits require confirmation."].exists)
        returnButton.tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))

        tab(named: "Flight Plans", in: app).tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["return-to-cockpit"].exists)
    }

    @MainActor
    func testRestartKeepsLoadedSnapshotAndLoadUpdatedPlanAdoptsSavedRevision() throws {
        let loaded = try oneLegPlanData()
        let savedUpdate = try changingRevision(in: loaded, by: 60)
        let app = launchFlightPlans(seedData: [savedUpdate], loadedPlanData: loaded)
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        XCTAssertTrue(app.buttons["load-updated-plan"].waitForExistence(timeout: 2))
        XCTAssertEqual(app.buttons["return-to-cockpit"].label, "Continue to Cockpit")
        XCTAssertTrue(app.staticTexts["Flight Actions"].exists)
        XCTAssertEqual(app.buttons["restart-flight"].label, "Restart Flight…")
        app.buttons["restart-flight"].tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))

        tab(named: "Flight Plans", in: app).tap()
        XCTAssertTrue(app.buttons["load-updated-plan"].waitForExistence(timeout: 2))
        app.buttons["load-updated-plan"].tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))

        tab(named: "Flight Plans", in: app).tap()
        XCTAssertTrue(app.buttons["restart-flight"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["load-updated-plan"].exists)
    }

    @MainActor
    func testProtectedLoadCancellationAndConfirmationPreserveThenReplaceFlight() throws {
        let loaded = try oneLegPlanData()
        let anotherPlan = try changingIdentity(in: loaded)
        let app = launchFlightPlans(
            seedData: [anotherPlan],
            loadedPlanData: loaded,
            protectLoadedFlight: true
        )
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["load-in-cockpit"].tap()

        let confirmation = app.alerts["End current Flight?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["load-in-cockpit"].waitForExistence(timeout: 2))

        app.buttons["load-in-cockpit"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["End & Load"].tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["cockpit-time"].label.contains("Running"))
    }

    @MainActor
    func testProtectedRestartRequiresConfirmationAndCancellationPreservesInspection() throws {
        let data = try oneLegPlanData()
        let app = launchFlightPlans(
            seedData: [data],
            loadedPlanData: data,
            protectLoadedFlight: true
        )
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["restart-flight"].tap()

        let confirmation = app.alerts["Restart this Flight?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["restart-flight"].waitForExistence(timeout: 2))

        app.buttons["restart-flight"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Restart"].tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.descendants(matching: .any)["cockpit-time"].label.contains("Running"))
    }

    @MainActor
    func testProtectedUpdatedPlanRequiresConfirmation() throws {
        let loaded = try oneLegPlanData()
        let savedUpdate = try changingRevision(in: loaded, by: 60)
        let app = launchFlightPlans(
            seedData: [savedUpdate],
            loadedPlanData: loaded,
            protectLoadedFlight: true
        )
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["load-updated-plan"].tap()

        let confirmation = app.alerts["End current Flight?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["load-updated-plan"].waitForExistence(timeout: 2))

        app.buttons["load-updated-plan"].tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["End & Load"].tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testFailedLoadPreservesOriginalFlightAndInspection() throws {
        let loaded = try oneLegPlanData()
        let anotherPlan = try changingIdentity(in: loaded)
        let app = launchFlightPlans(
            seedData: [anotherPlan],
            loadedPlanData: loaded,
            failFlightChange: true
        )
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["load-in-cockpit"].tap()

        let error = app.alerts["Couldn’t load this Flight Plan"]
        XCTAssertTrue(error.waitForExistence(timeout: 3))
        error.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["load-in-cockpit"].waitForExistence(timeout: 2))

        tab(named: "Cockpit", in: app).tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testRemovalCancellationAndSuccess() throws {
        let data = try oneLegPlanData()
        let app = launchFlightPlans(seedData: [data])
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let remove = app.buttons["remove-flight-plan"]
        XCTAssertTrue(remove.waitForExistence(timeout: 2))
        remove.tap()
        let confirmation = app.alerts["Remove saved plan?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.buttons["Cancel"].tap()
        let removeAfterCancellation = app.buttons["remove-flight-plan"]
        XCTAssertTrue(removeAfterCancellation.waitForExistence(timeout: 5))

        removeAfterCancellation.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        confirmation.buttons["Remove"].tap()
        XCTAssertTrue(app.staticTexts["No flight plans yet"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch.exists)
    }

    @MainActor
    func testLoadedPlanRemovalPreservesCockpitInspectionAndRestart() throws {
        let data = try oneLegPlanData()
        let app = launchFlightPlans(seedData: [data], loadedPlanData: data)
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["remove-flight-plan"].tap()

        let confirmation = app.alerts["Remove from Flight Plans?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        XCTAssertTrue(confirmation.staticTexts[
            "Only the library copy will be removed. The current Flight remains usable until replacement or app closure."
        ].exists)
        confirmation.buttons["Remove"].tap()
        XCTAssertTrue(app.staticTexts["No flight plans yet"].waitForExistence(timeout: 5))

        tab(named: "Cockpit", in: app).tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))
        tab(named: "Flight Plans", in: app).tap()
        XCTAssertTrue(app.staticTexts["No flight plans yet"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testRemovalFailurePreservesRecordAndInspection() throws {
        let data = try oneLegPlanData()
        let app = launchFlightPlans(seedData: [data], removalFailure: true)
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["remove-flight-plan"].tap()
        let confirmation = app.alerts["Remove saved plan?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Remove"].tap()

        let failure = app.alerts["Couldn’t remove plan"]
        XCTAssertTrue(failure.waitForExistence(timeout: 3))
        XCTAssertTrue(failure.staticTexts[
            "The Flight Plan remains saved. This inspection and the current Flight are unchanged."
        ].exists)
        failure.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["remove-flight-plan"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testAddPickerCancellationPreservesEmptyLibrary() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launch()
        let add = app.buttons["add-flight-plan"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        add.tap()

        let cancel = app.buttons["Cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5))
        cancel.tap()
        XCTAssertTrue(app.staticTexts["No flight plans yet"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Couldn’t add this plan"].exists)
    }

    @MainActor
    func testNewAndSameRevisionImportOutcomes() throws {
        let data = try oneLegPlanData()
        let title = try projectTitle(in: data)
        var app = launchFlightPlans(importData: data)
        XCTAssertTrue(app.alerts["Flight Plan added"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.alerts["Flight Plan added"].staticTexts[title].exists || app.alerts["Flight Plan added"].exists)
        app.alerts["Flight Plan added"].buttons["Done"].tap()
        XCTAssertEqual(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'" )).count,
            1
        )

        app.terminate()
        app = launchFlightPlans(seedData: [data], importData: data)
        XCTAssertTrue(app.alerts["Already imported"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'" )).count, 1)
    }

    @MainActor
    func testNewerReplacementConfirmsAndDoesNotDuplicate() throws {
        let original = try oneLegPlanData()
        let newer = try changingRevision(in: original, by: 60)
        let app = launchFlightPlans(seedData: [original], importData: newer)
        let confirmation = app.alerts["Replace saved plan?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 10))
        confirmation.buttons["Replace"].tap()
        XCTAssertTrue(app.alerts["Flight Plan added"].waitForExistence(timeout: 5))
        app.alerts["Flight Plan added"].buttons["Done"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'" )).count, 1)
    }

    @MainActor
    func testOlderReplacementWarnsAndCancellationPreservesSavedCopy() throws {
        let original = try oneLegPlanData()
        let older = try changingRevision(in: original, by: -60)
        let app = launchFlightPlans(seedData: [original], importData: older)
        let confirmation = app.alerts["Replace with older revision?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 5))
        confirmation.buttons["Cancel"].tap()
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'flight-plan-row-'" )).count, 1)
        XCTAssertFalse(app.alerts["Flight Plan added"].exists)
    }

    @MainActor
    func testInvalidInputAndPersistenceFailureShowNoFalseSuccess() throws {
        var app = launchFlightPlans(importData: Data("invalid".utf8))
        XCTAssertTrue(app.alerts["Couldn’t add this plan"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No flight plans yet"].exists)

        app.terminate()
        app = launchFlightPlans(importData: try oneLegPlanData(), storageFailure: true)
        XCTAssertTrue(app.alerts["Plan wasn’t saved"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["No flight plans yet"].exists)
    }

    @MainActor
    func testActionOnlyRecordingStatusAndEndConfirmation() throws {
        let app = launchCockpit(planData: try oneLegPlanData())

        app.buttons["start-leg"].tap()
        let closeChecklist = app.buttons["leg-start-checklist-close"]
        XCTAssertTrue(closeChecklist.waitForExistence(timeout: 3))
        closeChecklist.tap()
        XCTAssertTrue(app.buttons["leg-start-checklist-chip"].waitForExistence(timeout: 3))

        let recordingStatus = app.buttons["recording-status"]
        XCTAssertTrue(recordingStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(recordingStatus.label, "Recording · No GPS")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] 'latitude' OR label CONTAINS[c] 'longitude'")).firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Navigation actions are recorded without coordinates or a GPS track."].exists)
        XCTAssertFalse(app.buttons["end-recording"].exists)

        recordingStatus.tap()
        XCTAssertTrue(app.staticTexts["Navigation actions are recorded without coordinates or a GPS track."].waitForExistence(timeout: 3))
        let endRecording = app.buttons["end-recording"]
        XCTAssertTrue(endRecording.waitForExistence(timeout: 3))
        endRecording.tap()
        let confirmation = app.alerts["End Recording?"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["Keep Recording"].tap()
        XCTAssertTrue(recordingStatus.exists)
        XCTAssertEqual(recordingStatus.label, "Recording · No GPS")

        app.buttons["waypoint-identified"].tap()
        app.buttons["waypoint-reached"].tap()
        let navigationComplete = app.buttons["navigation-complete"]
        XCTAssertTrue(navigationComplete.waitForExistence(timeout: 3))
        navigationComplete.tap()
        XCTAssertEqual(recordingStatus.label, "Navigation Complete · Recording Continues")

        recordingStatus.tap()
        XCTAssertTrue(endRecording.waitForExistence(timeout: 3))
        endRecording.tap()
        XCTAssertTrue(confirmation.waitForExistence(timeout: 3))
        confirmation.buttons["End Recording"].tap()
        let closedStatus = app.buttons["recording-status"]
        XCTAssertTrue(closedStatus.waitForExistence(timeout: 5))
        XCTAssertEqual(closedStatus.label, "Recording ended · Complete")
        XCTAssertFalse(endRecording.exists)

        app.buttons["Map tools"].firstMatch.tap()
        let inspectFlightPlan = app.buttons["map-tools-inspect-flight-plan"]
        XCTAssertTrue(inspectFlightPlan.waitForExistence(timeout: 3))
        inspectFlightPlan.tap()
        XCTAssertTrue(app.descendants(matching: .any)["flight-plan-inspection"].waitForExistence(timeout: 3))
        app.buttons["restart-flight"].tap()
        let restartConfirmation = app.alerts["Restart this Flight?"]
        XCTAssertTrue(restartConfirmation.waitForExistence(timeout: 3))
        restartConfirmation.buttons["Restart"].tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["recording-status"].label, "Prepared · Sensing")
        app.buttons["start-leg"].tap()
        XCTAssertEqual(app.buttons["recording-status"].label, "Recording · No GPS")
    }

    @MainActor
    func testPreparedGapAndResumedRecordingStatesHidePosition() throws {
        let plan = try oneLegPlanData()
        var app = launchCockpit(planData: plan)
        XCTAssertEqual(app.buttons["recording-status"].label, "Prepared · Sensing")

        for expected in [(fixture: "recording", label: "Recording"),
                         (fixture: "partial", label: "Partial Recording"),
                         (fixture: "gps-gap", label: "Recording · GPS Gap"),
                         (fixture: "gps-resumed", label: "Recording · GPS Resumed")] {
            app.terminate()
            app = launchCockpit(planData: plan, recordingStatus: expected.fixture)
            let status = app.buttons["recording-status"]
            XCTAssertTrue(status.waitForExistence(timeout: 3))
            XCTAssertEqual(status.label, expected.label)
            XCTAssertFalse(app.staticTexts.matching(NSPredicate(
                format: "label CONTAINS[c] 'latitude' OR label CONTAINS[c] 'longitude'"
            )).firstMatch.exists)
            if expected.fixture == "partial" {
                status.tap()
                XCTAssertTrue(app.staticTexts[
                    "Recording began after airborne movement was detected. Earlier track history is unavailable."
                ].waitForExistence(timeout: 2))
            }
        }
    }

    @MainActor
    func testRecordingPersistenceFailureLeavesLegReady() throws {
        let app = launchCockpit(
            planData: try oneLegPlanData(),
            recordingFailure: true
        )

        app.buttons["start-leg"].tap()
        let alert = app.alerts["Couldn’t Start Leg"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["The recording couldn’t be saved. The leg remains ready."].exists)
        alert.buttons["OK"].tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))
        let readyStatus = app.buttons["recording-status"]
        XCTAssertTrue(readyStatus.exists)
        XCTAssertEqual(readyStatus.label, "Prepared · Sensing")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label == 'Recording · No GPS'")).firstMatch.exists)
    }

    @MainActor
    func testRecordingDegradationWarnsWithoutBlockingOperationalActions() throws {
        let app = launchCockpit(
            planData: try oneLegPlanData(),
            recordingDegradation: true
        )

        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        let status = app.buttons["recording-status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Recording May Be Incomplete")
        XCTAssertTrue(app.buttons["waypoint-identified"].isEnabled)
        XCTAssertTrue(app.buttons["reached-now"].isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["position-check-control"].isEnabled)
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(
            format: "label CONTAINS[c] 'latitude' OR label CONTAINS[c] 'longitude'"
        )).firstMatch.exists)

        status.tap()
        XCTAssertTrue(app.staticTexts[
            "Some track data could not be saved. Navigation actions remain available."
        ].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["end-recording"].exists)
    }

    @MainActor
    func testLowStorageStatusRemainsVisibleAndOpensAccessibleDetails() throws {
        let app = launchCockpit(planData: try oneLegPlanData(), recordingStatus: "low-storage")
        let status = app.buttons["recording-status"]

        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertEqual(status.label, "Recording · Low Storage")
        status.tap()
        XCTAssertTrue(app.staticTexts[
            "New GPS track samples are paused. Saved evidence is preserved and navigation actions continue to be recorded when possible."
        ].waitForExistence(timeout: 3))
    }

    @MainActor
    func testTabRoundTripAndRotationPreserveActiveFlight() throws {
        let app = launchCockpit(planData: try oneLegPlanData())
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        let timer = app.descendants(matching: .any)["cockpit-time"]
        XCTAssertTrue(timer.waitForExistence(timeout: 2))
        XCTAssertTrue(timer.label.contains("Elapsed from leg start"))

        let flightPlansTab = tab(named: "Flight Plans", in: app)
        flightPlansTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["No flight plans yet"].waitForExistence(timeout: 2))
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.staticTexts["No flight plans yet"].waitForExistence(timeout: 2))
        XCUIDevice.shared.orientation = .portrait

        let cockpitTab = tab(named: "Cockpit", in: app)
        XCTAssertTrue(cockpitTab.waitForExistence(timeout: 2))
        cockpitTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(timer.waitForExistence(timeout: 2))
        XCTAssertTrue(timer.label.contains("Elapsed from leg start"))
        XCTAssertTrue(app.buttons["waypoint-identified"].exists)
        XCTAssertTrue(app.buttons["reached-now"].isEnabled)

    }

    @MainActor
    func testImportedWindPlanLaunchesCockpitWithNoWindValuesAndNoModeSelector() throws {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repository = sourceFile.deletingLastPathComponent().deletingLastPathComponent()
        let fixture = repository.appending(path: "NavigationFlightTests/Fixtures/FPLNav/V7/Editor/editor-wind.fplnav")
        let data = try Data(contentsOf: fixture)
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = data.base64EncodedString()
        app.launch()

        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["calculation-mode"].exists)
        XCTAssertFalse(app.buttons["Wind"].exists)
        let cockpitHeading = app.descendants(matching: .any)["cockpit-heading"]
        XCTAssertTrue(cockpitHeading.waitForExistence(timeout: 2))
        XCTAssertTrue(cockpitHeading.label.contains("035°"))
        XCTAssertFalse(cockpitHeading.label.contains("° M"))
        let readyTimer = app.descendants(matching: .any)["cockpit-time"]
        XCTAssertTrue(readyTimer.exists)
        XCTAssertTrue(readyTimer.label.contains("00:00"))
        XCTAssertTrue(app.buttons["choose-starting-leg"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-eta"].label.contains("09:56"))
        let compactFrequencies = app.buttons["compact-frequencies"]
        if compactFrequencies.exists {
            compactFrequencies.tap()
            let groupedVOR = app.descendants(matching: .any).matching(
                NSPredicate(format: "label CONTAINS 'BGN' AND label CONTAINS 'VOR/DME' AND label CONTAINS 'megahertz'")
            )
            XCTAssertGreaterThanOrEqual(groupedVOR.count, 1)
        } else {
            XCTAssertTrue(app.descendants(matching: .any)["planned-frequencies"].exists)
        }
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-altitude"].label.contains("3,000"))
        let map = app.descendants(matching: .any)["aviation-map"]
        XCTAssertTrue(map.exists)
        map.swipeLeft()
        let startLeg = app.buttons["start-leg"]
        XCTAssertTrue(startLeg.isEnabled)
        XCTAssertFalse(app.buttons["waypoint-identified"].exists)
        XCTAssertFalse(app.buttons["reached-now"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["leg-start-checklist"].exists)
        startLeg.tap()

        let waypointIdentified = app.buttons["waypoint-identified"]
        XCTAssertTrue(waypointIdentified.waitForExistence(timeout: 2))
        XCTAssertTrue(waypointIdentified.isEnabled)
        XCTAssertTrue(app.buttons["reached-now"].isEnabled)
        let activeTimer = app.descendants(matching: .any)["cockpit-time"]
        XCTAssertTrue(activeTimer.exists)
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-eta"].label.contains("09:56"))
        XCTAssertTrue(app.descendants(matching: .any)["planned-frequencies"].exists)
        XCTAssertTrue(cockpitHeading.label.contains("035°"))
        map.swipeRight()

        let checklist = app.descendants(matching: .any)["leg-start-checklist"]
        XCTAssertTrue(checklist.waitForExistence(timeout: 2))
        app.buttons["leg-start-checklist-noted"].tap()
        XCTAssertTrue(app.buttons["leg-start-checklist-chip"].waitForExistence(timeout: 2))
        XCTAssertFalse(checklist.exists)

        waypointIdentified.tap()
        let waypointReached = app.buttons["waypoint-reached"]
        XCTAssertTrue(waypointReached.waitForExistence(timeout: 2))
        waypointReached.tap()
        XCTAssertTrue(app.descendants(matching: .any)["navigation-complete"].waitForExistence(timeout: 2))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(cockpitHeading.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["navigation-complete"].exists)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.descendants(matching: .any)["navigation-complete"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testCockpitOperationalCuesExposeSemanticFrequencyAndAltitudeValues() throws {
        let app = launchCockpit(planData: try oneLegPlanData())

        let currentFrequency = app.descendants(matching: .any)["planned-now"]
        let nextFrequency = app.descendants(matching: .any)["planned-next"]
        XCTAssertTrue(currentFrequency.waitForExistence(timeout: 3))
        XCTAssertTrue(nextFrequency.waitForExistence(timeout: 3))
        XCTAssertEqual(currentFrequency.label, "Planned now, SYN, 113.50 megahertz")
        XCTAssertEqual(nextFrequency.label, "Planned next, Synthetic service, 120.50 megahertz")

        let altitude = app.descendants(matching: .any)["cockpit-altitude"]
        XCTAssertTrue(altitude.waitForExistence(timeout: 3))
        XCTAssertTrue((altitude.value as? String)?.contains("Target altitude") == true)
        XCTAssertTrue((altitude.value as? String)?.contains("next target") == true)
    }

    @MainActor
    func testCockpitOperationalCuesRemainAvailableWithLargerText() throws {
        let app = launchCockpit(
            planData: try oneLegPlanData(),
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityExtraExtraExtraLarge"
        )

        let altitude = app.descendants(matching: .any)["cockpit-altitude"]
        XCTAssertTrue(altitude.waitForExistence(timeout: 3))
        XCTAssertTrue((altitude.value as? String)?.contains("Target altitude") == true)
        XCTAssertTrue(app.descendants(matching: .any)["planned-frequencies"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testDriftLineVisibilityPersistsAcrossPlanInspection() throws {
        let app = launchCockpit(planData: try oneLegPlanData())
        app.buttons["Map tools"].firstMatch.tap()
        let toggle = app.buttons["map-tools-toggle-drift-lines"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 3))
        XCTAssertEqual(toggle.label, "Drift lines · On")

        toggle.tap()
        XCTAssertEqual(toggle.label, "Drift lines · Off")
        let inspectFlightPlan = app.buttons["map-tools-inspect-flight-plan"]
        XCTAssertTrue(inspectFlightPlan.waitForExistence(timeout: 3))
        inspectFlightPlan.tap()
        XCTAssertTrue(app.buttons["return-to-cockpit"].waitForExistence(timeout: 5))
        app.buttons["return-to-cockpit"].tap()

        app.buttons["Map tools"].firstMatch.tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 2))
        XCTAssertEqual(toggle.label, "Drift lines · Off")
    }

    @MainActor
    func testPilotCanCommitAndReopenMagneticHeading() throws {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repository = sourceFile.deletingLastPathComponent().deletingLastPathComponent()
        let fixture = repository.appending(path: "NavigationFlightTests/Fixtures/FPLNav/V7/Editor/editor-wind.fplnav")
        let app = launchCockpit(planData: try Data(contentsOf: fixture))

        app.buttons["start-leg"].tap()
        let checklistNoted = app.buttons["leg-start-checklist-noted"]
        XCTAssertTrue(checklistNoted.waitForExistence(timeout: 2))
        checklistNoted.tap()
        let heading = app.buttons["cockpit-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 2))
        XCTAssertTrue(heading.label.contains("Operational heading"))
        XCTAssertTrue(heading.label.contains("035°"))
        heading.tap()

        let headingEditor = app.descendants(matching: .any)
        XCTAssertTrue(headingEditor.matching(NSPredicate(format: "label == 'Revise heading'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(headingEditor.matching(NSPredicate(format: "label == 'Pilot-authored · magnetic'")).firstMatch.exists)
        XCTAssertTrue(headingEditor.matching(NSPredicate(format: "label == 'Imported baseline'")).firstMatch.exists)
        XCTAssertTrue(headingEditor.matching(NSPredicate(format: "label == 'Draft'")).firstMatch.exists)
        XCTAssertTrue(app.descendants(matching: .any)["heading-draft"].label.contains("035°"))
        let headingDraft = app.descendants(matching: .any)["heading-draft"]
        app.buttons["increase-heading"].press(forDuration: 0.8)
        let repeatedHeading = headingDraft.label
        XCTAssertNotEqual(repeatedHeading, "035°")
        XCTAssertNotEqual(repeatedHeading, "036°")
        app.buttons["commit-heading"].tap()

        XCTAssertFalse(headingEditor.matching(NSPredicate(format: "label == 'Revise heading'")).firstMatch.exists)
        XCTAssertTrue(heading.label.contains(repeatedHeading))
        let confirmation = app.descendants(matching: .any)["heading-commit-confirmation"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 2))
        expectation(
            for: NSPredicate(format: "exists == false"),
            evaluatedWith: confirmation
        )
        waitForExpectations(timeout: 5)
        heading.tap()
        XCTAssertTrue(app.descendants(matching: .any)["heading-draft"].label.contains(repeatedHeading))
        XCTAssertEqual(app.buttons["commit-heading"].label, "Commit revised heading")
    }

    @MainActor
    func testDirectReachAutomaticallyStartsSuccessor() throws {
        let app = launchCockpit(planData: try twoLegPlanData())

        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        XCTAssertTrue(app.buttons["reached-now"].waitForExistence(timeout: 2))
        app.buttons["reached-now"].tap()

        let noticeTitle = app.staticTexts["progression-notice-title"]
        XCTAssertTrue(noticeTitle.waitForExistence(timeout: 2))
        XCTAssertTrue(noticeTitle.label.contains("successor started"))
        XCTAssertTrue(app.staticTexts["progression-notice-detail"].label.contains("Automatic progression"))
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Started at"))
        XCTAssertFalse(app.descendants(matching: .any)["navigation-complete"].exists)
    }

    @MainActor
    func testWaypointReachUndoRestoresActiveLeg() throws {
        let app = launchCockpit(planData: try oneLegPlanData())
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["reached-now"].tap()

        let banner = app.staticTexts["progression-notice-title"]
        XCTAssertTrue(banner.waitForExistence(timeout: 2))
        XCTAssertEqual(banner.label, "Navigation complete")
        let undo = app.buttons["undo-reach"]
        XCTAssertTrue(undo.exists)
        XCTAssertEqual(undo.label, "Undo reach report")
        let undoValue = undo.value as? String
        XCTAssertTrue(undoValue == "20 seconds remaining" || undoValue == "19 seconds remaining")
        undo.tap()

        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Elapsed from leg start"))
        XCTAssertFalse(app.descendants(matching: .any)["navigation-complete"].exists)
        XCTAssertFalse(banner.exists)
    }

    @MainActor
    func testPreviousLegHistoryExpandsWithoutChangingSuccessorOrTimer() throws {
        let app = launchCockpit(planData: try twoLegPlanData())
        XCTAssertFalse(app.buttons["previous-leg-tab"].exists)

        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["reached-now"].tap()

        let collapseChecklist = app.buttons["leg-start-checklist-close"]
        if collapseChecklist.waitForExistence(timeout: 2) {
            collapseChecklist.tap()
        }

        let timer = app.descendants(matching: .any)["cockpit-time"]
        XCTAssertTrue(timer.waitForExistence(timeout: 2))
        XCTAssertTrue(timer.label.contains("Leg timer"))
        XCTAssertTrue(timer.label.contains("Started at"))
        let previousLeg = app.buttons["previous-leg-tab"]
        XCTAssertTrue(previousLeg.waitForExistence(timeout: 2))
        previousLeg.tap()

        XCTAssertTrue(app.descendants(matching: .any)["previous-leg-drawer"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Previous leg"].exists)
        XCTAssertTrue(app.staticTexts["TARGET OUTCOMES"].exists)
        XCTAssertTrue(app.staticTexts["HEADING HISTORY"].exists)
        XCTAssertTrue(app.staticTexts["Reviewing history does not change the current leg, map, or timer."].exists)
        XCTAssertTrue(app.buttons["leg-start-checklist-chip"].exists)
        XCTAssertTrue(timer.label.contains("Started at"))

        let drawer = app.descendants(matching: .any)["previous-leg-drawer"]
        XCTAssertTrue(app.buttons["undo-reach"].exists)
        app.buttons["Close previous leg"].tap()
        XCTAssertFalse(drawer.exists)
        XCTAssertTrue(timer.label.contains("Started at"))
        XCTAssertTrue(app.buttons["previous-leg-tab"].label.contains("Previous"))
    }

    @MainActor
    func testClosedChecklistPreviousAndNextLegDisclosuresCoexist() throws {
        let app = launchCockpit(planData: try threeLegPlanData())

        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["reached-now"].tap()
        let collapseChecklist = app.buttons["leg-start-checklist-close"]
        if collapseChecklist.waitForExistence(timeout: 2) {
            collapseChecklist.tap()
        }

        XCTAssertTrue(app.buttons["leg-start-checklist-chip"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["previous-leg-tab"].exists)
        XCTAssertTrue(app.buttons["next-leg-preview"].exists)
    }

    @MainActor
    func testNextLegPreviewShowsPlannedInformationWithoutProgression() throws {
        let app = launchCockpit(planData: try threeLegPlanData())
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["reached-now"].tap()
        let collapseChecklist = app.buttons["leg-start-checklist-close"]
        if collapseChecklist.waitForExistence(timeout: 2) {
            collapseChecklist.tap()
        }
        let timer = app.descendants(matching: .any)["cockpit-time"]

        app.buttons["next-leg-preview"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["next-leg-card"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Next leg"].exists)
        XCTAssertTrue(app.staticTexts["Course"].exists)
        XCTAssertTrue(app.staticTexts["Altitude"].exists)
        XCTAssertTrue(app.staticTexts["Leg time"].exists)
        XCTAssertTrue(app.staticTexts["PLANNED COMMUNICATION"].exists)
        app.buttons["show-next-leg-on-map"].tap()
        XCTAssertTrue(timer.label.contains("Started at"))
        XCTAssertFalse(app.descendants(matching: .any)["navigation-complete"].exists)

        app.buttons["Close next leg"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["next-leg-card"].exists)
        XCTAssertTrue(timer.label.contains("Started at"))
        XCTAssertTrue(app.buttons["next-leg-preview"].exists)
    }

    @MainActor
    func testIdentifyThenReachPreservesActiveTimingAndCompletesFinalLeg() throws {
        let app = launchCockpit(planData: try oneLegPlanData())

        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["waypoint-identified"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Elapsed from leg start"))
        XCTAssertTrue(app.buttons["waypoint-reached"].isEnabled)
        app.buttons["waypoint-reached"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["navigation-complete"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["progression-notice-detail"].label.contains("No successor timer was started"))
    }

    @MainActor
    func testFinalReachPassesEveryUnreportedIdentificationPoint() throws {
        let plan = try fixtureData(named: "representative-v7", directory: "V7/Official")
        let app = launchCockpit(planData: plan)

        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        XCTAssertTrue(app.buttons["reached-now"].waitForExistence(timeout: 2))
        app.buttons["reached-now"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["navigation-complete"].waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["identification-point-reached"].exists)
        XCTAssertFalse(app.buttons["edit-identification-point-eta"].exists)
    }

    @MainActor
    func testManualProgressionLeavesSuccessorReadyUntilStart() throws {
        let app = launchCockpit(planData: try twoLegPlanData(), progressionPolicy: "manual")

        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["reached-now"].tap()

        let noticeTitle = app.staticTexts["progression-notice-title"]
        XCTAssertTrue(noticeTitle.waitForExistence(timeout: 2))
        XCTAssertTrue(noticeTitle.label.contains("next leg ready"))
        XCTAssertTrue(app.staticTexts["progression-notice-detail"].label.contains("no successor timing until Start next leg"))
        XCTAssertTrue(app.descendants(matching: .any)["leg-status"].label.contains("READY · SUCCESSOR TRACK-UP"))
        XCTAssertTrue(app.buttons["start-leg"].isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Not started"))
        app.buttons["start-leg"].tap()
        let timer = app.descendants(matching: .any)["cockpit-time"]
        expectation(
            for: NSPredicate(format: "label CONTAINS 'Elapsed from leg start'"),
            evaluatedWith: timer
        )
        waitForExpectations(timeout: 3)
    }

    @MainActor
    func testStartNowAmendmentFliesReplacementLeg() throws {
        try verifyAmendmentDeparture(startNow: true, landscape: false)
    }

    @MainActor
    func testScheduledAmendmentWaitsForManualStart() throws {
        try verifyAmendmentDeparture(startNow: false, landscape: false)
    }

    @MainActor
    func testScheduledAmendmentInIPadLandscape() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad landscape only")
        try verifyAmendmentDeparture(startNow: false, landscape: true)
    }

    @MainActor
    func testAutomaticRejoinContinuesOnTheOriginalRoute() throws {
        try verifyRejoin(manual: false, landscape: false)
    }

    @MainActor
    func testManualRejoinUsesTheRegularStartChecklist() throws {
        try verifyRejoin(manual: true, landscape: false)
    }

    @MainActor
    func testManualRejoinInIPadLandscape() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad landscape evidence")
        try verifyRejoin(manual: true, landscape: true)
    }

    @MainActor
    func testRejoinAtFinalWaypointUsesNavigationComplete() throws {
        let app = try launchRejoinCockpit(fixture: "final", manual: true, landscape: false)
        let reach = app.buttons["waypoint-reached"]
        captureAmendmentState("208-final-rejoin-approach", in: app)
        reach.tap()
        let complete = app.buttons["navigation-complete"]
        XCTAssertTrue(complete.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["start-leg"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].firstMatch.label.contains("Stopped at final arrival"))
        captureAmendmentState("208-final-arrival", in: app)
        complete.tap()
        XCTAssertTrue(app.buttons["recording-status"].label.contains("Navigation Complete"))
        captureAmendmentState("208-navigation-complete", in: app)
    }

    @MainActor
    private func verifyRejoin(manual: Bool, landscape: Bool) throws {
        let app = try launchRejoinCockpit(fixture: "partway", manual: manual, landscape: landscape)
        defer {
            if landscape {
                app.terminate()
                XCUIDevice.shared.orientation = .portrait
            }
        }
        let scenario = "208-" + (landscape ? "landscape-" : "") + (manual ? "manual" : "automatic")
        let reach = app.buttons["waypoint-reached"]
        XCTAssertTrue(reach.isHittable)
        assertPendingTapTarget(reach)
        captureAmendmentState(scenario + "-approach", in: app)
        reach.tap()

        let eta = app.descendants(matching: .any)["cockpit-eta"].firstMatch
        let timer = app.descendants(matching: .any)["cockpit-time"].firstMatch
        let retainedETA = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            eta.exists && eta.label.contains("06:00")
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [retainedETA], timeout: 8), .completed, eta.label)
        if manual {
            let start = app.buttons["start-leg"]
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            XCTAssertTrue(timer.label.contains("Not started"), timer.label)
            let destination = app.buttons["destination-eta-target"]
            let map = app.descendants(matching: .any)["aviation-map"]
            let fitting = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                guard destination.exists else { return false }
                let frame = destination.frame
                return !frame.isEmpty && map.frame.contains(CGPoint(x: frame.midX, y: frame.midY))
            }, object: nil)
            let fitted = XCTWaiter.wait(for: [fitting], timeout: 8)
            captureAmendmentState(scenario + "-ready", in: app)
            XCTAssertEqual(fitted, .completed, "The retained destination should be inside the Ready map.")
            start.tap()
        }

        let checklist = app.buttons["leg-start-checklist-close"]
        XCTAssertTrue(checklist.waitForExistence(timeout: 5))
        captureAmendmentState(scenario + "-checklist", in: app)
        closeStartChecklist(in: app)
        XCTAssertFalse(timer.label.contains("Not started"), timer.label)
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-altitude"].label.contains("800"))
        let currentFrequency = app.descendants(matching: .any).matching(
            NSPredicate(format: "(identifier == %@ OR identifier == %@) AND label CONTAINS %@",
                        "planned-now", "planned-frequencies", "Planned now")
        ).firstMatch
        XCTAssertTrue(currentFrequency.exists)
        XCTAssertTrue(currentFrequency.label.contains("118.40"))
        if UIDevice.current.userInterfaceIdiom == .phone {
            let route = app.descendants(matching: .any)["retained-leg-route"].firstMatch
            XCTAssertTrue(route.isHittable)
            XCTAssertTrue(route.label.contains("50%"))
        }
        captureAmendmentState(scenario + "-active", in: app)
        if UIDevice.current.userInterfaceIdiom == .pad && !landscape {
            eta.tap()
            let increase = app.buttons["+ 5 sec"]
            XCTAssertTrue(increase.waitForExistence(timeout: 5))
            captureAmendmentState(scenario + "-eta", in: app)
            increase.tap()
            app.buttons["Commit revised ETA"].tap()
            XCTAssertTrue(eta.label.contains("06:05"), eta.label)

            app.terminate()
            app.launchEnvironment.removeValue(forKey: "NAVIGATION_FLIGHT_UI_TEST_PLAN")
            app.launch()
            let resume = app.buttons["Continue Flight"]
            XCTAssertTrue(resume.waitForExistence(timeout: 8))
            resume.tap()
            XCTAssertTrue(eta.waitForExistence(timeout: 8))
            XCTAssertTrue(eta.label.contains("06:05"), eta.label)
            let destination = app.buttons["destination-eta-target"]
            let didRestoreMap = destination.waitForExistence(timeout: 20)
            captureAmendmentState(scenario + "-recovered", in: app)
            XCTAssertTrue(didRestoreMap, "The recovered map should show the retained destination.")
        }
        let pencil = app.buttons["amend-route"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 5))
        pencil.tap()
        let console = app.descendants(matching: .any)["route-amendment-console"].firstMatch
        XCTAssertTrue(console.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["amend-route"].exists)
        captureAmendmentState(scenario + "-retained-draft", in: app)
    }

    @MainActor
    private func launchRejoinCockpit(fixture: String, manual: Bool, landscape: Bool) throws -> XCUIApplication {
        try XCTSkipIf(true, "Owner deferred preparation arming to AP-11 (#235); disabled Arm is covered by the AP-01 workspace tests. Domain and recording amendment tests remain active.")
        var document = try XCTUnwrap(
            JSONSerialization.jsonObject(with: realFlightPlanData(named: "llhz-llib-via-jerusalem")) as? [String: Any]
        )
        var execution = try XCTUnwrap(document["execution"] as? [String: Any])
        var legs = try XCTUnwrap(execution["legs"] as? [[String: Any]])
        var timing = try XCTUnwrap(legs[0]["noWind"] as? [String: Any])
        timing["plannedDurationSeconds"] = 720
        legs[0]["noWind"] = timing
        execution["legs"] = legs
        document["execution"] = execution

        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] =
            try JSONSerialization.data(withJSONObject: document).base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_REJOIN"] = fixture
        app.launchEnvironment["NAVIGATION_FLIGHT_PROGRESSION_POLICY"] = manual ? "manual" : "automatic"
        app.launch()
        let start = app.buttons["start-leg"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        if landscape {
            XCUIDevice.shared.orientation = .landscapeLeft
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.frame.width > app.frame.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
            let sidebar = app.buttons["ToggleSidebar"].firstMatch
            if sidebar.exists, sidebar.label == "Hide Sidebar" { sidebar.tap() }
        }
        start.tap()
        closeStartChecklist(in: app)
        app.buttons["amend-route"].tap()
        let immediate = app.buttons["start-amendment-now"]
        XCTAssertTrue(immediate.waitForExistence(timeout: 8))
        immediate.tap()
        closeStartChecklist(in: app)
        let identify = app.buttons["waypoint-identified"]
        XCTAssertTrue(identify.waitForExistence(timeout: 8))
        identify.tap()
        let reach = app.buttons["waypoint-reached"]
        XCTAssertTrue(reach.waitForExistence(timeout: 5))
        reach.tap()
        if manual {
            XCTAssertTrue(start.waitForExistence(timeout: 5))
            start.tap()
        }
        closeStartChecklist(in: app)
        XCTAssertTrue(identify.waitForExistence(timeout: 5))
        assertDirectDestinationReach(in: app, stacked: UIDevice.current.userInterfaceIdiom == .phone)
        identify.tap()
        XCTAssertTrue(reach.waitForExistence(timeout: 5))
        return app
    }

    @MainActor
    func testFutureAmendmentReviewHidesStartNow() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] =
            try realFlightPlanData(named: "llhz-llib-via-jerusalem").base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_CONFIRMATION"] = "3"
        app.launch()

        let start = app.buttons["start-leg"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        closeStartChecklist(in: app)
        assertDirectDestinationReach(in: app, stacked: UIDevice.current.userInterfaceIdiom == .phone)

        let pencil = app.buttons["amend-route"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 8))
        pencil.tap()
        let confirm = app.buttons["arm-amendment"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 8))
        XCTAssertFalse(confirm.isEnabled)
        XCTAssertFalse(app.buttons["start-amendment-now"].exists)
        captureAmendmentState("207-future-departure-review", in: app)

    }

    @MainActor
    private func verifyAmendmentDeparture(startNow: Bool, landscape: Bool) throws {
        try XCTSkipIf(true, "Owner deferred preparation arming to AP-11 (#235); disabled Arm is covered by the AP-01 workspace tests. Domain and recording amendment tests remain active.")
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] =
            try realFlightPlanData(named: "llhz-llib-via-jerusalem").base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_CONFIRMATION"] = "2"
        app.launchEnvironment["NAVIGATION_FLIGHT_PROGRESSION_POLICY"] = startNow ? "automatic" : "manual"
        app.launch()
        let initialStart = app.buttons["start-leg"]
        XCTAssertTrue(initialStart.waitForExistence(timeout: 8))
        if landscape {
            XCUIDevice.shared.orientation = .landscapeLeft
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.frame.width > app.frame.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
            let sidebar = app.buttons["ToggleSidebar"].firstMatch
            if sidebar.exists, sidebar.label == "Hide Sidebar" { sidebar.tap() }
        }
        defer { if landscape { XCUIDevice.shared.orientation = .portrait } }
        initialStart.tap()
        closeStartChecklist(in: app)
        let pencil = app.buttons["amend-route"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 8))
        pencil.tap()
        let immediate = app.buttons["start-amendment-now"]
        XCTAssertTrue(immediate.waitForExistence(timeout: 8))
        XCTAssertTrue(immediate.isHittable)
        assertPendingTapTarget(immediate)
        let capture = landscape ? "207-landscape-" : "207-"
        captureAmendmentState(capture + "review", in: app)
        let timer = app.descendants(matching: .any)["cockpit-time"].firstMatch
        let identifyReplacement = app.buttons["waypoint-identified"]
        let nextLeg = app.buttons["next-leg-preview"]
        let positionCheck = app.descendants(matching: .any)["position-check-control"].firstMatch
        let startReplacement = app.buttons["start-leg"]
        if startNow {
            immediate.tap()
        } else {
            app.buttons["confirm-amendment-for-later"].tap()
            let identify = app.buttons["waypoint-identified"]
            XCTAssertTrue(identify.waitForExistence(timeout: 8))
            XCTAssertEqual(identify.label, "Identify departure point")
            captureAmendmentState(capture + "shortened", in: app)
            identify.tap()
            let reached = app.buttons["waypoint-reached"]
            XCTAssertTrue(reached.waitForExistence(timeout: 8))
            captureAmendmentState(capture + "departure-identified", in: app)
            reached.tap()
            XCTAssertTrue(startReplacement.waitForExistence(timeout: 8))
            XCTAssertTrue(timer.label.contains("Not started"), timer.label)
            XCTAssertFalse(identifyReplacement.exists)
            XCTAssertTrue(nextLeg.exists)
            XCTAssertFalse(app.buttons["choose-starting-leg"].exists)
            captureAmendmentState(capture + "ready", in: app)
            XCTAssertTrue(startReplacement.isHittable)
            startReplacement.tap()
        }
        XCTAssertTrue(identifyReplacement.waitForExistence(timeout: 8))
        closeStartChecklist(in: app)
        XCTAssertTrue(timer.frame.intersects(app.frame))
        XCTAssertTrue(positionCheck.exists)
        XCTAssertTrue(nextLeg.exists)
        if UIDevice.current.userInterfaceIdiom == .phone {
            let position = app.staticTexts["amendment-leg-position"]
            XCTAssertTrue(position.isHittable)
            XCTAssertEqual(position.label, "LEG 2 OF 26")
        }
        let heading = app.buttons["cockpit-heading"]
        let eta = app.descendants(matching: .any)["cockpit-eta"].firstMatch
        XCTAssertTrue(heading.label.contains("087°"), heading.label)
        XCTAssertTrue(eta.label.contains("03:20"), eta.label)
        assertDirectDestinationReach(in: app, stacked: UIDevice.current.userInterfaceIdiom == .phone)
        captureAmendmentState(capture + (startNow ? "immediate-active" : "scheduled-active"), in: app)

        if startNow, UIDevice.current.userInterfaceIdiom == .pad {
            nextLeg.tap()
            XCTAssertTrue(app.descendants(matching: .any)["next-leg-card"].waitForExistence(timeout: 4))
            app.buttons["Close next leg"].tap()
            app.buttons["open-frequency-plan"].tap()
            XCTAssertTrue(app.staticTexts["frequency-plan-title"].waitForExistence(timeout: 4))
            XCTAssertTrue(app.staticTexts["Amendment advisories and planned references"].exists)
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "123.50")).firstMatch.exists)
            captureAmendmentState(capture + "frequency-plan", in: app)
            app.buttons["close-frequency-plan"].tap()

            heading.tap()
            let headingDraft = app.descendants(matching: .any)["heading-draft"]
            XCTAssertTrue(headingDraft.waitForExistence(timeout: 4))
            XCTAssertTrue(headingDraft.label.contains("087°"))
            app.buttons["increase-heading"].tap()
            app.buttons["commit-heading"].tap()
            XCTAssertTrue(heading.label.contains("088°"), heading.label)
            eta.tap()
            let increaseETA = app.buttons["+ 5 sec"]
            XCTAssertTrue(increaseETA.waitForExistence(timeout: 4))
            captureAmendmentState(capture + "eta-editor", in: app)
            increaseETA.tap()
            app.buttons["Commit revised ETA"].tap()
            XCTAssertTrue(eta.label.contains("03:25"), eta.label)
        }

        identifyReplacement.tap()
        let reachReplacement = app.buttons["waypoint-reached"]
        XCTAssertTrue(reachReplacement.waitForExistence(timeout: 8))
        XCTAssertFalse(identifyReplacement.exists)
        XCTAssertTrue(reachReplacement.isHittable)
        assertPendingTapTarget(reachReplacement)
        captureAmendmentState(capture + "replacement-identified", in: app)
        if startNow {
            reachReplacement.tap()
            let newHeading = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                heading.exists && heading.label.contains("024°")
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [newHeading], timeout: 8), .completed)
            closeStartChecklist(in: app)
            XCTAssertTrue(eta.label.contains("05:40"), eta.label)
            assertDirectDestinationReach(in: app, stacked: UIDevice.current.userInterfaceIdiom == .phone)
            XCTAssertFalse(reachReplacement.exists)
            captureAmendmentState(capture + "second-active", in: app)
            app.terminate()
            app.launchEnvironment.removeValue(forKey: "NAVIGATION_FLIGHT_UI_TEST_PLAN")
            app.launch()
            let resume = app.buttons["Continue Flight"]
            XCTAssertTrue(resume.waitForExistence(timeout: 8))
            captureAmendmentState(capture + "recovery", in: app)
            resume.tap()
            XCTAssertTrue(heading.waitForExistence(timeout: 8))
            XCTAssertTrue(heading.label.contains("024°"), heading.label)
            XCTAssertTrue(eta.label.contains("05:40"), eta.label)
            captureAmendmentState(capture + "recovered-second-leg", in: app)
        }

    }

    @MainActor
    private func assertDirectDestinationReach(in app: XCUIApplication, stacked: Bool) {
        let identify = app.buttons["waypoint-identified"]
        let reach = app.buttons["reached-now"]
        XCTAssertTrue(reach.waitForExistence(timeout: 5))
        XCTAssertEqual(reach.label.lowercased(), "report destination reached")
        XCTAssertTrue(reach.isHittable)
        assertPendingTapTarget(reach)
        if stacked {
            XCTAssertGreaterThan(reach.frame.minY, identify.frame.maxY)
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.exists)
            XCTAssertLessThanOrEqual(reach.frame.maxY, tabBar.frame.minY)
        }
    }

    @MainActor
    func testFutureAmendmentRetriesAndRecoversItsShortenedLeg() throws {
        try verifyFutureAmendment(landscape: false)
    }

    @MainActor
    func testCompactPendingAmendmentKeepsLegIdentityAtLargerText() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone only")
        try verifyFutureAmendment(landscape: false, preferredContentSize: "UICTContentSizeCategoryAccessibilityM")
    }

    @MainActor
    func testFutureAmendmentInIPadLandscape() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad landscape only")
        try verifyFutureAmendment(landscape: true)
    }

    @MainActor
    func testUnreplayableAmendmentUsesTheIncompleteRecoveryGate() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] =
            try realFlightPlanData(named: "llhz-llib-via-jerusalem").base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_RECOVERY_STATE"] = "invalid-amendment"
        app.launch()
        let end = app.buttons["end-unavailable-amendment"]
        XCTAssertTrue(end.waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Continue Flight"].exists)
        captureAmendmentState("206-amendment-unavailable", in: app)
        end.tap()
        let confirmation = app.buttons["End as Incomplete"]
        XCTAssertTrue(confirmation.waitForExistence(timeout: 4))
        confirmation.tap()
        XCTAssertTrue(end.waitForNonExistence(timeout: 6))
    }

    @MainActor
    private func verifyFutureAmendment(landscape: Bool, preferredContentSize: String? = nil) throws {
        try XCTSkipIf(true, "Owner deferred preparation arming to AP-11 (#235); disabled Arm is covered by the AP-01 workspace tests. Domain and recording amendment tests remain active.")
        let app = XCUIApplication()
        let capturePrefix: String
        if let preferredContentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", preferredContentSize]
            capturePrefix = "206-larger-text-"
        } else {
            capturePrefix = landscape ? "206-landscape-" : "206-"
        }
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] =
            try realFlightPlanData(named: "llhz-llib-via-jerusalem").base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_CONFIRMATION"] = "1"
        app.launch()
        let start = app.buttons["start-leg"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        if landscape {
            XCUIDevice.shared.orientation = .landscapeLeft
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                app.frame.width > app.frame.height
            }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
        }
        start.tap()
        closeStartChecklist(in: app)
        let pencil = app.buttons["amend-route"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 5))
        pencil.tap()
        let confirm = app.buttons["confirm-amendment-for-later"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        XCTAssertTrue(confirm.isEnabled)
        captureAmendmentState(capturePrefix + "review", in: app)
        confirm.tap()
        XCTAssertTrue(app.staticTexts["amendment-saving"].waitForExistence(timeout: 2))
        captureAmendmentState(capturePrefix + "saving", in: app)
        let retry = app.buttons["retry-amendment-save"]
        XCTAssertTrue(retry.waitForExistence(timeout: 10))
        XCTAssertFalse(app.descendants(matching: .any)["pending-amendment-pencil"].firstMatch.exists)
        captureAmendmentState(capturePrefix + "retry", in: app)
        retry.tap()
        let pending = app.descendants(matching: .any)["pending-amendment-pencil"].firstMatch
        XCTAssertTrue(pending.waitForExistence(timeout: 10))
        assertPendingTapTarget(pending)
        assertCompactPendingDepartureHeader(in: app)
        let identify = app.buttons["waypoint-identified"]
        XCTAssertTrue(identify.exists)
        XCTAssertEqual(identify.label, "Identify departure point")
        captureAmendmentState(capturePrefix + "pending", in: app)

        let frequencyPlan = app.buttons["open-frequency-plan"]
        if frequencyPlan.exists { frequencyPlan.tap() }
        else { app.buttons["planned-now"].tap() }
        XCTAssertTrue(app.staticTexts["frequency-plan-title"].waitForExistence(timeout: 4))
        app.buttons["close-frequency-plan"].tap()
        identify.tap()
        let reached = app.buttons["waypoint-reached"]
        XCTAssertTrue(reached.waitForExistence(timeout: 5))
        XCTAssertEqual(reached.label, "Report reached")
        captureAmendmentState(capturePrefix + "identified", in: app)

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "NAVIGATION_FLIGHT_UI_TEST_PLAN")
        app.launchEnvironment.removeValue(forKey: "NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_CONFIRMATION")
        app.launch()
        let resume = app.buttons["Continue Flight"]
        XCTAssertTrue(resume.waitForExistence(timeout: 6))
        captureAmendmentState(capturePrefix + "recovery-gate", in: app)
        resume.tap()
        XCTAssertTrue(pending.waitForExistence(timeout: 8))
        XCTAssertTrue(reached.exists)
        assertCompactPendingDepartureHeader(in: app)
        XCTAssertFalse(app.staticTexts["Review legs"].exists)
        captureAmendmentState(capturePrefix + "recovered", in: app)
    }

    @MainActor
    private func assertCompactPendingDepartureHeader(in app: XCUIApplication) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let position = app.staticTexts["pending-departure-leg-position"]
        let route = app.descendants(matching: .any)["pending-departure-leg-route"].firstMatch
        XCTAssertEqual(position.label, "LEG 1 OF 25")
        let routeLabel = route.label.replacingOccurrences(of: "\u{2068}", with: "")
            .replacingOccurrences(of: "\u{2069}", with: "")
        XCTAssertEqual(routeLabel, "From שפיים to Departure point")
        XCTAssertTrue(position.isHittable)
        XCTAssertTrue(route.isHittable)
        let mapTools = app.buttons["Map tools"].firstMatch
        assertPendingTapTarget(mapTools)
    }

    @MainActor
    private func assertPendingTapTarget(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let frame = element.frame
        // XCUI frame conversion can represent an exact 44-point extent just below 44.
        XCTAssertGreaterThanOrEqual(frame.width, 43.99, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.height, 43.99, file: file, line: line)
    }

    @MainActor
    func testPendingAmendmentManagementAndOriginalDestinationReport() throws {
        try verifyPendingAmendmentManagement(landscape: false)
    }

    @MainActor
    func testPendingAmendmentManagementInIPadLandscape() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad landscape only")
        try verifyPendingAmendmentManagement(landscape: true)
    }

    @MainActor
    private func verifyPendingAmendmentManagement(landscape: Bool) throws {
        let app = try launchPendingAmendmentForManagement(landscape: landscape)
        let prefix = landscape ? "209-landscape-" : "209-"
        let pencil = app.buttons["pending-amendment-pencil"]
        XCTAssertEqual(pencil.label, "Amend route, armed, not flying")
        assertPendingTapTarget(pencil)
        let identify = app.buttons["waypoint-identified"]
        XCTAssertEqual(identify.label, "Identify departure point")

        pencil.tap()
        let report = app.buttons["report-original-destination"]
        let replace = app.buttons["replace-pending-amendment"]
        let cancel = app.buttons["cancel-pending-amendment"]
        XCTAssertTrue(report.waitForExistence(timeout: 4))
        captureAmendmentState(prefix + "management", in: app)
        let done = app.buttons["dismiss-pending-amendment-management"]
        if done.exists { done.tap() }
        else { app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.45)).tap() }
        XCTAssertTrue(report.waitForNonExistence(timeout: 4))
        XCTAssertTrue(pencil.isHittable)

        pencil.tap()
        XCTAssertTrue(report.waitForExistence(timeout: 4))
        report.tap()
        let keep = app.buttons["keep-pending-amendment"]
        let commit = app.buttons["confirm-pending-amendment-management"]
        XCTAssertTrue(keep.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Report original destination reached?"].exists)
        XCTAssertEqual(commit.label, "Cancel and record reach")
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Ramat")).firstMatch.exists)
        captureAmendmentState(prefix + "original-destination", in: app)
        keep.tap()
        XCTAssertTrue(keep.waitForNonExistence(timeout: 3))
        XCTAssertEqual(identify.label, "Identify departure point")

        pencil.tap()
        XCTAssertTrue(replace.waitForExistence(timeout: 4))
        replace.tap()
        let keepSaved = app.buttons["keep-saved-amendment"]
        let confirmReplacement = app.buttons["confirm-amendment-replacement"]
        XCTAssertTrue(keepSaved.waitForExistence(timeout: 4))
        XCTAssertTrue(confirmReplacement.isEnabled)
        captureAmendmentState(prefix + "replacement-review", in: app)
        keepSaved.tap()
        XCTAssertTrue(pencil.waitForExistence(timeout: 4))
        XCTAssertEqual(identify.label, "Identify departure point")
        pencil.tap()
        XCTAssertTrue(replace.waitForExistence(timeout: 4))
        replace.tap()
        XCTAssertTrue(confirmReplacement.waitForExistence(timeout: 4))
        confirmReplacement.tap()
        XCTAssertTrue(pencil.waitForExistence(timeout: 6))

        pencil.tap()
        XCTAssertTrue(cancel.waitForExistence(timeout: 4))
        cancel.tap()
        XCTAssertTrue(keep.waitForExistence(timeout: 4))
        XCTAssertEqual(commit.label, "Cancel amendment")
        captureAmendmentState(prefix + "cancel-confirmation", in: app)
        keep.tap()

        pencil.tap()
        XCTAssertTrue(report.waitForExistence(timeout: 4))
        report.tap()
        XCTAssertTrue(commit.waitForExistence(timeout: 4))
        commit.tap()
        let retry = app.buttons["retry-pending-amendment-management"]
        XCTAssertTrue(retry.waitForExistence(timeout: 5))
        captureAmendmentState(prefix + "original-destination-retry", in: app)
        retry.tap()
        XCTAssertTrue(pencil.waitForNonExistence(timeout: 6))
        let successorChecklist = app.buttons["leg-start-checklist-close"]
        if successorChecklist.waitForExistence(timeout: 2) { successorChecklist.tap() }
        let undo = app.buttons["undo-reach"]
        if undo.waitForExistence(timeout: 4) {
            XCTAssertTrue(undo.isHittable)
            undo.tap()
            XCTAssertTrue(pencil.waitForExistence(timeout: 5))
        } else {
            XCTFail("Expected ordinary reach Undo after cancel and reach")
        }
    }

    @MainActor
    func testPendingAmendmentDepartureUsesNormalReportControls() throws {
        let app = try launchPendingAmendmentForManagement()
        let pendingPencil = app.buttons["pending-amendment-pencil"]
        pendingPencil.tap()
        let replace = app.buttons["replace-pending-amendment"]
        XCTAssertTrue(replace.waitForExistence(timeout: 4))
        replace.tap()
        let confirm = app.buttons["confirm-amendment-replacement"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 4))
        confirm.tap()
        XCTAssertTrue(pendingPencil.waitForExistence(timeout: 5))

        let identify = app.buttons["waypoint-identified"]
        XCTAssertEqual(identify.label, "Identify departure point")
        identify.tap()
        let reached = app.buttons["waypoint-reached"]
        XCTAssertTrue(reached.waitForExistence(timeout: 5))
        reached.tap()
        XCTAssertTrue(pendingPencil.waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Report original destination reached?"].exists)
        let amendedIdentify = app.buttons["waypoint-identified"]
        XCTAssertTrue(amendedIdentify.waitForExistence(timeout: 5))
        XCTAssertNotEqual(amendedIdentify.label, "Identify departure point")
        captureAmendmentState("209-actual-departure-active", in: app)
        closeStartChecklist(in: app)
        let amend = app.buttons["amend-route"]
        XCTAssertTrue(amend.waitForExistence(timeout: 5))
        amend.tap()
        XCTAssertTrue(app.descendants(matching: .any)["route-amendment-console"].firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testCompactPendingAmendmentConfirmationAtLargerText() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .phone, "iPhone only")
        let app = try launchPendingAmendmentForManagement(
            preferredContentSize: "UICTContentSizeCategoryAccessibilityM"
        )
        app.buttons["pending-amendment-pencil"].tap()
        let report = app.buttons["report-original-destination"]
        XCTAssertTrue(report.waitForExistence(timeout: 5))
        report.tap()
        let keep = app.buttons["keep-pending-amendment"]
        let commit = app.buttons["confirm-pending-amendment-management"]
        XCTAssertTrue(keep.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Report original destination reached?"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Ramat")).firstMatch.exists)
        XCTAssertTrue(keep.isHittable)
        XCTAssertTrue(commit.isHittable)
        captureAmendmentState("209-larger-text-original-destination", in: app)
        keep.tap()
        XCTAssertTrue(app.buttons["pending-amendment-pencil"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testReplacementReviewPreservesManualCameraAcrossPresentationChanges() throws {
        try verifyReplacementReviewCamera(landscape: false)
    }

    @MainActor
    func testReplacementReviewPreservesManualCameraInIPadLandscape() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPad landscape only")
        try verifyReplacementReviewCamera(landscape: true)
    }

    @MainActor
    private func verifyReplacementReviewCamera(landscape: Bool) throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = try launchPendingAmendmentForManagement(landscape: landscape, captureCamera: true)
        let pendingPencil = app.buttons["pending-amendment-pencil"]
        func openReplacement() {
            pendingPencil.tap()
            let replace = app.buttons["replace-pending-amendment"]
            XCTAssertTrue(replace.waitForExistence(timeout: 4))
            replace.tap()
            XCTAssertTrue(app.buttons["keep-saved-amendment"].waitForExistence(timeout: 4))
        }
        func captureCameraState(_ name: String, in app: XCUIApplication) {
            // Device captures preserve the full rotated screen; app snapshots can crop
            // a newly rotated iPad to its prior portrait bounds in Xcode 27.2.
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        openReplacement()
        let map = app.descendants(matching: .any)["aviation-map"].firstMatch
        let initial = try settledCameraValues(of: map)
        // Reference iPad can start at the map's maximum zoom; zoom out in that case.
        map.pinch(withScale: initial[2] >= 12 ? 0.7 : 1.4, velocity: initial[2] >= 12 ? -1 : 1)
        map.rotate(.pi / 10, withVelocity: 1)
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7))
            .press(forDuration: 0.1, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)))
        let manual = try settledCameraValues(of: map)
        XCTAssertEqual(manual[5], 1, "Gestures must claim camera ownership")
        XCTAssertNotEqual(initial[0], manual[0], "Pan must change the observed center")
        XCTAssertNotEqual(initial[2], manual[2], "Pinch must change the observed zoom")
        XCTAssertNotEqual(initial[3], manual[3], "Rotation must change the observed bearing")
        captureCameraState("r2-manual-camera", in: app)

        app.buttons["amend-route"].tap()
        XCTAssertTrue(pendingPencil.waitForExistence(timeout: 4))
        assertCamera(manual, remainsOn: map)
        captureCameraState("r2-hidden-camera", in: app)
        openReplacement()
        assertCamera(manual, remainsOn: map)
        captureCameraState("r2-reopened-camera", in: app)

        app.buttons.matching(identifier: "edit-amendment-leg").firstMatch.tap()
        let panel = app.descendants(matching: .any)["amendment-chart-panel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 4))
        assertCamera(manual, remainsOn: map)
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: map.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.7)))
        let editorCamera = try settledCameraValues(of: map)
        XCTAssertNotEqual(manual[0], editorCamera[0], "Map remains pannable beside the editor")
        captureCameraState("r2-editor-camera", in: app)
        panel.buttons["Cancel"].tap()
        XCTAssertTrue(panel.waitForNonExistence(timeout: 4))
        assertCamera(editorCamera, remainsOn: map)
        captureCameraState("r2-editor-closed-camera", in: app)
    }

    @MainActor
    private func cameraValues(of map: XCUIElement) throws -> [Double] {
        let value = try XCTUnwrap(map.value as? String)
        let components = value.split(separator: "|").compactMap { Double($0) }
        XCTAssertEqual(components.count, 6, "Expected center latitude/longitude, zoom, bearing, pitch and ownership: \(value)")
        guard components.count == 6 else { throw NSError(domain: "CameraFixture", code: 1) }
        return components
    }

    @MainActor
    private func settledCameraValues(of map: XCUIElement) throws -> [Double] {
        var last = try cameraValues(of: map)
        var stableSince = Date()
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let current = try? self.cameraValues(of: map) else { return false }
            if zip(current, last).contains(where: { abs($0 - $1) > 0.000001 }) {
                last = current
                stableSince = Date()
            }
            return Date().timeIntervalSince(stableSince) >= 0.6
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [settled], timeout: 6), .completed, "Wait for actual gesture deceleration to finish")
        return try cameraValues(of: map)
    }

    @MainActor
    private func assertCamera(_ expected: [Double], remainsOn map: XCUIElement) {
        // Observe beyond the next run-loop/layout pass so an asynchronously scheduled fit fails.
        let deadline = Date().addingTimeInterval(1)
        let stable = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            guard let actual = try? self.cameraValues(of: map) else { return false }
            for (a, b) in zip(actual, expected) { XCTAssertEqual(a, b, accuracy: 0.000001) }
            return Date() >= deadline
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [stable], timeout: 4), .completed)
        let attachment = XCTAttachment(string: "Expected camera: \(expected)\nObserved: \(map.value ?? "missing")")
        attachment.name = "R2 retained MapLibre camera"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func launchPendingAmendmentForManagement(
        landscape: Bool = false, preferredContentSize: String? = nil, captureCamera: Bool = false
    ) throws -> XCUIApplication {
        let app = XCUIApplication()
        if let preferredContentSize {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", preferredContentSize]
        }
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = try crossingAmendmentPlanData().base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_CONFIRMATION"] = "1"
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_WORKSPACE"] = "armed"
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_MANAGEMENT_FAILURE"] = "1"
        if captureCamera { app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_CAMERA"] = "1" }
        app.launch()
        let start = app.buttons["start-leg"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        if landscape {
            XCUIDevice.shared.orientation = .landscapeLeft
            let rotated = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in app.frame.width > app.frame.height }, object: nil)
            XCTAssertEqual(XCTWaiter.wait(for: [rotated], timeout: 5), .completed)
        }
        start.tap()
        closeStartChecklist(in: app)
        app.buttons["amend-route"].tap()
        let retry = app.buttons["retry-amendment-save"]
        XCTAssertTrue(retry.waitForExistence(timeout: 8))
        retry.tap()
        XCTAssertTrue(app.buttons["pending-amendment-pencil"].waitForExistence(timeout: 8))
        return app
    }

    @MainActor
    func testManualAmendmentVoiceOverNamesFlightTimeFieldsInOrder() throws {
        let voiceOver = XCUIDevice.shared.voiceOverService
        let wasEnabled = voiceOver.isEnabled
        if wasEnabled { try voiceOver.disable() }
        defer {
            if wasEnabled && !voiceOver.isEnabled { try? voiceOver.enable() }
            if !wasEnabled && voiceOver.isEnabled { try? voiceOver.disable() }
        }

        let app = try launchManualAmendmentReview()
        let console = app.descendants(matching: .any)["route-amendment-console"]
        let panel = app.descendants(matching: .any)["amendment-chart-panel"].firstMatch
        openAmendmentCheck(in: app, console: console)
        XCTAssertTrue(panel.waitForExistence(timeout: 4))

        try voiceOver.enable()
        var speech: [String] = []
        defer {
            let attachment = XCTAttachment(string: speech.joined(separator: "\n"))
            attachment.name = "Manual amendment VoiceOver speech"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        if let current = try? voiceOver.currentSpeech().utterance { speech.append(current) }
        for _ in 0..<38 {
            let utterance = try voiceOver.moveForward().utterance
            speech.append(utterance)
            if utterance.localizedCaseInsensitiveContains("Flight time seconds") { break }
        }

        let minutes = try XCTUnwrap(speech.firstIndex {
            $0.localizedCaseInsensitiveContains("Flight time minutes")
        })
        let seconds = try XCTUnwrap(speech.firstIndex {
            $0.localizedCaseInsensitiveContains("Flight time seconds")
        })
        XCTAssertLessThan(minutes, seconds)
    }

    @MainActor
    func testManualAmendmentRejectsOutOfRangeExactEntryWhileTyping() throws {
        let app = try launchManualAmendmentReview()
        let console = app.descendants(matching: .any)["route-amendment-console"]
        let panel = app.descendants(matching: .any)["amendment-chart-panel"].firstMatch
        openAmendmentCheck(in: app, console: console)
        let heading = app.textFields["amendment-field-heading"]
        let seconds = app.textFields["amendment-field-seconds"]
        let done = app.buttons["amendment-keyboard-done"]

        tapChartPanelControl(heading, in: panel)
        heading.typeText("435")
        XCTAssertEqual(heading.value as? String, "43")
        heading.typeText("\u{8}\u{8}360")
        XCTAssertEqual(heading.value as? String, "360")
        heading.typeText("\u{8}\u{8}\u{8}435")
        XCTAssertEqual(heading.value as? String, "43")
        done.tap()
        XCTAssertEqual(heading.value as? String, "043")

        tapChartPanelControl(seconds, in: panel)
        seconds.typeText("78")
        XCTAssertEqual(seconds.value as? String, "7")
        seconds.typeText("\u{8}59")
        XCTAssertEqual(seconds.value as? String, "59")
        seconds.typeText("\u{8}\u{8}78")
        XCTAssertEqual(seconds.value as? String, "7")
        done.tap()
        XCTAssertEqual(seconds.value as? String, "07")
    }

    @MainActor
    func testManualAmendmentEntersCuesAndChecksWithoutChangingPilotValues() throws {
        let app = try launchManualAmendmentReview()
        let iPad = app.frame.width > 700
        let console = app.descendants(matching: .any)["route-amendment-console"]
        let panel = app.descendants(matching: .any)["amendment-chart-panel"].firstMatch
        let edit = app.buttons.matching(identifier: "edit-amendment-leg").firstMatch
        let check = app.buttons.matching(identifier: "edit-amendment-leg").firstMatch
        let save = app.buttons["save-amendment-leg-values"]
        let cancel = app.buttons["back-to-amendment-review"]
        let eta = app.staticTexts["amendment-leg-planned"].label
        captureAmendmentState("manual-review-portrait", in: app)

        openAmendmentCheck(in: app, console: console)
        let estimate = app.descendants(matching: .any)["amendment-reference-estimate"]
        XCTAssertTrue(estimate.waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Not entered"].firstMatch.exists)
        captureAmendmentState("manual-blank-check", in: app)
        tapChartPanelControl(cancel, in: panel)

        tapAmendmentControl(edit, in: console)
        XCTAssertTrue(panel.waitForExistence(timeout: 4))
        captureAmendmentState("manual-cue-editor-top", in: app)
        tapChartPanelControl(save, in: panel)
        XCTAssertTrue(app.staticTexts["amendment-error-heading"].waitForExistence(timeout: 4))
        captureAmendmentState("manual-required-values", in: app)

        let done = app.buttons["amendment-keyboard-done"]
        func type(_ text: String, in fieldName: String) {
            let field = app.textFields["amendment-field-\(fieldName)"]
            tapChartPanelControl(field, in: panel)
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 4))
            field.typeText(text)
            XCTAssertEqual(field.value as? String, text)
            XCTAssertTrue(done.isHittable)
            if fieldName == "seconds" { captureAmendmentState("manual-keyboard", in: app) }
            done.tap()
            XCTAssertTrue(done.waitForNonExistence(timeout: 4))
        }
        type("150", in: "heading")
        type("05", in: "minutes")
        type("13", in: "seconds")

        if iPad {
            tapChartPanelControl(app.buttons["toggle-amendment-cues"], in: panel)
            type("2500", in: "altitude")
            type("123.50", in: "frequency")
            type("Road junction", in: "visualReference")

            tapChartPanelControl(app.buttons["inspect-amendment-original"], in: panel)
            XCTAssertTrue(app.staticTexts["Inspect original leg is active"].waitForExistence(timeout: 4))
            captureAmendmentState("manual-inspection", in: app)
            tapChartPanelControl(app.buttons["choose-original-amendment-leg"], in: panel)
            let original = app.buttons.matching(identifier: "choose-amendment-original-row").firstMatch
            XCTAssertFalse(app.buttons.matching(identifier: "choose-amendment-proposed-row").firstMatch.exists)
            tapChartPanelControl(original, in: panel)
            XCTAssertTrue(app.staticTexts["Full planned flight time"].exists)
            captureAmendmentState("manual-original-reference", in: app)
            tapChartPanelControl(app.buttons["close-amendment-original"], in: panel)
            XCTAssertTrue(app.descendants(matching: .any)["amendment-original-summary"].exists)
            XCTAssertEqual(app.textFields["amendment-field-visualReference"].value as? String, "Road junction")
            captureAmendmentState("manual-restored-editor", in: app)
            tapChartPanelControl(app.buttons["toggle-amendment-cues"], in: panel)
        }

        tapChartPanelControl(app.buttons["check-working-amendment-leg"], in: panel)
        XCTAssertTrue(estimate.waitForExistence(timeout: 4))
        XCTAssertTrue(estimate.label.contains("Magnetic course"))
        XCTAssertTrue(estimate.label.contains("No wind"))
        XCTAssertTrue(app.staticTexts["05:13"].firstMatch.exists)
        XCTAssertEqual(app.staticTexts["amendment-leg-planned"].label, eta)
        captureAmendmentState("manual-check-portrait", in: app)

        app.buttons["amend-route"].tap()
        XCTAssertFalse(estimate.exists)
        app.buttons["amend-route"].tap()
        XCTAssertTrue(estimate.waitForExistence(timeout: 4))
        XCTAssertEqual(app.textFields["amendment-field-heading"].value as? String, "150")
        if iPad {
            XCTAssertTrue(app.descendants(matching: .any)["amendment-original-summary"].exists)
        }

        tapChartPanelControl(save, in: panel)
        XCTAssertTrue(panel.waitForNonExistence(timeout: 4))
        XCTAssertTrue(edit.value.debugDescription.contains("05:13"))
        captureAmendmentState("manual-saved-review", in: app)
        openAmendmentCheck(in: app, console: console)
        XCTAssertTrue(estimate.waitForExistence(timeout: 4))
        captureAmendmentState("manual-saved-check", in: app)
        tapChartPanelControl(cancel, in: panel)
        if iPad {
            defer {
                app.terminate()
                XCUIDevice.shared.orientation = .portrait
            }
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(app.buttons.matching(identifier: "edit-amendment-leg").firstMatch.waitForExistence(timeout: 4))
            captureAmendmentState("manual-review-landscape", in: app)
            tapAmendmentControl(edit, in: console)
            XCTAssertTrue(panel.waitForExistence(timeout: 4))
            captureAmendmentState("manual-editor-landscape", in: app)
        }
    }

    @MainActor
    private func tapChartPanelControl(
        _ element: XCUIElement, in panel: XCUIElement, beforeTap: () -> Void = {}
    ) {
        let nestedViewport = panel.scrollViews.firstMatch
        let viewport = nestedViewport.exists ? nestedViewport : panel
        for _ in 0..<10 {
            let frame = element.frame
            let visible = viewport.frame.insetBy(dx: 0, dy: 3).contains(CGPoint(x: frame.midX, y: frame.midY))
            let inFooter = frame.minY >= viewport.frame.maxY && frame.maxY <= panel.frame.maxY
            if element.isHittable, visible || inFooter {
                beforeTap()
                element.tap()
                return
            }
            if element.exists && element.frame.midY < viewport.frame.midY {
                viewport.swipeDown(velocity: .slow)
            } else {
                viewport.swipeUp(velocity: .slow)
            }
        }
        XCTFail("Could not reveal chart panel control: \(element), panel: \(viewport.frame)")
    }

    @MainActor
    func testManualAmendmentChartSelectsLegsAndDisambiguatesTheirRoles() throws {
        let app = try launchManualAmendmentReview()
        guard app.frame.width > 700 else { throw XCTSkip("These chart coordinates use the canonical iPad fixture.") }
        let map = app.descendants(matching: .any)["aviation-map"]
        let panel = app.descendants(matching: .any)["amendment-chart-panel"].firstMatch
        func tapMap(x: CGFloat, y: CGFloat) {
            map.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
        }

        tapMap(x: 0.51, y: 0.815)
        let heading = app.textFields["amendment-field-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 4))
        XCTAssertEqual(panel.frame.width, 338, accuracy: 1)
        XCTAssertEqual(panel.frame.minX, 446, accuracy: 1)
        XCTAssertEqual(panel.frame.minY, 232, accuracy: 2)
        captureAmendmentState("manual-editor-chart", in: app)
        app.buttons["Increase by 1 degree"].press(forDuration: 0.8)
        let adjusted = Int(heading.value as? String ?? "")
        XCTAssertGreaterThanOrEqual(adjusted ?? 0, 2)
        tapMap(x: 0.18, y: 0.75)
        XCTAssertTrue(heading.exists)
        tapChartPanelControl(app.buttons["back-to-amendment-review"], in: panel)

        tapMap(x: 0.426, y: 0.953)
        let originals = app.buttons.matching(identifier: "choose-amendment-original-row")
        let proposed = app.buttons.matching(identifier: "choose-amendment-proposed-row")
        XCTAssertTrue(originals.firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(proposed.firstMatch.exists)
        captureAmendmentState("manual-review-overlap", in: app)
        tapChartPanelControl(app.buttons["cancel-amendment-leg-choice"], in: panel)

        tapMap(x: 0.426, y: 0.78)
        XCTAssertTrue(app.staticTexts["Full planned flight time"].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["\u{2068}שפיים\u{2069} → \u{2068}רידינג\u{2069}"].exists)
        captureAmendmentState("manual-review-original", in: app)
        tapChartPanelControl(app.buttons["close-amendment-original"], in: panel)

        app.buttons["choose-amendment-leg"].tap()
        XCTAssertTrue(proposed.firstMatch.waitForExistence(timeout: 4))
        XCTAssertTrue(originals.firstMatch.exists)
        captureAmendmentState("manual-named-chooser", in: app)
        tapChartPanelControl(app.buttons["cancel-amendment-leg-choice"], in: panel)
        app.buttons["back-to-amendment-drawing"].tap()
        let selected = app.staticTexts["selected-amendment-point"]
        let selectionBefore = selected.exists ? selected.label : nil
        app.buttons["inspect-amendment-leg"].tap()
        XCTAssertTrue(app.staticTexts["Inspect original leg is active"].waitForExistence(timeout: 4))
        tapMap(x: 0.18, y: 0.75)
        XCTAssertTrue(app.staticTexts["No original leg here. Try another chart location."].exists)
        tapMap(x: 0.426, y: 0.574)
        XCTAssertTrue(originals.firstMatch.waitForExistence(timeout: 4))
        XCTAssertGreaterThanOrEqual(originals.count, 2)
        XCTAssertFalse(proposed.firstMatch.exists)
        captureAmendmentState("manual-inspection-overlap", in: app)
        tapChartPanelControl(app.buttons["cancel-amendment-leg-choice"], in: panel)
        tapChartPanelControl(app.buttons["cancel-amendment-inspection"], in: panel)
        XCTAssertEqual(selected.exists ? selected.label : nil, selectionBefore)
    }

    @MainActor
    func testManualAmendmentChooserIdentifiesRepeatedOriginalOccurrences() throws {
        let fixture = try realFlightPlanData(named: "llhz-llib-via-jerusalem")
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture) as? [String: Any])
        var navigation = try XCTUnwrap(document["navigation"] as? [String: Any])
        var route = try XCTUnwrap(navigation["route"] as? [String: Any])
        var waypoints = try XCTUnwrap(route["waypoints"] as? [[String: Any]])
        waypoints[2]["name"] = waypoints[0]["name"]
        waypoints[3]["name"] = waypoints[1]["name"]
        waypoints[2].removeValue(forKey: "reportingPointReference")
        waypoints[3].removeValue(forKey: "reportingPointReference")
        route["waypoints"] = waypoints
        navigation["route"] = route
        document["navigation"] = navigation
        let execution = try XCTUnwrap(document["execution"] as? [String: Any])
        let legs = try XCTUnwrap(execution["legs"] as? [[String: Any]])
        let firstTiming = try XCTUnwrap(legs[0]["noWind"] as? [String: Any])
        let thirdTiming = try XCTUnwrap(legs[2]["noWind"] as? [String: Any])
        let firstSeconds = try XCTUnwrap(firstTiming["plannedDurationSeconds"] as? Int)
        let thirdSeconds = try XCTUnwrap(thirdTiming["plannedDurationSeconds"] as? Int)
        XCTAssertNotEqual(firstSeconds, thirdSeconds)

        let app = launchCockpit(planData: try JSONSerialization.data(withJSONObject: document))
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["amend-route"].tap()
        let console = app.descendants(matching: .any)["route-amendment-console"]
        tapAmendmentControl(app.buttons["inspect-amendment-leg"], in: console)
        let panel = app.descendants(matching: .any)["amendment-chart-panel"].firstMatch
        tapChartPanelControl(app.buttons["choose-original-amendment-leg"], in: panel)
        let originals = app.buttons.matching(identifier: "choose-amendment-original-row")
        let first = originals.containing(NSPredicate(format: "label BEGINSWITH %@", "Leg 1 ·")).firstMatch
        let third = originals.containing(NSPredicate(format: "label BEGINSWITH %@", "Leg 3 ·")).firstMatch
        XCTAssertTrue(first.exists)
        XCTAssertTrue(third.exists)
        captureAmendmentState("manual-repeated-original-chooser", in: app)
        tapChartPanelControl(third, in: panel)
        let duration = String(format: "%02d:%02d", thirdSeconds / 60, thirdSeconds % 60)
        XCTAssertTrue(panel.staticTexts[duration].waitForExistence(timeout: 4))
        captureAmendmentState("manual-repeated-original-reference", in: app)
    }

    @MainActor
    func testManualAmendmentShowsUnavailableEstimate() throws {
        let app = try launchManualAmendmentReview(unavailable: true)
        let console = app.descendants(matching: .any)["route-amendment-console"]
        openAmendmentCheck(in: app, console: console)
        XCTAssertTrue(app.staticTexts["amendment-estimate-unavailable"].waitForExistence(timeout: 4))
        XCTAssertFalse(app.descendants(matching: .any)["amendment-reference-estimate"].exists)
        captureAmendmentState("manual-check-unavailable", in: app)
    }

    @MainActor
    func testManualAmendmentReviewSupportsLargerText() throws {
        let app = try launchManualAmendmentReview(contentSize: "UICTContentSizeCategoryAccessibilityM")
        let console = app.descendants(matching: .any)["route-amendment-console"]
        let check = app.buttons.matching(identifier: "edit-amendment-leg").firstMatch
        XCTAssertGreaterThanOrEqual(check.frame.height, 44)
        tapAmendmentControl(check, in: console) {
            captureAmendmentState("manual-review-larger-text", in: app)
        }
        let panel = app.descendants(matching: .any)["amendment-chart-panel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 4))
        tapChartPanelControl(app.buttons["back-to-amendment-review"], in: panel) {
            captureAmendmentState("manual-editor-larger-text", in: app)
        }
    }

    @MainActor
    func testAmendmentModeSettingsShowsSelectedPreference() {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = "settings-205-\(UUID().uuidString)"
        app.launch()
        openSettings(in: app)
        app.buttons["settings-amend-route"].tap()
        let manual = app.buttons["amendment-mode-manual"]
        let assisted = app.buttons["amendment-mode-assisted"]
        XCTAssertTrue(manual.isSelected)
        captureAmendmentState("manual-mode-settings", in: app)
        assisted.tap()
        let selected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "selected == true"), object: assisted)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
    }

    @MainActor
    private func launchManualAmendmentReview(unavailable: Bool = false, contentSize: String? = nil) throws -> XCUIApplication {
        var plan = try realFlightPlanData(named: "llhz-llib-via-jerusalem")
        if unavailable {
            // A positive but very large plan-wide speed rounds both plotted estimates to zero.
            var document = try XCTUnwrap(JSONSerialization.jsonObject(with: plan) as? [String: Any])
            var navigation = try XCTUnwrap(document["navigation"] as? [String: Any])
            var parameters = try XCTUnwrap(navigation["parameters"] as? [String: Any])
            let speed = 1_000_000.0
            parameters["planningAirspeedKnots"] = speed
            navigation["parameters"] = parameters
            document["navigation"] = navigation
            var execution = try XCTUnwrap(document["execution"] as? [String: Any])
            var legs = try XCTUnwrap(execution["legs"] as? [[String: Any]])
            for index in legs.indices {
                var timing = try XCTUnwrap(legs[index]["noWind"] as? [String: Any])
                timing["plannedGroundSpeedKnots"] = speed
                legs[index]["noWind"] = timing
            }
            execution["legs"] = legs
            document["execution"] = execution
            plan = try JSONSerialization.data(withJSONObject: document)
        }
        let app = launchCockpit(planData: plan, preferredContentSizeCategory: contentSize)
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["amend-route"].tap()
        app.buttons["toggle-amendment-plotting"].tap()
        chooseAmendmentWaypoint("שפיים", in: app)
        let console = app.descendants(matching: .any)["route-amendment-console"]
        if contentSize == nil {
            app.descendants(matching: .any)["aviation-map"]
                .coordinate(withNormalizedOffset: CGVector(dx: 0.74, dy: 0.43)).tap()
        } else {
            tapAmendmentControl(app.buttons["pick-amendment-point"], in: console)
            app.buttons["Use map center"].tap()
        }
        XCTAssertTrue(app.buttons["amendment-draft-point"].firstMatch.waitForExistence(timeout: 4))
        chooseAmendmentWaypoint("תל יונה", in: app)
        let finish = app.buttons["finish-amendment-here"]
        tapAmendmentControl(finish, in: console)
        XCTAssertTrue(app.buttons.matching(identifier: "edit-amendment-leg").firstMatch.waitForExistence(timeout: 4))
        return app
    }

    @MainActor
    private func tapAmendmentControl(
        _ element: XCUIElement, in console: XCUIElement, scrollDown: Bool = true, beforeTap: () -> Void = {}
    ) {
        let compact = console.frame.width < 430
        for attempt in 0..<14 {
            if element.exists {
                let frame = element.frame
                let viewport = console.frame
                let isReviewRow = ["edit-amendment-leg", "edit-amendment-leg"].contains(element.identifier)
                let bottomClearance = compact && !isReviewRow ? 65.0 : 0.0
                let bottom = viewport.maxY - bottomClearance
                if element.isHittable, frame.midY >= viewport.minY, frame.midY < bottom {
                    beforeTap()
                    element.tap()
                    return
                }
                scrollAmendmentConsole(console, down: frame.midY >= bottom)
            } else {
                scrollAmendmentConsole(console, down: attempt < 7 ? scrollDown : !scrollDown)
            }
        }
        XCTFail("Could not reveal amendment control: \(element), console: \(console.frame)")
    }

    @MainActor
    private func scrollAmendmentConsole(_ console: XCUIElement, down: Bool) {
        let upperY = 0.10
        let lowerY = console.frame.height < 150 ? 0.85 : min(0.65, 1 - 55 / console.frame.height)
        let upper = console.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: upperY))
        let lower = console.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: lowerY))
        let start = down ? lower : upper
        let end = down ? upper : lower
        start.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
    }

    @MainActor
    func testRouteAmendmentDraftCanPlotPauseResumeAndRecoverDeparture() throws {
        let app = launchCockpit(
            planData: try realFlightPlanData(named: "llhz-llib-via-jerusalem"),
            progressionPolicy: "manual"
        )
        XCTAssertFalse(app.buttons["amend-route"].exists)
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)

        let pencil = app.buttons["amend-route"]
        let pause = app.buttons["amend-route"]
        let play = app.buttons["amend-route"]
        let map = app.descendants(matching: .any)["aviation-map"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(pencil.frame.width, 44)
        XCTAssertGreaterThanOrEqual(pencil.frame.height, 44)
        let restingMapHeight = map.frame.height
        captureAmendmentState("entry", in: app)
        pencil.tap()
        XCTAssertTrue(app.staticTexts["Choose departure"].waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(pause.frame.width, 44)
        XCTAssertGreaterThanOrEqual(pause.frame.height, 44)
        XCTAssertEqual(map.frame.height, restingMapHeight, accuracy: 1)
        let timer = app.staticTexts["amendment-leg-elapsed"]
        let eta = app.staticTexts["amendment-leg-planned"]
        XCTAssertTrue(timer.isHittable)
        XCTAssertTrue(eta.isHittable)
        let initialTimer = timer.label
        let currentETA = eta.label
        captureAmendmentState("empty", in: app)

        chooseAmendmentWaypoint("שפיים", in: app)
        XCTAssertTrue(app.buttons["choose-amendment-rejoin"].waitForExistence(timeout: 3))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.73, dy: 0.43)).tap()
        let selected = app.staticTexts["selected-amendment-point"]
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
        XCTAssertEqual(selected.label, "Point 1")
        XCTAssertTrue(timer.isHittable)
        XCTAssertNotEqual(timer.label, initialTimer)
        XCTAssertEqual(eta.label, currentETA)
        captureAmendmentState("selected", in: app)

        pause.tap()
        XCTAssertTrue(play.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["reached-now"].exists)
        XCTAssertFalse(selected.exists)
        captureAmendmentState("paused", in: app)
        let frequencyPlan = app.buttons["open-frequency-plan"]
        if frequencyPlan.exists {
            frequencyPlan.tap()
        } else {
            app.buttons["planned-now"].tap()
        }
        XCTAssertTrue(app.staticTexts["frequency-plan-title"].waitForExistence(timeout: 3))
        app.buttons["close-frequency-plan"].tap()
        play.tap()
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
        XCTAssertEqual(selected.label, "Point 1")

        app.buttons["move-amendment-point"].tap()
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.55)).tap()
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
        app.buttons["remove-amendment-point"].tap()
        XCTAssertFalse(selected.exists)
        app.buttons["undo-amendment-plot"].tap()
        XCTAssertTrue(selected.waitForExistence(timeout: 3))

        app.buttons["choose-amendment-rejoin"].tap()
        chooseAmendmentWaypoint("תל יונה", in: app)
        let confirmRejoin = app.buttons["confirm-amendment-rejoin"]
        XCTAssertTrue(confirmRejoin.waitForExistence(timeout: 3))
        XCTAssertTrue(confirmRejoin.isHittable)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Leg ")).allElementsBoundByIndex
            .contains(where: \.isHittable))
        captureAmendmentState("rejoin", in: app)
        confirmRejoin.tap()
        app.buttons["review-amendment-legs"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "edit-amendment-leg").firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(timer.isHittable)
        XCTAssertEqual(eta.label, currentETA)
        captureAmendmentState("review-timing", in: app)
        pause.tap()
        XCTAssertTrue(play.waitForExistence(timeout: 3))
        play.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "edit-amendment-leg").firstMatch.waitForExistence(timeout: 3))
        pause.tap()
        app.buttons["reached-now"].tap()
        XCTAssertTrue(play.waitForExistence(timeout: 3))
        play.tap()
        XCTAssertTrue(app.staticTexts["Update departure"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Current leg · not started"].isHittable)
        XCTAssertFalse(timer.exists)
        XCTAssertFalse(eta.exists)
        captureAmendmentState("stale", in: app)
        tapAmendmentControl(app.buttons["replace-amendment-departure"],
                            in: app.descendants(matching: .any)["route-amendment-console"].firstMatch)
        chooseAmendmentWaypoint("רידינג", in: app)
        XCTAssertTrue(selected.waitForExistence(timeout: 3))

        app.buttons["discard-amendment-draft"].tap()
        let dialog = app.buttons["Keep editing"]
        XCTAssertTrue(dialog.waitForExistence(timeout: 3))
        captureAmendmentState("discard", in: app)
        dialog.tap()
        XCTAssertTrue(selected.waitForExistence(timeout: 3))
        app.buttons["discard-amendment-draft"].tap()
        app.alerts.buttons["Discard draft"].tap()
        XCTAssertTrue(pencil.waitForExistence(timeout: 3))
        XCTAssertTrue(pencil.isEnabled)
        XCTAssertFalse(selected.exists)
    }

    @MainActor
    func testRouteSequenceShowsAllPointsAndFinishHereOpensReview() throws {
        let app = launchCockpit(planData: try realFlightPlanData(named: "llhz-llib-via-jerusalem"))
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["amend-route"].tap()
        app.buttons["toggle-amendment-plotting"].tap()
        chooseAmendmentWaypoint("שפיים", in: app)

        let map = app.descendants(matching: .any)["aviation-map"]
        let points = app.buttons.matching(identifier: "amendment-draft-point")
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.72, dy: 0.40)).tap()
        XCTAssertTrue(points.element(boundBy: 0).waitForExistence(timeout: 3))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.79, dy: 0.60)).tap()
        XCTAssertTrue(points.element(boundBy: 1).waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["choose-amendment-rejoin"].waitForExistence(timeout: 3))
        captureAmendmentState("off-route-return", in: app)
        chooseAmendmentWaypoint("תל יונה", in: app)

        let departure = app.buttons["amendment-departure-point"]
        XCTAssertEqual(points.count, 3)
        XCTAssertEqual(points.element(boundBy: 0).label, "Point 1, Via")
        XCTAssertEqual(points.element(boundBy: 1).label, "Point 2, Via")
        let last = points.element(boundBy: 2)
        XCTAssertTrue(last.label.contains("תל יונה"))
        XCTAssertLessThan(departure.frame.minX, points.element(boundBy: 0).frame.minX)
        XCTAssertLessThan(points.element(boundBy: 1).frame.minX, last.frame.minX)
        XCTAssertEqual(app.buttons["finish-amendment-here"].label, "Finish here")
        captureAmendmentState("finish-here", in: app)

        points.element(boundBy: 0).tap()
        XCTAssertEqual(app.staticTexts["selected-amendment-point"].label, "Point 1")
        XCTAssertTrue(app.buttons["finish-amendment-here"].label.contains("תל יונה"))
        captureAmendmentState("select-earlier-point", in: app)
        points.element(boundBy: 2).tap()
        app.buttons["finish-amendment-here"].tap()

        XCTAssertTrue(app.buttons.matching(identifier: "edit-amendment-leg").firstMatch.waitForExistence(timeout: 3))
        let legs = app.buttons.matching(identifier: "edit-amendment-leg")
        XCTAssertEqual(legs.count, 3)
        XCTAssertTrue(legs.element(boundBy: 2).label.contains("תל יונה"))
        XCTAssertTrue(app.staticTexts["amendment-leg-elapsed"].isHittable)
        captureAmendmentState("finish-review", in: app)

        app.buttons["back-to-amendment-drawing"].tap()
        app.buttons["undo-amendment-plot"].tap()
        XCTAssertTrue(app.buttons["finish-amendment-here"].exists)
        XCTAssertEqual(points.count, 3)
        XCTAssertFalse(app.buttons["amendment-return-point"].exists)

        if app.frame.width > 700 {
            points.element(boundBy: 1).tap()
            XCUIDevice.shared.orientation = .landscapeLeft
            XCTAssertTrue(app.staticTexts["selected-amendment-point"].waitForExistence(timeout: 3))
            XCTAssertTrue(app.buttons["finish-amendment-here"].label.contains("תל יונה"))
            captureAmendmentState("landscape-selected", in: app)
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }
    }

    @MainActor
    func testUseMapCenterPlotsBesideAnExistingAmendmentPoint() throws {
        let app = launchCockpit(planData: try realFlightPlanData(named: "llhz-llib-via-jerusalem"))
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["amend-route"].tap()
        app.buttons["toggle-amendment-plotting"].tap()
        chooseAmendmentWaypoint("שפיים", in: app)

        let map = app.descendants(matching: .any)["aviation-map"]
        let nearCenter = map.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .withOffset(CGVector(dx: 12, dy: 0))
        nearCenter.tap()
        let points = app.buttons.matching(identifier: "amendment-draft-point")
        XCTAssertTrue(points.element(boundBy: 0).waitForExistence(timeout: 3))
        app.buttons["pick-amendment-point"].tap()
        app.buttons["Use map center"].tap()
        XCTAssertTrue(points.element(boundBy: 1).waitForExistence(timeout: 3))
        XCTAssertEqual(points.count, 2)
    }

    @MainActor
    func testUseMapCenterCanFinishAtAnExactRouteWaypoint() throws {
        let app = launchCockpit(planData: try realFlightPlanData(named: "llhz-llib-via-jerusalem"))
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        let map = app.descendants(matching: .any)["aviation-map"]
        let from = map.coordinate(withNormalizedOffset: CGVector(dx: 0.60, dy: 0.7))
        let to = map.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.7))
        from.press(forDuration: 0.05, thenDragTo: to)
        let destination = app.buttons["show-destination-waypoint"]
        XCTAssertTrue(destination.waitForExistence(timeout: 3))
        destination.tap()

        app.buttons["amend-route"].tap()
        app.buttons["toggle-amendment-plotting"].tap()
        chooseAmendmentWaypoint("שפיים", in: app)
        app.buttons["pick-amendment-point"].tap()
        app.buttons["Use map center"].tap()
        let finish = app.buttons["finish-amendment-here"]
        XCTAssertTrue(finish.waitForExistence(timeout: 3))
        finish.tap()
        XCTAssertTrue(app.buttons.matching(identifier: "edit-amendment-leg").firstMatch.waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.matching(identifier: "edit-amendment-leg").allElementsBoundByIndex
            .contains { $0.label.contains("רידינג") })
    }

    @MainActor
    func testAmendmentShowsPastETAWhileKeepingDrawingAvailable() throws {
        let plan = try realFlightPlanData(named: "llhz-llib-via-jerusalem")
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: plan) as? [String: Any])
        var execution = try XCTUnwrap(document["execution"] as? [String: Any])
        var legs = try XCTUnwrap(execution["legs"] as? [[String: Any]])
        var timing = try XCTUnwrap(legs.first?["noWind"] as? [String: Any])
        // The first leg's sole annotation is the frequency at its start.
        timing["plannedDurationSeconds"] = 12
        legs[0]["noWind"] = timing
        execution["legs"] = legs
        document["execution"] = execution

        let app = launchCockpit(planData: try JSONSerialization.data(withJSONObject: document))
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["amend-route"].tap()

        let eta = app.staticTexts["amendment-leg-planned"]
        XCTAssertTrue(eta.label.contains("00:12"))
        XCTAssertTrue(app.staticTexts["Over planned"].waitForExistence(timeout: 18))
        XCTAssertTrue(app.staticTexts["amendment-leg-elapsed"].isHittable)
        app.buttons["toggle-amendment-plotting"].tap()
        XCTAssertTrue(app.buttons["pick-amendment-point"].isHittable)
        XCTAssertTrue(app.buttons["amend-route"].isHittable)
        captureAmendmentState("eta-passed", in: app)
    }

    @MainActor
    func testDraftCanSelectAnInteriorDepartureAndKeepItWhenRotated() throws {
        let app = launchCockpit(planData: try realFlightPlanData(named: "llhz-llib-via-jerusalem"))
        guard app.frame.width > 700 else { throw XCTSkip("iPad portrait and landscape evidence") }
        defer {
            app.terminate()
            XCUIDevice.shared.orientation = .portrait
        }
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["amend-route"].tap()
        app.buttons["toggle-amendment-plotting"].tap()
        let map = app.descendants(matching: .any)["aviation-map"]
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.50, dy: 0.50)).tap()
        let departure = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Departure · Leg 1")).firstMatch
        XCTAssertTrue(departure.waitForExistence(timeout: 3))
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.70, dy: 0.44)).tap()
        let point = app.staticTexts["selected-amendment-point"]
        XCTAssertTrue(point.waitForExistence(timeout: 3))
        app.buttons["choose-amendment-rejoin"].tap()
        chooseAmendmentWaypoint("תל יונה", in: app)
        app.buttons["confirm-amendment-rejoin"].tap()
        captureAmendmentState("portrait-bypass", in: app)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(point.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(point.frame.minX, map.frame.midX)
        captureAmendmentState("landscape-selected", in: app)
    }

    @MainActor
    func testRouteAmendmentDisambiguatesCrossingLegsOnMap() throws {
        let app = launchCockpit(planData: try crossingAmendmentPlanData())
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["amend-route"].tap()
        app.buttons["toggle-amendment-plotting"].tap()
        let map = app.descendants(matching: .any)["aviation-map"]
        map.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.50)).tap()
        captureAmendmentState("crossing", in: app)
        let heading = app.staticTexts["Choose departure leg"]
        XCTAssertTrue(heading.waitForExistence(timeout: 3))
        let firstLeg = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Leg 1 · Kadima")).firstMatch
        let laterLeg = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Leg 3 · West")).firstMatch
        XCTAssertTrue(firstLeg.isHittable)
        XCTAssertTrue(laterLeg.isHittable)
        let console = app.descendants(matching: .any)["route-amendment-console"]
        XCTAssertTrue(console.frame.insetBy(dx: -1, dy: -1).contains(laterLeg.frame))
        laterLeg.tap()
        let departure = app.buttons["amendment-departure-point"]
        XCTAssertTrue(departure.waitForExistence(timeout: 3))
        XCTAssertTrue(departure.label.contains("Leg 3"))
    }

    @MainActor
    func testFinishingNearACrossingRequiresChoosingTheReturnLeg() throws {
        let app = launchCockpit(planData: try crossingAmendmentPlanData())
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        app.buttons["amend-route"].tap()
        app.buttons["toggle-amendment-plotting"].tap()
        chooseAmendmentWaypoint("Kadima", in: app)

        let map = app.descendants(matching: .any)["aviation-map"]
        let nearCrossing = map.coordinate(withNormalizedOffset: CGVector(dx: 0.48, dy: 0.50))
            .withOffset(CGVector(dx: 1, dy: 0))
        nearCrossing.tap()
        XCTAssertTrue(app.buttons["amendment-draft-point"].firstMatch.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["finish-amendment-here"].exists)
        app.buttons["choose-amendment-rejoin"].tap()
        nearCrossing.tap()
        XCTAssertTrue(app.staticTexts["Choose return leg"].waitForExistence(timeout: 3))
        let options = app.buttons.matching(identifier: "amendment-leg-occurrence")
        XCTAssertEqual(options.count, 2)
        captureAmendmentState("crossing-return", in: app)
        options.element(boundBy: 1).tap()
        XCTAssertTrue(app.buttons["confirm-amendment-rejoin"].waitForExistence(timeout: 3))
    }

    private func crossingAmendmentPlanData() throws -> Data {
        let data = try realFlightPlanData(named: "llhz-llib-via-jerusalem")
        var document = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var navigation = try XCTUnwrap(document["navigation"] as? [String: Any])
        var route = try XCTUnwrap(navigation["route"] as? [String: Any])
        var waypoints = try XCTUnwrap(route["waypoints"] as? [[String: Any]])
        let from = try XCTUnwrap(waypoints[0]["position"] as? [String: Double])
        let to = try XCTUnwrap(waypoints[1]["position"] as? [String: Double])
        let west = ["latitude": try XCTUnwrap(from["latitude"]), "longitude": try XCTUnwrap(to["longitude"])]
        let east = ["latitude": try XCTUnwrap(to["latitude"]), "longitude": try XCTUnwrap(from["longitude"])]
        for (index, name) in ["Kadima", "Ramat", "West", "Aviel"].enumerated() {
            waypoints[index]["name"] = name
            waypoints[index].removeValue(forKey: "reportingPointReference")
        }
        waypoints[2]["position"] = west
        waypoints[3]["position"] = east
        route["waypoints"] = waypoints
        navigation["route"] = route
        document["navigation"] = navigation
        return try JSONSerialization.data(withJSONObject: document)
    }

    @MainActor
    func testAmendmentWorkspaceKeepsBoundaryAcrossUntouchedAndEditedToggles() throws {
        try verifyAmendmentWorkspaceToggle(landscape: false)
    }

    @MainActor
    func testAmendmentWorkspaceKeepsBoundaryInLandscape() throws {
        guard UIDevice.current.userInterfaceIdiom == .pad else { throw XCTSkip("iPad landscape only") }
        try verifyAmendmentWorkspaceToggle(landscape: true)
    }

    @MainActor
    func testAmendmentWorkspaceLargerTextKeepsActionsReachable() throws {
        try verifyAmendmentWorkspaceToggle(landscape: false, largerText: true)
    }

    @MainActor
    func testAmendmentWorkspaceReducedMotionKeepsBoundary() throws {
        try XCTSkipUnless(UIAccessibility.isReduceMotionEnabled, "The test runner must inherit the simulator Reduce Motion setting; device interaction verifies the app when it does not")
        try verifyAmendmentWorkspaceToggle(landscape: false)
    }

    @MainActor
    private func verifyAmendmentWorkspaceToggle(landscape: Bool, largerText: Bool = false) throws {
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = try crossingAmendmentPlanData().base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_WORKSPACE"] = "A"
        if largerText { app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"] }
        app.launch()
        let start = app.buttons["start-leg"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        if largerText {
            start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            if !start.waitForNonExistence(timeout: 3) {
                start.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap()
            }
        } else {
            start.tap()
        }
        if largerText {
            let close = app.buttons["leg-start-checklist-close"]
            if close.exists { close.tap() }
        } else {
            closeStartChecklist(in: app)
        }
        if landscape { XCUIDevice.shared.orientation = .landscapeLeft }
        let pencil = app.buttons["amend-route"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 8))
        let map = app.descendants(matching: .any)["aviation-map"].firstMatch
        let before = map.frame
        captureAmendmentState("ap01-before-\(landscape ? "landscape" : "portrait")", in: app)
        if UIDevice.current.userInterfaceIdiom == .pad && !landscape && !largerText {
            assertPortraitConsoleRenderedBoundary(mapFrame: before, in: app)
        }
        pencil.tap()
        let arm = app.buttons["arm-amendment"]
        XCTAssertTrue(arm.waitForExistence(timeout: 8))
        XCTAssertFalse(arm.isEnabled)
        XCTAssertFalse(app.buttons["start-amendment-now"].exists)
        XCTAssertFalse(app.buttons["pause-route-amendment"].exists)
        XCTAssertEqual(map.frame, before)
        let plot = app.buttons["toggle-amendment-plotting"]
        XCTAssertEqual(plot.value as? String, "Off")
        captureAmendmentState("ap01-open-\(landscape ? "landscape" : "portrait")", in: app)
        if UIDevice.current.userInterfaceIdiom == .pad && !landscape && !largerText {
            assertPortraitConsoleRenderedBoundary(mapFrame: before, in: app)
        }
        let leg = app.buttons.matching(identifier: "edit-amendment-leg").firstMatch
        XCTAssertTrue(leg.waitForExistence(timeout: 5))
        leg.tap()
        XCTAssertTrue(app.descendants(matching: .any)["amendment-chart-panel"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(map.frame, before)
        captureAmendmentState("ap01-editor-\(landscape ? "landscape" : "portrait")", in: app)
        pencil.tap()
        XCTAssertTrue(arm.waitForNonExistence(timeout: 5))
        XCTAssertEqual(map.frame, before)
        if largerText {
            let console = app.descendants(matching: .any)["compact-cockpit-console"].firstMatch
            for _ in 0..<4 where !app.buttons["reached-now"].isHittable { console.swipeUp() }
        }
        XCTAssertTrue(app.buttons["waypoint-identified"].isHittable)
        XCTAssertTrue(app.buttons["reached-now"].isHittable)
        captureAmendmentState("ap01-closed-\(landscape ? "landscape" : "portrait")", in: app)
        pencil.tap()
        XCTAssertTrue(arm.waitForExistence(timeout: 5))
        XCTAssertEqual(plot.value as? String, "Off")
        XCTAssertEqual(map.frame, before)
        XCTAssertTrue(app.descendants(matching: .any)["amendment-chart-panel"].firstMatch.exists)
    }

    /// The map frame alone cannot detect a console background painting outside its frame.
    /// This disposable chart fixture has a distinct left edge above the console.
    @MainActor
    private func assertPortraitConsoleRenderedBoundary(mapFrame: CGRect, in app: XCUIApplication) {
        let screenshot = app.screenshot().image
        guard let image = screenshot.cgImage else {
            XCTFail("Missing screenshot pixels")
            return
        }
        let bytesPerRow = image.width * 4
        var pixels = [UInt8](repeating: 0, count: bytesPerRow * image.height)
        let rendered = pixels.withUnsafeMutableBytes { bytes in
            guard let context = CGContext(
                data: bytes.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            ) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            return true
        }
        XCTAssertTrue(rendered)
        guard rendered else { return }
        let scaleX = CGFloat(image.width) / app.frame.width
        let scaleY = CGFloat(image.height) / app.frame.height
        let x = Int(2 * scaleX)
        func rgb(at screenY: CGFloat) -> [Int]? {
            let y = Int((screenY - app.frame.minY) * scaleY)
            guard (0..<image.height).contains(y), (0..<image.width).contains(x) else { return nil }
            let offset = y * bytesPerRow + x * 4
            return pixels[offset..<(offset + 3)].map(Int.init)
        }
        guard let above = rgb(at: mapFrame.maxY - 2), let below = rgb(at: mapFrame.maxY + 2) else {
            XCTFail("Console boundary must be inside the screenshot")
            return
        }
        let difference = zip(above, below).map { abs($0 - $1) }.max() ?? 0
        XCTAssertGreaterThan(difference, 12, "The fixture chart must remain visible above the console background")
    }

    @MainActor
    func testAmendmentLifecycleBadgeStaysArmedUntilManualStart() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = try crossingAmendmentPlanData().base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_WORKSPACE"] = "armed"
        app.launchEnvironment["NAVIGATION_FLIGHT_PROGRESSION_POLICY"] = "manual"
        app.launch()
        let start = app.buttons["start-leg"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        closeStartChecklist(in: app)
        let pending = app.buttons["pending-amendment-pencil"]
        XCTAssertTrue(pending.waitForExistence(timeout: 8))
        XCTAssertEqual(pending.value as? String, "Armed · awaiting departure")
        captureAmendmentState("ap01-armed", in: app)
        app.buttons["reached-now"].tap()
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        let pencil = app.descendants(matching: .any)["flying-amendment-pencil"].firstMatch
        XCTAssertTrue(pencil.waitForExistence(timeout: 5))
        XCTAssertEqual(pencil.value as? String, "Armed · awaiting Start leg")
        captureAmendmentState("ap01-awaiting-start-leg", in: app)
        start.tap()
        closeStartChecklist(in: app)
        XCTAssertEqual(pencil.value as? String, "Flying · read-only")
        captureAmendmentState("ap01-flying", in: app)
    }

    @MainActor
    func testAmendmentUnsavedIndicatorIsIndependentFromReadyAndVisibility() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = try crossingAmendmentPlanData().base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_WORKSPACE"] = "armed"
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_AMENDMENT_CONFIRMATION"] = "1"
        app.launch()
        let start = app.buttons["start-leg"]
        XCTAssertTrue(start.waitForExistence(timeout: 8))
        start.tap()
        closeStartChecklist(in: app)
        let pencil = app.buttons["amend-route"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 8))
        pencil.tap()
        XCTAssertTrue(app.staticTexts["amendment-save-failed"].waitForExistence(timeout: 8))
        XCTAssertEqual(pencil.value as? String, "Ready · not armed, changes not saved")
        captureAmendmentState("ap01-ready-unsaved-open", in: app)
        let map = app.descendants(matching: .any)["aviation-map"].firstMatch
        let frame = map.frame
        pencil.tap()
        XCTAssertTrue(app.staticTexts["amendment-save-failed"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(pencil.value as? String, "Ready · not armed, changes not saved")
        XCTAssertEqual(map.frame, frame)
        XCTAssertTrue(app.buttons["waypoint-identified"].isHittable)
        captureAmendmentState("ap01-ready-unsaved-closed", in: app)
    }

    @MainActor
    func testAmendmentIncompletePencilRetainsDraftWithoutDiscardDialog() throws {
        let app = launchCockpit(planData: try crossingAmendmentPlanData())
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        let pencil = app.buttons["amend-route"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 5))
        pencil.tap()
        chooseAmendmentWaypoint("Kadima", in: app)
        XCTAssertEqual(pencil.value as? String, "Incomplete draft")
        captureAmendmentState("ap01-incomplete-open", in: app)
        pencil.tap()
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertEqual(pencil.value as? String, "Incomplete draft")
        captureAmendmentState("ap01-incomplete-closed", in: app)
        pencil.tap()
        XCTAssertEqual(app.buttons["toggle-amendment-plotting"].value as? String, "Off")
        XCTAssertTrue(app.buttons["amendment-departure-point"].exists)
    }

    @MainActor
    func testAmendmentWorkspaceUntouchedExitAndPlottingSwitch() throws {
        let app = launchCockpit(planData: try crossingAmendmentPlanData())
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        let pencil = app.buttons["amend-route"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 5))
        pencil.tap()
        let plot = app.buttons["toggle-amendment-plotting"]
        XCTAssertTrue(plot.waitForExistence(timeout: 5))
        captureAmendmentState("ap01-none-open", in: app)
        plot.tap()
        XCTAssertEqual(plot.value as? String, "On")
        pencil.tap()
        XCTAssertEqual(pencil.value as? String, "")
        captureAmendmentState("ap01-none-closed", in: app)
        XCTAssertFalse(app.buttons["resume-route-amendment"].exists)
        pencil.tap()
        XCTAssertEqual(plot.value as? String, "Off")
        XCTAssertGreaterThanOrEqual(pencil.frame.width, 44)
        XCTAssertGreaterThanOrEqual(pencil.frame.height, 44)
    }

    @MainActor
    func testRouteAmendmentExposesWaypointAndResumeControlsWithAccessibilityText() throws {
        let app = launchCockpit(
            planData: try realFlightPlanData(named: "llhz-llib-via-jerusalem"),
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        let startLeg = app.buttons["start-leg"]
        startLeg.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        if startLeg.exists { startLeg.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.5)).tap() }
        let close = app.buttons["leg-start-checklist-close"]
        if close.exists { close.tap() }
        let pencil = app.buttons["amend-route"]
        XCTAssertTrue(pencil.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(pencil.frame.width, 44)
        XCTAssertGreaterThanOrEqual(pencil.frame.height, 44)
        pencil.tap()
        chooseAmendmentWaypoint("שפיים", in: app)
        captureAmendmentState("accessibility-text", in: app)
        app.buttons["amend-route"].tap()
        let play = app.buttons["amend-route"]
        XCTAssertEqual(play.label, "Amend route")
        XCTAssertGreaterThanOrEqual(play.frame.width, 44)
        XCTAssertGreaterThanOrEqual(play.frame.height, 44)
        play.tap()
        XCTAssertTrue(app.buttons["amendment-departure-point"].waitForExistence(timeout: 3))
    }

    @MainActor
    private func openAmendmentCheck(in app: XCUIApplication, console: XCUIElement) {
        tapAmendmentControl(app.buttons.matching(identifier: "edit-amendment-leg").firstMatch, in: console)
        let panel = app.descendants(matching: .any)["amendment-chart-panel"].firstMatch
        XCTAssertTrue(panel.waitForExistence(timeout: 4))
        tapChartPanelControl(app.buttons["check-working-amendment-leg"], in: panel)
    }

    @MainActor
    private func chooseAmendmentWaypoint(_ name: String, in app: XCUIApplication) {
        let plotting = app.buttons["toggle-amendment-plotting"]
        if plotting.exists, plotting.value as? String == "Off", plotting.isEnabled { plotting.tap() }
        let menu = app.buttons["pick-amendment-point"]
        if !menu.isHittable {
            app.descendants(matching: .any)["route-amendment-console"].swipeUp()
        }
        menu.tap()
        let point = app.buttons.matching(
            NSPredicate(format: "identifier == %@ AND label CONTAINS %@", "amendment-route-waypoint", name)
        ).firstMatch
        XCTAssertTrue(point.waitForExistence(timeout: 3))
        point.tap()
        XCTAssertTrue(point.waitForNonExistence(timeout: 4))
    }

    @MainActor
    private func captureAmendmentState(_ name: String, in app: XCUIApplication) {
        let needsFullScreen = name.contains("landscape") || name.contains("keyboard")
        let screenshot = needsFullScreen ? XCUIScreen.main.screenshot() : app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Route amendment - \(name)"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testAdaptiveCockpitKeepsOperationalActionsAvailableAcrossOrientations() throws {
        let app = launchCockpit(planData: try oneLegPlanData())
        app.buttons["start-leg"].tap()
        let collapseChecklist = app.buttons["Collapse start of leg checklist"]
        if collapseChecklist.waitForExistence(timeout: 1) {
            collapseChecklist.tap()
        }

        for orientation in [UIDeviceOrientation.portrait, .landscapeLeft] {
            XCUIDevice.shared.orientation = orientation
            XCTAssertTrue(app.buttons["waypoint-identified"].waitForExistence(timeout: 2))
            XCTAssertTrue(app.buttons["reached-now"].isEnabled)
            XCTAssertTrue(app.descendants(matching: .any)["aviation-map"].exists)
            XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].exists)
            XCTAssertTrue(app.descendants(matching: .any)["cockpit-eta"].exists)
        }

        XCUIDevice.shared.orientation = .portrait
    }

    @MainActor
    func testCompactChecklistPresentsAsDismissibleSheet() throws {
        let app = launchCockpit(planData: try oneLegPlanData())

        app.buttons["start-leg"].tap()

        let checklist = app.descendants(matching: .any)["leg-start-checklist"]
        XCTAssertTrue(checklist.waitForExistence(timeout: 2))
        let done = app.buttons["leg-start-checklist-close"]
        let noted = app.buttons["leg-start-checklist-noted"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(noted.exists)
        XCTAssertGreaterThanOrEqual(done.frame.width, 44)
        XCTAssertGreaterThanOrEqual(done.frame.height, 44)
        XCTAssertGreaterThanOrEqual(noted.frame.minX - checklist.frame.minX, 19.5)
        XCTAssertGreaterThanOrEqual(checklist.frame.maxX - noted.frame.maxX, 19.5)
        done.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        let chip = app.buttons["leg-start-checklist-chip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.label, "Checklist")
    }

    @MainActor
    func testChecklistActionsRemainReachableWithAccessibilityText() throws {
        let app = launchCockpit(
            planData: try oneLegPlanData(),
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )

        app.buttons["start-leg"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["leg-start-checklist"].waitForExistence(timeout: 2))
        let done = app.buttons["leg-start-checklist-close"]
        let noted = app.buttons["leg-start-checklist-noted"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(done.frame.width, 44)
        XCTAssertGreaterThanOrEqual(done.frame.height, 44)
        XCTAssertTrue(noted.exists)
        XCTAssertGreaterThanOrEqual(noted.frame.height, 44)
    }

    @MainActor
    func testCompactRestingCockpitKeepsMapAndOperationalScanVisibleWithoutScrolling() throws {
        let app = launchCockpit(planData: try oneLegPlanData())
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)

        let requiredElements = [
            ("map", app.descendants(matching: .any)["aviation-map"]),
            ("heading", app.buttons["cockpit-heading"]),
            ("timer", app.descendants(matching: .any)["cockpit-time"]),
            ("ETA", app.descendants(matching: .any)["cockpit-eta"]),
            ("altitude", app.descendants(matching: .any)["cockpit-altitude"]),
            ("Planned now", app.descendants(matching: .any)["planned-now"]),
            ("Planned next", app.descendants(matching: .any)["planned-next"])
        ]

        for (name, element) in requiredElements {
            XCTAssertTrue(element.waitForExistence(timeout: 3), "Missing \(name)")
            XCTAssertTrue(element.frame.intersects(app.frame), "Off-screen \(name)")
        }

        let identified = app.buttons["waypoint-identified"]
        let reached = app.buttons["reached-now"]
        XCTAssertEqual(identified.label, "Report destination identified")
        XCTAssertEqual(reached.label, "Report destination reached")
        XCTAssertTrue(identified.isHittable)
        XCTAssertTrue(reached.isHittable)
        let mapFrame = app.descendants(matching: .any)["aviation-map"].frame
        XCTAssertGreaterThan(mapFrame.height, reached.frame.maxY - mapFrame.maxY)
    }

    @MainActor
    func testFrequencyPlanDisclosureOpensAndClosesWithoutReplacingRestingReferences() throws {
        let app = launchCockpit(planData: try oneLegPlanData())
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)

        let plannedNow = app.descendants(matching: .any)["planned-now"]
        let plannedNext = app.descendants(matching: .any)["planned-next"]
        XCTAssertTrue(plannedNow.waitForExistence(timeout: 3))
        XCTAssertTrue(plannedNext.exists)

        app.buttons["open-frequency-plan"].tap()

        let panel = app.staticTexts["frequency-plan-title"]
        XCTAssertTrue(panel.waitForExistence(timeout: 3))
        XCTAssertEqual(panel.label, "Frequency plan")
        XCTAssertTrue(app.staticTexts["Imported planning data—not live radio state"].exists)
        XCTAssertTrue(app.staticTexts["These values come from the imported plan. The app does not know what is tuned."].exists)
        XCTAssertFalse(app.staticTexts["Not tuned"].exists)

        app.buttons["close-frequency-plan"].tap()

        XCTAssertTrue(panel.waitForNonExistence(timeout: 3))
        XCTAssertTrue(plannedNow.exists)
        XCTAssertTrue(plannedNext.exists)
    }

    @MainActor
    func testAccessibilityTextUsesScrollableCompactConsoleWithoutTruncatingActions() throws {
        let app = launchCockpit(
            planData: try oneLegPlanData(),
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.buttons["start-leg"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["compact-cockpit-console"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["waypoint-identified"].exists)
        XCTAssertTrue(app.buttons["reached-now"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["planned-frequencies"].exists)
    }

    @MainActor
    func testPositionCheckAccessibilityTextStacksDistinctReachableActions() throws {
        let app = launchCockpit(
            planData: try oneLegPlanData(),
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL",
            positionCheckState: "ready"
        )
        app.buttons["start-leg"].tap()

        let positionCheck = app.buttons["position-check-control"]
        let waypointIdentified = app.buttons["waypoint-identified"]
        XCTAssertTrue(positionCheck.waitForExistence(timeout: 3))
        XCTAssertTrue(waypointIdentified.exists)
        XCTAssertTrue(positionCheck.label.contains("Position Check, Ready"))
        XCTAssertEqual(positionCheck.value as? String, "GPS Ready")
        XCTAssertLessThan(positionCheck.frame.maxY, waypointIdentified.frame.minY)

        XCTAssertTrue(positionCheck.isHittable)
        app.swipeUp()
        XCTAssertTrue(waypointIdentified.isHittable)
        XCTAssertTrue(app.buttons["reached-now"].exists)
    }

    @MainActor
    func testPositionCheckPermissionEducationCanContinueManually() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = try oneLegPlanData().base64EncodedString()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_POSITION_CHECK_EDUCATION"] = "1"
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_POSITION_CHECK_STATE"] = "permission-required"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["position-check-permission-education"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Allow Location for Position Check"].exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'ten seconds'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'active Flight'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'background'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'on this device'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'export'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'force-quit'")).firstMatch.exists)
        app.buttons["position-check-not-now"].tap()

        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 3))
    }

    @MainActor
    func testPositionCheckReadinessFixturesPreserveManualNavigationAndHideGPSValues() throws {
        let fixtures = [
            ("ready", "Ready"),
            ("acquiring", "Acquiring"),
            ("unavailable", "Unavailable"),
            ("permission-required", "Permission Required")
        ]

        for (fixture, status) in fixtures {
            let app = launchCockpit(planData: try oneLegPlanData(), positionCheckState: fixture)
            app.buttons["start-leg"].tap()

            let control = app.descendants(matching: .any)["position-check-control"]
            XCTAssertTrue(control.waitForExistence(timeout: 3), "Missing \(status) fixture")
            XCTAssertTrue(control.label.contains(status))
            XCTAssertTrue(control.label.contains("Position Check"))
            XCTAssertFalse(control.label.contains("32."))
            XCTAssertFalse(control.label.localizedCaseInsensitiveContains("metres"))
            XCTAssertFalse(control.label.localizedCaseInsensitiveContains("accuracy 50"))
            XCTAssertTrue(app.buttons["waypoint-identified"].exists)
            XCTAssertTrue(app.buttons["reached-now"].exists)
            app.terminate()
        }
    }

    @MainActor
    func testPositionCheckRequiresCompletedHoldAndCanEndEarly() throws {
        let app = launchCockpit(planData: try oneLegPlanData(), positionCheckState: "ready")
        app.buttons["start-leg"].tap()
        let control = app.descendants(matching: .any)["position-check-control"]
        XCTAssertTrue(control.waitForExistence(timeout: 3))

        control.tap()
        XCTAssertTrue(control.label.contains("Ready"))
        XCTAssertFalse(control.label.contains("Active"))

        control.press(forDuration: 1.1)
        XCTAssertTrue(
            NSPredicate(format: "label CONTAINS 'Active'").evaluate(with: control),
            "Completed hold should start the bounded disclosure"
        )
        XCTAssertTrue(control.label.contains("Position Check"))
        XCTAssertEqual(control.value as? String, "Tap to end")
        XCTAssertTrue(app.buttons["waypoint-identified"].exists)

        control.tap()
        let ended = NSPredicate(format: "NOT (label CONTAINS 'Active')")
        expectation(for: ended, evaluatedWith: control)
        waitForExpectations(timeout: 2)

        control.press(forDuration: 1.1)
        XCTAssertTrue(NSPredicate(format: "label CONTAINS 'Active'").evaluate(with: control))
    }

    @MainActor
    func testPositionCheckRecoveryOutcomeFixtures() throws {
        let fixtures = [
            ("recovery-available", "Rejoin active leg"),
            ("on-track", "ON TRACK"),
            ("position-only", "POSITION ONLY"),
            ("no-sensible-intercept", "NO SENSIBLE INTERCEPT"),
            ("extreme-displacement", "OUTSIDE RECOVERY RANGE")
        ]

        for (fixture, expectedText) in fixtures {
            let app = launchCockpit(planData: try oneLegPlanData(), positionCheckState: fixture)
            app.buttons["start-leg"].tap()
            closeStartChecklist(in: app)
            let control = app.descendants(matching: .any)["position-check-control"]
            XCTAssertTrue(control.waitForExistence(timeout: 3))
            control.press(forDuration: 1.1)
            let recovery = app.descendants(matching: .any)["position-check-recovery"]
            XCTAssertTrue(recovery.waitForExistence(timeout: 3), "Missing recovery presentation for \(fixture)")
            XCTAssertTrue(recovery.label.contains(expectedText), "Unexpected recovery presentation for \(fixture): \(recovery.label)")
            XCTAssertTrue(app.buttons["waypoint-identified"].exists)
            app.terminate()
        }
    }

    @MainActor
    func testPositionCheckAcquisitionCanBeCancelled() throws {
        let app = launchCockpit(planData: try oneLegPlanData(), positionCheckState: "acquiring")
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        let control = app.descendants(matching: .any)["position-check-control"]
        XCTAssertTrue(control.waitForExistence(timeout: 3))

        control.press(forDuration: 1.1)
        XCTAssertTrue(control.label.contains("Acquiring"))
        XCTAssertEqual(control.value as? String, "Disclosure timer has not started")

        control.tap()
        let cancelled = NSPredicate(format: "NOT (value CONTAINS 'timer has not started')")
        expectation(for: cancelled, evaluatedWith: control)
        waitForExpectations(timeout: 2)
        XCTAssertTrue(app.buttons["waypoint-identified"].exists)
    }

    @MainActor
    func testPositionCheckSignalLossClearsDisclosureAndPreservesManualControls() throws {
        let app = launchCockpit(
            planData: try oneLegPlanData(),
            positionCheckState: "signal-loss",
            fixtureDelay: 12
        )
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        let control = app.descendants(matching: .any)["position-check-control"]
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        control.press(forDuration: 1.1)

        let recovery = app.descendants(matching: .any)["position-check-recovery"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 3))
        let gpsLost = NSPredicate(format: "label CONTAINS 'GPS Lost'")
        expectation(for: gpsLost, evaluatedWith: control)
        waitForExpectations(timeout: 12)

        XCTAssertFalse(recovery.exists)
        XCTAssertTrue(control.label.contains("GPS Lost"))
        XCTAssertFalse(control.label.contains("Active"))
        XCTAssertTrue(app.buttons["waypoint-identified"].exists)
        XCTAssertTrue(app.buttons["reached-now"].exists)
    }

    @MainActor
    func testPositionCheckPermissionRevocationFailsClosed() throws {
        let app = launchCockpit(
            planData: try oneLegPlanData(),
            positionCheckState: "permission-revoked",
            fixtureDelay: 12
        )
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        let control = app.descendants(matching: .any)["position-check-control"]
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        control.press(forDuration: 1.1)
        XCTAssertTrue(app.descendants(matching: .any)["position-check-recovery"].waitForExistence(timeout: 3))

        expectation(for: NSPredicate(format: "label CONTAINS 'Permission Required'"), evaluatedWith: control)
        waitForExpectations(timeout: 12)
        XCTAssertFalse(app.descendants(matching: .any)["position-check-recovery"].exists)
        XCTAssertTrue((control.value as? String)?.contains("manual navigation remains available") == true)
        XCTAssertTrue(app.buttons["waypoint-identified"].exists)
    }

    @MainActor
    func testPositionCheckBackgroundAndTabExitRequireANewHold() throws {
        let app = launchCockpit(planData: try oneLegPlanData(), positionCheckState: "ready")
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        let control = app.descendants(matching: .any)["position-check-control"]
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        control.press(forDuration: 1.1)
        XCTAssertTrue(control.label.contains("Active"))

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        XCTAssertFalse(control.label.contains("Active"))

        control.press(forDuration: 1.1)
        XCTAssertTrue(control.label.contains("Active"))
        tab(named: "Flight Plans", in: app).tap()
        tab(named: "Cockpit", in: app).tap()
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        XCTAssertFalse(control.label.contains("Active"))
    }

    @MainActor
    func testPositionCheckEndsWhenActiveFlightCompletes() throws {
        let app = launchCockpit(planData: try oneLegPlanData(), positionCheckState: "ready")
        app.buttons["start-leg"].tap()
        closeStartChecklist(in: app)
        let control = app.descendants(matching: .any)["position-check-control"]
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        control.press(forDuration: 1.1)
        XCTAssertTrue(control.label.contains("Active"))

        app.buttons["waypoint-identified"].tap()
        app.buttons["waypoint-reached"].tap()
        XCTAssertTrue(control.waitForNonExistence(timeout: 3) || !control.label.contains("Active"))
    }

    @MainActor
    func testPositionCheckDisclosureAndAcquisitionExpireWithoutRetainingGPS() throws {
        let activeApp = launchCockpit(
            planData: try oneLegPlanData(),
            positionCheckState: "ready",
            positionCheckDuration: 1
        )
        activeApp.buttons["start-leg"].tap()
        closeStartChecklist(in: activeApp)
        let activeControl = activeApp.descendants(matching: .any)["position-check-control"]
        XCTAssertTrue(activeControl.waitForExistence(timeout: 3))
        activeControl.press(forDuration: 1.1)
        XCTAssertTrue(activeControl.label.contains("Active"))
        XCTAssertTrue(
            activeControl.waitForNonExistence(timeout: 2)
                || NSPredicate(format: "NOT (label CONTAINS 'Active')").evaluate(with: activeControl)
        )
        XCTAssertFalse(activeControl.label.localizedCaseInsensitiveContains("accuracy"))
        activeApp.terminate()

        let acquiringApp = launchCockpit(
            planData: try oneLegPlanData(),
            positionCheckState: "acquiring",
            positionCheckDuration: 1
        )
        acquiringApp.buttons["start-leg"].tap()
        closeStartChecklist(in: acquiringApp)
        let acquiringControl = acquiringApp.descendants(matching: .any)["position-check-control"]
        XCTAssertTrue(acquiringControl.waitForExistence(timeout: 3))
        acquiringControl.press(forDuration: 1.1)
        XCTAssertEqual(acquiringControl.value as? String, "Disclosure timer has not started")
        let timedOut = NSPredicate(format: "value CONTAINS 'timed out'")
        expectation(for: timedOut, evaluatedWith: acquiringControl)
        waitForExpectations(timeout: 2)
        XCTAssertFalse(acquiringControl.label.localizedCaseInsensitiveContains("latitude"))
        XCTAssertTrue(acquiringApp.buttons["waypoint-identified"].exists)
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func recoveryApp(state: String, planData: Data?) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_RECOVERY_STATE"] = state
        if let planData {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = planData.base64EncodedString()
        }
        app.launch()
        return app
    }

    private func launchFlights(
        state: String,
        planData: Data? = nil,
        preferredContentSizeCategory: String? = nil,
        exportFailure: Bool = false,
        exportPreparationFailure: Bool = false,
        exportDelay: Bool = false,
        deletionFailure: Bool = false,
        debriefHasNoPosition: Bool = false,
        debriefHasShortDuration: Bool = false,
        debriefHasUnreliableCourse: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_INITIAL_SECTION"] = "flights"
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_FLIGHTS_STATE"] = state
        if exportFailure {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_EXPORT_FAILURE"] = "1"
        }
        if exportPreparationFailure {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_EXPORT_PREPARATION_FAILURE"] = "1"
        }
        if exportDelay {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_EXPORT_DELAY"] = "1"
        }
        if deletionFailure {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_DELETE_FAILURE"] = "1"
        }
        if debriefHasNoPosition {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_DEBRIEF_NO_POSITION"] = "1"
        }
        if debriefHasShortDuration {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_SHORT_DEBRIEF"] = "1"
        }
        if debriefHasUnreliableCourse {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_UNRELIABLE_COURSE"] = "1"
        }
        if let planData {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = planData.base64EncodedString()
        }
        if let preferredContentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", preferredContentSizeCategory]
        }
        app.launch()
        return app
    }

    @MainActor
    private func openFlightDetail(id: String, in app: XCUIApplication) {
        let list = app.descendants(matching: .any)["flights.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        let row = app.descendants(matching: .any)["flights.row.\(id)"]
        for _ in 0..<5 where !row.isHittable {
            list.swipeUp()
        }
        XCTAssertTrue(row.isHittable)
        row.tap()
        XCTAssertTrue(
            app.descendants(matching: .any)["flight-detail.status"].waitForExistence(timeout: 5)
        )
    }

    private func closeStartChecklist(in app: XCUIApplication) {
        let closeChecklist = app.buttons["leg-start-checklist-close"]
        XCTAssertTrue(closeChecklist.waitForExistence(timeout: 3))
        closeChecklist.tap()
        XCTAssertTrue(app.buttons["leg-start-checklist-chip"].waitForExistence(timeout: 3))
    }

    private func launchCockpit(
        planData: Data,
        progressionPolicy: String? = nil,
        preferredContentSizeCategory: String? = nil,
        positionCheckState: String? = nil,
        positionCheckDuration: Double? = nil,
        fixtureDelay: Double? = nil,
        recordingFailure: Bool = false,
        recordingDegradation: Bool = false,
        recordingStatus: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = planData.base64EncodedString()
        if let progressionPolicy {
            app.launchEnvironment["NAVIGATION_FLIGHT_PROGRESSION_POLICY"] = progressionPolicy
        }
        if let preferredContentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", preferredContentSizeCategory]
        }
        if let positionCheckState {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_POSITION_CHECK_STATE"] = positionCheckState
        }
        if let positionCheckDuration {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_POSITION_CHECK_DURATION"] = String(positionCheckDuration)
        }
        if let fixtureDelay {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_POSITION_CHECK_FIXTURE_DELAY"] = String(fixtureDelay)
        }
        if recordingFailure {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_RECORDING_FAILURE"] = "1"
        }
        if recordingDegradation {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_RECORDING_DEGRADATION"] = "1"
        }
        if let recordingStatus {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_RECORDING_STATUS"] = recordingStatus
        }
        app.launch()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 2))
        return app
    }

    private func oneLegPlanData() throws -> Data {
        let data = try fixtureData(named: "representative-v7", directory: "V7/Official")
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var navigation = try XCTUnwrap(object["navigation"] as? [String: Any])
        let identificationPoints = try XCTUnwrap(navigation["identificationPoints"] as? [[String: Any]])
        let identificationPointIDs = Set(identificationPoints.compactMap { $0["id"] as? String })
        navigation["identificationPoints"] = []
        let altitudeChanges = try XCTUnwrap(navigation["altitudeChanges"] as? [[String: Any]])
        let dependentAltitudeChangeIDs = Set(altitudeChanges.compactMap { change -> String? in
            guard let anchor = change["anchor"] as? [String: Any],
                  anchor["kind"] as? String == "identification-point",
                  let pointID = anchor["identificationPointId"] as? String,
                  identificationPointIDs.contains(pointID) else { return nil }
            return change["id"] as? String
        })
        navigation["altitudeChanges"] = altitudeChanges.filter { change in
            guard let id = change["id"] as? String else { return true }
            return !dependentAltitudeChangeIDs.contains(id)
        }
        object["navigation"] = navigation

        var execution = try XCTUnwrap(object["execution"] as? [String: Any])
        let annotations = try XCTUnwrap(execution["annotations"] as? [[String: Any]])
        let removedEntityIDs = identificationPointIDs.union(dependentAltitudeChangeIDs)
        execution["annotations"] = annotations.filter { annotation in
            guard let entityID = annotation["entityId"] as? String else { return true }
            return !removedEntityIDs.contains(entityID)
        }
        object["execution"] = execution
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func debriefPlanData() throws -> Data {
        try realFlightPlanData(named: "llhz-llib-via-jerusalem")
    }

    private func realFlightPlanData(named name: String) throws -> Data {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repository = sourceFile.deletingLastPathComponent().deletingLastPathComponent()
        return try Data(contentsOf: repository.appending(
            path: "fixtures/FlightRecords/\(name)/flight-plan.fplnav"
        ))
    }

    private func launchFlightPlans(
        seedData: [Data] = [],
        importData: Data? = nil,
        storageFailure: Bool = false,
        loadedPlanData: Data? = nil,
        protectLoadedFlight: Bool = false,
        failFlightChange: Bool = false,
        removalFailure: Bool = false,
        preferredContentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        if seedData.isEmpty == false {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_PLANS"] = seedData
                .map { $0.base64EncodedString() }
                .joined(separator: ",")
        }
        if let importData {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_IMPORT_PLAN"] = importData.base64EncodedString()
        }
        if storageFailure {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_STORAGE_FAILURE"] = "1"
        }
        if let loadedPlanData {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LOADED_PLAN"] = loadedPlanData.base64EncodedString()
        }
        if protectLoadedFlight {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PROTECTED_FLIGHT"] = "1"
        }
        if failFlightChange {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_FLIGHT_CHANGE_FAILURE"] = "1"
        }
        if removalFailure {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_REMOVAL_FAILURE"] = "1"
        }
        if let preferredContentSizeCategory {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", preferredContentSizeCategory]
        }
        app.launch()
        return app
    }

    private func projectTitle(in data: Data) throws -> String {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let project = try XCTUnwrap(object["project"] as? [String: Any])
        return try XCTUnwrap(project["title"] as? String)
    }

    private func changingRevision(in data: Data, by interval: TimeInterval) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var project = try XCTUnwrap(object["project"] as? [String: Any])
        let value = try XCTUnwrap(project["modifiedAt"] as? String)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let modifiedAt = try XCTUnwrap(formatter.date(from: value) ?? ISO8601DateFormatter().date(from: value))
        project["modifiedAt"] = formatter.string(from: modifiedAt.addingTimeInterval(interval))
        object["project"] = project
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func changingIdentity(in data: Data) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var project = try XCTUnwrap(object["project"] as? [String: Any])
        project["id"] = UUID().uuidString
        project["title"] = "Alternate Flight Plan"
        object["project"] = project
        return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func twoLegPlanData() throws -> Data {
        let data = try oneLegPlanData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var navigation = try XCTUnwrap(object["navigation"] as? [String: Any])
        var route = try XCTUnwrap(navigation["route"] as? [String: Any])
        var waypoints = try XCTUnwrap(route["waypoints"] as? [[String: Any]])
        var thirdWaypoint = waypoints[1]
        let thirdWaypointID = "00000000-0000-4000-8000-000000000020"
        thirdWaypoint["id"] = thirdWaypointID
        thirdWaypoint["name"] = "Third waypoint"
        thirdWaypoint["position"] = ["latitude": 0.03, "longitude": 0.01]
        waypoints.append(thirdWaypoint)
        route["waypoints"] = waypoints
        let firstWaypointID = try XCTUnwrap(waypoints[0]["id"] as? String)
        let secondWaypointID = try XCTUnwrap(waypoints[1]["id"] as? String)
        route["waypointOrder"] = [firstWaypointID, secondWaypointID, thirdWaypointID]

        var sourceLegs = try XCTUnwrap(route["legs"] as? [[String: Any]])
        var secondLeg = sourceLegs[0]
        let secondLegID = "00000000-0000-4000-8000-000000000021"
        secondLeg["id"] = secondLegID
        secondLeg["departureWaypointId"] = secondWaypointID
        secondLeg["arrivalWaypointId"] = thirdWaypointID
        sourceLegs.append(secondLeg)
        route["legs"] = sourceLegs
        navigation["route"] = route

        var execution = try XCTUnwrap(object["execution"] as? [String: Any])
        var resolvedLegs = try XCTUnwrap(execution["legs"] as? [[String: Any]])
        var resolvedSecondLeg = resolvedLegs[0]
        resolvedSecondLeg["legId"] = secondLegID
        resolvedLegs.append(resolvedSecondLeg)
        execution["legs"] = resolvedLegs

        object["navigation"] = navigation
        object["execution"] = execution
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func threeLegPlanData() throws -> Data {
        let data = try twoLegPlanData()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var navigation = try XCTUnwrap(object["navigation"] as? [String: Any])
        var route = try XCTUnwrap(navigation["route"] as? [String: Any])
        var waypoints = try XCTUnwrap(route["waypoints"] as? [[String: Any]])
        var fourthWaypoint = waypoints[2]
        let fourthWaypointID = "00000000-0000-4000-8000-000000000030"
        fourthWaypoint["id"] = fourthWaypointID
        fourthWaypoint["name"] = "Fourth waypoint"
        fourthWaypoint["position"] = ["latitude": 0.04, "longitude": 0.015]
        waypoints.append(fourthWaypoint)
        route["waypoints"] = waypoints
        route["waypointOrder"] = try waypoints.map { waypoint in
            try XCTUnwrap(waypoint["id"] as? String)
        }

        var sourceLegs = try XCTUnwrap(route["legs"] as? [[String: Any]])
        var thirdLeg = sourceLegs[1]
        let thirdLegID = "00000000-0000-4000-8000-000000000031"
        thirdLeg["id"] = thirdLegID
        thirdLeg["departureWaypointId"] = try XCTUnwrap(waypoints[2]["id"] as? String)
        thirdLeg["arrivalWaypointId"] = fourthWaypointID
        sourceLegs.append(thirdLeg)
        route["legs"] = sourceLegs
        navigation["route"] = route

        var execution = try XCTUnwrap(object["execution"] as? [String: Any])
        var resolvedLegs = try XCTUnwrap(execution["legs"] as? [[String: Any]])
        var resolvedThirdLeg = resolvedLegs[1]
        resolvedThirdLeg["legId"] = thirdLegID
        resolvedLegs.append(resolvedThirdLeg)
        execution["legs"] = resolvedLegs

        object["navigation"] = navigation
        object["execution"] = execution
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func fixtureData(named name: String, directory: String) throws -> Data {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repository = sourceFile.deletingLastPathComponent().deletingLastPathComponent()
        let fixture = repository.appending(path: "NavigationFlightTests/Fixtures/FPLNav/\(directory)/\(name).fplnav")
        return try Data(contentsOf: fixture)
    }

    private func tab(named label: String, in app: XCUIApplication) -> XCUIElement {
        if label == "Cockpit" {
            let matches = app.buttons.matching(identifier: "cockpit-tab")
            return matches.element(boundBy: max(matches.count - 1, 0))
        }
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
        return matches.element(boundBy: max(matches.count - 1, 0))
    }
}
