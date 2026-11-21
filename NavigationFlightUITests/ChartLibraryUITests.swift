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
        capture("library", app)

        library.tap()
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
        capture("aerodrome", app)
        let chart = app.buttons[circuit]
        reveal(chart, in: app)
        chart.tap()

        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["charts-viewer-title"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["charts-source"].firstMatch.exists)
        capture("viewer-fit", app)
        app.buttons["Zoom in"].tap()
        app.buttons["Zoom in"].tap()
        capture("viewer-zoom", app)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.65, dy: 0.55)).press(
            forDuration: 0.1,
            thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.40, dy: 0.35))
        )
        capture("viewer-pan", app)
        app.buttons["charts-fit-page"].tap()
        capture("viewer-refit", app)
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
        capture("airfield", app)
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
        capture("viewer-error", app)
        app.buttons["charts-error-back"].tap()
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
        let otherChart = app.buttons["charts-document-aip-llhz-chart-10"]
        reveal(otherChart, in: app)
        otherChart.tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
    }

    func testWideSettingsOrNarrowMoreAndRetainedSection() {
        let app = launch()
        section("Charts", in: app).tap()
        XCTAssertTrue(app.staticTexts["Airports"].waitForExistence(timeout: 5))
        capture("shell-charts", app)

        let more = app.buttons["More"].firstMatch
        if app.frame.width < 390 || more.isHittable {
            XCTAssertTrue(more.isHittable)
            more.tap()
            XCTAssertTrue(app.buttons["more-settings"].waitForExistence(timeout: 5))
            capture("more", app)
            app.buttons["more-settings"].tap()
            XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
            capture("more-settings", app)
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
        capture("ipad-portrait-aerodrome", app)

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
        capture("ipad-landscape-aerodrome", app)
        let toggle = app.buttons["ToggleSideBar"].firstMatch
        if toggle.isHittable {
            toggle.tap()
            XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
            capture("ipad-landscape-sidebar-aerodrome", app)
        }
        let chart = app.buttons[circuit]
        reveal(chart, in: app)
        chart.tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        capture("ipad-landscape-viewer", app)

        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        capture("ipad-portrait-viewer", app)
        app.buttons["charts-viewer-back"].tap()
        XCTAssertTrue(app.navigationBars["הרצליה"].waitForExistence(timeout: 5))
    }

    func testLargeTextKeepsLongPublishedTitleAndControlsReachable() {
        let app = XCUIApplication()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        initialize(app)
        app.launch()
        let chartsTab = section("Charts", in: app)
        XCTAssertTrue(chartsTab.waitForExistence(timeout: 10))
        XCTAssertTrue(chartsTab.isHittable)
        chartsTab.tap()
        XCTAssertTrue(app.buttons[herzliya].waitForExistence(timeout: 5))
        app.buttons[herzliya].tap()
        let chart = app.buttons["charts-document-aip-llhz-chart-01"]
        reveal(chart, in: app)
        capture("large-text-aerodrome", app)
        chart.tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        capture("large-text-viewer", app)
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

    private func capture(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
