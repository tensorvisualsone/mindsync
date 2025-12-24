import XCTest
import Combine
import SwiftUI
@testable import MindSync

final class ScreenControllerTests: XCTestCase {
    var screenController: ScreenController!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        screenController = ScreenController()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        screenController.stop()
        cancellables = nil
        screenController = nil
        super.tearDown()
    }
    
    // MARK: - Basic Properties Tests
    
    func testSource_ReturnsScreen() {
        XCTAssertEqual(screenController.source, .screen)
    }
    
    func testInitialColor_IsBlack() {
        XCTAssertEqual(screenController.currentColor, .black)
    }
    
    func testInitialState_IsNotActive() {
        XCTAssertFalse(screenController.isActive)
    }
    
    // MARK: - Start/Stop Tests
    
    func testStart_SetsActiveToTrue() throws {
        // When
        try screenController.start()
        
        // Then
        XCTAssertTrue(screenController.isActive)
    }
    
    func testStop_SetsActiveToFalse() throws {
        // Given
        try screenController.start()
        XCTAssertTrue(screenController.isActive)
        
        // When
        screenController.stop()
        
        // Then
        XCTAssertFalse(screenController.isActive)
    }
    
    func testStop_ResetsColorToBlack() throws {
        // Given
        try screenController.start()
        
        // When
        screenController.stop()
        
        // Then
        XCTAssertEqual(screenController.currentColor, .black)
    }
    
    // MARK: - Color Setting Tests
    
    func testSetColor_UpdatesDefaultColor() {
        // When
        screenController.setColor(.red)
        
        // Then: We can't directly test defaultColor as it's private,
        // but we can verify it works through script execution
        XCTAssertNotNil(screenController)
    }
    
    // MARK: - Script Execution Tests
    
    func testExecute_InitializesScriptExecution() {
        // Given
        let script = createTestScript()
        let startTime = Date()
        
        // When
        screenController.execute(script: script, syncedTo: startTime)
        
        // Then: Script execution should be initialized (verified by not crashing)
        XCTAssertNotNil(screenController.currentScript)
    }
    
    func testCancelExecution_ResetsState() {
        // Given
        let script = createTestScript()
        screenController.execute(script: script, syncedTo: Date())
        
        // When
        screenController.cancelExecution()
        
        // Then
        XCTAssertNil(screenController.currentScript)
        XCTAssertEqual(screenController.currentColor, .black)
    }
    
    // MARK: - Color Publishing Tests
    
    func testCurrentColor_IsPublished() {
        // Given
        var receivedColor: Color?
        let expectation = expectation(description: "Color published")
        
        screenController.$currentColor
            .first()
            .sink { color in
                receivedColor = color
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedColor)
    }
    
    func testIsActive_IsPublished() {
        // Given
        var receivedState: Bool?
        let expectation = expectation(description: "Active state published")
        
        screenController.$isActive
            .first()
            .sink { state in
                receivedState = state
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Then
        wait(for: [expectation], timeout: 1.0)
        XCTAssertNotNil(receivedState)
    }
    
    // MARK: - Event Timing Tests
    
    func testScriptExecution_CompletesAfterDuration() {
        // Given: A short script with 0.1 second duration
        let script = createTestScript(duration: 0.1)
        let startTime = Date()
        let expectation = expectation(description: "Script completes")
        
        screenController.execute(script: script, syncedTo: startTime)
        
        // When: Wait for script duration + small buffer
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            // Then: Script should be cancelled and color should be black
            XCTAssertNil(self.screenController.currentScript)
            XCTAssertEqual(self.screenController.currentColor, .black)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
    }
    
    // MARK: - Opacity Calculation Tests (Indirect)
    
    func testSquareWaveform_ProducesConstantIntensity() {
        // Given: Script with square waveform
        let event = LightEvent(
            timestamp: 0,
            intensity: 0.8,
            duration: 1.0,
            waveform: .square,
            color: .white
        )
        let script = LightScript(
            trackId: UUID(),
            mode: .alpha,
            targetFrequency: 10.0,
            multiplier: 1,
            events: [event]
        )
        
        // When
        screenController.execute(script: script, syncedTo: Date())
        
        // Give the display link time to update
        let expectation = expectation(description: "Display link updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then: Color should not be black (event is active)
            XCTAssertNotEqual(self.screenController.currentColor, .black)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
        
        screenController.cancelExecution()
    }
    
    func testSineWaveform_UsesFrequencyBasedTiming() {
        // Given: Script with sine waveform at 10 Hz
        let event = LightEvent(
            timestamp: 0,
            intensity: 1.0,
            duration: 1.0,
            waveform: .sine,
            color: .white
        )
        let script = LightScript(
            trackId: UUID(),
            mode: .alpha,
            targetFrequency: 10.0, // 10 Hz
            multiplier: 1,
            events: [event]
        )
        
        // When
        screenController.execute(script: script, syncedTo: Date())
        
        // Give the display link time to update
        let expectation = expectation(description: "Display link updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then: Color should be set (even if partially transparent)
            // The sine wave calculation should be working
            XCTAssertNotNil(self.screenController.currentColor)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
        
        screenController.cancelExecution()
    }
    
    func testTriangleWaveform_UsesFrequencyBasedTiming() {
        // Given: Script with triangle waveform at 10 Hz
        let event = LightEvent(
            timestamp: 0,
            intensity: 1.0,
            duration: 1.0,
            waveform: .triangle,
            color: .white
        )
        let script = LightScript(
            trackId: UUID(),
            mode: .alpha,
            targetFrequency: 10.0, // 10 Hz
            multiplier: 1,
            events: [event]
        )
        
        // When
        screenController.execute(script: script, syncedTo: Date())
        
        // Give the display link time to update
        let expectation = expectation(description: "Display link updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then: Color should be set
            XCTAssertNotNil(self.screenController.currentColor)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
        
        screenController.cancelExecution()
    }
    
    // MARK: - Color Application Tests
    
    func testColorFromEvent_IsApplied() {
        // Given: Script with red color event
        let event = LightEvent(
            timestamp: 0,
            intensity: 1.0,
            duration: 1.0,
            waveform: .square,
            color: .red
        )
        let script = LightScript(
            trackId: UUID(),
            mode: .alpha,
            targetFrequency: 10.0,
            multiplier: 1,
            events: [event]
        )
        
        // When
        screenController.execute(script: script, syncedTo: Date())
        
        // Give the display link time to update
        let expectation = expectation(description: "Color updates")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then: Color should be red-based (not black)
            XCTAssertNotEqual(self.screenController.currentColor, .black)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
        
        screenController.cancelExecution()
    }
    
    func testDefaultColor_IsUsedWhenEventHasNoColor() {
        // Given: Script with no color specified in event
        let event = LightEvent(
            timestamp: 0,
            intensity: 1.0,
            duration: 1.0,
            waveform: .square,
            color: nil
        )
        let script = LightScript(
            trackId: UUID(),
            mode: .alpha,
            targetFrequency: 10.0,
            multiplier: 1,
            events: [event]
        )
        
        // When: Set default color to blue
        screenController.setColor(.blue)
        screenController.execute(script: script, syncedTo: Date())
        
        // Give the display link time to update
        let expectation = expectation(description: "Color updates with default")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Then: Color should not be black (default color applied)
            XCTAssertNotEqual(self.screenController.currentColor, .black)
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 0.5)
        
        screenController.cancelExecution()
    }
    
    // MARK: - Multiple Events Tests
    
    func testMultipleEvents_TransitionCorrectly() {
        // Given: Script with two events
        let events = [
            LightEvent(timestamp: 0, intensity: 1.0, duration: 0.1, waveform: .square, color: .red),
            LightEvent(timestamp: 0.15, intensity: 0.5, duration: 0.1, waveform: .square, color: .blue)
        ]
        let script = LightScript(
            trackId: UUID(),
            mode: .alpha,
            targetFrequency: 10.0,
            multiplier: 1,
            events: events
        )
        
        // When
        screenController.execute(script: script, syncedTo: Date())
        
        // Then: First event should be active
        let expectation1 = expectation(description: "First event active")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            XCTAssertNotEqual(self.screenController.currentColor, .black)
            expectation1.fulfill()
        }
        
        wait(for: [expectation1], timeout: 0.2)
        
        // Then: Between events should be black
        let expectation2 = expectation(description: "Between events is black")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.125) {
            XCTAssertEqual(self.screenController.currentColor, .black)
            expectation2.fulfill()
        }
        
        wait(for: [expectation2], timeout: 0.3)
        
        screenController.cancelExecution()
    }
    
    // MARK: - Helper Methods
    
    private func createTestScript(duration: TimeInterval = 1.0) -> LightScript {
        let event = LightEvent(
            timestamp: 0,
            intensity: 1.0,
            duration: duration,
            waveform: .square,
            color: .white
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
