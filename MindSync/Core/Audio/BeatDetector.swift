import Foundation
import Accelerate

/// Service zur Beat-Erkennung mittels FFT und Spectral Flux
final class BeatDetector {
    private let sampleRate: Double = 44100.0
    private let fftSize: Int = 2048
    private let hopSize: Int = 512
    
    // Reusable FFT setup to avoid creating/destroying on every frame
    private let fftSetup: FFTSetup
    private let log2n: vDSP_Length
    
    init() {
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        self.fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    }
    
    deinit {
        vDSP_destroy_fftsetup(fftSetup)
    }

    /// Erkennt Beat-Positionen in PCM-Daten
    /// - Parameter samples: PCM-Samples (mono, 44.1kHz)
    /// - Returns: Array von Zeitstempeln in Sekunden für jeden Beat
    func detectBeats(in samples: [Float]) async -> [TimeInterval] {
        // Run on background queue to prevent blocking the main thread
        return await Task.detached(priority: .userInitiated) { [self] in
            var beatTimestamps: [TimeInterval] = []
            var previousMagnitude: [Float] = Array(repeating: 0, count: self.fftSize / 2)

            let frameCount = samples.count
            var frameIndex = 0
            
            // Calculate adaptive threshold based on spectral flux statistics
            var spectralFluxValues: [Float] = []

            while frameIndex + self.fftSize < frameCount {
                // Extrahiere Frame
                let frame = Array(samples[frameIndex..<frameIndex + self.fftSize])

                // FFT durchführen
                let magnitude = self.performFFT(on: frame)

                // Spectral Flux berechnen
                var spectralFlux: Float = 0
                for i in 0..<min(magnitude.count, previousMagnitude.count) {
                    let diff = magnitude[i] - previousMagnitude[i]
                    if diff > 0 {
                        spectralFlux += diff
                    }
                }
                
                spectralFluxValues.append(spectralFlux)
                previousMagnitude = magnitude
                frameIndex += self.hopSize
            }
            
            // Calculate adaptive threshold (mean + 0.5 * std deviation)
            let mean = spectralFluxValues.reduce(0, +) / Float(spectralFluxValues.count)
            let variance = spectralFluxValues.map { pow($0 - mean, 2) }.reduce(0, +) / Float(spectralFluxValues.count)
            let stdDev = sqrt(variance)
            let adaptiveThreshold = mean + 0.5 * stdDev
            
            // Detect beats using adaptive threshold
            frameIndex = 0
            var fluxIndex = 0
            while frameIndex + self.fftSize < frameCount {
                if fluxIndex < spectralFluxValues.count && spectralFluxValues[fluxIndex] > adaptiveThreshold {
                    let timestamp = Double(frameIndex) / self.sampleRate
                    beatTimestamps.append(timestamp)
                }
                frameIndex += self.hopSize
                fluxIndex += 1
            }

            return beatTimestamps
        }.value
    }

    /// Führt FFT auf einem Frame durch
    private func performFFT(on frame: [Float]) -> [Float] {
        // Hann-Fenster anwenden
        var windowed = frame
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // Complex-Buffer erstellen
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)

        windowed.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexBuffer in
                vDSP_ctoz(complexBuffer, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
            }
        }

        // FFT ausführen (using reusable setup)
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Magnitude berechnen
        var magnitude = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvabs(&splitComplex, 1, &magnitude, 1, vDSP_Length(fftSize / 2))

        return magnitude
    }
}
