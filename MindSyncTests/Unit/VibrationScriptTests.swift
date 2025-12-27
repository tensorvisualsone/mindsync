import XCTest
@testable import MindSync

final class VibrationScriptTests: XCTestCase {
    
    // MARK: - Helper Methods
    
    private func makeTestParameters() -> (trackId: UUID, events: [VibrationEvent]) {
        return (UUID(), [])
    }
    
    // MARK: - Shared Test Case Structures
    
    /// Shared test case structure for mode-based tests
    private struct ModeTestCase {
        let mode: EntrainmentMode
        let targetFrequency: Double
        let multiplier: Int
        
        /// Computed description for consistent test reporting
        var description: String {
            "\(mode) mode with frequency \(targetFrequency) Hz and multiplier \(multiplier)"
        }
    }
    
    // MARK: - Tests
    
    func testVibrationScript_ValidParameters_Succeeds() throws {
        let (trackId, events) = makeTestParameters()
        
        let script = try VibrationScript(
            trackId: trackId,
            mode: .alpha,
            targetFrequency: 10.0,
            multiplier: 2,
            events: events
        )
        
        XCTAssertEqual(script.trackId, trackId)
        XCTAssertEqual(script.mode, .alpha)
        XCTAssertEqual(script.targetFrequency, 10.0)
        XCTAssertEqual(script.multiplier, 2)
        XCTAssertEqual(script.events.count, 0)
    }
    
    func testVibrationScript_InvalidTargetFrequency_NaN_Throws() {
        let (trackId, events) = makeTestParameters()
        
        XCTAssertThrowsError(try VibrationScript(
            trackId: trackId,
            mode: .alpha,
            targetFrequency: Double.nan,
            multiplier: 2,
            events: events
        )) { error in
            if case VibrationScriptError.invalidTargetFrequency(let frequency) = error {
                XCTAssertTrue(frequency.isNaN)
            } else {
                XCTFail("Expected invalidTargetFrequency error")
            }
        }
    }
    
    func testVibrationScript_InvalidTargetFrequency_Infinity_Throws() {
        let (trackId, events) = makeTestParameters()
        
        XCTAssertThrowsError(try VibrationScript(
            trackId: trackId,
            mode: .alpha,
            targetFrequency: Double.infinity,
            multiplier: 2,
            events: events
        )) { error in
            if case VibrationScriptError.invalidTargetFrequency(let frequency) = error {
                XCTAssertTrue(frequency.isInfinite)
            } else {
                XCTFail("Expected invalidTargetFrequency error")
            }
        }
    }
    
    func testVibrationScript_InvalidTargetFrequency_NegativeInfinity_Throws() {
        let (trackId, events) = makeTestParameters()
        
        XCTAssertThrowsError(try VibrationScript(
            trackId: trackId,
            mode: .alpha,
            targetFrequency: -Double.infinity,
            multiplier: 2,
            events: events
        )) { error in
            if case VibrationScriptError.invalidTargetFrequency(let frequency) = error {
                XCTAssertTrue(frequency.isInfinite)
            } else {
                XCTFail("Expected invalidTargetFrequency error")
            }
        }
    }
    
    func testVibrationScript_InvalidTargetFrequency_Zero_Throws() {
        let (trackId, events) = makeTestParameters()
        
        XCTAssertThrowsError(try VibrationScript(
            trackId: trackId,
            mode: .alpha,
            targetFrequency: 0.0,
            multiplier: 2,
            events: events
        )) { error in
            if case VibrationScriptError.invalidTargetFrequency(let frequency) = error {
                XCTAssertEqual(frequency, 0.0)
            } else {
                XCTFail("Expected invalidTargetFrequency error")
            }
        }
    }
    
    func testVibrationScript_InvalidTargetFrequency_Negative_Throws() {
        let (trackId, events) = makeTestParameters()
        
        XCTAssertThrowsError(try VibrationScript(
            trackId: trackId,
            mode: .alpha,
            targetFrequency: -5.0,
            multiplier: 2,
            events: events
        )) { error in
            if case VibrationScriptError.invalidTargetFrequency(let frequency) = error {
                XCTAssertEqual(frequency, -5.0)
            } else {
                XCTFail("Expected invalidTargetFrequency error")
            }
        }
    }
    
    func testVibrationScript_InvalidMultiplier_Zero_Throws() {
        let (trackId, events) = makeTestParameters()
        
        XCTAssertThrowsError(try VibrationScript(
            trackId: trackId,
            mode: .alpha,
            targetFrequency: 10.0,
            multiplier: 0,
            events: events
        )) { error in
            if case VibrationScriptError.invalidMultiplier(let multiplier) = error {
                XCTAssertEqual(multiplier, 0)
            } else {
                XCTFail("Expected invalidMultiplier error")
            }
        }
    }
    
