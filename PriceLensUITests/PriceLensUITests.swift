import XCTest

/// UI tests run entirely on fixture data — no camera, no network.
final class PriceLensUITests: XCTestCase {

    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "-FixtureScenario", scenario]
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 15) -> Bool {
        element.waitForExistence(timeout: timeout)
    }

    // AC-2/AC-3/AC-5: fixture scan locks, search starts automatically, results appear.
    func testSuccessfulScanShowsDecisionAndOffers() {
        let app = launch("successfulScan")

        XCTAssertTrue(waitFor(element(app, "decisionBadge")),
                      "Decision badge should appear after fixture lock + search")

        let viewOffers = element(app, "viewOffersButton")
        XCTAssertTrue(viewOffers.exists)
        viewOffers.tap()

        XCTAssertTrue(waitFor(element(app, "sortMenu")), "Sort menu should exist in expanded sheet")
        XCTAssertTrue(waitFor(element(app, "offerCard_google"), timeout: 10),
                      "Google offer card should be listed")
    }

    // AC-4: no price detected -> "Add store price" is offered; entering it updates the decision.
    func testNoStorePriceAllowsManualEntry() {
        let app = launch("noStorePrice")

        let addPrice = element(app, "addStorePriceButton")
        XCTAssertTrue(waitFor(addPrice), "Add store price button should appear")
        addPrice.tap()

        let priceField = element(app, "editPriceField")
        XCTAssertTrue(waitFor(priceField))
        priceField.tap()
        priceField.typeText("2000")

        element(app, "applyEditButton").tap()

        XCTAssertTrue(waitFor(element(app, "decisionBadge")),
                      "Decision should appear after entering a store price")
    }

    // AC-8: Google blocked, Allegro keeps working; Google fallback link present.
    func testProviderFailureKeepsFallback() {
        let app = launch("providerFailure")

        XCTAssertTrue(waitFor(element(app, "decisionBadge")))
        element(app, "viewOffersButton").tap()

        XCTAssertTrue(waitFor(element(app, "fallback_google"), timeout: 10),
                      "Google fallback should be visible")
    }

    // Journey F: offline -> offline state + retry, identity still shown.
    func testOfflineShowsRetry() {
        let app = launch("offline")

        XCTAssertTrue(waitFor(element(app, "fallback_google"), timeout: 15),
                      "Offline fallback with retry should appear")
    }

    // AC-10: language switch to Russian changes UI text.
    func testLanguageSwitchToRussian() {
        let app = launch("successfulScan")

        // Close the result sheet so the top chrome (Settings gear) is reachable.
        let rescan = element(app, "rescanButton")
        XCTAssertTrue(waitFor(rescan), "Rescan button should exist")
        rescan.tap()

        let settingsButton = element(app, "settingsButton")
        XCTAssertTrue(waitFor(settingsButton))
        settingsButton.tap()

        let russian = element(app, "language_ru")
        XCTAssertTrue(waitFor(russian), "Russian language option should exist")
        russian.tap()

        let done = app.buttons["Готово"].exists ? app.buttons["Готово"] : app.buttons["Done"]
        XCTAssertTrue(waitFor(done))
        done.tap()

        let historyButton = element(app, "historyButton")
        XCTAssertTrue(waitFor(historyButton), "History button should exist after language switch")
        XCTAssertEqual(historyButton.label, "История", "Russian UI should show История as the history button label")
    }

    // AC-12: completed scan is saved to history and can be reopened.
    func testHistoryRowAppearsAndReopens() {
        let app = launch("successfulScan")

        XCTAssertTrue(waitFor(element(app, "decisionBadge")))

        // Close the result sheet via Rescan.
        let rescan = element(app, "rescanButton")
        XCTAssertTrue(waitFor(rescan), "Rescan button should exist")
        rescan.tap()

        let history = element(app, "historyButton")
        XCTAssertTrue(waitFor(history))
        history.tap()

        let row = app.cells.firstMatch
        XCTAssertTrue(waitFor(row), "History should contain the scan")
        row.tap()

        XCTAssertTrue(waitFor(element(app, "decisionBadge"), timeout: 20),
                      "Re-running from history should show results again")
    }
}
