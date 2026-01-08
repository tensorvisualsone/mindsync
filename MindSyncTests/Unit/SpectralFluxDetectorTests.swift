import XCTest
import AVFoundation
@testable import MindSync

final class SpectralFluxDetectorTests: XCTestCase {
    
    var detector: SpectralFluxDetector!
    
    override func setUp() {
        super.setUp()
        detector = SpectralFluxDetector()
    }
    
    override func tearDown() {
        detector = nil
        super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() {
        let detector = SpectralFluxDetector()
        XCTAssertNotNil(detector, "Detector should initialize successfully")
    }
    
    func testFFTSetupCreation() {
        // If detector initialized, FFT setup should be valid
        XCTAssertNotNil(detector)
    }
    
    // MARK: - Flux Calculation Tests
    
    func testCalculateFluxWithSilence() {
        // Create silent audio buffer
        let frameCount = 2048
        let buffer = createAudioBuffer(frameCount: frameCount, frequency: 0, amplitude: 0.0)
        
        let flux = detector.calculateBassFlux(from: buffer)
        
        // Silence should produce zero or near-zero flux
        XCTAssertEqual(flux, 0.0, accuracy: 0.01)
    }
    
    func testCalculateFluxWithLowFrequencyTone() {
        // Create low frequency tone (100 Hz - in bass range)
        let frameCount = 2048
        let buffer = createAudioBuffer(frameCount: frameCount, frequency: 100, amplitude: 0.5)
        
        // First call establishes baseline
        _ = detector.calculateBassFlux(from: buffer)
        
        // Second call with same signal should show low flux (no change)
        let flux = detector.calculateBassFlux(from: buffer)
        
        XCTAssertLessThan(flux, 0.2, "Constant tone should have low flux")
    }
    
    func testCalculateFluxWithTransient() {
        let frameCount = 2048
        
        // First buffer: silence
        let silentBuffer = createAudioBuffer(frameCount: frameCount, frequency: 0, amplitude: 0.0)
        _ = detector.calculateBassFlux(from: silentBuffer)
        
        // Second buffer: loud bass tone (simulates kick drum)
        let loudBuffer = createAudioBuffer(frameCount: frameCount, frequency: 80, amplitude: 0.8)
        let flux = detector.calculateBassFlux(from: loudBuffer)
        
        // Transient from silence to loud should produce high flux
        XCTAssertGreaterThan(flux, 0.1, "Transient should produce noticeable flux")
    }
    
    func testCalculateFluxNormalization() {
        let frameCount = 2048
        
        // Create extremely loud signal
        let silentBuffer = createAudioBuffer(frameCount: frameCount, frequency: 0, amplitude: 0.0)
        _ = detector.calculateBassFlux(from: silentBuffer)
        
        let extremeBuffer = createAudioBuffer(frameCount: frameCount, frequency: 100, amplitude: 1.0)
        let flux = detector.calculateBassFlux(from: extremeBuffer)
        
        // Flux should be normalized to [0, 1]
        XCTAssertGreaterThanOrEqual(flux, 0.0)
        XCTAssertLessThanOrEqual(flux, 1.0)
    }
    
    func testCalculateFluxWithHighFrequency() {
        let frameCount = 2048
        
        // First: silence
        let silentBuffer = createAudioBuffer(frameCount: frameCount, frequency: 0, amplitude: 0.0)
        _ = detector.calculateBassFlux(from: silentBuffer)
        
        // Second: high frequency tone (5000 Hz - outside bass range 0-1400 Hz)
        // Should contribute less to flux than bass frequencies
        let highFreqBuffer = createAudioBuffer(frameCount: frameCount, frequency: 5000, amplitude: 0.8)
        let highFreqFlux = detector.calculateBassFlux(from: highFreqBuffer)
        
        // Third: bass frequency tone (100 Hz - in bass range)
        detector.reset()
        _ = detector.calculateBassFlux(from: silentBuffer)
        let bassBuffer = createAudioBuffer(frameCount: frameCount, frequency: 100, amplitude: 0.8)
        let bassFlux = detector.calculateBassFlux(from: bassBuffer)
        
        // Bass should produce higher flux (bass is isolated in this detector)
        XCTAssertGreaterThan(bassFlux, highFreqFlux, "Bass frequencies should dominate flux calculation")
    }
    
    // MARK: - Reset Tests
    
    func testReset() {
        let frameCount = 2048
        
        // Calculate flux with some signal
        let buffer = createAudioBuffer(frameCount: frameCount, frequency: 100, amplitude: 0.5)
        _ = detector.calculateBassFlux(from: buffer)
        
        // Reset detector
        detector.reset()
        
        // After reset, same signal should produce flux again (no previous magnitude)
        let fluxAfterReset = detector.calculateBassFlux(from: buffer)
        
        // First measurement after reset uses zero as previous magnitude,
        // so flux should be non-zero for non-silent signal
        XCTAssertGreaterThanOrEqual(fluxAfterReset, 0.0)
    }
    
    func testResetClearsPreviousState() {
        let frameCount = 2048
        
        // Establish some history
        let buffer1 = createAudioBuffer(frameCount: frameCount, frequency: 100, amplitude: 0.3)
        let buffer2 = createAudioBuffer(frameCount: frameCount, frequency: 100, amplitude: 0.7)
        
        _ = detector.calculateBassFlux(from: buffer1)
        let fluxBefore = detector.calculateBassFlux(from: buffer2)
        
        // Reset and measure again
        detector.reset()
        _ = detector.calculateBassFlux(from: buffer1)
        let fluxAfter = detector.calculateBassFlux(from: buffer2)
        
        // After reset, flux should be similar (same signal transition)
        XCTAssertEqual(fluxBefore, fluxAfter, accuracy: 0.1)
    }
    
    // MARK: - Edge Cases
    
    func testCalculateFluxWithEmptyBuffer() {
        // Create minimal buffer
        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1)!
        buffer.frameLength = 1
        
        // Should not crash with very small buffer
        let flux = detector.calculateBassFlux(from: buffer)
        
        // With insufficient data, flux should be minimal
        XCTAssertEqual(flux, 0.0, accuracy: 0.01)
    }
    
