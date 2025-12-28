import Foundation
import AVFoundation
import os.log

/// Proactive beat detector with lookahead buffer for real-time cinematic mode
/// Analyzes audio 300-500ms ahead to predict beats before they occur,
/// enabling proactive light control that synchronizes with audio transients
final class LookaheadBeatDetector {
    private let logger = Logger(subsystem: "com.mindsync", category: "LookaheadBeatDetector")
    
    /// Lookahead duration in seconds (300-500ms as recommended in plan)
    private let lookaheadDuration: TimeInterval = 0.4 // 400ms
    
    /// Sample rate (assumed 44.1kHz, will be updated from actual audio format)
    private var sampleRate: Double = 44100.0
    
    /// Lookahead buffer size in samples
    private var lookaheadSamples: Int {
        Int(lookaheadDuration * sampleRate)
    }
    
    /// Circular buffer for lookahead samples
    private var lookaheadBuffer: [Float] = []
    private var bufferWriteIndex: Int = 0
    private var isBufferReady: Bool = false
    
    /// Spectral flux detector for onset detection
    private let spectralFluxDetector: SpectralFluxDetector?
    
    /// Adaptive threshold for beat detection
    private var adaptiveThreshold: Float = 0.5
    private var fluxHistory: [Float] = []
    private let fluxHistorySize = 100 // Keep last 100 flux values for threshold calculation
    
    /// Callback for detected beats (called with predicted timestamp)
    var onBeatDetected: ((TimeInterval) -> Void)?
    
    /// Initializes the lookahead beat detector
    init() {
        self.spectralFluxDetector = SpectralFluxDetector()
        self.lookaheadBuffer = Array(repeating: 0, count: 8192) // Initial size, will resize
    }
    
    /// Updates the sample rate from audio format
    /// - Parameter format: The audio format being processed
    func updateSampleRate(from format: AVAudioFormat) {
        let newSampleRate = format.sampleRate
        if newSampleRate != sampleRate {
            sampleRate = newSampleRate
            // Resize buffer based on new sample rate
            let newBufferSize = max(8192, lookaheadSamples * 2) // 2x for safety
            lookaheadBuffer = Array(repeating: 0, count: newBufferSize)
            bufferWriteIndex = 0
            isBufferReady = false
            logger.info("Sample rate updated to \(newSampleRate)")
        }
    }
    
    /// Processes an audio buffer and detects beats with lookahead
    /// - Parameters:
    ///   - buffer: The audio buffer to process
    ///   - timestamp: The timestamp of the buffer (for beat timing)
    func processBuffer(_ buffer: AVAudioPCMBuffer, timestamp: AVAudioTime) {
        guard let detector = spectralFluxDetector else {
            logger.warning("SpectralFluxDetector not available")
            return
        }
        
        // Update sample rate if needed
        updateSampleRate(from: buffer.format)
        
        // Extract samples from buffer
        guard let channelData = buffer.floatChannelData,
              buffer.frameLength > 0 else {
            return
        }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Convert to mono
        var samples: [Float] = []
        if channelCount == 1 {
            samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
        } else {
            samples = Array(repeating: 0, count: frameLength)
            for i in 0..<frameLength {
                var sum: Float = 0
                for ch in 0..<channelCount {
                    sum += channelData[ch][i]
                }
                samples[i] = sum / Float(channelCount)
            }
        }
        
        // Add samples to lookahead buffer
        for sample in samples {
            lookaheadBuffer[bufferWriteIndex] = sample
            bufferWriteIndex = (bufferWriteIndex + 1) % lookaheadBuffer.count
            
            // Mark buffer as ready once we've filled at least one lookahead period
            if bufferWriteIndex >= lookaheadSamples {
                isBufferReady = true
            }
        }
        
        // Process lookahead window if buffer is ready
        guard isBufferReady else { return }
        
        // Extract lookahead window (samples ahead of current position)
        let lookaheadStart = bufferWriteIndex
        let lookaheadEnd = (bufferWriteIndex + lookaheadSamples) % lookaheadBuffer.count
        
        var lookaheadWindow: [Float] = []
        if lookaheadEnd > lookaheadStart {
            // Simple case: contiguous samples
            lookaheadWindow = Array(lookaheadBuffer[lookaheadStart..<lookaheadEnd])
        } else {
            // Wraparound case: need to concatenate
            lookaheadWindow = Array(lookaheadBuffer[lookaheadStart..<lookaheadBuffer.count])
            lookaheadWindow.append(contentsOf: Array(lookaheadBuffer[0..<lookaheadEnd]))
        }
        
        // Create a temporary buffer for spectral flux calculation
        // We need at least 2048 samples for FFT, so we pad if necessary
        var analysisWindow = lookaheadWindow
        if analysisWindow.count < 2048 {
            analysisWindow.append(contentsOf: Array(repeating: 0, count: 2048 - analysisWindow.count))
        } else if analysisWindow.count > 2048 {
            analysisWindow = Array(analysisWindow.prefix(2048))
        }
        
        // Create AVAudioPCMBuffer for spectral flux detector
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else {
            return
        }
        
        guard let tempBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(analysisWindow.count)) else {
            return
        }
        
        tempBuffer.frameLength = AVAudioFrameCount(analysisWindow.count)
        if let channelData = tempBuffer.floatChannelData {
            analysisWindow.withUnsafeBufferPointer { source in
                channelData[0].update(from: source.baseAddress!, count: analysisWindow.count)
            }
        }
        
        // Calculate spectral flux
        let flux = detector.calculateBassFlux(from: tempBuffer)
        
        // Update adaptive threshold
        fluxHistory.append(flux)
        if fluxHistory.count > fluxHistorySize {
            fluxHistory.removeFirst()
        }
        
        // Calculate threshold as mean + 0.5 * std deviation
        if fluxHistory.count >= 10 {
            let mean = fluxHistory.reduce(0, +) / Float(fluxHistory.count)
            let variance = fluxHistory.map { pow($0 - mean, 2) }.reduce(0, +) / Float(fluxHistory.count)
            let stdDev = sqrt(variance)
            adaptiveThreshold = mean + 0.5 * stdDev
        }
        
        // Detect beat if flux exceeds threshold
        if flux > self.adaptiveThreshold {
            // Calculate predicted timestamp (current + lookahead)
            let currentTime = Double(timestamp.sampleTime) / Double(timestamp.sampleRate)
            let predictedBeatTime = currentTime + lookaheadDuration
            
            // Notify callback
            onBeatDetected?(predictedBeatTime)
            
            logger.debug("Beat detected at predicted time: \(predictedBeatTime)s (flux: \(flux), threshold: \(self.adaptiveThreshold))")
        }
    }
    
    /// Resets the detector state
    func reset() {
        lookaheadBuffer = Array(repeating: 0, count: max(8192, lookaheadSamples * 2))
        bufferWriteIndex = 0
        isBufferReady = false
        fluxHistory.removeAll()
        adaptiveThreshold = 0.5
        spectralFluxDetector?.reset()
    }
}
