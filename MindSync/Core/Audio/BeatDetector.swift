import Foundation
import Accelerate

/// Service for beat detection using FFT and Spectral Flux
final class BeatDetector {
    private let sampleRate: Double = 44100.0
    private let fftSize: Int = 2048
    private let hopSize: Int = 512
    
    // Reusable FFT setup to avoid creating/destroying on every frame
    private let fftSetup: FFTSetup
    private let log2n: vDSP_Length
    
    init() {
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            fatalError("Failed to create FFT setup with log2n=\(log2n). This may indicate insufficient memory or invalid FFT size.")
        }
        self.fftSetup = setup
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Detects beat positions in PCM data
    /// - Parameter samples: PCM samples (mono, 44.1kHz)
    /// - Returns: Array of timestamps in seconds for each beat
    /// - Note: For very long audio files (e.g., >30 minutes), this method may consume significant memory
    ///         as it processes the entire file and creates arrays (spectralFluxValues, beatTimestamps)
    ///         that scale with file length. Consider adding file length validation with user warnings
    ///         for extremely long files.
    func detectBeats(in samples: [Float]) async -> [TimeInterval] {
        // Capture needed properties for the detached task
        let sampleRate = self.sampleRate
        let fftSize = self.fftSize
        let hopSize = self.hopSize
        
        // Run on background queue to prevent blocking the main thread
        return await Task.detached(priority: .userInitiated) { [self] in
            var beatTimestamps: [TimeInterval] = []
            var previousMagnitude: [Float] = Array(repeating: 0, count: fftSize / 2)

            let frameCount = samples.count
            var frameIndex = 0
            
            // Calculate adaptive threshold based on spectral flux statistics
            var spectralFluxValues: [Float] = []

            while frameIndex + fftSize < frameCount {
                // Extract frame
                let frame = Array(samples[frameIndex..<frameIndex + fftSize])

                // Perform FFT
                let magnitude = self.performFFT(on: frame)

                // Calculate spectral flux
                var spectralFlux: Float = 0
                for i in 0..<min(magnitude.count, previousMagnitude.count) {
                    let diff = magnitude[i] - previousMagnitude[i]
                    if diff > 0 {
                        spectralFlux += diff
                    }
                }
                
                spectralFluxValues.append(spectralFlux)
                previousMagnitude = magnitude
                frameIndex += hopSize
            }
            
            // Calculate adaptive threshold using single-pass algorithm (mean + 0.5 * std deviation)
            var sum: Float = 0
            var sumOfSquares: Float = 0
            for flux in spectralFluxValues {
                sum += flux
                sumOfSquares += flux * flux
            }
            let count = Float(spectralFluxValues.count)
            let mean = sum / count
            let variance = (sumOfSquares / count) - (mean * mean)
            let stdDev = sqrt(max(0, variance)) // max(0, ...) to handle floating point errors
            let adaptiveThreshold = mean + 0.5 * stdDev
            
            // Detect beats using adaptive threshold
            frameIndex = 0
            var fluxIndex = 0
            while frameIndex + fftSize < frameCount {
                if fluxIndex < spectralFluxValues.count && spectralFluxValues[fluxIndex] > adaptiveThreshold {
                    let timestamp = Double(frameIndex) / sampleRate
                    beatTimestamps.append(timestamp)
                }
                frameIndex += hopSize
                fluxIndex += 1
            }

            return beatTimestamps
        }.value
    }

    /// Performs FFT on a frame
    private func performFFT(on frame: [Float]) -> [Float] {
        // Apply Hann window
        var windowed = frame
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // Create complex buffer
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)

        windowed.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexBuffer in
                vDSP_ctoz(complexBuffer, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
            }
        }

        // Perform FFT (using reusable setup)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Calculate magnitude
        var magnitude = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvabs(&splitComplex, 1, &magnitude, 1, vDSP_Length(fftSize / 2))

        return magnitude
    }
}