    func testCalculateFluxWithMaxAmplitude() {
        let frameCount = 2048
        
        // Test with maximum amplitude signal
        let silentBuffer = createAudioBuffer(frameCount: frameCount, frequency: 0, amplitude: 0.0)
        _ = detector.calculateBassFlux(from: silentBuffer)
        
        let maxBuffer = createAudioBuffer(frameCount: frameCount, frequency: 100, amplitude: 1.0)
        let flux = detector.calculateBassFlux(from: maxBuffer)
        
        // Should handle max amplitude without issues
        XCTAssertGreaterThan(flux, 0.0)
        XCTAssertLessThanOrEqual(flux, 1.0)
    }
    
    func testMultipleSequentialCalculations() {
        let frameCount = 2048
        
        // Simulate multiple sequential frames
        for i in 0..<10 {
            let amplitude = Double(i) / 10.0
            let buffer = createAudioBuffer(frameCount: frameCount, frequency: 100, amplitude: amplitude)
            let flux = detector.calculateBassFlux(from: buffer)
            
            // Each calculation should return valid flux
            XCTAssertGreaterThanOrEqual(flux, 0.0)
            XCTAssertLessThanOrEqual(flux, 1.0)
        }
    }
    
    // MARK: - Bass Range Isolation Tests
    
    func testBassRangeIsolation() {
        let frameCount = 2048
        
        // Create mixed frequency buffer (bass + treble)
        // We'll test that bass dominates
        
        detector.reset()
        let silentBuffer = createAudioBuffer(frameCount: frameCount, frequency: 0, amplitude: 0.0)
        _ = detector.calculateBassFlux(from: silentBuffer)
        
        // Bass-heavy signal (100 Hz)
        let bassBuffer = createAudioBuffer(frameCount: frameCount, frequency: 100, amplitude: 0.7)
        let bassFlux = detector.calculateBassFlux(from: bassBuffer)
        
        detector.reset()
        _ = detector.calculateBassFlux(from: silentBuffer)
        
        // Treble signal (4000 Hz)
        let trebleBuffer = createAudioBuffer(frameCount: frameCount, frequency: 4000, amplitude: 0.7)
        let trebleFlux = detector.calculateBassFlux(from: trebleBuffer)
        
        // Bass should produce significantly more flux due to bass range isolation (0-1400 Hz)
        XCTAssertGreaterThan(bassFlux, trebleFlux)
    }
    
    // MARK: - Helper Methods
    
    /// Creates an audio buffer with a sine wave at specified frequency and amplitude
    private func createAudioBuffer(frameCount: Int, frequency: Double, amplitude: Double) -> AVAudioPCMBuffer {
        let sampleRate = 44100.0
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount))!
        buffer.frameLength = AVAudioFrameCount(frameCount)
        
        guard let channelData = buffer.floatChannelData?[0] else {
            return buffer
        }
        
        // Generate sine wave
        for i in 0..<frameCount {
            let time = Double(i) / sampleRate
            let value = Float(sin(2.0 * .pi * frequency * time) * amplitude)
            channelData[i] = value
        }
        
        return buffer
    }
}
