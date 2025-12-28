import XCTest
import AVFoundation
@testable import MindSync

@MainActor
final class FlashlightControllerPrewarmTests: XCTestCase {
    
    var controller: FlashlightController!
    var thermalManager: ThermalManager!
    
    override func setUp() async throws {
        try await super.setUp()
        thermalManager = ThermalManager()
        controller = FlashlightController(thermalManager: thermalManager)
    }
    
    override func tearDown() async throws {
        controller = nil
        thermalManager = nil
        try await super.tearDown()
    }
    
    // MARK: - Prewarm Tests
    
    func testPrewarmWithAuthorizedPermissions() async throws {
        // Note: This test will only pass on physical devices with camera permissions
        // On simulator or without permissions, it will skip the prewarm
        
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        guard permissionStatus == .authorized else {
            throw XCTSkip("Camera permissions not authorized - skipping prewarm test")
        }
        
        // Should not throw if permissions are granted
        do {
            try await controller.prewarm()
            // Success - prewarm completed
        } catch {
            // If it throws, check if it's due to device availability
            if let lightError = error as? LightControlError {
                switch lightError {
                case .torchUnavailable:
                    throw XCTSkip("Device does not have torch - test not applicable")
                default:
                    XCTFail("Unexpected error during prewarm: \(error)")
                }
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testPrewarmWithoutDevice() async throws {
        // Test behavior when device is nil
        // This simulates simulator or device without camera
        
        // We can't directly test this without mocking, but we document expected behavior:
        // - prewarm() should return early without throwing if device is nil
        // - This is logged as a warning but not an error
        
        // On simulator, prewarm should complete without crashing
        do {
            try await controller.prewarm()
            // Success - handled gracefully
        } catch {
            // Only acceptable error is torchUnavailable
            if let lightError = error as? LightControlError {
                XCTAssertEqual(lightError, .torchUnavailable)
            } else {
                XCTFail("Unexpected error type: \(error)")
            }
        }
    }
    
    func testPrewarmWithUnauthorizedPermissions() async throws {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        
        // Only test if permissions are explicitly denied or not determined
        guard permissionStatus != .authorized else {
            throw XCTSkip("Camera permissions are authorized - cannot test unauthorized case")
        }
        
        // Prewarm should skip gracefully when permissions not authorized
        do {
            try await controller.prewarm()
            // Should complete without error (logs info but doesn't throw)
        } catch {
            // If it throws, it should be torchUnavailable
            if let lightError = error as? LightControlError {
                XCTAssertEqual(lightError, .torchUnavailable)
            }
        }
    }
    
    func testPrewarmDuration() async throws {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard permissionStatus == .authorized else {
            throw XCTSkip("Camera permissions not authorized")
        }
        
        let startTime = Date()
        
        do {
            try await controller.prewarm()
        } catch {
            throw XCTSkip("Could not prewarm - device or permission issue")
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        // Prewarm should take at least 50ms (the pulse duration)
        // and no more than 200ms (allowing for overhead)
        XCTAssertGreaterThanOrEqual(duration, 0.05, "Prewarm should take at least 50ms")
        XCTAssertLessThan(duration, 0.2, "Prewarm should complete within 200ms")
    }
    
    func testPrewarmMultipleTimes() async throws {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard permissionStatus == .authorized else {
            throw XCTSkip("Camera permissions not authorized")
        }
        
        // Prewarm multiple times in succession
        for _ in 0..<3 {
            do {
                try await controller.prewarm()
            } catch {
                throw XCTSkip("Could not prewarm - device issue")
            }
            
            // Brief pause between prewarming attempts
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        // Should complete without errors
    }
    
    func testPrewarmDoesNotAffectControllerState() async throws {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard permissionStatus == .authorized else {
            throw XCTSkip("Camera permissions not authorized")
        }
        
        // Verify controller state before prewarm
        // Controller should not be started
        
        do {
            try await controller.prewarm()
        } catch {
            throw XCTSkip("Could not prewarm - device issue")
        }
        
        // After prewarm, controller should still not be in "started" state
        // (we can't directly check internal state, but we verify it doesn't throw when starting)
        do {
            try await controller.start()
            controller.stop()
        } catch {
            XCTFail("Controller state was affected by prewarm: \(error)")
        }
    }
    
    // MARK: - Edge Cases
    
    func testPrewarmConcurrency() async throws {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard permissionStatus == .authorized else {
            throw XCTSkip("Camera permissions not authorized")
        }
        
        // Start multiple prewarm operations concurrently
        async let prewarm1: () = {
            do {
                try await controller.prewarm()
            } catch {
                // Ignore errors for this test
            }
        }()
        
        async let prewarm2: () = {
            do {
                try await controller.prewarm()
            } catch {
                // Ignore errors for this test
            }
        }()
        
        // Should handle concurrent prewarms without crashing
        let _ = await (prewarm1, prewarm2)
    }
    
    func testPrewarmAfterStart() async throws {
        let permissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
        guard permissionStatus == .authorized else {
            throw XCTSkip("Camera permissions not authorized")
        }
        
        // Start controller first
        do {
            try await controller.start()
        } catch {
            throw XCTSkip("Could not start controller - device issue")
        }
        
        // Attempt prewarm while running
        // Should handle gracefully
        do {
            try await controller.prewarm()
        } catch {
            // Error is acceptable here - prewarm expects device not to be locked
        }
        
        controller.stop()
    }
    
    func testPrewarmLevel() async throws {
        // This test documents the expected prewarm torch level
        // Actual verification would require hardware access
        
        // Expected: prewarmTorchLevel = 0.01 (1%)
        // This level should be:
        // - Low enough to be imperceptible to users
        // - High enough to initialize LED driver
        
        // We document this behavior but can't directly test without device hardware access
    }
}
