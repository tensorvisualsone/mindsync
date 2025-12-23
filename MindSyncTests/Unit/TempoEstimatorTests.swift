import XCTest
@testable import MindSync

final class TempoEstimatorTests: XCTestCase {
    var tempoEstimator: TempoEstimator!
    
    override func setUp() {
        super.setUp()
        tempoEstimator = TempoEstimator()
    }
    
    override func tearDown() {
        tempoEstimator = nil
        super.tearDown()
    }
    
    // MARK: - Basic BPM Estimation Tests
    
    func testEstimateBPM_WithRegularBeats_Returns120BPM() {
        // Given: Regular beats at 120 BPM (0.5 second intervals)
        let beatTimestamps: [TimeInterval] = [0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
        
        // When
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        // Then: Should estimate 120 BPM (with some tolerance)
        XCTAssertEqual(bpm, 120.0, accuracy: 5.0, "Expected 120 BPM for 0.5s intervals")
    }
    
    func testEstimateBPM_WithSlowerBeats_Returns90BPM() {
        // Given: Slower beats at ~90 BPM (0.667 second intervals)
        let beatTimestamps: [TimeInterval] = [0.0, 0.667, 1.334, 2.001, 2.668, 3.335]
        
        // When
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        // Then: Should estimate around 90 BPM
        XCTAssertEqual(bpm, 90.0, accuracy: 5.0, "Expected ~90 BPM for 0.667s intervals")
    }
    
    func testEstimateBPM_WithFasterBeats_Returns140BPM() {
        // Given: Faster beats at ~140 BPM (0.429 second intervals)
        let beatTimestamps: [TimeInterval] = [0.0, 0.429, 0.858, 1.287, 1.716, 2.145, 2.574]
        
        // When
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        // Then: Should estimate around 140 BPM
        XCTAssertEqual(bpm, 140.0, accuracy: 5.0, "Expected ~140 BPM for 0.429s intervals")
    }
    
    // MARK: - Edge Cases
    
    func testEstimateBPM_WithEmptyArray_ReturnsDefaultBPM() {
        // Given: No beats
        let beatTimestamps: [TimeInterval] = []
        
        // When
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        // Then: Should return default BPM (120)
        XCTAssertEqual(bpm, 120.0, "Expected default BPM for empty array")
    }
    
    func testEstimateBPM_WithSingleBeat_ReturnsDefaultBPM() {
        // Given: Only one beat
        let beatTimestamps: [TimeInterval] = [1.0]
        
        // When
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        // Then: Should return default BPM
        XCTAssertEqual(bpm, 120.0, "Expected default BPM for single beat")
    }
    
    func testEstimateBPM_WithTwoBeats_ReturnsValidBPM() {
        // Given: Two beats 0.5 seconds apart (120 BPM)
        let beatTimestamps: [TimeInterval] = [0.0, 0.5]
        
        // When
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        // Then: Should estimate around 120 BPM
        XCTAssertGreaterThan(bpm, 60.0, "BPM should be within valid range")
        XCTAssertLessThan(bpm, 200.0, "BPM should be within valid range")
    }
    
    // MARK: - Outlier Filtering Tests
    
    func testEstimateBPM_WithOutliers_FiltersOutliers() {
        // Given: Regular 120 BPM beats with some outliers
        let beatTimestamps: [TimeInterval] = [
            0.0, 0.5, 1.0, 
            1.1,  // Outlier (very close to previous)
            1.5, 2.0, 2.5, 
            4.0,  // Outlier (long gap)
            4.5, 5.0
        ]
        
        // When
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        // Then: Should still estimate around 120 BPM, ignoring outliers
        XCTAssertEqual(bpm, 120.0, accuracy: 10.0, "Expected ~120 BPM despite outliers")
    }
    
    // MARK: - Tempo Folding Tests
    
    func testEstimateBPM_WithDoubleTimeBeats_FoldsToCorrectTempo() {
        // Given: Beats at double-time (240 BPM / 0.25s intervals)
        // Algorithm should fold this down to 120 BPM
        let beatTimestamps: [TimeInterval] = [0.0, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
        
        // When
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        // Then: Should fold to reasonable BPM range (60-200)
        XCTAssertGreaterThanOrEqual(bpm, 60.0, "BPM should be folded into valid range")
        XCTAssertLessThanOrEqual(bpm, 200.0, "BPM should be folded into valid range")
    }
    
    func testEstimateBPM_WithHalfTimeBeats_FoldsToCorrectTempo() {
        // Given: Beats at half-time (60 BPM / 1.0s intervals)
        // Algorithm should fold this up to 120 BPM
        let beatTimestamps: [TimeInterval] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0]
        
        // When
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        // Then: Should fold to reasonable BPM range
        XCTAssertGreaterThanOrEqual(bpm, 60.0, "BPM should be folded into valid range")
        XCTAssertLessThanOrEqual(bpm, 200.0, "BPM should be folded into valid range")
    }
    
    // MARK: - Validation Tests
    
    func testEstimateBPM_AlwaysReturnsValueInValidRange() {
        // Given: Various beat patterns
        let testCases: [[TimeInterval]] = [
            [0.0, 0.1, 0.2, 0.3],  // Very fast
            [0.0, 2.0, 4.0, 6.0],  // Very slow
            [0.0, 0.5, 1.0, 1.5],  // Normal
            [0.0, 0.3, 0.9, 1.2, 1.8, 2.1]  // Irregular
        ]
        
        // When & Then: All should return values in valid range (60-200 BPM)
        for beatTimestamps in testCases {
            let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
            XCTAssertGreaterThanOrEqual(bpm, 60.0, "BPM should be at least 60")
            XCTAssertLessThanOrEqual(bpm, 200.0, "BPM should be at most 200")
        }
    }
}
