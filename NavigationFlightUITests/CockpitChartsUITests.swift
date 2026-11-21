import XCTest

@MainActor
final class CockpitChartsUITests: XCTestCase {
    private let circuit = "cockpit-chart-aip-llhz-chart-11"

    override func setUp() {
        continueAfterFailure = false
    }

    func testChartsViewerReturnsToListAndMapDuringAnActiveLeg() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = try launch()
        app.buttons["start-leg"].tap()
        let checklist = app.buttons["leg-start-checklist-close"]
        XCTAssertTrue(checklist.waitForExistence(timeout: 5))
        checklist.tap()

        let timer = app.descendants(matching: .any)["cockpit-time"].firstMatch
        let recording = app.buttons["recording-status"]
        XCTAssertTrue(recording.waitForExistence(timeout: 5))
        let recordingBefore = recording.label
        XCTAssertTrue(recordingBefore.contains("Recording"))
        XCTAssertTrue(timer.label.contains("Elapsed from leg start"))
        let positionCheck = app.descendants(matching: .any)["position-check-control"].firstMatch
        XCTAssertTrue(positionCheck.exists)

        let mapTools = showMapTools(app)
        let drift = app.buttons["map-tools-toggle-drift-lines"]
        drift.tap()
        XCTAssertEqual(drift.label, "Drift lines · Off")
        capture("map-tools")
        mapTools.tap()
        waitForCharts(app)
        if UIDevice.current.userInterfaceIdiom == .phone {
            let header = app.buttons["close-cockpit-charts"].frame
            XCTAssertGreaterThan(header.minY, app.frame.minY + app.frame.height * 0.13)
        }
        capture("charts-panel")
        XCTAssertFalse(app.buttons["cockpit-chart-aip-llha-chart-01"].exists)
        let selected = app.buttons[circuit]
        reveal(selected, app: app)
        XCTAssertTrue(selected.label.contains("Departure"))
        selected.tap()

        let fit = app.buttons["charts-fit-page"]
        XCTAssertTrue(fit.waitForExistence(timeout: 5))
        capture("chart-fit")
        app.buttons["Zoom in"].tap()
        capture("chart-zoom")

        app.buttons["charts-viewer-back"].tap()
        waitForCharts(app)
        reveal(selected, app: app)
        selected.tap()
        XCTAssertTrue(fit.waitForExistence(timeout: 5))
        app.buttons["charts-viewer-close"].tap()

