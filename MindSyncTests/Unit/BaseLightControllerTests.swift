import XCTest
@testable import MindSync

/// Tests for BaseLightController shared logic
/// Note: Most functionality is tested through ScreenControllerTests and integration tests
@MainActor
final class BaseLightControllerTests: XCTestCase {
    fileprivate var baseLightController: TestBaseLightController!
    
    override func setUp() {
        super.setUp()
        baseLightController = TestBaseLightController()
    }
    
    override func tearDown() {
        baseLightController.invalidateDisplayLink()
        baseLightController = nil
        super.tearDown()
    }
    
    // MARK: - Script Execution Initialization Tests
    
    func testInitializeScriptExecution_SetsProperties() {
        // Given
        let script = createTestScript()
        let startTime = Date()
        
        // When
        baseLightController.initializeScriptExecution(script: script, startTime: startTime)
        
        // Then
        XCTAssertNotNil(baseLightController.currentScript)
        XCTAssertNotNil(baseLightController.scriptStartTime)
        XCTAssertEqual(baseLightController.currentEventIndex, 0)
    }
    
    func testResetScriptExecution_ClearsProperties() {
        // Given
        let script = createTestScript()
        baseLightController.initializeScriptExecution(script: script, startTime: Date())
        
        // When
        baseLightController.resetScriptExecution()
        
        // Then
        XCTAssertNil(baseLightController.currentScript)
        XCTAssertNil(baseLightController.scriptStartTime)
        XCTAssertEqual(baseLightController.currentEventIndex, 0)
    }
    
    // MARK: - Current Event Finding Tests
    
    func testFindCurrentEvent_WithNoScript_ReturnsNilEvent() {
        // When
        let result = baseLightController.findCurrentEvent()
        
        // Then
        XCTAssertNil(result.event)
        XCTAssertFalse(result.isComplete)
        XCTAssertEqual(result.elapsed, 0)
    }
    
    func testFindCurrentEvent_WithActiveEvent_ReturnsEvent() {
        // Given: Script with event at timestamp 0
        let script = createTestScript()
        let startTime = Date()
        baseLightController.initializeScriptExecution(script: script, startTime: startTime)
        
        // When: Immediately find current event
        let result = baseLightController.findCurrentEvent()
        
        // Then: First event should be active
        XCTAssertNotNil(result.event)
        XCTAssertFalse(result.isComplete)
        XCTAssertGreaterThanOrEqual(result.elapsed, 0)
    }
    
    func testFindCurrentEvent_AfterScriptDuration_ReturnsComplete() {
        // Given: Script with very short duration
        let event = LightEvent(timestamp: 0, intensity: 1.0, duration: 0.01, waveform: .square, color: nil)
        let script = LightScript(
            trackId: UUID(),
            mode: .alpha,
            targetFrequency: 10.0,
            multiplier: 1,
            events: [event]
        )
        // Start script in the past
        let startTime = Date(timeIntervalSinceNow: -1.0) // 1 second ago
        baseLightController.initializeScriptExecution(script: script, startTime: startTime)
        
        // When
        let result = baseLightController.findCurrentEvent()
        
        // Then: Script should be complete
        XCTAssertTrue(result.isComplete)
        XCTAssertNil(result.event)
    }
    
    func testFindCurrentEvent_BetweenEvents_ReturnsNilEvent() {
        // Given: Script with two events separated by gap
        let events = [
            LightEvent(timestamp: 0, intensity: 1.0, duration: 0.01, waveform: .square, color: nil),
            LightEvent(timestamp: 0.5, intensity: 1.0, duration: 0.5, waveform: .square, color: nil)
        ]
        let script = LightScript(
            trackId: UUID(),
            mode: .alpha,
            targetFrequency: 10.0,
            multiplier: 1,
            events: events
        )
        // Start script in the past, positioned between events
        let startTime = Date(timeIntervalSinceNow: -0.2) // 0.2 seconds ago (between events)
        baseLightController.initializeScriptExecution(script: script, startTime: startTime)
        
        // When
        let result = baseLightController.findCurrentEvent()
        
        // Then: Between events, so no active event
        XCTAssertNil(result.event)
        XCTAssertFalse(result.isComplete)
    }
    
    // MARK: - Pause/Resume Tests
    
    func testPauseScriptExecution_SetsIsPausedFlag() {
        // Given
        let script = createTestScript()
        baseLightController.initializeScriptExecution(script: script, startTime: Date())
        
        // When
        baseLightController.pauseScriptExecution()
        
        // Then
        XCTAssertTrue(baseLightController.isPaused)
        XCTAssertNotNil(baseLightController.pauseStartTime)
    }
    
