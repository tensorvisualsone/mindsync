import XCTest
@testable import MindSync

/// Tests for mode selection functionality
@MainActor
final class ModeSelectionTests: XCTestCase {
    
    func testEntrainmentMode_AllCasesContainsAllModes() {
        // Verify that all expected modes are in allCases
        let allCases = EntrainmentMode.allCases
        let expectedModes: [EntrainmentMode] = [.alpha, .theta, .gamma, .cinematic]
        
        XCTAssertEqual(allCases.count, 4, "Should have exactly 4 modes")
        
        for expectedMode in expectedModes {
            XCTAssertTrue(allCases.contains(expectedMode), "\(expectedMode) should be in allCases")
        }
    }
    
    func testEntrainmentMode_CinematicModeExists() {
        // Verify Cinematic mode is properly defined
        let cinematic = EntrainmentMode.cinematic
        
        XCTAssertEqual(cinematic.frequencyRange.lowerBound, 5.5, accuracy: 0.1)
        XCTAssertEqual(cinematic.frequencyRange.upperBound, 7.5, accuracy: 0.1)
        XCTAssertEqual(cinematic.targetFrequency, 6.5, accuracy: 0.1)
        XCTAssertEqual(cinematic.iconName, "film.fill")
        
        // Verify display name and description are accessible (may return key if not localized)
        let displayName = cinematic.displayName
        let description = cinematic.description
        XCTAssertFalse(displayName.isEmpty, "Display name should not be empty")
        XCTAssertFalse(description.isEmpty, "Description should not be empty")
    }
    
    func testEntrainmentMode_AllModesHaveValidProperties() {
        // Verify all modes have valid properties
        for mode in EntrainmentMode.allCases {
            // Frequency range should be valid
            XCTAssertGreaterThan(mode.frequencyRange.upperBound, mode.frequencyRange.lowerBound,
                               "\(mode) should have valid frequency range")
            XCTAssertGreaterThan(mode.targetFrequency, 0,
                               "\(mode) should have positive target frequency")
            
            // Icon name should not be empty
            XCTAssertFalse(mode.iconName.isEmpty, "\(mode) should have an icon name")
            
            // Display name and description should not be empty
            let displayName = mode.displayName
            let description = mode.description
            XCTAssertFalse(displayName.isEmpty, "\(mode) should have a display name")
            XCTAssertFalse(description.isEmpty, "\(mode) should have a description")
        }
    }
    
    func testUserPreferences_ModeCanBeChanged() {
        // Test that mode can be changed and persisted
        var preferences = UserPreferences.load()
        let originalMode = preferences.preferredMode
        
        // Change to a different mode
        let newMode: EntrainmentMode = originalMode == .alpha ? .theta : .alpha
        preferences.preferredMode = newMode
        preferences.save()
        
        // Reload and verify
        let reloadedPreferences = UserPreferences.load()
        XCTAssertEqual(reloadedPreferences.preferredMode, newMode,
                      "Mode should be persisted and reloaded correctly")
        
        // Restore original mode
        preferences.preferredMode = originalMode
        preferences.save()
    }
    
    func testUserPreferences_AllModesCanBeSet() {
        // Verify that all modes can be set as preferred mode
        var preferences = UserPreferences.load()
        let originalMode = preferences.preferredMode
        
        for mode in EntrainmentMode.allCases {
            preferences.preferredMode = mode
            preferences.save()
            
            let reloaded = UserPreferences.load()
            XCTAssertEqual(reloaded.preferredMode, mode,
                          "\(mode) should be settable as preferred mode")
        }
        
        // Restore original
        preferences.preferredMode = originalMode
        preferences.save()
    }
    
    func testEntrainmentMode_ThemeColorsAreDefined() {
        // Verify all modes have theme colors
        for mode in EntrainmentMode.allCases {
            let themeColor = mode.themeColor
            // Theme color should be accessible (this tests the extension)
            XCTAssertNotNil(themeColor, "\(mode) should have a theme color")
        }
    }
    
    func testEntrainmentMode_UsesFixedScriptProperty() {
        // Test that usesFixedScript returns true for fixed-script modes (dmnShutdown, beliefRewiring)
        // and false for audio-reactive modes (alpha, theta, gamma, cinematic)
        
        // Fixed-script modes (should return true)
        XCTAssertTrue(EntrainmentMode.dmnShutdown.usesFixedScript,
                     "DMN-Shutdown should use fixed script")
        XCTAssertTrue(EntrainmentMode.beliefRewiring.usesFixedScript,
                     "Belief Rewiring should use fixed script")
        
        // Audio-reactive modes (should return false)
        XCTAssertFalse(EntrainmentMode.alpha.usesFixedScript,
                      "Alpha mode should not use fixed script (audio-reactive)")
        XCTAssertFalse(EntrainmentMode.theta.usesFixedScript,
                      "Theta mode should not use fixed script (audio-reactive)")
        XCTAssertFalse(EntrainmentMode.gamma.usesFixedScript,
                      "Gamma mode should not use fixed script (audio-reactive)")
        XCTAssertFalse(EntrainmentMode.cinematic.usesFixedScript,
                      "Cinematic mode should not use fixed script (audio-reactive)")
    }
}

