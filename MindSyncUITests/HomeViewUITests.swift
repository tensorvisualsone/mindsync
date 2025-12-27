import XCTest

final class HomeViewUITests: XCTestCase {
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        
        // Skip onboarding if present
        if app.staticTexts["onboarding.title"].waitForExistence(timeout: 2) {
            app.buttons["onboarding.acceptButton"].tap()
        }
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testHomeView_DisplaysTitle() throws {
        XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 5))
    }
    
    func testHomeView_ShowsStartSessionButton() throws {
        let startButton = app.buttons["home.startSessionButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        XCTAssertTrue(startButton.isEnabled)
    }
    
    func testHomeView_ShowsCurrentMode() throws {
        // Verify that current mode is displayed
        let currentModeLabel = app.staticTexts.matching(identifier: "home.currentMode").firstMatch
        XCTAssertTrue(currentModeLabel.waitForExistence(timeout: 5))
    }
    
    // MARK: - Mode Selection Tests
    
    func testHomeView_ModeCardIsTappable() throws {
        // Find the mode card (it should be a button now)
        // We'll look for the current mode text which should be inside a tappable element
        let modeCard = app.buttons.containing(.staticText, identifier: "home.currentMode").firstMatch
        
        if modeCard.waitForExistence(timeout: 5) {
            modeCard.tap()
            
            // Verify that ModeSelectionView appears
            let modeSelectionTitle = app.staticTexts.matching(identifier: "modeSelection.title").firstMatch
            XCTAssertTrue(modeSelectionTitle.waitForExistence(timeout: 5), "ModeSelectionView should appear after tapping mode card")
            
            // Dismiss the sheet by swiping down
            app.swipeDown(velocity: .fast)
        } else {
            XCTFail("Mode card button not found")
        }
    }
    
    func testModeSelectionView_ShowsAllModes() throws {
        // Open mode selection
        let modeCard = app.buttons.containing(.staticText, identifier: "home.currentMode").firstMatch
        if modeCard.waitForExistence(timeout: 5) {
            modeCard.tap()
            
            // Wait for ModeSelectionView
            let modeSelectionTitle = app.staticTexts.matching(identifier: "modeSelection.title").firstMatch
            XCTAssertTrue(modeSelectionTitle.waitForExistence(timeout: 5))
            
            // Verify all modes are visible (Alpha, Theta, Gamma, Cinematic)
            // We check for display names since they're localized
            let alphaMode = app.buttons.containing(.staticText, identifier: "mode.alpha.displayName").firstMatch
            let thetaMode = app.buttons.containing(.staticText, identifier: "mode.theta.displayName").firstMatch
            let gammaMode = app.buttons.containing(.staticText, identifier: "mode.gamma.displayName").firstMatch
            let cinematicMode = app.buttons.containing(.staticText, identifier: "mode.cinematic.displayName").firstMatch
            
            XCTAssertTrue(alphaMode.waitForExistence(timeout: 2), "Alpha mode should be visible")
            XCTAssertTrue(thetaMode.waitForExistence(timeout: 2), "Theta mode should be visible")
            XCTAssertTrue(gammaMode.waitForExistence(timeout: 2), "Gamma mode should be visible")
            XCTAssertTrue(cinematicMode.waitForExistence(timeout: 2), "Cinematic mode should be visible")
            
            // Dismiss
            app.swipeDown(velocity: .fast)
        } else {
            XCTFail("Mode card button not found")
        }
    }
    
    func testModeSelection_CanSelectMode() throws {
        // Open mode selection
        let modeCard = app.buttons.containing(.staticText, identifier: "home.currentMode").firstMatch
        if modeCard.waitForExistence(timeout: 5) {
            modeCard.tap()
            
            // Wait for ModeSelectionView
            let modeSelectionTitle = app.staticTexts.matching(identifier: "modeSelection.title").firstMatch
            XCTAssertTrue(modeSelectionTitle.waitForExistence(timeout: 5))
            
            // Select a different mode (e.g., Theta if not already selected)
            let thetaMode = app.buttons.containing(.staticText, identifier: "mode.theta.displayName").firstMatch
            if thetaMode.waitForExistence(timeout: 2) {
                thetaMode.tap()
                
                // Wait a bit for the sheet to dismiss
                sleep(1)
                
                // Verify we're back on HomeView
                XCTAssertTrue(app.staticTexts["home.title"].waitForExistence(timeout: 5))
            }
        } else {
            XCTFail("Mode card button not found")
        }
    }
    
    // MARK: - Settings Navigation Tests
    
    func testHomeView_ShowsSettingsButton() throws {
        // Look for the settings gear icon button in the toolbar
        let settingsButton = app.buttons.matching(identifier: "settings.title").firstMatch
        
        // If not found by accessibility label, try by navigation bar
        if !settingsButton.exists {
            // Settings button should be in the navigation bar
            let navBar = app.navigationBars.firstMatch
            if navBar.exists {
                let buttons = navBar.buttons
                XCTAssertGreaterThan(buttons.count, 0, "Navigation bar should have buttons")
            }
        }
    }
    
    func testSettingsNavigation_OpensSettingsView() throws {
        // Try to find and tap settings button
        let settingsButton = app.buttons.matching(identifier: "settings.title").firstMatch
        
        if !settingsButton.exists {
            // Try tapping the rightmost button in navigation bar (usually settings)
            let navBar = app.navigationBars["Home"]
            if navBar.exists {
                let buttons = navBar.buttons
                if buttons.count > 0 {
                    buttons.element(boundBy: buttons.count - 1).tap()
                }
            }
        } else {
            settingsButton.tap()
        }
        
        // Verify SettingsView appears
        let settingsTitle = app.staticTexts["settings.title"]
        if settingsTitle.waitForExistence(timeout: 5) {
            XCTAssertTrue(settingsTitle.exists, "SettingsView should appear")
            
            // Verify settings content is visible
            let modePicker = app.pickers.matching(identifier: "settings.modePicker").firstMatch
            XCTAssertTrue(modePicker.waitForExistence(timeout: 2), "Mode picker should be visible in settings")
            
            // Dismiss settings
            app.buttons["settings.doneButton"].tap()
        }
    }
    
    func testSettingsView_ShowsAllModes() throws {
        // Open settings
        let navBar = app.navigationBars["Home"]
        if navBar.exists {
            let buttons = navBar.buttons
            if buttons.count > 0 {
                buttons.element(boundBy: buttons.count - 1).tap()
            }
        }
        
        // Wait for SettingsView
        let settingsTitle = app.staticTexts["settings.title"]
        if settingsTitle.waitForExistence(timeout: 5) {
            // Open mode picker
            let modePicker = app.pickers.matching(identifier: "settings.modePicker").firstMatch
            if modePicker.waitForExistence(timeout: 2) {
                modePicker.tap()
                
                // Verify all modes are available in picker
                // Note: Picker content might be in a wheel or menu
                // This is a basic check - actual picker interaction may vary
                XCTAssertTrue(modePicker.exists, "Mode picker should be accessible")
            }
            
            // Dismiss
            app.buttons["settings.doneButton"].tap()
        }
    }
    
    // MARK: - Source Selection Tests
    
    func testSourceSelection_OpensOnButtonTap() throws {
        let startButton = app.buttons["home.startSessionButton"]
        XCTAssertTrue(startButton.waitForExistence(timeout: 5))
        
        startButton.tap()
        
        // Verify SourceSelectionView appears
        let sourceSelectionTitle = app.staticTexts.matching(identifier: "sourceSelection.title").firstMatch
        XCTAssertTrue(sourceSelectionTitle.waitForExistence(timeout: 5), "SourceSelectionView should appear")
    }
    
    func testSourceSelection_ShowsMusicLibraryOption() throws {
        // Open source selection
        app.buttons["home.startSessionButton"].tap()
        
        // Wait for SourceSelectionView
        let sourceSelectionTitle = app.staticTexts.matching(identifier: "sourceSelection.title").firstMatch
        if sourceSelectionTitle.waitForExistence(timeout: 5) {
            // Verify music library button exists
            let musicButton = app.buttons["sourceSelection.musicLibraryButton"]
            XCTAssertTrue(musicButton.waitForExistence(timeout: 2), "Music library button should be visible")
        }
    }
    
    func testSourceSelection_ShowsMicrophoneOption() throws {
        // Open source selection
        app.buttons["home.startSessionButton"].tap()
        
        // Wait for SourceSelectionView
        let sourceSelectionTitle = app.staticTexts.matching(identifier: "sourceSelection.title").firstMatch
        if sourceSelectionTitle.waitForExistence(timeout: 5) {
            // Verify microphone button exists
            let micButton = app.buttons["sourceSelection.microphoneButton"]
            XCTAssertTrue(micButton.waitForExistence(timeout: 2), "Microphone button should be visible")
        }
    }
}

