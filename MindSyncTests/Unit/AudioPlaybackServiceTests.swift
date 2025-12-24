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
}