    func testVibrationScript_InvalidMultiplier_Negative_Throws() {
        let (trackId, events) = makeTestParameters()
        
        XCTAssertThrowsError(try VibrationScript(
            trackId: trackId,
            mode: .alpha,
            targetFrequency: 10.0,
            multiplier: -1,
            events: events
        )) { error in
            if case VibrationScriptError.invalidMultiplier(let multiplier) = error {
                XCTAssertEqual(multiplier, -1)
            } else {
                XCTFail("Expected invalidMultiplier error")
            }
        }
    }
    
    func testVibrationScript_ValidParameters_EdgeCases_Succeeds() throws {
        let (trackId, events) = makeTestParameters()
        
        // Test with very small positive frequency
        let script1 = try VibrationScript(
            trackId: trackId,
            mode: .alpha,
            targetFrequency: Double.leastNormalMagnitude,
            multiplier: 1,
            events: events
        )
        XCTAssertGreaterThan(script1.targetFrequency, 0)
        
        // Test with very large positive frequency
        let script2 = try VibrationScript(
            trackId: trackId,
            mode: .alpha,
            targetFrequency: 1000.0,
            multiplier: 100,
            events: events
        )
        XCTAssertEqual(script2.targetFrequency, 1000.0)
        XCTAssertEqual(script2.multiplier, 100)
    }
    
    // MARK: - Mode Coverage Tests
    
    func testVibrationScript_ValidParameters_OtherModes_Succeeds() throws {
        let testCases: [ModeTestCase] = [
            ModeTestCase(mode: .theta, targetFrequency: 6.0, multiplier: 2),
            ModeTestCase(mode: .gamma, targetFrequency: 35.0, multiplier: 3),
            ModeTestCase(mode: .cinematic, targetFrequency: 6.5, multiplier: 1)
        ]
        
        for testCase in testCases {
            try XCTContext.runActivity(named: testCase.description) { _ in
                let (trackId, events) = makeTestParameters()
                
                let script = try VibrationScript(
                    trackId: trackId,
                    mode: testCase.mode,
                    targetFrequency: testCase.targetFrequency,
                    multiplier: testCase.multiplier,
                    events: events
                )
                
                XCTAssertEqual(script.mode, testCase.mode)
                XCTAssertEqual(script.targetFrequency, testCase.targetFrequency)
                XCTAssertEqual(script.multiplier, testCase.multiplier)
            }
        }
    }
    
    func testVibrationScript_InvalidTargetFrequency_Zero_OtherModes_Throws() throws {
        let testCases: [ModeTestCase] = [
            ModeTestCase(mode: .theta, targetFrequency: 0.0, multiplier: 2),
            ModeTestCase(mode: .gamma, targetFrequency: 0.0, multiplier: 2),
            ModeTestCase(mode: .cinematic, targetFrequency: 0.0, multiplier: 2)
        ]
        
        for testCase in testCases {
            try XCTContext.runActivity(named: testCase.description) { _ in
                let (trackId, events) = makeTestParameters()
                
                XCTAssertThrowsError(try VibrationScript(
                    trackId: trackId,
                    mode: testCase.mode,
                    targetFrequency: testCase.targetFrequency,
                    multiplier: testCase.multiplier,
                    events: events
                ), "Expected invalidTargetFrequency error") { error in
                    if case VibrationScriptError.invalidTargetFrequency(let frequency) = error {
                        XCTAssertEqual(frequency, testCase.targetFrequency)
                    } else {
                        XCTFail("Expected invalidTargetFrequency error, got \(error)")
                    }
                }
            }
        }
    }
    
    func testVibrationScript_InvalidTargetFrequency_Negative_OtherModes_Throws() throws {
        let testCases: [ModeTestCase] = [
            ModeTestCase(mode: .theta, targetFrequency: -5.0, multiplier: 2),
            ModeTestCase(mode: .gamma, targetFrequency: -10.0, multiplier: 3),
            ModeTestCase(mode: .cinematic, targetFrequency: -7.0, multiplier: 4)
        ]
        
        for testCase in testCases {
            try XCTContext.runActivity(named: testCase.description) { _ in
                let (trackId, events) = makeTestParameters()
                
                XCTAssertThrowsError(try VibrationScript(
                    trackId: trackId,
                    mode: testCase.mode,
                    targetFrequency: testCase.targetFrequency,
                    multiplier: testCase.multiplier,
                    events: events
                ), "Expected invalidTargetFrequency error") { error in
                    if case VibrationScriptError.invalidTargetFrequency(let frequency) = error {
                        XCTAssertEqual(frequency, testCase.targetFrequency)
                    } else {
                        XCTFail("Expected invalidTargetFrequency error, got \(error)")
                    }
                }
            }
        }
    }
    
