import XCTest
@testable import MindSync

final class VibrationScriptTests: XCTestCase {
    
    func testVibrationScript_ValidParameters_Succeeds() throws {
        let trackId = UUID()
        let events: [VibrationEvent] = []
        
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
        let trackId = UUID()
        let events: [VibrationEvent] = []
        
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
        let trackId = UUID()
        let events: [VibrationEvent] = []
        
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
        let trackId = UUID()
        let events: [VibrationEvent] = []
        
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
        let trackId = UUID()
        let events: [VibrationEvent] = []
        
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
        let trackId = UUID()
        let events: [VibrationEvent] = []
        
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
        let trackId = UUID()
        let events: [VibrationEvent] = []
        
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
        let trackId = UUID()
        let events: [VibrationEvent] = []
        
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
        let trackId = UUID()
        let events: [VibrationEvent] = []
        
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
    
    func testVibrationScriptError_LocalizedError() {
        let frequencyError = VibrationScriptError.invalidTargetFrequency(0.0)
        XCTAssertNotNil(frequencyError.localizedDescription)
        
        let multiplierError = VibrationScriptError.invalidMultiplier(0)
        XCTAssertNotNil(multiplierError.localizedDescription)
    }
}