    func testPauseScriptExecution_InvalidatesDisplayLink() {
        // Given
        let script = createTestScript()
        baseLightController.initializeScriptExecution(script: script, startTime: Date())
        let target = TestDisplayLinkTarget()
        baseLightController.setupDisplayLink(target: target, selector: #selector(TestDisplayLinkTarget.update))
        XCTAssertNotNil(baseLightController.displayLink)
        
        // When
        baseLightController.pauseScriptExecution()
        
        // Then
        XCTAssertNil(baseLightController.displayLink)
    }
    
    func testPauseScriptExecution_WhenAlreadyPaused_DoesNothing() {
        // Given
        let script = createTestScript()
        baseLightController.initializeScriptExecution(script: script, startTime: Date())
        baseLightController.pauseScriptExecution()
        let firstPauseStartTime = baseLightController.pauseStartTime
        
        // When
        baseLightController.pauseScriptExecution()
        
        // Then: pauseStartTime should not change
        XCTAssertEqual(baseLightController.pauseStartTime, firstPauseStartTime)
    }
    
    func testResumeScriptExecution_ClearsIsPausedFlag() {
        // Given
        let script = createTestScript()
        baseLightController.initializeScriptExecution(script: script, startTime: Date())
        baseLightController.pauseScriptExecution()
        
        // When
        baseLightController.resumeScriptExecution()
        
        // Then
        XCTAssertFalse(baseLightController.isPaused)
        XCTAssertNil(baseLightController.pauseStartTime)
    }
    
    func testResumeScriptExecution_AccumulatesPauseDuration() {
        // Given
        let script = createTestScript()
        baseLightController.initializeScriptExecution(script: script, startTime: Date())
        baseLightController.pauseScriptExecution()
        
        // Wait a short time
        Thread.sleep(forTimeInterval: 0.1)
        
        // When
        baseLightController.resumeScriptExecution()
        
        // Then: totalPauseDuration should be accumulated
        XCTAssertGreaterThan(baseLightController.totalPauseDuration, 0)
        XCTAssertLessThan(baseLightController.totalPauseDuration, 0.2) // Should be around 0.1
    }
    
    func testResumeScriptExecution_WhenNotPaused_DoesNothing() {
        // Given
        let script = createTestScript()
        baseLightController.initializeScriptExecution(script: script, startTime: Date())
        let initialPauseDuration = baseLightController.totalPauseDuration
        
        // When
        baseLightController.resumeScriptExecution()
        
        // Then: totalPauseDuration should not change
        XCTAssertEqual(baseLightController.totalPauseDuration, initialPauseDuration)
    }
    
    func testMultiplePauseResumeCycles_AccumulatesDuration() {
        // Given
        let script = createTestScript()
        baseLightController.initializeScriptExecution(script: script, startTime: Date())
        
        // First pause/resume cycle
        baseLightController.pauseScriptExecution()
        Thread.sleep(forTimeInterval: 0.05)
        baseLightController.resumeScriptExecution()
        let firstPauseDuration = baseLightController.totalPauseDuration
        
        // Second pause/resume cycle
        baseLightController.pauseScriptExecution()
        Thread.sleep(forTimeInterval: 0.05)
        baseLightController.resumeScriptExecution()
        let secondPauseDuration = baseLightController.totalPauseDuration
        
        // Then: second duration should be greater than first
        XCTAssertGreaterThan(secondPauseDuration, firstPauseDuration)
        XCTAssertGreaterThan(secondPauseDuration, 0.08) // Should be around 0.1 total
    }
    
    func testFindCurrentEvent_WithPauseDuration_AdjustsElapsedTime() {
        // Given: Script with event at timestamp 0
        let script = createTestScript()
        let startTime = Date(timeIntervalSinceNow: -1.0) // Started 1 second ago
        baseLightController.initializeScriptExecution(script: script, startTime: startTime)
        
        // Simulate a pause by setting totalPauseDuration
        baseLightController.pauseScriptExecution()
        Thread.sleep(forTimeInterval: 0.1)
        baseLightController.resumeScriptExecution()
        
        // When
        let result = baseLightController.findCurrentEvent()
        
        // Then: Elapsed time should account for pause duration
        // Real elapsed is ~1 second, but with ~0.1s pause, effective elapsed should be ~0.9s
        XCTAssertLessThan(result.elapsed, 1.0)
        XCTAssertGreaterThan(result.elapsed, 0.8)
    }
    
    func testResetScriptExecution_ClearsPauseState() {
        // Given
        let script = createTestScript()
        baseLightController.initializeScriptExecution(script: script, startTime: Date())
        baseLightController.pauseScriptExecution()
        Thread.sleep(forTimeInterval: 0.05)
        baseLightController.resumeScriptExecution()
        
        // When
        baseLightController.resetScriptExecution()
        
        // Then
        XCTAssertEqual(baseLightController.totalPauseDuration, 0)
        XCTAssertNil(baseLightController.pauseStartTime)
        XCTAssertFalse(baseLightController.isPaused)
    }
    
    // MARK: - Display Link Management Tests
    
    func testInvalidateDisplayLink_ClearsDisplayLink() {
        // Given: Setup display link
        let target = TestDisplayLinkTarget()
        baseLightController.setupDisplayLink(target: target, selector: #selector(TestDisplayLinkTarget.update))
        XCTAssertNotNil(baseLightController.displayLink)
        
        // When
        baseLightController.invalidateDisplayLink()
        
        // Then
        XCTAssertNil(baseLightController.displayLink)
    }
    
    // MARK: - Helper Methods
    
    private func createTestScript() -> LightScript {
        let event = LightEvent(
            timestamp: 0,
            intensity: 1.0,
            duration: 1.0,
            waveform: .square,
            color: nil
        )
        return LightScript(
            trackId: UUID(),
            mode: .alpha,
            targetFrequency: 10.0,
            multiplier: 1,
            events: [event]
        )
    }
}

// MARK: - Test Helpers

/// Test subclass to expose BaseLightController for testing
private class TestBaseLightController: BaseLightController {
    // Inherits all functionality from BaseLightController
}

/// Test target for display link testing
private class TestDisplayLinkTarget: NSObject {
    @objc func update() {
        // Empty selector for testing
    }
}