    func testVibrationScript_InvalidMultiplier_Zero_OtherModes_Throws() throws {
        let testCases: [ModeTestCase] = [
            ModeTestCase(mode: .theta, targetFrequency: 6.0, multiplier: 0),
            ModeTestCase(mode: .gamma, targetFrequency: 35.0, multiplier: 0),
            ModeTestCase(mode: .cinematic, targetFrequency: 6.5, multiplier: 0)
        ]
        
        for testCase in testCases {
            try XCTContext.runActivity(named: testCase.description) { _ in
                let (trackId, events) = makeTestParameters()
                
                XCTAssertThrowsError(try VibrationScript(
                    trackId: trackId,
                    mode: testCase.mode,
                    targetFrequency: testCase.targetFrequency,
                    multiplier: testCase.multiplier,
                    events: events
                ), "Expected invalidMultiplier error") { error in
                    if case VibrationScriptError.invalidMultiplier(let multiplier) = error {
                        XCTAssertEqual(multiplier, testCase.multiplier)
                    } else {
                        XCTFail("Expected invalidMultiplier error, got \(error)")
                    }
                }
            }
        }
    }
    
    func testVibrationScript_InvalidMultiplier_Negative_OtherModes_Throws() throws {
        let testCases: [ModeTestCase] = [
            ModeTestCase(mode: .theta, targetFrequency: 6.0, multiplier: -1),
            ModeTestCase(mode: .gamma, targetFrequency: 35.0, multiplier: -2),
            ModeTestCase(mode: .cinematic, targetFrequency: 6.5, multiplier: -3)
        ]
        
        for testCase in testCases {
            try XCTContext.runActivity(named: testCase.description) { _ in
                let (trackId, events) = makeTestParameters()
                
                XCTAssertThrowsError(try VibrationScript(
                    trackId: trackId,
                    mode: testCase.mode,
                    targetFrequency: testCase.targetFrequency,
                    multiplier: testCase.multiplier,
                    events: events
                ), "Expected invalidMultiplier error") { error in
                    if case VibrationScriptError.invalidMultiplier(let multiplier) = error {
                        XCTAssertEqual(multiplier, testCase.multiplier)
                    } else {
                        XCTFail("Expected invalidMultiplier error, got \(error)")
                    }
                }
            }
        }
    }
    
    func testVibrationScript_EventsArray_StoredCorrectly() throws {
        let (trackId, _) = makeTestParameters()
        
        // Create representative VibrationEvent instances with known values
        // Include events with different waveforms and non-default values
        let event1 = try VibrationEvent(
            timestamp: 0.0,
            intensity: 0.5,
            duration: 0.1,
            waveform: .square
        )
        
        let event2 = try VibrationEvent(
            timestamp: 1.5,
            intensity: 0.8,
            duration: 0.2,
            waveform: .sine
        )
        
        let event3 = try VibrationEvent(
            timestamp: 3.0,
            intensity: 1.0,
            duration: 0.15,
            waveform: .triangle
        )
        
        let inputEvents = [event1, event2, event3]
        
        let script = try VibrationScript(
            trackId: trackId,
            mode: .theta,
            targetFrequency: 6.0,
            multiplier: 3,
            events: inputEvents
        )
        
        // Assert that the events count matches
        XCTAssertEqual(script.events.count, inputEvents.count, "Events count should match input")
        XCTAssertEqual(script.events.count, 3, "Should have exactly 3 events")
        
        // Assert that stored events equal the original events by comparing properties
        XCTAssertEqual(script.events[0].timestamp, event1.timestamp, accuracy: 0.001)
        XCTAssertEqual(script.events[0].intensity, event1.intensity, accuracy: 0.001)
        XCTAssertEqual(script.events[0].duration, event1.duration, accuracy: 0.001)
        XCTAssertEqual(script.events[0].waveform, event1.waveform)
        
        XCTAssertEqual(script.events[1].timestamp, event2.timestamp, accuracy: 0.001)
        XCTAssertEqual(script.events[1].intensity, event2.intensity, accuracy: 0.001)
        XCTAssertEqual(script.events[1].duration, event2.duration, accuracy: 0.001)
        XCTAssertEqual(script.events[1].waveform, event2.waveform)
        
        XCTAssertEqual(script.events[2].timestamp, event3.timestamp, accuracy: 0.001)
        XCTAssertEqual(script.events[2].intensity, event3.intensity, accuracy: 0.001)
        XCTAssertEqual(script.events[2].duration, event3.duration, accuracy: 0.001)
        XCTAssertEqual(script.events[2].waveform, event3.waveform)
    }
    
    func testVibrationScriptError_LocalizedError() {
        let frequencyError = VibrationScriptError.invalidTargetFrequency(0.0)
        XCTAssertNotNil(frequencyError.localizedDescription)
        
        let multiplierError = VibrationScriptError.invalidMultiplier(0)
        XCTAssertNotNil(multiplierError.localizedDescription)
    }
}

