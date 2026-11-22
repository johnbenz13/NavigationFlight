import XCTest

@MainActor
final class ChartLibraryUITests: XCTestCase {
    private let herzliya = "charts-aerodrome-llhz"
    private let circuit = "charts-document-aip-llhz-chart-11"

    override func setUp() {
        continueAfterFailure = false
    }

    func testBrowseOpenZoomAndReturnWithoutFlightPlan() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = launch()
        XCTAssertTrue(app.navigationBars["Flight Plans"].waitForExistence(timeout: 10))
        section("Charts", in: app).tap()

        XCTAssertTrue(app.staticTexts["Airports"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Airfields"].exists)
        XCTAssertTrue(app.buttons["charts-aerodrome-llmg"].exists)
        let library = app.buttons[herzliya]
        XCTAssertTrue(library.isHittable)
        capture("library")

        library.tap()
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
        capture("aerodrome")
        let chart = app.buttons[circuit]
        reveal(chart, in: app)
        chart.tap()

        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["charts-viewer-title"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["charts-source"].firstMatch.exists)
        capture("viewer-fit")
        app.buttons["Zoom in"].tap()
        app.buttons["Zoom in"].tap()
        capture("viewer-zoom")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.55)).press(
            forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.35))
        )
        capture("viewer-pan")
        app.buttons["charts-fit-page"].tap()
        capture("viewer-refit")
        app.buttons["charts-viewer-back"].tap()
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))

        section("Flights", in: app).tap()
        section("Charts", in: app).tap()
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
        reveal(app.buttons[circuit], in: app)
    }

    func testBrowseAirfieldAndOpenOriginalChart() {
        let app = launch()
        section("Charts", in: app).tap()
        let megiddo = app.buttons["charts-aerodrome-llmg"]
        reveal(megiddo, in: app)
        megiddo.tap()
        XCTAssertTrue(app.navigationBars["מגידו"].waitForExistence(timeout: 5))
        capture("airfield")
        let chart = app.buttons["charts-document-aip-llmg-chart-01"]
        XCTAssertTrue(chart.isHittable)
        chart.tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        app.buttons["charts-viewer-back"].tap()
        XCTAssertTrue(app.navigationBars["מגידו"].waitForExistence(timeout: 5))
    }

    func testUnreadableChartReturnsToAerodromeAndCanOpenAnother() {
        let app = launch(unreadable: true)
        section("Charts", in: app).tap()
        app.buttons[herzliya].tap()
        let chart = app.buttons[circuit]
        reveal(chart, in: app)
        chart.tap()

        let heading = app.staticTexts["Chart unavailable"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "LLHZ")).firstMatch.exists)
        capture("viewer-error")
        app.buttons["charts-error-back"].tap()
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
        let otherChart = app.buttons["charts-document-aip-llhz-chart-10"]
        reveal(otherChart, in: app)
        otherChart.tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
    }

    func testOfflineChartEditionsInPortrait() {
        verifyOfflineChartEditions(in: .portrait)
    }

    func testOfflineChartEditionsInIPadLandscape() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        verifyOfflineChartEditions(in: .landscapeLeft)
    }

    private func verifyOfflineChartEditions(in orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = XCUIApplication()
        initialize(app)
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_CHART_EDITIONS"] = "1"
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_CHART_OFFLINE"] = "1"
        app.launch()
        waitForOrientation(landscape: orientation.isLandscape, in: app)
        section("Charts", in: app).tap()

        let field = app.buttons["charts-aerodrome-fixture-field"]
        let retired = app.buttons["charts-aerodrome-retired-field"]
        let chart = app.buttons["charts-document-fixture-field-chart"]
        let title = app.staticTexts["charts-viewer-title"].firstMatch
        let fit = app.buttons["charts-fit-page"]
        let source = app.descendants(matching: .any)["charts-source"].firstMatch

        XCTAssertTrue(retired.waitForExistence(timeout: 5))
        capture("fixture-a-library")
        field.tap()
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        capture("fixture-a-aerodrome")
        chart.tap()
        XCTAssertTrue(fit.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Edition A · Test circuit")
        XCTAssertTrue(source.label.contains("Fixture A"))

        // Foregrounding commits B through the actual store while this viewer holds A.
        XCUIDevice.shared.press(.home)
        app.activate()
        let committed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "B"), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [committed], timeout: 8), .completed)
        XCTAssertEqual(title.label, "Edition A · Test circuit")
        XCTAssertTrue(source.label.contains("Fixture A"))
        app.buttons["Zoom in"].tap()
        capture("fixture-a-viewer-after-b-commit")
        app.buttons["charts-viewer-back"].tap()

        section("Flights", in: app).tap()
        section("Charts", in: app).tap()
        XCTAssertTrue(app.navigationBars["Fixture Field"].waitForExistence(timeout: 5))
        let updatedChart = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Edition B"), object: chart
        )
        XCTAssertEqual(XCTWaiter.wait(for: [updatedChart], timeout: 8), .completed)
        chart.tap()
        XCTAssertTrue(fit.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Edition B · Test circuit")
        XCTAssertTrue(source.label.contains("Fixture B"))
        capture("fixture-b-viewer")

        app.terminate()
        app.launchEnvironment.removeValue(forKey: "NAVIGATION_FLIGHT_UI_TEST_CHART_EDITIONS")
        app.launch()
        section("Charts", in: app).tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertFalse(retired.exists)
        field.tap()
        chart.tap()
        XCTAssertTrue(fit.waitForExistence(timeout: 5))
        XCTAssertEqual(title.label, "Edition B · Test circuit")
        XCTAssertTrue(source.label.contains("Fixture B"))
        capture("fixture-b-after-offline-relaunch")
    }

    func testWideSettingsOrNarrowMoreAndRetainedSection() {
        let app = launch()
        section("Charts", in: app).tap()
        XCTAssertTrue(app.staticTexts["Airports"].waitForExistence(timeout: 5))
        capture("shell-charts")

        let more = app.buttons["More"].firstMatch
        if app.frame.width < 390 || more.isHittable {
            XCTAssertTrue(more.isHittable)
            more.tap()
            XCTAssertTrue(app.buttons["more-settings"].waitForExistence(timeout: 5))
            capture("more")
            app.buttons["more-settings"].tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
            capture("more-settings")
            app.navigationBars.buttons["More"].firstMatch.tap()
            XCTAssertTrue(app.buttons["more-settings"].waitForExistence(timeout: 5))
        } else {
            XCTAssertFalse(more.exists)
            section("Settings", in: app).tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        }
        section("Charts", in: app).tap()
        XCTAssertTrue(app.staticTexts["Airports"].waitForExistence(timeout: 5))
    }

    func testIPadRotationKeepsAerodromeAndViewer() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = launch()
        section("Charts", in: app).tap()
        app.buttons[herzliya].tap()
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
        capture("ipad-portrait-aerodrome")

        XCUIDevice.shared.orientation = .landscapeLeft
        waitForOrientation(landscape: true, in: app)
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
        capture("ipad-landscape-aerodrome")
        let toggle = app.buttons["ToggleSideBar"].firstMatch
        if toggle.isHittable {
            toggle.tap()
            XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
            capture("ipad-landscape-sidebar-aerodrome")
        }
        let chart = app.buttons[circuit]
        reveal(chart, in: app)
        chart.tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        capture("ipad-landscape-viewer")

        XCUIDevice.shared.orientation = .portrait
        waitForOrientation(landscape: false, in: app)
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        capture("ipad-portrait-viewer")
        app.buttons["charts-viewer-back"].tap()
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
    }

    func testLargeTextKeepsLongPublishedTitleAndControlsReachable() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        initialize(app)
        app.launch()
        if UIDevice.current.userInterfaceIdiom == .pad {
            let sidebar = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "sidebar")).firstMatch
            if sidebar.exists && sidebar.isHittable {
                sidebar.tap()
            }
        }
        capture("large-text-shell")
        let chartsTab = section("Charts", in: app)
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 10))
        XCTAssertTrue(chartsTab.isHittable)
        chartsTab.tap()
        XCTAssertTrue(app.buttons[herzliya].waitForExistence(timeout: 5))
        app.buttons[herzliya].tap()
        let chart = app.buttons["charts-document-aip-llhz-chart-01"]
        reveal(chart, in: app)
        capture("large-text-aerodrome")
        chart.tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        capture("large-text-viewer")
        XCTAssertTrue(app.buttons["charts-viewer-back"].isHittable)
    }

    private func launch(unreadable: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        initialize(app)
        if unreadable {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_UNREADABLE_CHART"] = "aip-llhz-chart-11"
        }
        app.launch()
        XCTAssertTrue(section("Charts", in: app).waitForExistence(timeout: 10))
        return app
    }

    private func initialize(_ app: XCUIApplication) {
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = "ChartsUITest-\(UUID())"
    }

    private func section(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[title].firstMatch
        if button.exists { return button }
        let sidebarItem = app.cells[title].firstMatch
        return sidebarItem.exists ? sidebarItem : app.staticTexts[title].firstMatch
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<8 where !element.isHittable { app.swipeUp() }
        XCTAssertTrue(element.isHittable)
    }

    private func waitForOrientation(landscape: Bool, in app: XCUIApplication) {
        let predicate = NSPredicate { _, _ in
            let frame = app.frame
            return frame.width > 0 && frame.height > 0 && (frame.width > frame.height) == landscape
        }
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 8), .completed)
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
