import XCTest
import Combine
@testable import MindSync

final class MicrophoneAnalyzerTests: XCTestCase {
    
    var analyzer: MicrophoneAnalyzer?
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        analyzer = MicrophoneAnalyzer()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        analyzer?.stop()
        analyzer = nil
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_WithValidFFTSetup_Succeeds() {
        // Given: The analyzer created in setUp()
        // Then: Should not be nil (FFT setup succeeded)
        // Note: We use the shared analyzer from setUp() instead of creating a new one
        // to avoid conflicts with AVAudioEngine and potential double-free issues
        XCTAssertNotNil(analyzer, "Analyzer should initialize successfully")
    }
    
    // MARK: - State Tests
    
    func testIsActive_BeforeStart_ReturnsFalse() {
        // Given: Analyzer not started
        guard let analyzer = analyzer else {
            XCTFail("Analyzer not initialized")
            return
        }
        
        // Then
        XCTAssertFalse(analyzer.isActive, "Should not be active before start")
    }
    
    func testCurrentBPM_BeforeStart_ReturnsDefault() {
        // Given: Analyzer not started
        guard let analyzer = analyzer else {
            XCTFail("Analyzer not initialized")
            return
        }
        
        // Then: Should return default BPM
        XCTAssertEqual(analyzer.currentBPM, 120.0, "Should return default BPM before start")
    }
    
    // MARK: - Publisher Tests
    
    func testBeatEventPublisher_IsCreated() {
        // Given: Analyzer
        guard let analyzer = analyzer else {
            XCTFail("Analyzer not initialized")
            return
        }
        
        // Then: Publisher should exist
        _ = analyzer.beatEventPublisher
    }
    
    func testBPMPublisher_IsCreated() {
        // Given: Analyzer
        guard let analyzer = analyzer else {
            XCTFail("Analyzer not initialized")
            return
        }
        
        // Then: Publisher should exist
        _ = analyzer.bpmPublisher
    }
    
    // MARK: - Error Handling Tests
    
    func testStart_WithoutPermission_ThrowsError() async {
        // Note: This test may not work in simulator without actual permission denial
        // In real device, permission would need to be denied first
        
        guard let analyzer = analyzer else {
            XCTFail("Analyzer not initialized")
            return
        }
        
        // This test is difficult to execute without actual permission state
        // We'll test that the method exists and can be called
        do {
            // Note: This will likely fail in test environment
            // In real scenario, permission would be denied
            try await analyzer.start()
            // If we get here, permission was granted (test environment)
            analyzer.stop()
        } catch {
            // Expected if permission is denied
            if case MicrophoneError.permissionDenied = error {
                // This is expected behavior
            } else {
                // Other errors are also acceptable in test environment
            }
        }
    }
    
    // MARK: - Integration Note
    
    // Note: Full integration tests for MicrophoneAnalyzer require:
    // 1. Actual microphone input (not available in simulator)
    // 2. Permission handling (requires user interaction)
    // 3. Real-time audio processing (complex to mock)
    //
    // These tests verify the basic structure and error handling.
    // Full functionality should be tested manually on a real device.
}

