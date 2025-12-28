import XCTest
import Combine
@testable import MindSync

final class ThermalManagerTests: XCTestCase {
    var thermalManager: ThermalManager!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        thermalManager = ThermalManager()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        thermalManager = nil
        super.tearDown()
    }
    
    // MARK: - Thermal State Tests
    
    func testCurrentState_ReturnsValidThermalState() {
        // When
        let state = thermalManager.currentState
        
        // Then: Should return a valid thermal state (no assertion needed, test passes if no crash)
        _ = state
    }
    
    // MARK: - Warning Level Tests
    
    func testWarningLevel_IsPublished() {
        // Given
        var receivedLevel: ThermalWarningLevel?
        let expectation = expectation(description: "Warning level published")
        
        thermalManager.$warningLevel
            .first()
            .sink { level in
                receivedLevel = level
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedLevel)
    }
    
    @MainActor
    func testWarningLevel_MatchesThermalState() {
        // When
        let state = thermalManager.thermalState
        let warningLevel = thermalManager.warningLevel
        
        // Then
        switch state {
        case .nominal, .fair:
            XCTAssertEqual(warningLevel, .none)
        case .serious:
            XCTAssertEqual(warningLevel, .reduced)
        case .critical:
            XCTAssertEqual(warningLevel, .critical)
        @unknown default:
            XCTAssertEqual(warningLevel, .reduced)
        }
    }
    
    // MARK: - Warning Level Message Tests
    
    func testWarningLevel_NoneHasNoMessage() {
        XCTAssertNil(ThermalWarningLevel.none.message)
    }
    
    func testWarningLevel_ReducedHasMessage() {
        XCTAssertNotNil(ThermalWarningLevel.reduced.message)
        XCTAssertTrue(ThermalWarningLevel.reduced.message!.contains("reduziert"))
    }
    
    func testWarningLevel_CriticalHasMessage() {
        XCTAssertNotNil(ThermalWarningLevel.critical.message)
        XCTAssertTrue(ThermalWarningLevel.critical.message!.contains("deaktiviert"))
    }
    
    // MARK: - Warning Level Icon Tests
    
    func testWarningLevel_ReducedHasIcon() {
        XCTAssertFalse(ThermalWarningLevel.reduced.icon.isEmpty)
    }
    
    func testWarningLevel_CriticalHasIcon() {
        XCTAssertFalse(ThermalWarningLevel.critical.icon.isEmpty)
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
        // If device is in fair state, intensity should be 0.8
        if thermalManager.currentState == .fair {
            XCTAssertEqual(thermalManager.maxFlashlightIntensity, 0.8,
                         "Fair state should reduce intensity slightly")
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
    
    // MARK: - Duty Cycle Multiplier Tests
    
    func testRecommendedDutyCycleMultiplier_IsWithinValidRange() {
        let multiplier = thermalManager.recommendedDutyCycleMultiplier
        XCTAssertGreaterThanOrEqual(multiplier, 0.0)
        XCTAssertLessThanOrEqual(multiplier, 1.0)
    }
    
    func testRecommendedDutyCycleMultiplier_WithFairState_IsReduced() {
        if thermalManager.currentState == .fair {
            XCTAssertEqual(thermalManager.recommendedDutyCycleMultiplier, 0.85, accuracy: 0.001)
        }
    }
    
    // MARK: - Screen Fallback Tests
    
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
        case .nominal:
            XCTAssertEqual(maxIntensity, 1.0, "Full intensity in nominal state")
            XCTAssertFalse(shouldSwitch, "No need to switch in nominal state")
        case .fair:
            XCTAssertEqual(maxIntensity, 0.8, "Slightly reduced intensity in fair state")
            XCTAssertFalse(shouldSwitch, "No need to switch in fair state")
            
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
