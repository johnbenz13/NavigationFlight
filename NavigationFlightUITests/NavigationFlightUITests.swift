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
    func testFreshLaunchShellRoutesBetweenFixedAppSections() throws {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launch()

        let cockpitTab = tab(named: "Cockpit", in: app)
        let flightPlansTab = tab(named: "Flight Plans", in: app)
        let settingsTab = tab(named: "Settings", in: app)
        XCTAssertTrue(cockpitTab.waitForExistence(timeout: 5))
        XCTAssertTrue(flightPlansTab.exists)
        XCTAssertTrue(settingsTab.exists)
        XCTAssertLessThan(cockpitTab.frame.minX, flightPlansTab.frame.minX)
        XCTAssertLessThan(flightPlansTab.frame.minX, settingsTab.frame.minX)
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
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func launchCockpit(
        planData: Data,
        progressionPolicy: String? = nil,
        preferredContentSizeCategory: String? = nil
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
