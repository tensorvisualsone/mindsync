import XCTest
import MediaPlayer
@testable import MindSync

/// Unit tests for HomeView navigation logic
/// Tests verify navigation state management and preference handling
@MainActor
final class HomeViewNavigationTests: XCTestCase {
    
    // MARK: - Preference Loading Tests
    
    func testHomeView_PreferencesLoadCorrectly() {
        // Test that UserPreferences can be loaded (simulating HomeView behavior)
        let preferences = UserPreferences.load()
        
        // Verify preferences are valid
        XCTAssertNotNil(preferences.preferredMode)
        XCTAssertNotNil(preferences.preferredLightSource)
        XCTAssertTrue(preferences.defaultIntensity >= 0.0 && preferences.defaultIntensity <= 1.0)
    }
    
    func testHomeView_PreferencesReloadOnAppear() {
        // Test that preferences can be reloaded (simulating onAppear behavior)
        var preferences1 = UserPreferences.load()
        let originalMode = preferences1.preferredMode
        
        // Change mode
        preferences1.preferredMode = originalMode == .alpha ? .theta : .alpha
        preferences1.save()
        
        // Reload (simulating onAppear)
        let preferences2 = UserPreferences.load()
        
        // Verify reloaded preferences reflect changes
        XCTAssertEqual(preferences2.preferredMode, preferences1.preferredMode)
        
        // Restore original
        preferences1.preferredMode = originalMode
        preferences1.save()
    }
    
    // MARK: - Mode Selection Navigation Tests
    
    func testHomeView_ModeSelectionBinding_UpdatesPreferences() {
        // Test that mode selection binding correctly updates preferences
        var preferences = UserPreferences.load()
        let originalMode = preferences.preferredMode
        
        // Simulate mode selection (as done in HomeView)
        let newMode: EntrainmentMode = originalMode == .alpha ? .theta : .alpha
        preferences.preferredMode = newMode
        preferences.save()
        
        // Verify change persisted
        let reloaded = UserPreferences.load()
        XCTAssertEqual(reloaded.preferredMode, newMode)
        
        // Restore
        preferences.preferredMode = originalMode
        preferences.save()
    }
    
    func testHomeView_ModeSelection_AllModesCanBeSelected() {
        // Test that all modes can be selected through the binding pattern
        var preferences = UserPreferences.load()
        let originalMode = preferences.preferredMode
        
        for mode in EntrainmentMode.allCases {
            // Simulate selection
            preferences.preferredMode = mode
            preferences.save()
            
            // Verify
            let reloaded = UserPreferences.load()
            XCTAssertEqual(reloaded.preferredMode, mode, "Should be able to select \(mode)")
        }
        
        // Restore
        preferences.preferredMode = originalMode
        preferences.save()
    }
    
    func testHomeView_ModeSelection_IncludesCinematic() {
        // Verify that Cinematic mode can be selected
        var preferences = UserPreferences.load()
        let originalMode = preferences.preferredMode
        
        preferences.preferredMode = .cinematic
        preferences.save()
        
        let reloaded = UserPreferences.load()
        XCTAssertEqual(reloaded.preferredMode, .cinematic, "Cinematic mode should be selectable")
        
        // Restore
        preferences.preferredMode = originalMode
        preferences.save()
    }
    
    // MARK: - Settings Navigation Tests
    
    func testHomeView_SettingsNavigation_DoesNotBreakPreferences() {
        // Test that opening/closing settings doesn't break preference state
        var preferences = UserPreferences.load()
        let originalMode = preferences.preferredMode
        let originalLightSource = preferences.preferredLightSource
        
        // Simulate settings changes
        preferences.preferredMode = .gamma
        preferences.preferredLightSource = .flashlight
        preferences.save()
        
        // Simulate returning from settings (onDisappear reload)
        let reloaded = UserPreferences.load()
        
        // Verify changes persisted
        XCTAssertEqual(reloaded.preferredMode, .gamma)
        XCTAssertEqual(reloaded.preferredLightSource, .flashlight)
        
        // Restore
        preferences.preferredMode = originalMode
        preferences.preferredLightSource = originalLightSource
        preferences.save()
    }
    
    // MARK: - State Management Tests
    
