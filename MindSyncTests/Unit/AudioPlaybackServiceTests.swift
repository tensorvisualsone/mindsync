import XCTest
import AVFoundation
@testable import MindSync

final class AudioPlaybackServiceTests: XCTestCase {
    var service: AudioPlaybackService!
    
    override func setUp() {
        super.setUp()
        service = AudioPlaybackService()
    }
    
    override func tearDown() {
        service.stop()
        service = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization_Succeeds() {
        XCTAssertNotNil(service, "AudioPlaybackService should initialize")
        XCTAssertFalse(service.isPlaying, "Should not be playing initially")
        XCTAssertEqual(service.currentTime, 0.0, "Initial current time should be 0")
    }
    
    // MARK: - MixerNode Tests
    
    func testGetMainMixerNode_WhenNotPlaying_ReturnsNil() {
        let mixerNode = service.getMainMixerNode()
        
        // MixerNode only exists when engine is initialized (during playback)
        // So it should be nil when not playing
        XCTAssertNil(mixerNode, "MixerNode should be nil when not playing")
    }
    
    // MARK: - Playback Tests
    
    // Note: Full playback tests would require actual audio files
    // These tests verify the interface and basic behavior
    
    func testStop_WhenNotPlaying_DoesNotCrash() {
        // Should not crash when stopping without playing
        service.stop()
        XCTAssertFalse(service.isPlaying)
    }
    
    func testPause_WhenNotPlaying_DoesNotCrash() {
        // Should not crash when pausing without playing
        service.pause()
        XCTAssertFalse(service.isPlaying)
    }
    
    func testResume_WhenNotPlaying_DoesNotStart() {
        // Resuming without starting should not start playback
        service.resume()
        XCTAssertFalse(service.isPlaying)
    }
    
    // MARK: - Deprecated Property Tests
    
    func testAudioPlayer_IsDeprecated() {
        // The deprecated property should return nil (signaling AVAudioPlayer is no longer used)
        // This is a compile-time check - the property exists but returns nil
        let player = service.audioPlayer
        XCTAssertNil(player, "Deprecated audioPlayer should return nil")
    }
    
    // MARK: - Callback Tests
    
    func testOnPlaybackComplete_CallbackExists() {
        var callbackCalled = false
        
        service.onPlaybackComplete = {
            callbackCalled = true
        }
        
        // Callback should be settable
        XCTAssertNotNil(service.onPlaybackComplete)
    }
    
    // Note: Testing actual playback completion would require:
    // 1. A real audio file
    // 2. Waiting for playback to complete
    // This is better suited for integration tests
    
    // MARK: - Audio Synchronization Tests
    
    func testWaitForPlaybackToStart_WhenNotPlaying_TimesOut() async {
        // Given: Service is not playing
        XCTAssertFalse(service.isPlaying)
        
        // When: Waiting for playback to start with very short timeout
        let timeout: TimeInterval = 0.1
        let startTime = Date()
        let actualStartTime = await service.waitForPlaybackToStart(timeout: timeout)
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Then: Should timeout and return nil
        XCTAssertNil(actualStartTime, "Should return nil when audio doesn't start")
        XCTAssertGreaterThanOrEqual(elapsed, timeout, "Should wait at least the timeout duration")
        // Allow up to 2x timeout for system scheduling variance
        XCTAssertLessThan(elapsed, timeout * 2.0, "Should not wait significantly longer than timeout")
    }
    
    func testWaitForPlaybackToStart_WithZeroTimeout_ReturnsImmediately() async {
        // Given: Service is not playing
        XCTAssertFalse(service.isPlaying)
        
        // When: Waiting with zero timeout
        let startTime = Date()
        let actualStartTime = await service.waitForPlaybackToStart(timeout: 0.0)
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Then: Should return immediately
        XCTAssertNil(actualStartTime, "Should return nil immediately")
        XCTAssertLessThan(elapsed, 0.1, "Should return very quickly with zero timeout")
    }
    
    func testIsScheduled_InitiallyFalse() {
        // Given: Newly initialized service
        // When: Checking scheduled state
        let scheduled = service.isScheduled
        
        // Then: Should not be scheduled initially
        XCTAssertFalse(scheduled, "Should not be scheduled initially")
    }
    
    // Note: Testing actual audio rendering requires:
    // 1. A real audio file to be prepared and played
    // 2. Access to AVAudioPlayerNode's timing information
    // 3. Proper audio session configuration
    // These scenarios are better covered by integration tests that use actual audio files
    // and can verify the synchronization behavior in a real playback context.
}

