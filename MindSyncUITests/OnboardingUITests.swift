import XCTest

final class OnboardingUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testOnboardingFlowShowsWarningAndCanBeAccepted() throws {
        let app = XCUIApplication()
        app.launch()

        // Prüfe, dass der Hinweistext angezeigt wird
        XCTAssertTrue(app.staticTexts["onboarding.title"].waitForExistence(timeout: 5))

        // Optional: Details öffnen
        app.buttons["onboarding.learnMoreButton"].tap()
        XCTAssertTrue(app.otherElements["epilepsyWarning.view"].waitForExistence(timeout: 5))
        app.buttons["epilepsyWarning.closeButton"].tap()

        // Disclaimer akzeptieren
        app.buttons["onboarding.acceptButton"].tap()

        // Erwartung: Home-Screen erscheint (Platzhalter-Check)
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 5))
    }
}