        XCTAssertTrue(recording.waitForExistence(timeout: 5))
        XCTAssertEqual(recording.label, recordingBefore)
        XCTAssertTrue(timer.label.contains("Elapsed from leg start"))
        XCTAssertTrue(positionCheck.exists)
        XCTAssertFalse(app.staticTexts["cockpit-charts-title"].exists)
        XCTAssertFalse(app.buttons["start-leg"].exists)
        capture("returned-map")
        _ = showMapTools(app)
        XCTAssertEqual(drift.label, "Drift lines · Off")
    }

    func testUnreadableChartCanReturnAndOpenArrivalCircuit() throws {
        let app = try launch(broken: true)
        openCharts(app)
        reveal(app.buttons[circuit], app: app)
        app.buttons[circuit].tap()
        XCTAssertTrue(app.staticTexts["Chart unavailable"].waitForExistence(timeout: 5))
        capture("chart-error")
        app.buttons["charts-error-back"].tap()
        waitForCharts(app)
        let arrival = app.buttons["cockpit-chart-aip-llib-chart-05"]
        reveal(arrival, app: app, upwards: false)
        XCTAssertTrue(arrival.label.contains("Arrival"))
        arrival.tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        app.buttons["charts-viewer-close"].tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 5))
    }

    func testNoEndpointsAndSameEndpoint() throws {
        let app = try launch { $0.removeValue(forKey: "departureAerodromeReference"); $0.removeValue(forKey: "arrivalAerodromeReference") }
        openCharts(app)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "No charts for this Flight")).firstMatch.exists)
        capture("no-endpoints")
        app.terminate()

        let shared = try launch { $0["arrivalAerodromeReference"] = $0["departureAerodromeReference"] }
        openCharts(shared)
        capture("shared-endpoint")
        reveal(shared.buttons[circuit], app: shared)
        XCTAssertEqual(shared.buttons.matching(identifier: circuit).count, 1)
        XCTAssertTrue(shared.buttons[circuit].label.contains("Departure & Arrival"))
    }

    func testUnresolvedArrivalKeepsDepartureCharts() throws {
        let app = try launch { context in
            if var reference = context["arrivalAerodromeReference"] as? [String: Any],
               var snapshot = reference["snapshot"] as? [String: Any] {
                reference["catalogId"] = "unknown-field"
                snapshot["icao"] = "ZZZZ"
                reference["snapshot"] = snapshot
                context["arrivalAerodromeReference"] = reference
            }
        }
        openCharts(app)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "Arrival charts unavailable")).firstMatch.exists)
        capture("unresolved-arrival")
        reveal(app.buttons[circuit], app: app)
        XCTAssertFalse(app.buttons["cockpit-chart-aip-llib-chart-05"].exists)
    }

    func testKnownArrivalWithoutChartsAndLargeTextLeaveDepartureUsable() throws {
        let app = try launch(emptyAerodrome: "llib", largeText: true)
        openCharts(app)
        let notice = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "no published charts")).firstMatch
        XCTAssertTrue(notice.exists)
        capture("known-empty-arrival-large-text")
        let departure = app.buttons["cockpit-chart-aip-llhz-chart-02"]
        reveal(departure, app: app)
        XCTAssertTrue(departure.label.contains("Departure"))
        departure.tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        app.buttons["charts-viewer-close"].tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 5))
    }

    func testIPadRotationAndTabRoundTripKeepTheMapUsable() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        XCUIDevice.shared.orientation = .portrait
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = try launch()
        openCharts(app)
        XCUIDevice.shared.orientation = .landscapeLeft
        let orientation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            app.frame.width > app.frame.height
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [orientation], timeout: 8), .completed)
        waitForCharts(app)
        capture("landscape-charts")
        reveal(app.buttons[circuit], app: app)
        app.buttons[circuit].tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        capture("landscape-viewer")
        app.buttons["charts-viewer-close"].tap()
        let plans = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Flight Plans"))
        plans.allElementsBoundByIndex.first { $0.isHittable }?.tap()
        XCTAssertTrue(app.navigationBars["Flight Plans"].waitForExistence(timeout: 5))
        let cockpit = app.descendants(matching: .any).matching(identifier: "cockpit-tab")
        cockpit.allElementsBoundByIndex.first { $0.isHittable }?.tap()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["cockpit-charts-title"].exists)
    }

    private func launch(
        broken: Bool = false,
        emptyAerodrome: String? = nil,
        largeText: Bool = false,
        change: ((inout [String: Any]) -> Void)? = nil
    ) throws -> XCUIApplication {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        var bytes = try Data(contentsOf: file.appending(
            path: "NavigationFlightTests/Fixtures/FPLNav/V7/Official/llhz-llib-via-jerusalem-v7.fplnav"
        ))
        if let change {
            var root = try XCTUnwrap(JSONSerialization.jsonObject(with: bytes) as? [String: Any])
            var navigation = try XCTUnwrap(root["navigation"] as? [String: Any])
            var context = try XCTUnwrap(navigation["operationalContext"] as? [String: Any])
            change(&context)
            navigation["operationalContext"] = context
            root["navigation"] = navigation
            bytes = try JSONSerialization.data(withJSONObject: root)
        }
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = UUID().uuidString
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_PLAN"] = bytes.base64EncodedString()
        if broken {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_UNREADABLE_CHART"] = "aip-llhz-chart-11"
        }
        if let emptyAerodrome {
            app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_EMPTY_CHART_AERODROME"] = emptyAerodrome
        }
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        }
        app.launch()
        XCTAssertTrue(app.buttons["start-leg"].waitForExistence(timeout: 10))
        return app
    }

    private func showMapTools(_ app: XCUIApplication) -> XCUIElement {
        let tools = app.buttons["Map tools"].firstMatch
        if !tools.isHittable {
            app.descendants(matching: .any)["aviation-map"].firstMatch
                .coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.3)).tap()
        }
        XCTAssertTrue(tools.waitForExistence(timeout: 5))
        tools.tap()
        let charts = app.buttons["map-tools-charts"]
        XCTAssertTrue(charts.waitForExistence(timeout: 5))
        return charts
    }

    private func openCharts(_ app: XCUIApplication) {
        showMapTools(app).tap()
        waitForCharts(app)
    }

    private func waitForCharts(_ app: XCUIApplication) {
        let close = app.buttons["close-cockpit-charts"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        let usableTarget = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            let frame = close.frame
            return frame.width >= 43.99 && frame.height >= 43.99
        }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [usableTarget], timeout: 5), .completed)
    }

    private func reveal(_ row: XCUIElement, app: XCUIApplication, upwards: Bool = true) {
        let list = app.scrollViews["cockpit-charts-scroll"]
        for _ in 0..<12 {
            let viewport = list.frame
            let target = row.frame
            let center = CGPoint(x: target.midX, y: target.midY)
            if viewport.contains(center), row.isHittable { return }

            let movesUp = target.isEmpty ? upwards : target.midY > viewport.midY
            let origin = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            let destination = list.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: movesUp ? 0.33 : 0.77))
            origin.press(forDuration: 0.05, thenDragTo: destination)
        }
        XCTFail("Chart row is outside the visible Charts list or cannot be tapped: \(row.identifier)")
    }

    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
