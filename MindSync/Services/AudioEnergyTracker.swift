import Foundation
import AVFoundation
import Accelerate
import Combine
import os.log

/// Service for real-time audio energy tracking using RMS calculation and spectral flux
/// Installs a tap on the audio engine's mixer node to calculate energy values
/// Supports both RMS (for general energy) and Spectral Flux (for cinematic mode beat detection)
final class AudioEnergyTracker {
    private let logger = Logger(subsystem: "com.mindsync", category: "AudioEnergyTracker")
    
    /// Publisher for real-time energy values (0.0 - 1.0)
    let energyPublisher = PassthroughSubject<Float, Never>()
    
    /// Publisher for spectral flux values (0.0 - 1.0) - bass-focused for cinematic mode
    let spectralFluxPublisher = PassthroughSubject<Float, Never>()
    
    private var mixerNode: AVAudioMixerNode?
    private var isTracking = false
    
    // Moving Average for smoothing
    private var averageEnergy: Float = 0.0
    private let smoothingFactor: Float = 0.95  // 95% old, 5% new
    private let bufferSize: AVAudioFrameCount = 4096
    
    /// Current energy value (0.0 - 1.0) - RMS-based
    @MainActor private(set) var currentEnergy: Float = 0.0
    
    /// Current spectral flux value (0.0 - 1.0) - bass-focused for cinematic mode
    @MainActor private(set) var currentSpectralFlux: Float = 0.0
    
    /// Spectral flux detector for bass isolation
    private let spectralFluxDetector: SpectralFluxDetector?
    
    /// Whether to use spectral flux instead of RMS for cinematic mode
    var useSpectralFlux: Bool = false
    
    init() {
        self.spectralFluxDetector = SpectralFluxDetector()
    }
    
    /// Starts tracking audio energy from the mixer node
    /// - Parameter mixerNode: The mixer node to install the tap on
    func startTracking(mixerNode: AVAudioMixerNode) {
        guard !isTracking else {
            logger.warning("AudioEnergyTracker is already tracking")
            return
        }
        
        self.mixerNode = mixerNode
        
        // Get the format from the mixer node's output
        let format = mixerNode.outputFormat(forBus: 0)
        
        // Reset state
        averageEnergy = 0.0
        currentEnergy = 0.0
        
        // Install tap on mixer node
        mixerNode.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, time in
            self?.processBuffer(buffer, timestamp: time)
        }
        
        isTracking = true
        logger.info("AudioEnergyTracker started tracking")
    }
    
    /// Stops tracking and removes the tap
    func stopTracking() {
        guard isTracking else { return }
        
        mixerNode?.removeTap(onBus: 0)
        mixerNode = nil
        isTracking = false
        
        // Reset state
        averageEnergy = 0.0
        currentEnergy = 0.0
        currentSpectralFlux = 0.0
        spectralFluxDetector?.reset()
        
        logger.info("AudioEnergyTracker stopped tracking")
    }
    
    /// Processes audio buffer to calculate RMS energy and/or spectral flux
    /// - Parameters:
    ///   - buffer: The audio buffer to process
    ///   - timestamp: The timestamp of the buffer
    private func processBuffer(_ buffer: AVAudioPCMBuffer, timestamp: AVAudioTime) {
        // Calculate RMS energy
        let rms = calculateRMS(from: buffer)
        
        // Apply moving average for smoothing
        if averageEnergy == 0.0 {
            // Initialize with first value
            averageEnergy = rms
        } else {
            averageEnergy = (averageEnergy * smoothingFactor) + (rms * (1.0 - smoothingFactor))
        }
        
        // Calculate spectral flux if detector is available
        var flux: Float = 0.0
        if let detector = spectralFluxDetector {
            flux = detector.calculateBassFlux(from: buffer)
        }
        
        // Update on main thread (audio callbacks run on audio thread)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Update current energy
            self.currentEnergy = averageEnergy
            self.currentSpectralFlux = flux
            
            // Publish appropriate value
            if self.useSpectralFlux {
                // Use spectral flux for cinematic mode (better beat detection)
                self.energyPublisher.send(flux)
                self.spectralFluxPublisher.send(flux)
            } else {
                // Use RMS for general energy tracking
                self.energyPublisher.send(averageEnergy)
            }
        }
    }
    
    /// Calculates RMS (Root Mean Square) energy from audio buffer
    /// - Parameter buffer: The audio buffer to process
    /// - Returns: Normalized RMS value (0.0 - 1.0)
    private func calculateRMS(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else {
            return 0.0
        }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        guard frameLength > 0, channelCount > 0 else {
            return 0.0
        }
        
        // Calculate RMS for all channels
        var sumOfSquares: Float = 0.0
        
        for channelIndex in 0..<channelCount {
            let channel = channelData[channelIndex]
            
            // Calculate sum of squares for this channel
            var channelSum: Float = 0.0
            vDSP_svesq(channel, 1, &channelSum, vDSP_Length(frameLength))
            
            sumOfSquares += channelSum
        }
        
        // Average across channels
        let meanSquare = sumOfSquares / Float(channelCount * frameLength)
        
        // RMS = sqrt(meanSquare)
        let rms = sqrt(meanSquare)
        
        // Normalize to 0.0 - 1.0 range
        // RMS values for normalized audio are typically in 0.0 - 1.0 range
        // but we clamp to ensure we stay within bounds
        return min(1.0, max(0.0, rms))
    }
    
    /// Whether tracking is currently active
    var isActive: Bool {
        return isTracking
    }
}

