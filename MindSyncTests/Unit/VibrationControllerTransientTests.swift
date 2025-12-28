import XCTest
import CoreHaptics
@testable import MindSync

@MainActor
final class VibrationControllerTransientTests: XCTestCase {
    
    var controller: VibrationController!
    
    override func setUp() async throws {
        try await super.setUp()
        controller = VibrationController()
    }
    
    override func tearDown() async throws {
        controller.stop()
        controller = nil
        try await super.tearDown()
    }
    
    // MARK: - Transient Haptics Tests
    
    func testSetTransientIntensityWithinCooldown() async throws {
        // Check if device supports haptics
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        // Start controller
        try await controller.start()
        
        // Set transient intensity
        controller.setTransientIntensity(0.8)
        
        // Immediately try to set again (within cooldown period)
        controller.setTransientIntensity(0.9)
        
        // Second call should be ignored due to cooldown
        // We can't directly verify this without internal state access,
        // but the test ensures it doesn't crash
    }
    
    func testSetTransientIntensityAfterCooldown() async throws {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        try await controller.start()
        
        // Set transient intensity
        controller.setTransientIntensity(0.7)
        
        // Wait for cooldown period (50ms + margin)
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        // Should be able to set again
        controller.setTransientIntensity(0.8)
        
        // Should not crash
    }
    
    func testSetTransientIntensityClamping() async throws {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        try await controller.start()
        
        // Test with intensity above 1.0
        controller.setTransientIntensity(1.5)
        
        // Wait for cooldown
        try await Task.sleep(nanoseconds: 60_000_000)
        
        // Test with intensity below 0.0
        controller.setTransientIntensity(-0.5)
        
        // Should clamp values without crashing
    }
    
    func testSetTransientIntensityZeroIntensity() async throws {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        try await controller.start()
        
        // Set zero intensity (should still work)
        controller.setTransientIntensity(0.0)
        
        try await Task.sleep(nanoseconds: 60_000_000)
        
        controller.setTransientIntensity(0.1)
        
        // Should handle zero intensity gracefully
    }
    
    func testSetTransientIntensityOneIntensity() async throws {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        try await controller.start()
        
        // Set maximum intensity
        controller.setTransientIntensity(1.0)
        
        // Should handle max intensity without issues
    }
    
    func testSetTransientIntensityBeforeStart() throws {
        // Calling setTransientIntensity before start should not crash
        controller.setTransientIntensity(0.5)
        
        // Should handle gracefully (likely no-op)
    }
    
    func testSetTransientIntensityAfterStop() async throws {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        try await controller.start()
        controller.stop()
        
        // Calling after stop should not crash
        controller.setTransientIntensity(0.5)
        
        // Should handle gracefully
    }
    
    func testMultipleRapidTransients() async throws {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        try await controller.start()
        
        // Send rapid transient requests (simulating rapid beats)
        for i in 0..<10 {
            controller.setTransientIntensity(0.5 + Float(i) * 0.05)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms between calls
        }
        
        // Cooldown should limit actual haptic events to ~2-3 out of 10
        // Test ensures this doesn't cause crashes or engine overload
    }
    
    func testTransientCooldownValue() {
        // This test documents the expected cooldown behavior
        // Cooldown is 50ms = 20 Hz maximum rate
        
        // Expected behavior:
        // - Multiple calls within 50ms should be coalesced
        // - Calls spaced >50ms apart should each trigger haptics
        // - Maximum rate is 20 Hz (well above musical beat rates of 1-4 Hz)
        
        // We document this but can't directly verify without internal state access
    }
    
    // MARK: - Cooldown Period Tests
    
    func testCooldownEnforcementSequence() async throws {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        try await controller.start()
        
        // First transient (should work)
        controller.setTransientIntensity(0.6)
        
        // Immediate second call (should be ignored)
        controller.setTransientIntensity(0.7)
        
        // Wait past cooldown
        try await Task.sleep(nanoseconds: 60_000_000) // 60ms
        
        // Third transient (should work)
        controller.setTransientIntensity(0.8)
        
        // Should complete without errors
    }
    
    func testCooldownWithVaryingIntensities() async throws {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        try await controller.start()
        
        let intensities: [Float] = [0.2, 0.4, 0.6, 0.8, 1.0]
        
        for intensity in intensities {
            controller.setTransientIntensity(intensity)
            try await Task.sleep(nanoseconds: 60_000_000) // Wait past cooldown
        }
        
        // All intensities should be handled correctly
    }
    
    // MARK: - Error Handling Tests
    
    func testTransientHapticsWithEngineReset() async throws {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        try await controller.start()
        
        // Set some transients
        controller.setTransientIntensity(0.5)
        
        // We can't directly trigger engine reset, but we document expected behavior:
        // - If engine resets during transient, the restart handler should reinitialize
        // - Subsequent transients should work after engine recovers
        
        // Wait and verify controller still works
        try await Task.sleep(nanoseconds: 100_000_000)
        controller.setTransientIntensity(0.6)
    }
    
    func testTransientIntensityCreatesShortPulse() async throws {
        // This test documents the expected pulse duration
        // Transient haptics should create ~20ms impulses for percussive feel
        
        // Expected behavior:
        // - CHHapticEvent with .hapticTransient type
        // - Sharpness: 1.0 (maximum for percussive feel)
        // - Intensity: clamped to [0, 1]
        // - Duration: ~20ms (characteristic of transient events)
        
        // This behavior is implemented in setTransientIntensity but can't be
        // directly verified without CoreHaptics internal access
    }
    
    // MARK: - Integration with Square Wave Tests
    
    func testSquareWaveCompatibility() async throws {
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        guard capabilities.supportsHaptics else {
            throw XCTSkip("Device does not support haptics")
        }
        
        try await controller.start()
        
        // Transient haptics are designed to work with square wave patterns
        // Simulate square wave by alternating transients with pauses
        
        for _ in 0..<5 {
            // "On" phase: transient
            controller.setTransientIntensity(0.8)
            
            // "Off" phase: wait (square wave period)
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms = 10 Hz
        }
        
        // Should create perceivable square wave pattern
    }
}