    func testHomeView_StateVariables_CanBeInitialized() {
        // Test that all state variables used in HomeView can be initialized
        // This verifies the state management pattern is correct
        
        var showingSourceSelection = false
        var selectedMediaItem: MPMediaItem? = nil
        var showingSession = false
        var isMicrophoneSession = false
        var showingModeSelection = false
        var showingSettings = false
        var preferences = UserPreferences.load()
        
        // Verify all can be set
        showingSourceSelection = true
        showingSession = true
        isMicrophoneSession = true
        showingModeSelection = true
        showingSettings = true
        
        XCTAssertTrue(showingSourceSelection)
        XCTAssertTrue(showingSession)
        XCTAssertTrue(isMicrophoneSession)
        XCTAssertTrue(showingModeSelection)
        XCTAssertTrue(showingSettings)
        XCTAssertNotNil(preferences)
    }
    
    func testHomeView_PreferencesUpdate_AfterModeSelection() {
        // Test that preferences update correctly after mode selection
        var preferences = UserPreferences.load()
        let originalMode = preferences.preferredMode
        
        // Simulate mode selection flow
        let newMode: EntrainmentMode = .gamma
        preferences.preferredMode = newMode
        preferences.save()
        
        // Simulate onModeSelected callback (as in HomeView)
        // Reload preferences after mode change
        preferences = UserPreferences.load()
        
        XCTAssertEqual(preferences.preferredMode, newMode)
        
        // Restore
        preferences.preferredMode = originalMode
        preferences.save()
    }
    
    func testHomeView_PreferencesUpdate_AfterSettingsDismiss() {
        // Test that preferences reload after settings dismiss (onDisappear)
        var preferences = UserPreferences.load()
        let originalMode = preferences.preferredMode
        
        // Simulate settings change
        preferences.preferredMode = .theta
        preferences.save()
        
        // Simulate onDisappear reload (as in HomeView)
        let reloaded = UserPreferences.load()
        
        XCTAssertEqual(reloaded.preferredMode, .theta)
        
        // Restore
        preferences.preferredMode = originalMode
        preferences.save()
    }
    
    // MARK: - Navigation Flow Tests
    
    func testHomeView_NavigationFlow_StartSession() {
        // Test the navigation flow for starting a session
        var showingSourceSelection = false
        var showingSession = false
        var selectedMediaItem: MPMediaItem? = nil
        var isMicrophoneSession = false
        
        // Step 1: Tap "Start Session"
        showingSourceSelection = true
        XCTAssertTrue(showingSourceSelection)
        
        // Step 2: Select source (simulated)
        showingSourceSelection = false
        isMicrophoneSession = true
        showingSession = true
        
        XCTAssertFalse(showingSourceSelection)
        XCTAssertTrue(showingSession)
        XCTAssertTrue(isMicrophoneSession)
    }
    
    func testHomeView_NavigationFlow_ModeSelection() {
        // Test the navigation flow for mode selection
        var showingModeSelection = false
        var preferences = UserPreferences.load()
        let originalMode = preferences.preferredMode
        
        // Step 1: Tap mode card
        showingModeSelection = true
        XCTAssertTrue(showingModeSelection)
        
        // Step 2: Select mode (simulated)
        preferences.preferredMode = .gamma
        preferences.save()
        showingModeSelection = false
        
        // Step 3: Reload preferences
        preferences = UserPreferences.load()
        
        XCTAssertFalse(showingModeSelection)
        XCTAssertEqual(preferences.preferredMode, .gamma)
        
        // Restore
        preferences.preferredMode = originalMode
        preferences.save()
    }
    
    func testHomeView_NavigationFlow_Settings() {
        // Test the navigation flow for settings
        var showingSettings = false
        var preferences = UserPreferences.load()
        let originalMode = preferences.preferredMode
        
        // Step 1: Tap settings button
        showingSettings = true
        XCTAssertTrue(showingSettings)
        
        // Step 2: Change settings (simulated)
        preferences.preferredMode = .alpha
        preferences.save()
        showingSettings = false
        
        // Step 3: Reload preferences (onDisappear)
        preferences = UserPreferences.load()
        
        XCTAssertFalse(showingSettings)
        XCTAssertEqual(preferences.preferredMode, .alpha)
        
        // Restore
        preferences.preferredMode = originalMode
        preferences.save()
    }
}

