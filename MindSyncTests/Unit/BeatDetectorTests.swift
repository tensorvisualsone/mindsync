import XCTest
@testable import MindSync

final class BeatDetectorTests: XCTestCase {
    var beatDetector: BeatDetector?
    
    override func setUp() {
        super.setUp()
        beatDetector = BeatDetector()
        XCTAssertNotNil(beatDetector, "BeatDetector initialization should succeed")
    }
    
    override func tearDown() {
        beatDetector = nil
        super.tearDown()
    }
    
    // MARK: - Basic Beat Detection Tests
    
    func testBeatDetector_Initialization_Succeeds() {
        // Given/When: BeatDetector is initialized in setUp
        // Then: Should not be nil
        XCTAssertNotNil(beatDetector, "BeatDetector should initialize successfully")
    }
    
    func testDetectBeats_WithEmptySamples_ReturnsEmptyArray() async {
        // Given: Empty audio samples
        guard let beatDetector = beatDetector else {
            XCTFail("BeatDetector should be initialized")
            return
        }
        let samples: [Float] = []
        
        // When
        let beatTimestamps = await beatDetector.detectBeats(in: samples)
        
        // Then: Should return empty array
        XCTAssertEqual(beatTimestamps.count, 0, "Expected no beats for empty samples")
    }
    
    func testDetectBeats_WithVeryShortSamples_ReturnsEmptyArray() async {
        // Given: Audio samples shorter than FFT size (2048)
        guard let beatDetector = beatDetector else {
            XCTFail("BeatDetector should be initialized")
            return
        }
        let samples = [Float](repeating: 0.5, count: 1000)
        
        // When
        let beatTimestamps = await beatDetector.detectBeats(in: samples)
        
        // Then: Should return empty or very few beats
        XCTAssertLessThanOrEqual(beatTimestamps.count, 1, "Expected few or no beats for very short audio")
    }
    
    func testDetectBeats_WithSilence_ReturnsFewerBeats() async {
        // Given: Silent audio (all zeros)
        guard let beatDetector = beatDetector else {
            XCTFail("BeatDetector should be initialized")
            return
        }
        let samples = [Float](repeating: 0.0, count: 44100) // 1 second of silence
        
        // When
        let beatTimestamps = await beatDetector.detectBeats(in: samples)
        
        // Then: Should detect few or no beats in silence
        XCTAssertLessThanOrEqual(beatTimestamps.count, 5, "Expected few beats in silence")
    }
    
    func testDetectBeats_WithConstantTone_ReturnsFewerBeats() async {
        // Given: Constant tone (no spectral flux changes)
        guard let beatDetector = beatDetector else {
            XCTFail("BeatDetector should be initialized")
            return
        }
        let samples = [Float](repeating: 0.5, count: 44100) // 1 second of constant tone
        
        // When
        let beatTimestamps = await beatDetector.detectBeats(in: samples)
        
        // Then: Should detect few beats with constant tone
        XCTAssertLessThanOrEqual(beatTimestamps.count, 10, "Expected few beats for constant tone")
    }
    
    // MARK: - Beat Detection with Synthetic Data
    
    func testDetectBeats_WithSimulatedBeats_DetectsBeats() async {
        // Given: Simulated audio with clear beat patterns
        guard let beatDetector = beatDetector else {
            XCTFail("BeatDetector should be initialized")
            return
        }
        // Create 4 seconds of audio at 44.1kHz with beats every 0.5s (120 BPM)
        let sampleRate = 44100
        let duration = 4 // seconds
        let totalSamples = sampleRate * duration
        var samples = [Float](repeating: 0.0, count: totalSamples)
        
        // Add impulses at 0.5s intervals (simulating beats)
        for beat in 0..<8 {
            let beatPosition = beat * sampleRate / 2 // Every 0.5 seconds
            if beatPosition < totalSamples - 1000 {
                // Add a short burst of energy at each beat position
                for i in 0..<1000 {
                    let position = beatPosition + i
                    if position < totalSamples {
                        samples[position] = Float(sin(Double(i) * 0.1)) * 0.8
                    }
                }
            }
        }
        
        // When
        let beatTimestamps = await beatDetector.detectBeats(in: samples)
        
        // Then: Should detect some beats
        XCTAssertGreaterThan(beatTimestamps.count, 0, "Expected to detect at least some beats")
    }
    
    // MARK: - Cancellation Tests
    
    func testDetectBeats_WithTaskCancellation_ReturnsEmptyArray() async {
        // Given: Long audio samples
        guard let beatDetector = beatDetector else {
            XCTFail("BeatDetector should be initialized")
            return
        }
        let samples = [Float](repeating: 0.5, count: 441000) // 10 seconds
        
        // When: Start detection and cancel immediately
        let task = Task {
            await beatDetector.detectBeats(in: samples)
        }
        task.cancel()
        let beatTimestamps = await task.value
        
        // Then: Should return empty array due to cancellation
        XCTAssertEqual(beatTimestamps.count, 0, "Expected empty array after cancellation")
    }
    
    // MARK: - Output Validation Tests
    
    func testDetectBeats_ReturnsTimestampsInAscendingOrder() async {
        // Given: Audio with multiple beats
        guard let beatDetector = beatDetector else {
            XCTFail("BeatDetector should be initialized")
            return
        }
        let sampleRate = 44100
        var samples = [Float](repeating: 0.0, count: sampleRate * 2) // 2 seconds
        
        // Add some energy variations
        for i in 0..<samples.count {
            samples[i] = Float(sin(Double(i) * 0.01)) * 0.5
        }
        
        // When
        let beatTimestamps = await beatDetector.detectBeats(in: samples)
        
        // Then: Timestamps should be in ascending order
        for i in 1..<beatTimestamps.count {
            XCTAssertGreaterThan(beatTimestamps[i], beatTimestamps[i-1],
                               "Beat timestamps should be in ascending order")
        }
    }
    
    func testDetectBeats_ReturnsNonNegativeTimestamps() async {
        // Given: Audio samples
        guard let beatDetector = beatDetector else {
            XCTFail("BeatDetector should be initialized")
            return
        }
        let samples = [Float](repeating: 0.5, count: 44100)
        
        // When
        let beatTimestamps = await beatDetector.detectBeats(in: samples)
        
        // Then: All timestamps should be non-negative
        for timestamp in beatTimestamps {
            XCTAssertGreaterThanOrEqual(timestamp, 0.0, "Beat timestamps should be non-negative")
        }
    }
    
    func testDetectBeats_ReturnsTimestampsWithinAudioDuration() async {
        // Given: 2 seconds of audio at 44.1kHz
        guard let beatDetector = beatDetector else {
            XCTFail("BeatDetector should be initialized")
            return
        }
        let sampleRate = 44100.0
        let duration = 2.0 // seconds
        let totalSamples = Int(sampleRate * duration)
        var samples = [Float](repeating: 0.0, count: totalSamples)
        
        // Add some variations
        for i in 0..<samples.count {
            samples[i] = Float(sin(Double(i) * 0.05)) * 0.7
        }
        
        // When
        let beatTimestamps = await beatDetector.detectBeats(in: samples)
        
        // Then: All timestamps should be within the audio duration
        for timestamp in beatTimestamps {
            XCTAssertLessThanOrEqual(timestamp, duration,
                                    "Beat timestamps should not exceed audio duration")
        }
    }
}
