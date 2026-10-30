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
        XCTAssertTrue(cockpitHeading.label.contains("Planned-wind heading · magnetic"))
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
        XCTAssertTrue(heading.label.contains("magnetic"))
        heading.tap()

        XCTAssertTrue(app.staticTexts["REVISED HEADING · MAGNETIC"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.descendants(matching: .any)["heading-draft"].label.contains("033°"))
        app.buttons["increase-heading"].tap()
        app.buttons["increase-heading"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["heading-draft"].label.contains("035°"))
        app.buttons["commit-heading"].tap()

        XCTAssertFalse(app.staticTexts["REVISED HEADING · MAGNETIC"].exists)
        XCTAssertTrue(heading.label.contains("Pilot-revised · magnetic"))
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

        XCTAssertTrue(app.descendants(matching: .any)["leg-status"].label.contains("ACTIVE"))
        XCTAssertTrue(app.staticTexts["LEG 2 OF 2"].exists)
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

        let legStatus = app.descendants(matching: .any)["leg-status"]
        expectation(for: NSPredicate(format: "label CONTAINS 'ACTIVE'"), evaluatedWith: legStatus)
        waitForExpectations(timeout: 2)
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
        previousLeg.tap()

        XCTAssertTrue(app.descendants(matching: .any)["previous-leg-drawer"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'PREVIOUS LEG · LEG 1'")).firstMatch.exists)
        XCTAssertTrue(app.staticTexts["TARGET HISTORY"].exists)
        XCTAssertTrue(app.staticTexts["HEADING HISTORY"].exists)
        XCTAssertTrue(app.staticTexts["Review only · current leg continues unchanged"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["leg-start-checklist"].exists)
        XCTAssertTrue(timer.label.contains("Running from pilot start"))

        let drawer = app.descendants(matching: .any)["previous-leg-drawer"]
        XCTAssertTrue(app.buttons["undo-reach"].exists)
        drawer.swipeLeft()
        XCTAssertFalse(drawer.exists)
        XCTAssertTrue(timer.label.contains("Running from pilot start"))
        XCTAssertTrue(app.staticTexts["LEG 2 OF 2"].exists)
    }

    @MainActor
    func testIdentifyThenReachPreservesActiveTimingAndCompletesFinalLeg() throws {
        let app = launchCockpit(planData: try oneLegPlanData())

        app.buttons["start-leg"].tap()
        app.buttons["waypoint-identified"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["leg-status"].label.contains("DESTINATION IDENTIFIED"))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Leg timing continues'")).firstMatch.exists)
        XCTAssertTrue(app.buttons["waypoint-reached"].isEnabled)
        app.buttons["waypoint-reached"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["navigation-complete"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["FLIGHT COMPLETE"].exists)
        XCTAssertTrue(app.staticTexts["No successor leg or timer is started."].exists)
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
        XCTAssertTrue(app.staticTexts["This leg remains untimed until Start Leg."].exists)
        XCTAssertTrue(app.buttons["start-leg"].isEnabled)
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Starts when Start Leg is pressed"))
        app.buttons["start-leg"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["cockpit-time"].label.contains("Running from pilot start"))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    @MainActor
    private func launchCockpit(planData: Data, progressionPolicy: String? = nil) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = planData.base64EncodedString()
        if let progressionPolicy {
            app.launchEnvironment["NAVIGATION_FLIGHT_PROGRESSION_POLICY"] = progressionPolicy
        }
        app.launch()
        XCTAssertTrue(app.buttons["open-cockpit"].waitForExistence(timeout: 3))
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
}
