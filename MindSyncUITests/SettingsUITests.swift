import XCTest

final class SettingsUITests: XCTestCase {
    
    var app: XCUIApplication!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }
    
    override func tearDownWithError() throws {
        app = nil
    }
    
    // MARK: - Navigation Tests
    
    func testSettingsNavigation() throws {
        // Complete onboarding if needed
        let homeTitle = app.staticTexts["home.title"]
        if !homeTitle.waitForExistence(timeout: 2) {
            let onboardingAcceptButton = app.buttons["onboarding.acceptButton"]
            if onboardingAcceptButton.waitForExistence(timeout: 5) {
                onboardingAcceptButton.tap()
                XCTAssertTrue(homeTitle.waitForExistence(timeout: 5))
            }
        }
        
        // Navigate to settings via toolbar button
        let navBar = app.navigationBars["Home"]
        if navBar.exists {
            let buttons = navBar.buttons
            if buttons.count > 0 {
                // Settings button is the rightmost button (trailing)
                buttons.element(boundBy: buttons.count - 1).tap()
                
                // Verify SettingsView appears
                let settingsTitle = app.navigationBars["Einstellungen"]
                XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5), "SettingsView should appear")
            }
        }
    }
    
    // MARK: - UI Structure Tests
    
    func testSettingsViewElementsExist() throws {
        // Navigate to settings
        navigateToSettings()
        
        // Verify all expected elements exist
        let modePicker = app.pickers["settings.modePicker"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 5), "Mode picker should exist")
        
        let fallDetectionToggle = app.switches["settings.fallDetectionToggle"]
        XCTAssertTrue(fallDetectionToggle.waitForExistence(timeout: 2), "Fall detection toggle should exist")
        
        let thermalProtectionToggle = app.switches["settings.thermalProtectionToggle"]
        XCTAssertTrue(thermalProtectionToggle.waitForExistence(timeout: 2), "Thermal protection toggle should exist")
        
        let hapticFeedbackToggle = app.switches["settings.hapticFeedbackToggle"]
        XCTAssertTrue(hapticFeedbackToggle.waitForExistence(timeout: 2), "Haptic feedback toggle should exist")
        
        let intensitySlider = app.sliders["settings.intensitySlider"]
        XCTAssertTrue(intensitySlider.waitForExistence(timeout: 2), "Intensity slider should exist")
        
        let doneButton = app.buttons["settings.doneButton"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 2), "Done button should exist")
    }
    
    func testModePickerInteraction() throws {
        navigateToSettings()
        
        let modePicker = app.pickers["settings.modePicker"]
        XCTAssertTrue(modePicker.waitForExistence(timeout: 5))
        
        // Tap to open picker
        modePicker.tap()
        
        // Note: Picker interaction depends on iOS version and picker style
        // In a wheel picker, we would need to swipe or tap specific values
        // For now, we verify the picker is accessible
        XCTAssertTrue(modePicker.exists, "Mode picker should be accessible")
        
        // Dismiss picker if needed
        app.tap() // Tap outside to dismiss
        
        // Dismiss settings
        app.buttons["settings.doneButton"].tap()
    }
    
    /// Tests light source selection
    func testLightSourceSelection() throws {
        // This test would:
        // 1. Navigate to settings
        // 2. Select flashlight option
        // 3. Verify preference saved
        // 4. Select screen option
        // 5. Verify color picker appears (if screen selected)
        // 6. Verify preference saved
        
        // Currently tested via:
        // - Unit tests (UserPreferencesTests)
        // - Manual testing
    }
    
    func testToggleSwitches() throws {
        navigateToSettings()
        
        // Test fall detection toggle
        let fallDetectionToggle = app.switches["settings.fallDetectionToggle"]
        XCTAssertTrue(fallDetectionToggle.waitForExistence(timeout: 5))
        
        let initialFallDetectionState = fallDetectionToggle.value as? String == "1"
        fallDetectionToggle.tap()
        
        // Wait a moment for state change
        sleep(1)
        
        let newFallDetectionState = fallDetectionToggle.value as? String == "1"
        XCTAssertNotEqual(initialFallDetectionState, newFallDetectionState, "Fall detection toggle should change state")
        
        // Test thermal protection toggle
        let thermalProtectionToggle = app.switches["settings.thermalProtectionToggle"]
        XCTAssertTrue(thermalProtectionToggle.waitForExistence(timeout: 2))
        
        let initialThermalState = thermalProtectionToggle.value as? String == "1"
        thermalProtectionToggle.tap()
        sleep(1)
        
        let newThermalState = thermalProtectionToggle.value as? String == "1"
        XCTAssertNotEqual(initialThermalState, newThermalState, "Thermal protection toggle should change state")
        
        // Test haptic feedback toggle
        let hapticFeedbackToggle = app.switches["settings.hapticFeedbackToggle"]
        XCTAssertTrue(hapticFeedbackToggle.waitForExistence(timeout: 2))
        
        let initialHapticState = hapticFeedbackToggle.value as? String == "1"
        hapticFeedbackToggle.tap()
        sleep(1)
        
        let newHapticState = hapticFeedbackToggle.value as? String == "1"
        XCTAssertNotEqual(initialHapticState, newHapticState, "Haptic feedback toggle should change state")
        
        // Dismiss settings
        app.buttons["settings.doneButton"].tap()
    }
    
    func testIntensitySlider() throws {
        navigateToSettings()
        
        let intensitySlider = app.sliders["settings.intensitySlider"]
        XCTAssertTrue(intensitySlider.waitForExistence(timeout: 5))
        
        // Get initial value for verification
        let initialIntensity = intensitySlider.value as? Float ?? 0.5
        XCTAssertEqual(initialIntensity, 0.5, accuracy: 0.1, "Initial intensity slider value should be 0.5")

        // Adjust slider (drag to a different position)
        intensitySlider.adjust(toNormalizedSliderPosition: 0.8)

        // Wait for value to update
        sleep(1)

        // Verify value changed
        let finalIntensity = intensitySlider.value as? Float ?? 0.5
        XCTAssertNotEqual(initialIntensity, finalIntensity, "Intensity slider value should change after adjustment")
        XCTAssertEqual(finalIntensity, 0.8, accuracy: 0.1, "Final intensity slider value should be approximately 0.8")
        // Note: Slider value might be normalized, so we just verify it changed
        // In a real scenario, we'd verify the displayed percentage text
        
        // Dismiss settings
        app.buttons["settings.doneButton"].tap()
    }
    
    /// Tests preference persistence across app restarts
    func testPreferencePersistence() throws {
        // This test would:
        // 1. Set various preferences
        // 2. Terminate app
        // 3. Relaunch app
        // 4. Verify preferences are restored
        
        // Currently tested via:
        // - Unit tests (UserPreferencesTests.testSaveAndLoad)
    }
    
    // MARK: - Helper Methods
    
    private func navigateToSettings() {
        // Complete onboarding if needed
        let homeTitle = app.staticTexts["home.title"]
        if !homeTitle.waitForExistence(timeout: 2) {
            let onboardingAcceptButton = app.buttons["onboarding.acceptButton"]
            if onboardingAcceptButton.waitForExistence(timeout: 5) {
                onboardingAcceptButton.tap()
                XCTAssertTrue(homeTitle.waitForExistence(timeout: 5))
            }
        }
        
        // Navigate to settings via toolbar button
        let navBar = app.navigationBars["Home"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Home navigation bar should exist")
        
        let buttons = navBar.buttons
        XCTAssertGreaterThan(buttons.count, 0, "Navigation bar should have buttons")
        
        // Settings button is the rightmost button (trailing)
        buttons.element(boundBy: buttons.count - 1).tap()
        
        // Verify SettingsView appears
        let settingsTitle = app.navigationBars["Einstellungen"]
        XCTAssertTrue(settingsTitle.waitForExistence(timeout: 5), "SettingsView should appear")
    }
    
    // MARK: - Integration Notes
    
    // Note: Some tests require actual device features:
    // - Light source selection (flashlight only works on real devices)
    // - Haptic feedback (only works on real devices)
    //
    // Preference persistence across app restarts is better tested via:
    // - Unit tests (UserPreferencesTests)
    // - Manual testing
}
