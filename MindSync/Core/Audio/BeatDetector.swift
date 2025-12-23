import Foundation
import Accelerate

/// Service zur Beat-Erkennung mittels FFT und Spectral Flux
final class BeatDetector {
    private let sampleRate: Double = 44100.0
    private let fftSize: Int = 2048
    private let hopSize: Int = 512

    /// Erkennt Beat-Positionen in PCM-Daten
    /// - Parameter samples: PCM-Samples (mono, 44.1kHz)
    /// - Returns: Array von Zeitstempeln in Sekunden für jeden Beat
    func detectBeats(in samples: [Float]) -> [TimeInterval] {
        var beatTimestamps: [TimeInterval] = []
        var previousMagnitude: [Float] = Array(repeating: 0, count: fftSize / 2)

        let frameCount = samples.count
        var frameIndex = 0

        while frameIndex + fftSize < frameCount {
            // Extrahiere Frame
            let frame = Array(samples[frameIndex..<frameIndex + fftSize])

            // FFT durchführen
            let magnitude = performFFT(on: frame)

            // Spectral Flux berechnen
            var spectralFlux: Float = 0
            for i in 0..<min(magnitude.count, previousMagnitude.count) {
                let diff = magnitude[i] - previousMagnitude[i]
                if diff > 0 {
                    spectralFlux += diff
                }
            }

            // Beat-Threshold (adaptiv basierend auf Durchschnitt)
            let threshold: Float = 0.3
            if spectralFlux > threshold {
                let timestamp = Double(frameIndex) / sampleRate
                beatTimestamps.append(timestamp)
            }

            previousMagnitude = magnitude
            frameIndex += hopSize
        }

        return beatTimestamps
    }

    /// Führt FFT auf einem Frame durch
    private func performFFT(on frame: [Float]) -> [Float] {
        // Hann-Fenster anwenden
        var windowed = frame
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(frame, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // FFT vorbereiten
        let log2n = vDSP_Length(log2(Double(fftSize)))
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))

        defer {
            vDSP_destroy_fftsetup(fftSetup)
        }

        // Complex-Buffer erstellen
        var realp = [Float](repeating: 0, count: fftSize / 2)
        var imagp = [Float](repeating: 0, count: fftSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realp, imagp: &imagp)

        windowed.withUnsafeMutableBufferPointer { buffer in
            buffer.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexBuffer in
                vDSP_ctoz(complexBuffer, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
            }
        }

        // FFT ausführen
        vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        // Magnitude berechnen
        var magnitude = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvabs(&splitComplex, 1, &magnitude, 1, vDSP_Length(fftSize / 2))

        return magnitude
    }
}
