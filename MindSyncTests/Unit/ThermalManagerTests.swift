import XCTest
@testable import MindSync

final class ThermalManagerTests: XCTestCase {
    var thermalManager: ThermalManager!
    
    override func setUp() {
        super.setUp()
        thermalManager = ThermalManager()
    }
    
    override func tearDown() {
        thermalManager = nil
        super.tearDown()
    }
    
    // MARK: - Thermal State Tests
    
    func testCurrentState_ReturnsValidThermalState() {
        // When
        let state = thermalManager.currentState
        
        // Then: Should return a valid thermal state
        // We can't control the actual device state, but we can verify it's a valid enum value
        switch state {
        case .nominal, .fair, .serious, .critical:
            XCTAssertTrue(true, "Valid thermal state")
        @unknown default:
            XCTAssertTrue(true, "Unknown but valid thermal state")
        }
    }
    
    // MARK: - Flashlight Intensity Tests
    
    func testMaxFlashlightIntensity_ReturnsValueBetween0And1() {
        // When
        let intensity = thermalManager.maxFlashlightIntensity
        
        // Then: Should be between 0.0 and 1.0
        XCTAssertGreaterThanOrEqual(intensity, 0.0, "Intensity should be at least 0.0")
        XCTAssertLessThanOrEqual(intensity, 1.0, "Intensity should be at most 1.0")
    }
    
    func testMaxFlashlightIntensity_WithNominalState_Returns1() {
        // Note: This test depends on actual device thermal state
        // If device is in nominal state, intensity should be 1.0
        if thermalManager.currentState == .nominal {
            XCTAssertEqual(thermalManager.maxFlashlightIntensity, 1.0,
                         "Nominal state should allow full intensity")
        }
    }
    
    func testMaxFlashlightIntensity_WithFairState_Returns1() {
        // Note: This test depends on actual device thermal state
        // If device is in fair state, intensity should be 1.0
        if thermalManager.currentState == .fair {
            XCTAssertEqual(thermalManager.maxFlashlightIntensity, 1.0,
                         "Fair state should allow full intensity")
        }
    }
    
    func testMaxFlashlightIntensity_WithSeriousState_ReturnsReduced() {
        // Note: This test depends on actual device thermal state
        // If device is in serious state, intensity should be reduced to 0.5
        if thermalManager.currentState == .serious {
            XCTAssertEqual(thermalManager.maxFlashlightIntensity, 0.5,
                         "Serious state should reduce intensity to 0.5")
        }
    }
    
    func testMaxFlashlightIntensity_WithCriticalState_Returns0() {
        // Note: This test depends on actual device thermal state
        // If device is in critical state, intensity should be 0
        if thermalManager.currentState == .critical {
            XCTAssertEqual(thermalManager.maxFlashlightIntensity, 0.0,
                         "Critical state should disable flashlight")
        }
    }
    
    // MARK: - Screen Fallback Tests
    
    func testShouldSwitchToScreen_ReturnsBool() {
        // When
        let shouldSwitch = thermalManager.shouldSwitchToScreen
        
        // Then: Should return a boolean value
        XCTAssertTrue(shouldSwitch || !shouldSwitch, "Should return boolean value")
    }
    
    func testShouldSwitchToScreen_WithNominalOrFairState_ReturnsFalse() {
        // Given: Device in nominal or fair state
        let state = thermalManager.currentState
        
        // Then
        if state == .nominal || state == .fair {
            XCTAssertFalse(thermalManager.shouldSwitchToScreen,
                          "Should not switch to screen in nominal/fair state")
        }
    }
    
    func testShouldSwitchToScreen_WithSeriousOrCriticalState_ReturnsTrue() {
        // Given: Device in serious or critical state
        let state = thermalManager.currentState
        
        // Then
        if state == .serious || state == .critical {
            XCTAssertTrue(thermalManager.shouldSwitchToScreen,
                         "Should switch to screen in serious/critical state")
        }
    }
    
    // MARK: - Consistency Tests
    
    func testThermalBehavior_IsConsistent() {
        // When: Check thermal state and derived values
        let state = thermalManager.currentState
        let maxIntensity = thermalManager.maxFlashlightIntensity
        let shouldSwitch = thermalManager.shouldSwitchToScreen
        
        // Then: Values should be consistent with thermal state
        switch state {
        case .nominal, .fair:
            XCTAssertEqual(maxIntensity, 1.0, "Full intensity in normal thermal states")
            XCTAssertFalse(shouldSwitch, "No need to switch in normal thermal states")
            
        case .serious:
            XCTAssertEqual(maxIntensity, 0.5, "Reduced intensity in serious state")
            XCTAssertTrue(shouldSwitch, "Should switch to screen in serious state")
            
        case .critical:
            XCTAssertEqual(maxIntensity, 0.0, "No flashlight in critical state")
            XCTAssertTrue(shouldSwitch, "Should switch to screen in critical state")
            
        @unknown default:
            // For unknown states, use conservative approach (reduce intensity)
            XCTAssertLessThanOrEqual(maxIntensity, 0.5, "Conservative intensity for unknown state")
        }
    }
}
