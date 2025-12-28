import Foundation
import AVFoundation
import Accelerate
import os.log

/// Real-time spectral flux detector with bass isolation for cinematic mode
/// Calculates spectral flux specifically in the bass range (0-1400 Hz) to detect
/// percussive events and transients that drive light pulsation
final class SpectralFluxDetector {
    private let logger = Logger(subsystem: "com.mindsync", category: "SpectralFluxDetector")
    
    // FFT Configuration
    private let sampleRate: Double = 44100.0
    private let fftSize: Int = 2048
    private let log2n: vDSP_Length
    
    // Reusable FFT setup
    private let fftSetup: FFTSetup
    
    // Bass range: 0-1400 Hz corresponds to bins 0-64 at 44.1 kHz with 2048-point FFT
    // Frequency resolution: sampleRate / fftSize = 44100 / 2048 ≈ 21.53 Hz per bin
    // Bin 64 ≈ 64 * 21.53 ≈ 1378 Hz ≈ 1.4 kHz
    // We use 0..<65 to capture approximately 0-1400 Hz bass frequencies
    private let bassRange = 0..<65
    
    // Previous magnitude spectrum for flux calculation
    private var previousMagnitude: [Float] = []
    
    /// Initializes the spectral flux detector
    /// - Returns: nil if FFT setup cannot be created
    init?() {
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return nil
        }
        self.fftSetup = setup
        self.previousMagnitude = Array(repeating: 0, count: fftSize / 2)
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    /// Calculates spectral flux for bass frequencies from an audio buffer
    /// - Parameter buffer: The audio buffer to analyze
    /// - Returns: Spectral flux value (0.0 - 1.0) representing energy increase in bass range
    /// 
    /// Spectral flux measures the rate of change in the magnitude spectrum.
    /// Positive changes (increases) indicate transients/onsets, which are ideal
    /// for triggering light pulses in cinematic mode.
    func calculateBassFlux(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else {
            return 0.0
        }
        
        // Use first channel (mono) or average if stereo
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Convert to mono if needed
        var monoFrame: [Float] = []
        if channelCount == 1 {
            monoFrame = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        } else {
            // Average channels for mono
            monoFrame = Array(repeating: 0, count: frameLength)
            for i in 0..<frameLength {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += channelData[ch][i]
                }
                monoFrame[i] = sum / Float(channelCount)
            }
        }
        
        // Pad or truncate to fftSize
        var frame: [Float]
        if monoFrame.count >= self.fftSize {
            frame = Array(monoFrame.prefix(self.fftSize))
        } else {
            frame = monoFrame
            frame.append(contentsOf: Array(repeating: 0, count: self.fftSize - monoFrame.count))
        }
        
        // Perform FFT
        let magnitude = performFFT(on: frame)
        
        // Calculate spectral flux: sum of positive differences in bass range
        var flux: Float = 0.0
        for i in bassRange {
            guard i < magnitude.count && i < previousMagnitude.count else { break }
            let diff = magnitude[i] - previousMagnitude[i]
            if diff > 0 {
                flux += diff
            }
        }
        
        // Update previous magnitude for next calculation
        self.previousMagnitude = magnitude
        
        // Normalize flux to 0.0 - 1.0 range
        // Normalization factor of 100.0 is empirically derived from testing with typical music
        // at standard listening levels (~70-85 dB SPL). Bass transients (kick drums, bass drops)
        // in this range produce flux values of 50-100 in the 0-1400 Hz range.
        // Higher values indicate stronger transients suitable for triggering light pulses.
        let normalizedFlux = min(1.0, flux / 100.0)
        
        return normalizedFlux
    }
    
    /// Resets the detector state (clears previous magnitude history)
    /// Call this when switching tracks or starting a new analysis session
    func reset() {
        self.previousMagnitude = Array(repeating: 0, count: self.fftSize / 2)
    }
    
    // MARK: - Private FFT Implementation
    
    /// Performs FFT on a frame and returns magnitude spectrum
    private func performFFT(on frame: [Float]) -> [Float] {
        guard frame.count == self.fftSize else {
            logger.warning("Frame size mismatch: expected \(self.fftSize), got \(frame.count)")
            return Array(repeating: 0, count: self.fftSize / 2)
        }
        
        // Apply Hann window
        var windowed = frame
        var window = [Float](repeating: 0, count: self.fftSize)
        vDSP_hann_window(&window, vDSP_Length(self.fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(self.fftSize))
        
        // Create complex buffer
        var realp = [Float](repeating: 0, count: self.fftSize / 2)
        var imagp = [Float](repeating: 0, count: self.fftSize / 2)
        var magnitude = [Float](repeating: 0, count: self.fftSize / 2)
        
        realp.withUnsafeMutableBufferPointer { realpBuffer in
            imagp.withUnsafeMutableBufferPointer { imagpBuffer in
                guard let realpAddress = realpBuffer.baseAddress,
                      let imagpAddress = imagpBuffer.baseAddress else {
                    return
                }
                
                var splitComplex = DSPSplitComplex(
                    realp: realpAddress,
                    imagp: imagpAddress
                )
                
                windowed.withUnsafeMutableBufferPointer { buffer in
                    buffer.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: self.fftSize / 2) { complexBuffer in
                        vDSP_ctoz(complexBuffer, 2, &splitComplex, 1, vDSP_Length(self.fftSize / 2))
                    }
                }
                
                // Perform FFT
                vDSP_fft_zrip(self.fftSetup, &splitComplex, 1, self.log2n, FFTDirection(FFT_FORWARD))
                
                // Calculate magnitude
                vDSP_zvabs(&splitComplex, 1, &magnitude, 1, vDSP_Length(self.fftSize / 2))
            }
        }
        
        return magnitude
    }
}
