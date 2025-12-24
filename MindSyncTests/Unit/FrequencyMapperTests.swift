import XCTest
@testable import MindSync

final class FrequencyMapperTests: XCTestCase {
    
    func testCalculateMultiplier_AlphaMode_120BPM() {
        let bpm = 120.0
        let targetRange = EntrainmentMode.alpha.frequencyRange // 8-12 Hz
        let maxFrequency = LightSource.screen.maxFrequency // 60 Hz
        
        let multiplier = FrequencyMapper.calculateMultiplier(
            bpm: bpm,
            targetRange: targetRange,
            maxFrequency: maxFrequency
        )
        
        // Base frequency: 120/60 = 2 Hz
        // Multiplier 5: 2 * 5 = 10 Hz (in range 8-12)
        XCTAssertEqual(multiplier, 5)
    }
    
    func testCalculateMultiplier_ThetaMode_60BPM() {
        let bpm = 60.0
        let targetRange = EntrainmentMode.theta.frequencyRange // 4-8 Hz
        let maxFrequency = LightSource.screen.maxFrequency
        
        let multiplier = FrequencyMapper.calculateMultiplier(
            bpm: bpm,
            targetRange: targetRange,
            maxFrequency: maxFrequency
        )
        
        // Base frequency: 60/60 = 1 Hz
        // Multiplier 5: 1 * 5 = 5 Hz (in range 4-8)
        XCTAssertEqual(multiplier, 5)
    }
    
    func testCalculateMultiplier_GammaMode_120BPM() {
        let bpm = 120.0
        let targetRange = EntrainmentMode.gamma.frequencyRange // 30-40 Hz
        let maxFrequency = LightSource.screen.maxFrequency
        
        let multiplier = FrequencyMapper.calculateMultiplier(
            bpm: bpm,
            targetRange: targetRange,
            maxFrequency: maxFrequency
        )
        
        // Base frequency: 120/60 = 2 Hz
        // Multiplier 18: 2 * 18 = 36 Hz (in range 30-40)
        XCTAssertEqual(multiplier, 18)
    }
    
    func testCalculateMultiplier_FlashlightMaxFrequency() {
        let bpm = 120.0
        let targetRange = EntrainmentMode.gamma.frequencyRange // 30-40 Hz
        let maxFrequency = LightSource.flashlight.maxFrequency // 30 Hz
        
        let multiplier = FrequencyMapper.calculateMultiplier(
            bpm: bpm,
            targetRange: targetRange,
            maxFrequency: maxFrequency
        )
        
        // Should be limited by flashlight max frequency (30 Hz)
        // Base: 2 Hz, multiplier 15: 2 * 15 = 30 Hz (at limit)
        XCTAssertEqual(multiplier, 15)
    }
    
    func testMapBPMToFrequency_AlphaMode() {
        let bpm = 120.0
        let frequency = FrequencyMapper.mapBPMToFrequency(
            bpm: bpm,
            mode: .alpha,
            lightSource: .screen
        )
        
        // Should be in alpha range (8-12 Hz)
        XCTAssertGreaterThanOrEqual(frequency, 8.0)
        XCTAssertLessThanOrEqual(frequency, 12.0)
    }
    
    func testMapBPMToFrequency_ThetaMode() {
        let bpm = 60.0
        let frequency = FrequencyMapper.mapBPMToFrequency(
            bpm: bpm,
            mode: .theta,
            lightSource: .screen
        )
        
        // Should be in theta range (4-8 Hz)
        XCTAssertGreaterThanOrEqual(frequency, 4.0)
        XCTAssertLessThanOrEqual(frequency, 8.0)
    }
    
    func testMapBPMToFrequency_GammaMode() {
        let bpm = 120.0
        let frequency = FrequencyMapper.mapBPMToFrequency(
            bpm: bpm,
            mode: .gamma,
            lightSource: .screen
        )
        
        // Should be in gamma range (30-40 Hz)
        XCTAssertGreaterThanOrEqual(frequency, 30.0)
        XCTAssertLessThanOrEqual(frequency, 40.0)
    }
    
    func testValidateFrequency_ValidFrequency() {
        let result = FrequencyMapper.validateFrequency(10.0)
        
        XCTAssertTrue(result.isValid)
        XCTAssertFalse(result.isPSEZone)
        XCTAssertNil(result.warningMessage)
    }
    
    func testValidateFrequency_PSEZone() {
        let result = FrequencyMapper.validateFrequency(20.0)
        
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.isPSEZone)
        XCTAssertNotNil(result.warningMessage)
    }
    
    func testValidateFrequency_TooLow() {
        let result = FrequencyMapper.validateFrequency(0.5)
        
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.warningMessage)
    }
    
    func testValidateFrequency_TooHigh() {
        let result = FrequencyMapper.validateFrequency(70.0)
        
        XCTAssertFalse(result.isValid)
        XCTAssertNotNil(result.warningMessage)
    }
    
    func testRecommendedFrequencyRange_AlphaScreen() {
        let range = FrequencyMapper.recommendedFrequencyRange(
            mode: .alpha,
            lightSource: .screen
        )
        
        XCTAssertEqual(range.lowerBound, 8.0)
        XCTAssertEqual(range.upperBound, 12.0)
    }
    
    func testRecommendedFrequencyRange_GammaFlashlight() {
        let range = FrequencyMapper.recommendedFrequencyRange(
            mode: .gamma,
            lightSource: .flashlight
        )
        
        // Should be clamped to flashlight max (30 Hz)
        XCTAssertEqual(range.lowerBound, 30.0)
        XCTAssertLessThanOrEqual(range.upperBound, 30.0)
    }
    
    func testCalculateMultiplier_CinematicMode() {
        let bpm = 120.0
        let targetRange = EntrainmentMode.cinematic.frequencyRange // 5.5-7.5 Hz
        let maxFrequency = LightSource.screen.maxFrequency
        
        let multiplier = FrequencyMapper.calculateMultiplier(
            bpm: bpm,
            targetRange: targetRange,
            maxFrequency: maxFrequency
        )
        
        // Base frequency: 120/60 = 2 Hz
        // Multiplier 3: 2 * 3 = 6 Hz (in range 5.5-7.5)
        XCTAssertEqual(multiplier, 3)
    }
    
    func testMapBPMToFrequency_CinematicMode() {
        let bpm = 120.0
        let frequency = FrequencyMapper.mapBPMToFrequency(
            bpm: bpm,
            mode: .cinematic,
            lightSource: .screen
        )
        
        // Should be in cinematic range (5.5-7.5 Hz)
        XCTAssertGreaterThanOrEqual(frequency, 5.5)
        XCTAssertLessThanOrEqual(frequency, 7.5)
    }
    
    func testRecommendedFrequencyRange_CinematicMode() {
        let range = FrequencyMapper.recommendedFrequencyRange(
            mode: .cinematic,
            lightSource: .screen
        )
        
        XCTAssertEqual(range.lowerBound, 5.5)
        XCTAssertEqual(range.upperBound, 7.5)
    }
}

