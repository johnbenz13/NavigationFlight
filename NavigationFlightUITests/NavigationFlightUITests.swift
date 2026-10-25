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

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testEmptyStateOffersPlanImport() throws {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["No Navigation Plan"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["open-plan"].isEnabled)
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
        XCTAssertTrue(cockpitHeading.label.contains("Planned-wind heading · magnetic"))
        XCTAssertFalse(cockpitHeading.label.contains("° M"))
        let readyTimer = app.descendants(matching: .any)["cockpit-time"]
        XCTAssertTrue(readyTimer.label.contains("LEG TIMER"))
        XCTAssertTrue(readyTimer.label.contains("Starts when Start Leg is pressed"))
        XCTAssertFalse(readyTimer.label.contains("ELAPSED"))
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-eta"].label.contains("09:16"))
        let groupedVOR = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'BGN · VOR/DME'"))
        XCTAssertGreaterThanOrEqual(groupedVOR.count, 1)
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-altitude"].label.contains("3,000"))
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
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("ELAPSED"))
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("09:16"))
        XCTAssertTrue(cockpitHeading.label.contains("033°"))
        XCTAssertTrue(cockpitHeading.label.contains("COURSE 035°"))

        waypointIdentified.tap()
        let waypointReached = app.buttons["waypoint-reached"]
        XCTAssertTrue(waypointReached.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("ELAPSED"))
        waypointReached.tap()
        XCTAssertTrue(app.descendants(matching: .any)["navigation-complete"].waitForExistence(timeout: 2))

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(cockpitHeading.waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["navigation-complete"].exists)
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.descendants(matching: .any)["navigation-complete"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
