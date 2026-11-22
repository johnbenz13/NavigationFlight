import XCTest

@MainActor
final class AIPDownloadsUITests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testDownloadRecoveryAndOfflineRelaunch() {
        exerciseUpdate(orientation: .portrait)
    }

    func testDownloadRecoveryOnIPadInLandscape() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        exerciseUpdate(orientation: .landscapeLeft)
    }

    private func exerciseUpdate(orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = makeApp(mode: "verification-failure")
        app.launch()

        tab("More", app).tap()
        let downloads = app.buttons["more-downloads"]
        XCTAssertTrue(downloads.waitForExistence(timeout: 6))
        waitForUpdateIndicator(downloads)
        capture("more-update")
        downloads.tap()
        waitForStatus("Update available", app)
        capture("downloads-available")
        app.buttons["downloads-back"].tap()
        app.buttons["more-settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["More"].firstMatch.tap()

        tab("Charts", app).tap()
        XCTAssertTrue(app.buttons["charts-aip-update"].waitForExistence(timeout: 5))
        capture("charts-update-link")
        app.buttons["charts-aip-update"].tap()
        waitForStatus("Update available", app)

        let action = app.buttons["downloads-confirm"]
        action.tap()
        let alert = app.alerts["Download chart update?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "02-2026")).firstMatch.exists)
        capture("download-confirm")
        alert.buttons["Cancel"].tap()
        waitForStatus("Update available", app)

        startDownload(app)
        XCTAssertTrue(app.buttons["downloads-cancel"].waitForExistence(timeout: 5))
        capture("download-progress")
        app.buttons["downloads-cancel"].tap()
        waitForStatus("Download canceled", app)
        capture("download-cancelled")

        startDownload(app)
        waitForStatus("Charts could not be verified", app, timeout: 15)
        capture("download-verification-failed")
        startDownload(app)
        waitForStatus("Update installed", app, timeout: 15)
        capture("download-installed")
        app.buttons["downloads-open-charts"].tap()
        XCTAssertTrue(app.buttons["charts-aerodrome-fixture-field"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["charts-aip-update"].exists)
        openFixturePDF(app)

        app.terminate()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_DOWNLOADS"] = "offline"
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_CHART_OFFLINE"] = "1"
        app.launch()
        tab("Charts", app).tap()
        openFixturePDF(app)
        capture("updated-chart-offline")
    }

    func testUpToDateAndUnreachableAreDistinct() {
        XCUIDevice.shared.orientation = .portrait
        let current = makeApp(mode: "current")
        current.launch()
        tab("More", current).tap()
        current.buttons["more-downloads"].tap()
        waitForStatus("Up to date", current)
        capture("downloads-up-to-date")
        current.terminate()

        let offline = makeApp(mode: "offline")
        offline.launch()
        tab("More", offline).tap()
        offline.buttons["more-downloads"].tap()
        waitForStatus("Update status unavailable", offline)
        XCTAssertTrue(offline.buttons["downloads-check"].exists)
        XCTAssertFalse(offline.buttons["downloads-confirm"].exists)
        capture("downloads-unreachable-no-offer")
    }

    func testBackgroundCancellationAndKnownOfferAfterOfflineRelaunch() {
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(mode: "available")
        app.launch()
        tab("More", app).tap()
        app.buttons["more-downloads"].tap()
        waitForStatus("Update available", app)
        startDownload(app)
        XCTAssertTrue(app.buttons["downloads-cancel"].waitForExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        app.activate()
        waitForStatus("Download canceled", app)
        XCTAssertTrue(app.buttons["downloads-confirm"].exists)

        app.terminate()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_DOWNLOADS"] = "offline"
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        app.launch()
        let sidebar = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "sidebar")).firstMatch
        if sidebar.exists && sidebar.isHittable { sidebar.tap() }
        tab("More", app).tap()
        let downloads = app.buttons["more-downloads"]
        XCTAssertTrue(downloads.waitForExistence(timeout: 5))
        waitForUpdateIndicator(downloads)
        downloads.tap()
        waitForStatus("Update status unavailable", app)
        XCTAssertTrue(app.buttons["downloads-check"].exists)
        XCTAssertFalse(app.buttons["downloads-confirm"].exists)
        capture("downloads-unreachable-known-offer-large-text")
    }

    func testVerifiedOfferRepairsUnavailableChartLibrary() {
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(mode: "available")
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_NO_BUNDLED_CHARTS"] = "1"
        app.launch()
        tab("Charts", app).tap()
        XCTAssertTrue(app.staticTexts["Charts unavailable"].waitForExistence(timeout: 5))
        let update = app.buttons["charts-aip-update"]
        XCTAssertTrue(update.waitForExistence(timeout: 5))
        capture("unavailable-charts-update-link")
        update.tap()
        waitForStatus("Update available", app)
        XCTAssertTrue(app.staticTexts["No chart edition is available offline."].exists)
        startDownload(app)
        waitForStatus("Update installed", app, timeout: 15)
        app.buttons["downloads-open-charts"].tap()
        openFixturePDF(app)
    }

    func testDownloadsAccessibility() throws {
        XCUIDevice.shared.orientation = .portrait
        let app = makeApp(mode: "available")
        app.launch()
        tab("More", app).tap()
        let downloads = app.buttons["more-downloads"]
        XCTAssertTrue(downloads.waitForExistence(timeout: 5))
        waitForUpdateIndicator(downloads)
        let audits: XCUIAccessibilityAuditType = .sufficientElementDescription
        try app.performAccessibilityAudit(for: audits)
        app.terminate()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = "DownloadsAudit-\(UUID())"
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_INITIAL_SECTION"] = "downloads"
        app.launch()
        waitForStatus("Update available", app)
        let download = app.buttons["downloads-confirm"]
        let sidebar = app.buttons["ToggleSideBar"].firstMatch
        if !download.isHittable, sidebar.isHittable { sidebar.tap() }
        XCTAssertTrue(download.isHittable)
        try app.performAccessibilityAudit(for: audits)
        download.tap()
        let alert = app.alerts["Download chart update?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: audits)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(download.isHittable)
    }

    func testCheckingVerifyingAndTransferAcrossTabs() {
        exerciseTransientDownloadStates(orientation: .portrait)
    }

    func testTransientDownloadStatesInIPadLandscape() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad)
        exerciseTransientDownloadStates(orientation: .landscapeLeft)
    }

    private func exerciseTransientDownloadStates(orientation: UIDeviceOrientation) {
        XCUIDevice.shared.orientation = orientation
        defer { XCUIDevice.shared.orientation = .portrait }
        let app = makeApp(mode: "held")
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_INITIAL_SECTION"] = "downloads"
        app.launch()
        waitForStatus("Checking for updates", app)
        capture("checking-without-offer")
        waitForStatus("Update available", app, timeout: 15)
        app.buttons["downloads-back"].tap()
        app.buttons["more-downloads"].tap()
        waitForStatus("Checking for updates", app)
        XCTAssertTrue(app.staticTexts["Last known update shown while checking."].exists)
        XCTAssertTrue(app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Last seen edition")).firstMatch.exists)
        capture("checking-with-known-offer")
        waitForStatus("Update available", app, timeout: 15)

        startDownload(app)
        assertHeldProgress(app)
        tab("Charts", app).tap()
        XCTAssertTrue(app.buttons["charts-aip-update"].waitForExistence(timeout: 5))
        app.buttons["charts-aip-update"].tap()
        assertHeldProgress(app)
        capture("progress-after-switching-tabs")
        waitForStatus("Verifying charts", app, timeout: 20)
        capture("verifying-charts")
        waitForStatus("Update installed", app, timeout: 15)
        app.buttons["downloads-open-charts"].tap()
        openFixturePDF(app)
    }

    func testTransferFailureKeepsOfferAndAllowsRetry() {
        let app = makeApp(mode: "transfer-failure")
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_INITIAL_SECTION"] = "downloads"
        app.launch()
        waitForStatus("Update available", app)
        startDownload(app)
        waitForStatus("Download failed", app, timeout: 15)
        XCTAssertTrue(app.staticTexts["The installed edition is still available offline."].exists)
        XCTAssertEqual(app.buttons["downloads-confirm"].label, "Retry download")
        capture("download-failed")
        startDownload(app)
        waitForStatus("Update installed", app, timeout: 15)
    }

    func testVoiceOverDownloadsFocus() async throws {
        guard #available(iOS 27.0, *) else { throw XCTSkip("The VoiceOver testing service requires iOS 27.") }
        let voiceOver = XCUIDevice.shared.voiceOverService
        let wasEnabled = voiceOver.isEnabled
        try voiceOver.enable()
        defer { if !wasEnabled { try? voiceOver.disable() } }

        var speech: [String] = []

        let app = makeApp(mode: "held")
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_INITIAL_SECTION"] = "downloads"
        app.launch()
        waitForStatus("Update available", app, timeout: 18)
        let tutorial = app.alerts["VoiceOver Gestures"]
        if tutorial.exists {
            tutorial.buttons["OK"].tap()
            if tutorial.exists { tutorial.buttons["OK"].doubleTap() }
            XCTAssertTrue(tutorial.waitForNonExistence(timeout: 6))
        }

        for phrase in ["Israel AIP charts", "Update available", "Installed edition", "Available edition", "Download size", "Download update"] {
            if try !findSpoken(phrase, with: voiceOver, recording: &speech) {
                captureSpeech(speech)
                XCTFail("VoiceOver omitted \(phrase)")
                return
            }
        }
        captureSpeech(speech)

        app.buttons["downloads-confirm"].doubleTap()
        let alert = app.alerts["Download chart update?"]
        XCTAssertTrue(alert.waitForExistence(timeout: 6))
        XCTAssertTrue(try findSpoken("Download chart update", with: voiceOver, recording: &speech))
        XCTAssertTrue(try findSpoken("Cancel", with: voiceOver, recording: &speech))
        XCTAssertTrue(try findSpoken("Download Button", with: voiceOver, recording: &speech))
        capture("voiceover-confirmation")
        alert.buttons["Cancel"].tap()
        if alert.exists { alert.buttons["Cancel"].doubleTap() }
        XCTAssertTrue(alert.waitForNonExistence(timeout: 6))
        var focusRestored = false
        for _ in 0..<8 {
            try await Task.sleep(for: .milliseconds(250))
            guard let restored = try? voiceOver.currentSpeech().utterance else { continue }
            speech.append("After cancel: \(restored)")
            if restored.localizedCaseInsensitiveContains("Download update") {
                focusRestored = true
                break
            }
        }
        captureSpeech(speech)
        XCTAssertTrue(focusRestored, "VoiceOver did not return to Download update.")
        capture("voiceover-back-to-downloads")
    }

    @available(iOS 27.0, *)
    private func findSpoken(
        _ phrase: String,
        with voiceOver: XCUIVoiceOverService,
        recording speech: inout [String]
    ) throws -> Bool {
        for step in 0..<20 {
            let output = step == 0 ? try? voiceOver.currentSpeech() : try voiceOver.moveForward()
            guard let output else { continue }
            let utterance = output.utterance
            speech.append(utterance)
            if speechKey(utterance).contains(speechKey(phrase)) { return true }
        }
        return false
    }

    private func speechKey(_ value: String) -> String {
        String(value.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private func captureSpeech(_ speech: [String]) {
        let attachment = XCTAttachment(string: speech.joined(separator: "\n"))
        attachment.name = "VoiceOver utterances"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func assertHeldProgress(_ app: XCUIApplication) {
        let indicator = app.progressIndicators["Chart download progress"].firstMatch
        let value = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value IN %@", ["39 percent", "40 percent"]), object: indicator
        )
        XCTAssertEqual(XCTWaiter.wait(for: [value], timeout: 7), .completed)
    }

    private func startDownload(_ app: XCUIApplication) {
        app.buttons["downloads-confirm"].tap()
        app.alerts["Download chart update?"].buttons["Download"].tap()
    }

    private func openFixturePDF(_ app: XCUIApplication) {
        let aerodrome = app.buttons["charts-aerodrome-fixture-field"]
        XCTAssertTrue(aerodrome.waitForExistence(timeout: 5))
        aerodrome.tap()
        app.buttons["charts-document-fixture-field-chart"].tap()
        XCTAssertTrue(app.buttons["charts-fit-page"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["charts-viewer-title"].firstMatch.label, "Edition B · Test circuit")
    }

    private func waitForStatus(_ value: String, _ app: XCUIApplication, timeout: TimeInterval = 8) {
        let status = app.staticTexts["downloads-status"]
        let expected = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", value), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: timeout), .completed, "Expected \(value)")
    }

    private func waitForUpdateIndicator(_ row: XCUIElement) {
        let expected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", "Update available"), object: row
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expected], timeout: 8), .completed)
    }

    private func tab(_ title: String, _ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons[title].firstMatch
        let sidebar = app.cells[title].firstMatch
        if button.exists { return button }
        if sidebar.exists { return sidebar }
        return app.staticTexts[title].firstMatch
    }

    private func makeApp(mode: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_LIBRARY_ID"] = "DownloadsUITest-\(UUID())"
        app.launchEnvironment["NAVIGATION_FLIGHT_UI_TEST_DOWNLOADS"] = mode
        return app
    }

    private func capture(_ name: String) {
        let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
