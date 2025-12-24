import Foundation
import AVFoundation
import Combine
import Accelerate
import os.log

@available(iOS 17.0, *)
extension AVAudioApplication {
    static func requestRecordPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

/// Service for real-time microphone audio analysis and beat detection
final class MicrophoneAnalyzer {
    private let audioEngine = AVAudioEngine()
    private let sampleRate: Double = 44100.0
    private let fftSize: Int = 2048
    private let hopSize: Int = 512
    
    // FFT setup for real-time analysis
    private let fftSetup: FFTSetup
    private let log2n: vDSP_Length
    
    // Beat detection state
    private var previousMagnitude: [Float] = []
    private var spectralFluxValues: [Float] = []
    private var beatTimestamps: [TimeInterval] = []
    private var lastBeatTime: TimeInterval = 0
    private var adaptiveThreshold: Float = 0.0
    private var frameIndex: Int = 0
    private var startTime: Date?
    
    // Publishers
    let beatEventPublisher = PassthroughSubject<TimeInterval, Never>()
    let bpmPublisher = PassthroughSubject<Double, Never>()
    
    // Services
    private let tempoEstimator = TempoEstimator()
    private let logger = Logger(subsystem: "com.mindsync", category: "MicrophoneAnalyzer")
    
    // State
    private var isRunning = false
    private var hasPermission = false
    
    init?() {
        // Initialize FFT setup
        self.log2n = vDSP_Length(log2(Double(fftSize)))
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            logger.error("Failed to create FFT setup for MicrophoneAnalyzer")
            return nil
        }
        self.fftSetup = setup
        self.previousMagnitude = Array(repeating: 0, count: fftSize / 2)
    }
    
    deinit {
        stop()
        vDSP_destroy_fftsetup(fftSetup)
    }
    
    /// Starts microphone analysis
    /// - Throws: Error if microphone permission is denied or setup fails
    func start() async throws {
        guard !isRunning else { return }
        
        // Check permission
        let audioSession = AVAudioSession.sharedInstance()
        let permissionStatus: Bool
        if #available(iOS 17.0, *) {
            permissionStatus = await AVAudioApplication.requestRecordPermission()
        } else {
            permissionStatus = await withCheckedContinuation { continuation in
                audioSession.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
        guard permissionStatus else {
            logger.error("Microphone permission denied")
            throw MicrophoneError.permissionDenied
        }
        
        hasPermission = true
        
        // Configure audio session
        try audioSession.setCategory(.record, mode: .measurement, options: [])
        try audioSession.setActive(true)
        
        // Get input node
        let inputNode = audioEngine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)
        
        // Validate sample rate (should be 44.1kHz or 48kHz)
        guard inputFormat.sampleRate >= 44100.0 else {
            logger.error("Unsupported sample rate: \(inputFormat.sampleRate)")
            throw MicrophoneError.unsupportedFormat
        }
        
        // Install tap on input node
        let bufferSize: AVAudioFrameCount = AVAudioFrameCount(hopSize)
        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, timestamp: time)
        }
        
        // Start audio engine
        try audioEngine.start()
        
        isRunning = true
        startTime = Date()
        frameIndex = 0
        beatTimestamps.removeAll()
        spectralFluxValues.removeAll()
        lastBeatTime = 0
        
        logger.info("Microphone analysis started")
    }
    
    /// Stops microphone analysis
    func stop() {
        guard isRunning else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        isRunning = false
        startTime = nil
        
        logger.info("Microphone analysis stopped")
    }
    
    /// Processes audio buffer for beat detection
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, timestamp: AVAudioTime) {
        guard isRunning,
              let channelData = buffer.floatChannelData else {
            return
        }
        
        let frameCount = Int(buffer.frameLength)
        let channel = channelData.pointee
        
        // Convert to mono if stereo
        var monoBuffer: [Float]
        if buffer.format.channelCount > 1 {
            monoBuffer = Array(UnsafeBufferPointer(start: channel, count: frameCount))
            // Average channels for mono (simplified - assumes interleaved)
            // For simplicity, we use the first channel
        } else {
            monoBuffer = Array(UnsafeBufferPointer(start: channel, count: frameCount))
        }
        
        // Process frames in chunks of fftSize
        var bufferIndex = 0
        while bufferIndex + fftSize <= monoBuffer.count {
            let frame = Array(monoBuffer[bufferIndex..<bufferIndex + fftSize])
            
            // Perform FFT
            let magnitude = performFFT(on: frame)
            
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
            
            // Calculate adaptive threshold after collecting some data
            if spectralFluxValues.count >= 50 {
                updateAdaptiveThreshold()
                
                // Detect beats
                if spectralFlux > adaptiveThreshold {
                    let currentTime = Date().timeIntervalSince(startTime ?? Date())
                    
                    // Prevent duplicate beats (minimum interval: ~100ms)
                    if currentTime - lastBeatTime > 0.1 {
                        beatTimestamps.append(currentTime)
                        lastBeatTime = currentTime
                        
                        // Publish beat event
                        beatEventPublisher.send(currentTime)
                        
                        // Update BPM estimate periodically
                        if beatTimestamps.count >= 10 {
                            let bpm = tempoEstimator.estimateBPM(from: beatTimestamps.suffix(20))
                            bpmPublisher.send(bpm)
                        }
                    }
                }
            }
            
            bufferIndex += hopSize
            frameIndex += hopSize
        }
    }
    
    /// Updates adaptive threshold based on recent spectral flux values
    private func updateAdaptiveThreshold() {
        guard spectralFluxValues.count >= 20 else { return }
        
        // Use last 50 values for threshold calculation
        let recentValues = Array(spectralFluxValues.suffix(50))
        
        var sum: Float = 0
        var sumOfSquares: Float = 0
        for flux in recentValues {
            sum += flux
            sumOfSquares += flux * flux
        }
        
        let count = Float(recentValues.count)
        let mean = sum / count
        let variance = (sumOfSquares / count) - (mean * mean)
        let stdDev = sqrt(max(0, variance))
        
        adaptiveThreshold = mean + 0.5 * stdDev
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
        var magnitude = [Float](repeating: 0, count: fftSize / 2)
        
        realp.withUnsafeMutableBufferPointer { realpBuffer in
            imagp.withUnsafeMutableBufferPointer { imagpBuffer in
                var splitComplex = DSPSplitComplex(
                    realp: realpBuffer.baseAddress!,
                    imagp: imagpBuffer.baseAddress!
                )
                
                windowed.withUnsafeMutableBufferPointer { buffer in
                    buffer.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexBuffer in
                        vDSP_ctoz(complexBuffer, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    }
                }
                
                // Perform FFT
                vDSP_fft_zrip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))
                
                // Calculate magnitude
                vDSP_zvabs(&splitComplex, 1, &magnitude, 1, vDSP_Length(fftSize / 2))
            }
        }
        
        return magnitude
    }
    
    /// Current estimated BPM
    var currentBPM: Double {
        guard beatTimestamps.count >= 2 else {
            return 120.0 // Default BPM
        }
        return tempoEstimator.estimateBPM(from: Array(beatTimestamps.suffix(20)))
    }
    
    /// Whether analysis is currently running
    var isActive: Bool {
        isRunning
    }
}

/// Errors for microphone analysis
enum MicrophoneError: LocalizedError {
    case permissionDenied
    case unsupportedFormat
    case engineStartFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Mikrofon-Berechtigung wurde verweigert"
        case .unsupportedFormat:
            return "Audioformat wird nicht unterstützt"
        case .engineStartFailed:
            return "Audio-Engine konnte nicht gestartet werden"
        }
    }
}
