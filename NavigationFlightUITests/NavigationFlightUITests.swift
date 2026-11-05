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
        XCTAssertEqual(status.label, "Recording · GPS Gap")
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
        let settingsTab = tab(named: "Settings", in: app)
        XCTAssertTrue(cockpitTab.waitForExistence(timeout: 5))
        XCTAssertTrue(flightPlansTab.exists)
        XCTAssertTrue(flightsTab.exists)
        XCTAssertTrue(settingsTab.exists)
        XCTAssertLessThan(cockpitTab.frame.minX, flightPlansTab.frame.minX)
        XCTAssertLessThan(flightPlansTab.frame.minX, flightsTab.frame.minX)
        XCTAssertLessThan(flightsTab.frame.minX, settingsTab.frame.minX)
        XCTAssertTrue(flightPlansTab.isSelected)
        XCTAssertTrue(app.staticTexts["No flight plans yet"].exists)
        XCTAssertTrue(app.buttons["add-flight-plan"].exists)

        cockpitTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(cockpitTab.isSelected)
        let chooseFlightPlan = app.buttons["Choose a Flight Plan"]
        XCTAssertTrue(chooseFlightPlan.waitForExistence(timeout: 2))
        chooseFlightPlan.tap()
        XCTAssertTrue(flightPlansTab.isSelected)

        settingsTab.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["Settings will be available here. No functional settings or inactive future app sections."].waitForExistence(timeout: 2))
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
    }

    @MainActor
    func testIncompleteFlightDetailOffersPartialExport() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())

        openFlightDetail(id: "04000000-0000-0000-0000-000000000004", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.status"].label.contains("Incomplete"))
        XCTAssertEqual(app.buttons["flight-detail.export"].label, "Export partial GPX")
    }

    @MainActor
    func testActiveFlightDetailIsReadOnlyAndContinuable() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())

        openFlightDetail(id: "01000000-0000-0000-0000-000000000001", in: app)

        XCTAssertTrue(app.descendants(matching: .any)["flight-detail.status"].label.contains("In Progress"))
        XCTAssertTrue(app.buttons["flight-detail.continue"].exists)
        XCTAssertFalse(app.buttons["flight-detail.delete"].exists)
    }

    @MainActor
    func testMissingEvidenceDetailUsesUnavailableInsteadOfZero() throws {
        let app = launchFlights(state: "populated", planData: try oneLegPlanData())

        openFlightDetail(id: "05000000-0000-0000-0000-000000000005", in: app)

        XCTAssertTrue(app.staticTexts["Unavailable"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["0 km"].exists)
        XCTAssertFalse(app.buttons["flight-detail.export"].exists)
        XCTAssertTrue(app.buttons["flight-detail.delete"].exists)
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
        XCTAssertTrue(app.buttons["open-cockpit"].waitForExistence(timeout: 3))

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
        XCTAssertTrue(app.buttons["open-cockpit"].waitForExistence(timeout: 3))
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
        XCTAssertTrue(app.navigationBars["Plan Inspection"].waitForExistence(timeout: 3))
        let restart = app.buttons["restart-flight"]
        XCTAssertTrue(restart.waitForExistence(timeout: 3))
        restart.tap()
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
        app.alerts["Remove saved plan?"].buttons["Remove"].tap()

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

        app.buttons["show-plan-inspection"].tap()
        XCTAssertTrue(app.navigationBars["Plan Inspection"].waitForExistence(timeout: 3))
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
    func testTabRoundTripAndRotationPreserveActiveFlight() throws {
        let app = launchCockpit(planData: try oneLegPlanData())
        app.buttons["start-leg"].tap()
        let timer = app.descendants(matching: .any)["cockpit-time"]
        XCTAssertTrue(timer.waitForExistence(timeout: 2))
        XCTAssertTrue(timer.label.contains("Running from pilot start"))

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
        XCTAssertTrue(timer.label.contains("Running from pilot start"))
        XCTAssertTrue(app.buttons["waypoint-identified"].exists)
        XCTAssertTrue(app.buttons["reached-now"].isEnabled)

    }

    @MainActor
    func testImportedEditorPlanShowsSavedValuesAndModeSelection() throws {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repository = sourceFile.deletingLastPathComponent().deletingLastPathComponent()
        let fixture = repository.appending(path: "NavigationFlightTests/Fixtures/FPLNav/V7/Editor/editor-wind.fplnav")
        let data = try Data(contentsOf: fixture)
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = data.base64EncodedString()
        app.launch()

        XCTAssertTrue(app.staticTexts["Synthetic Editor V7 wind handoff"].waitForExistence(timeout: 3))
        let course = app.descendants(matching: .any)["magnetic-course"]
        XCTAssertTrue(course.label.contains("35° M"))
        let heading = app.descendants(matching: .any)["magnetic-heading"]
        XCTAssertTrue(heading.label.contains("33° M"))

        app.buttons["No wind"].tap()
        XCTAssertTrue(heading.label.contains("Unavailable"))
        XCTAssertTrue(course.label.contains("MAGNETIC COURSE"))
        app.buttons["Wind"].tap()
        XCTAssertTrue(heading.label.contains("33° M"))

        app.buttons["open-cockpit"].tap()
        let cockpitHeading = app.descendants(matching: .any)["cockpit-heading"]
        XCTAssertTrue(cockpitHeading.waitForExistence(timeout: 2))
        XCTAssertTrue(cockpitHeading.label.contains("PLANNED HEADING"))
        XCTAssertTrue(cockpitHeading.label.contains("033°"))
        XCTAssertFalse(cockpitHeading.label.contains("° M"))
        let readyTimer = app.descendants(matching: .any)["cockpit-time"]
        XCTAssertTrue(readyTimer.label.contains("LEG TIMER"))
        XCTAssertTrue(readyTimer.label.contains("Starts when Start Leg is pressed"))
        XCTAssertFalse(readyTimer.label.contains("ELAPSED"))
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-eta"].label.contains("09:16"))
        let compactFrequencies = app.buttons["compact-frequencies"]
        if compactFrequencies.exists {
            compactFrequencies.tap()
            let groupedVOR = app.descendants(matching: .any).matching(
                NSPredicate(format: "label BEGINSWITH 'BGN · VOR/DME'")
            )
            XCTAssertGreaterThanOrEqual(groupedVOR.count, 1)
        } else {
            XCTAssertTrue(app.descendants(matching: .any)["planned-frequencies"].exists)
        }
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-altitude"].label.contains("3,000"))
        XCTAssertTrue(app.buttons["focus-leg"].exists)
        XCTAssertTrue(app.buttons["focus-waypoint"].exists)
        XCTAssertTrue(app.buttons["route-overview"].exists)
        XCTAssertTrue(app.buttons["show-plan-inspection"].exists)
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
        XCTAssertTrue(activeTimer.label.contains("LEG TIMER"))
        XCTAssertTrue(activeTimer.label.contains("Running from pilot start"))
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-eta"].label.contains("09:16"))
        XCTAssertTrue(app.descendants(matching: .any)["planned-frequencies"].exists)
        XCTAssertTrue(cockpitHeading.label.contains("033°"))
        map.swipeRight()
        XCTAssertTrue(activeTimer.label.contains("Running from pilot start"))

        let checklist = app.descendants(matching: .any)["leg-start-checklist"]
        XCTAssertTrue(checklist.waitForExistence(timeout: 2))
        app.buttons["leg-start-checklist-noted"].tap()
        XCTAssertTrue(app.buttons["leg-start-checklist-chip"].waitForExistence(timeout: 2))
        XCTAssertFalse(checklist.exists)

        waypointIdentified.tap()
        let waypointReached = app.buttons["waypoint-reached"]
        XCTAssertTrue(waypointReached.waitForExistence(timeout: 2))
        XCTAssertTrue(activeTimer.label.contains("Running from pilot start"))
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

        let currentFrequency = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'frequency-' AND value == 'current'")
        ).firstMatch
        let nextFrequency = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH 'frequency-' AND value == 'next'")
        ).firstMatch
        XCTAssertTrue(currentFrequency.waitForExistence(timeout: 3))
        XCTAssertTrue(nextFrequency.waitForExistence(timeout: 3))

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
        let toggle = app.buttons["toggle-drift-lines"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 2))
        XCTAssertEqual(toggle.label, "Hide drift lines, manual calculation aid")

        toggle.tap()
        XCTAssertEqual(toggle.label, "Show drift lines, manual calculation aid")
        app.buttons["show-plan-inspection"].tap()
        XCTAssertTrue(app.buttons["open-cockpit"].waitForExistence(timeout: 2))
        app.buttons["open-cockpit"].tap()

        XCTAssertTrue(toggle.waitForExistence(timeout: 2))
        XCTAssertEqual(toggle.label, "Show drift lines, manual calculation aid")
    }

    @MainActor
    func testPilotCanCommitAndReopenMagneticHeading() throws {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repository = sourceFile.deletingLastPathComponent().deletingLastPathComponent()
        let fixture = repository.appending(path: "NavigationFlightTests/Fixtures/FPLNav/V7/Editor/editor-wind.fplnav")
        let app = launchCockpit(planData: try Data(contentsOf: fixture))

        app.buttons["start-leg"].tap()
        let heading = app.buttons["cockpit-heading"]
        XCTAssertTrue(heading.waitForExistence(timeout: 2))
        XCTAssertTrue(heading.label.contains("PLANNED HEADING"))
        XCTAssertTrue(heading.label.contains("033°"))
        heading.tap()

        XCTAssertTrue(app.staticTexts["REVISED HEADING · MAGNETIC"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["heading-draft"].label.contains("033°"))
        app.buttons["increase-heading"].tap()
        app.buttons["increase-heading"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["heading-draft"].label.contains("035°"))
        app.buttons["commit-heading"].tap()

        XCTAssertFalse(app.staticTexts["REVISED HEADING · MAGNETIC"].exists)
        XCTAssertTrue(heading.label.contains("035°"))
        heading.tap()
        XCTAssertTrue(app.descendants(matching: .any)["heading-draft"].label.contains("035°"))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Committed 035°'")).firstMatch.exists)
    }

    @MainActor
    func testDirectReachAutomaticallyStartsSuccessor() throws {
        let app = launchCockpit(planData: try twoLegPlanData())

        app.buttons["start-leg"].tap()
        XCTAssertTrue(app.buttons["reached-now"].waitForExistence(timeout: 2))
        app.buttons["reached-now"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Running from pilot start"))
        XCTAssertFalse(app.descendants(matching: .any)["navigation-complete"].exists)
    }

    @MainActor
    func testWaypointReachUndoRestoresActiveLeg() throws {
        let app = launchCockpit(planData: try oneLegPlanData())
        app.buttons["start-leg"].tap()
        app.buttons["reached-now"].tap()

        let banner = app.staticTexts["reach-undo-banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 2))
        XCTAssertEqual(banner.label, "Final arrival reached")
        let undo = app.buttons["undo-reach"]
        XCTAssertTrue(undo.exists)
        XCTAssertEqual(undo.label, "Undo reach report")
        let undoValue = undo.value as? String
        XCTAssertTrue(undoValue == "20 seconds remaining" || undoValue == "19 seconds remaining")
        undo.tap()

        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Running from pilot start"))
        XCTAssertFalse(app.descendants(matching: .any)["navigation-complete"].exists)
        XCTAssertFalse(banner.exists)
    }

    @MainActor
    func testPreviousLegHistoryExpandsWithoutChangingSuccessorOrTimer() throws {
        let app = launchCockpit(planData: try twoLegPlanData())
        XCTAssertFalse(app.buttons["previous-leg-tab"].exists)

        app.buttons["start-leg"].tap()
        app.buttons["reached-now"].tap()

        let timer = app.descendants(matching: .any)["cockpit-time"]
        XCTAssertTrue(timer.waitForExistence(timeout: 2))
        XCTAssertTrue(timer.label.contains("Running from pilot start"))
        let previousLeg = app.buttons["previous-leg-tab"]
        XCTAssertTrue(previousLeg.waitForExistence(timeout: 2))
        let collapseChecklist = app.buttons["Collapse start of leg checklist"]
        if collapseChecklist.exists {
            collapseChecklist.tap()
        }
        previousLeg.tap()

        XCTAssertTrue(app.descendants(matching: .any)["previous-leg-drawer"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'PREVIOUS LEG · LEG 1'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["TARGET HISTORY"].exists)
        XCTAssertTrue(app.staticTexts["HEADING HISTORY"].exists)
        XCTAssertTrue(app.staticTexts["Review only · current leg continues unchanged"].exists)
        XCTAssertTrue(app.buttons["leg-start-checklist-chip"].exists)
        XCTAssertTrue(timer.label.contains("Running from pilot start"))

        let drawer = app.descendants(matching: .any)["previous-leg-drawer"]
        XCTAssertTrue(app.buttons["undo-reach"].exists)
        drawer.swipeLeft()
        XCTAssertFalse(drawer.exists)
        XCTAssertTrue(timer.label.contains("Running from pilot start"))
        XCTAssertTrue(app.buttons["previous-leg-tab"].label.contains("Leg 1"))
    }

    @MainActor
    func testIdentifyThenReachPreservesActiveTimingAndCompletesFinalLeg() throws {
        let app = launchCockpit(planData: try oneLegPlanData())

        app.buttons["start-leg"].tap()
        app.buttons["waypoint-identified"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Running from pilot start"))
        XCTAssertTrue(app.buttons["waypoint-reached"].isEnabled)
        app.buttons["waypoint-reached"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["navigation-complete"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testFinalReachPassesEveryUnreportedIdentificationPoint() throws {
        let plan = try fixtureData(named: "representative-v7", directory: "V7/Official")
        let app = launchCockpit(planData: plan)

        app.buttons["start-leg"].tap()
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
        app.buttons["reached-now"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["leg-status"].label.contains("READY · SUCCESSOR TRACK-UP"))
        XCTAssertTrue(app.buttons["start-leg"].isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Starts when Start Leg is pressed"))
        app.buttons["start-leg"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Running from pilot start"))
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
    func testAccessibilityTextUsesScrollableCompactConsoleWithoutTruncatingActions() throws {
        let app = launchCockpit(
            planData: try oneLegPlanData(),
            preferredContentSizeCategory: "UICTContentSizeCategoryAccessibilityXXXL"
        )
        app.buttons["start-leg"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["compact-cockpit-console"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.buttons["waypoint-identified"].exists)
        XCTAssertTrue(app.buttons["reached-now"].exists)
        let frequencies = app.buttons["compact-frequencies"]
        XCTAssertTrue(frequencies.exists)
        frequencies.tap()
        XCTAssertTrue(app.descendants(matching: .any)["planned-frequencies"].waitForExistence(timeout: 2))
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

        XCTAssertTrue(app.buttons["open-cockpit"].waitForExistence(timeout: 3))
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
        let app = launchCockpit(planData: try oneLegPlanData(), positionCheckState: "signal-loss")
        app.buttons["start-leg"].tap()
        let control = app.descendants(matching: .any)["position-check-control"]
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        control.press(forDuration: 1.1)

        let recovery = app.descendants(matching: .any)["position-check-recovery"]
        XCTAssertTrue(recovery.waitForExistence(timeout: 3))
        let gpsLost = NSPredicate(format: "label CONTAINS 'GPS Lost'")
        expectation(for: gpsLost, evaluatedWith: control)
        waitForExpectations(timeout: 8)

        XCTAssertFalse(recovery.exists)
        XCTAssertTrue(control.label.contains("GPS Lost"))
        XCTAssertFalse(control.label.contains("Active"))
        XCTAssertTrue(app.buttons["waypoint-identified"].exists)
        XCTAssertTrue(app.buttons["reached-now"].exists)
    }

    @MainActor
    func testPositionCheckPermissionRevocationFailsClosed() throws {
        let app = launchCockpit(planData: try oneLegPlanData(), positionCheckState: "permission-revoked")
        app.buttons["start-leg"].tap()
        let control = app.descendants(matching: .any)["position-check-control"]
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        control.press(forDuration: 1.1)
        XCTAssertTrue(app.descendants(matching: .any)["position-check-recovery"].waitForExistence(timeout: 3))

        expectation(for: NSPredicate(format: "label CONTAINS 'Permission Required'"), evaluatedWith: control)
        waitForExpectations(timeout: 8)
        XCTAssertFalse(app.descendants(matching: .any)["position-check-recovery"].exists)
        XCTAssertTrue((control.value as? String)?.contains("manual navigation remains available") == true)
        XCTAssertTrue(app.buttons["waypoint-identified"].exists)
    }

    @MainActor
    func testPositionCheckBackgroundAndTabExitRequireANewHold() throws {
        let app = launchCockpit(planData: try oneLegPlanData(), positionCheckState: "ready")
        app.buttons["start-leg"].tap()
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
        app.buttons["Flight Plans"].firstMatch.tap()
        app.buttons["Cockpit"].firstMatch.tap()
        XCTAssertTrue(control.waitForExistence(timeout: 3))
        XCTAssertFalse(control.label.contains("Active"))
    }

    @MainActor
    func testPositionCheckEndsWhenActiveFlightCompletes() throws {
        let app = launchCockpit(planData: try oneLegPlanData(), positionCheckState: "ready")
        app.buttons["start-leg"].tap()
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
        preferredContentSizeCategory: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_INITIAL_SECTION"] = "flights"
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_FLIGHTS_STATE"] = state
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
        XCTAssertTrue(app.buttons["open-cockpit"].waitForExistence(timeout: 5))
        app.buttons["open-cockpit"].tap()
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

    private func fixtureData(named name: String, directory: String) throws -> Data {
        let sourceFile = URL(fileURLWithPath: #filePath)
        let repository = sourceFile.deletingLastPathComponent().deletingLastPathComponent()
        let fixture = repository.appending(path: "NavigationFlightTests/Fixtures/FPLNav/\(directory)/\(name).fplnav")
        return try Data(contentsOf: fixture)
    }

    private func tab(named label: String, in app: XCUIApplication) -> XCUIElement {
        let matches = app.buttons.matching(NSPredicate(format: "label == %@", label))
        return matches.element(boundBy: max(matches.count - 1, 0))
    }
}
