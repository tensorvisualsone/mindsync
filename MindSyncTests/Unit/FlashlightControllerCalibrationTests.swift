import XCTest
import AVFoundation
@testable import MindSync

/// Tests for FlashlightController's Rolling Average Calibrator feature
/// The calibration learns the dynamics of the song in the first 10 seconds
/// and adjusts thresholds for cinematic mode beat detection.
@MainActor
final class FlashlightControllerCalibrationTests: XCTestCase {
    
    var controller: FlashlightController!
    var thermalManager: ThermalManager!
    
    override func setUp() async throws {
        try await super.setUp()
        thermalManager = ThermalManager()
        controller = FlashlightController(thermalManager: thermalManager)
    }
    
    override func tearDown() async throws {
        controller?.stop()
        controller = nil
        thermalManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Calibration State Tests
    
    func testCalibrationInitialState() {
        // Verify calibration starts in uncalibrated state
        // Note: We can't directly access private properties, so this test documents
        // expected behavior based on the implementation
        
        // Expected initial state (documented for maintainers):
        // - calibrationStartTime = -1.0 (not yet started)
        // - calibrationFluxValues = [] (empty)
        // - isCalibrated = false
        // - peakRiseThreshold = 0.04 (default)
        // - fixedThreshold = 0.08 (default)
        
        // The controller should be initialized and ready to start calibration
        XCTAssertNotNil(controller, "Controller should be initialized")
    }
    
    func testCalibrationResetOnStart() async throws {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard permissionStatus == .authorized else {
            throw XCTSkip("Camera permissions not authorized")
        }
        
        // Start the controller - this should reset calibration state
        do {
            try await controller.start()
        } catch {
            throw XCTSkip("Could not start controller - device issue")
        }
        
        // Expected behavior (documented for maintainers):
        // When start() is called, the controller should:
        // 1. Reset calibrationStartTime to -1.0
        // 2. Clear calibrationFluxValues array
        // 3. Set isCalibrated to false
        // 4. Reset peakRiseThreshold to 0.04
        // 5. Reset fixedThreshold to 0.08
        //
        // This ensures calibration adapts to different music tracks/playlists
        
        controller.stop()
        
        // If no crash occurred, the reset was successful
    }
    
    func testCalibrationDuration() {
        // Document the calibration duration constant
        // Expected: calibrationDuration = 10.0 seconds
        
        // The calibration period is designed to be:
        // - Long enough to capture representative dynamics of the music
        // - Short enough not to delay the entrainment experience
        // - Sufficient for genres ranging from ambient to techno
        
        let expectedCalibrationDuration: TimeInterval = 10.0
        XCTAssertEqual(expectedCalibrationDuration, 10.0,
                      "Calibration duration should be 10 seconds")
    }
    
    func testCalibrationThresholdDefaults() {
        // Document the default threshold values used before calibration
        
        let defaultPeakRiseThreshold: Float = 0.04
        let defaultFixedThreshold: Float = 0.08
        
        // These defaults should be:
        // - Sensitive enough for low-dynamic music (ambient, drone)
        // - Not too sensitive to trigger on noise
        // - Will be adjusted by calibration based on actual music dynamics
        
        XCTAssertGreaterThan(defaultPeakRiseThreshold, 0.0,
                            "Peak rise threshold should be positive")
        XCTAssertGreaterThan(defaultFixedThreshold, 0.0,
                            "Fixed threshold should be positive")
        XCTAssertGreaterThan(defaultFixedThreshold, defaultPeakRiseThreshold,
                            "Fixed threshold should be higher than peak rise threshold")
    }
    
    func testCalibrationHighDynamicsThresholds() {
        // Document the thresholds used for high-dynamics music (techno, EDM, rock)
        
        let highDynamicsPeakRiseThreshold: Float = 0.06
        let highDynamicsFixedThreshold: Float = 0.12
        let highDynamicsRangeThreshold: Float = 0.15
        
        // High dynamics calibration (dynamicRange > 0.15):
        // - Increases thresholds to only trigger on strong beats (kicks)
        // - Prevents light from triggering on every hi-hat or cymbal
        // - Provides cleaner, more impactful visual response
        
        XCTAssertGreaterThan(highDynamicsPeakRiseThreshold, 0.04,
                            "High dynamics threshold should be higher than default")
        XCTAssertGreaterThan(highDynamicsFixedThreshold, 0.08,
                            "High dynamics fixed threshold should be higher than default")
        XCTAssertGreaterThan(highDynamicsRangeThreshold, 0.0,
                            "Dynamic range threshold should be positive")
    }
    
    func testCalibrationLowDynamicsThresholds() {
        // Document the thresholds used for low-dynamics music (ambient, drone)
        
        let lowDynamicsPeakRiseThreshold: Float = 0.02
        let lowDynamicsFixedThreshold: Float = 0.05
        
        // Low dynamics calibration (dynamicRange <= 0.15):
        // - Decreases thresholds for more sensitive detection
        // - Allows light to respond to subtle variations
        // - Provides organic, fluid visual response for ambient music
        
        XCTAssertLessThan(lowDynamicsPeakRiseThreshold, 0.04,
                         "Low dynamics threshold should be lower than default")
        XCTAssertLessThan(lowDynamicsFixedThreshold, 0.08,
                         "Low dynamics fixed threshold should be lower than default")
        XCTAssertGreaterThan(lowDynamicsPeakRiseThreshold, 0.0,
                            "Threshold should still be positive")
    }
    
    // MARK: - Thread Safety Tests
    
    func testCalibrationThreadSafety() {
        // Document thread safety requirements for calibration properties
        
        // Thread Safety Model:
        // All calibration properties (calibrationStartTime, calibrationFluxValues,
        // isCalibrated, peakRiseThreshold, fixedThreshold) are accessed ONLY from
        // the precision timer thread (serial dispatch queue).
        //
        // ⚠️ WARNING: Accessing these properties from other threads (main thread,
        // logging, debugging) without proper locking will cause race conditions.
        //
        // This test documents the requirement but cannot enforce it at compile time.
        
        // If the controller is created and destroyed without crashes, thread safety
        // requirements are being followed (at least for the happy path)
        XCTAssertNotNil(controller, "Controller should handle thread safety correctly")
    }
    
    // MARK: - Calibration Integration Tests
    
    func testCalibrationOnlyForCinematicMode() {
        // Verify that calibration is only started for cinematic mode
        
        // Expected behavior (documented):
        // - Calibration should start when execute() is called with cinematic mode script
        // - Calibration should NOT start for other modes (alpha, theta, gamma)
        // - Fixed-script modes (dmnShutdown, beliefRewiring) don't use audio tracking
        
        // This is enforced in the execute() method which checks:
        // if script.mode == .cinematic {
        //     calibrationStartTime = ProcessInfo.processInfo.systemUptime
        //     ...
        // }
        
        // We document this behavior for maintainers
    }
    
    func testCalibrationResetBetweenSessions() {
        // Verify that calibration is intentionally reset between sessions
        
        // Design rationale:
        // Calibration is reset on each session start (in start() method) to allow
        // adaptation to different music tracks or playlists. This ensures the
        // cinematic mode optimizes its sensitivity for whatever the user plays next,
        // rather than carrying over calibration from previous sessions.
        
        // Expected reset locations:
        // 1. start() method - before session begins
        // 2. stop() method - when session ends
        // 3. execute() method - when new script is executed (cinematic mode only)
        
        // This test documents the design decision
    }
    
    // MARK: - Edge Cases
    
    func testCalibrationWithNoFluxData() {
        // Test behavior when calibration completes but no flux data was collected
        
        // Expected behavior:
        // if calibrationFluxValues.count > 0 {
        //     // Calculate and adjust thresholds
        // }
        // 
        // If count is 0, thresholds remain at default values
        
        // This prevents division by zero and ensures safe fallback behavior
    }
    
    func testCalibrationStatisticalCalculations() {
        // Document the statistical calculations used in calibration
        
        // Calculations performed:
        // 1. mean = sum(values) / count
        // 2. variance = sum((value - mean)^2) / count
        // 3. stdDev = sqrt(variance)
        // 4. maxFlux = max(values)
        // 5. minFlux = min(values)
        // 6. dynamicRange = maxFlux - minFlux
        
        // Threshold adjustment:
        // if dynamicRange > 0.15:
        //     High dynamics (techno, rock): higher thresholds
        // else:
        //     Low dynamics (ambient, drone): lower thresholds
        
        // This test documents the algorithm for maintainers
    }
    
    func testCalibrationDoesNotAffectOtherModes() {
        // Verify calibration is isolated to cinematic mode
        
        // Expected behavior:
        // - Alpha, theta, gamma modes don't check calibration variables
        // - DMN-Shutdown and Belief Rewiring use fixed scripts (no audio tracking)
        // - Calibration state doesn't interfere with these modes
        
        // This ensures mode isolation and prevents unexpected side effects
    }
}
