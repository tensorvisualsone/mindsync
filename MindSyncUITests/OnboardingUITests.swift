import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingFlowShowsWarningAndCanBeAccepted() throws {
        let app = XCUIApplication()
        app.launch()

        // Prüfe, dass der Hinweistext angezeigt wird
        XCTAssertTrue(app.staticTexts["Wichtige Sicherheitshinweise"].waitForExistence(timeout: 5))

        // Optional: Details öffnen
        app.buttons["Mehr erfahren"].tap()
        XCTAssertTrue(app.navigationBars["Sicherheit"].waitForExistence(timeout: 5))
        app.buttons["Close"].firstMatch.tap()

        // Disclaimer akzeptieren
        app.buttons["Ich verstehe und akzeptiere"].tap()

        // Erwartung: Home-Screen erscheint (Platzhalter-Check)
        XCTAssertTrue(app.staticTexts["MindSync"].waitForExistence(timeout: 5))
    }
}
