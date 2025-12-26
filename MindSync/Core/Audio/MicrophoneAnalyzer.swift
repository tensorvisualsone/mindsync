import Foundation
import AVFoundation
import Combine
import Accelerate
import os.log



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
    
    // Moving Average für dynamischen Threshold (wie von Gemini empfohlen)
    private var averageEnergy: Float = 0.0
    private let smoothingFactor: Float = 0.95 // 95% alt, 5% neu
    private let thresholdMultiplier: Float = 1.4 // Dynamischer Threshold = averageEnergy * 1.4
    
    // Counter for throttling signal level updates
    private var signalEmissionCounter: Int = 0
    private let signalEmissionInterval: Int = 4 // Emit every ~4th frame (approx 20Hz)
    
    // Publishers
    let beatEventPublisher = PassthroughSubject<TimeInterval, Never>()
    let bpmPublisher = PassthroughSubject<Double, Never>()
    let signalLevelPublisher = PassthroughSubject<Float, Never>()
    
    // Services
    private let tempoEstimator = TempoEstimator()
    private let logger = Logger(subsystem: "com.mindsync", category: "MicrophoneAnalyzer")
    
    // State
    private var isRunning = false
    private var hasPermission = false
    private var noiseFloor: Float = 0.005
    private let noiseFloorSmoothing: Float = 0.005
    private let noiseCompensationFactor: Float = 6.0
    private let levelNormalizationFactor: Float = 12.0
    
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
        let permissionStatus = await AVAudioApplication.requestRecordPermission()
        guard permissionStatus else {
            logger.error("Microphone permission denied")
            throw MicrophoneError.permissionDenied
        }
        
        hasPermission = true
        
        // Configure audio session and start engine with proper error cleanup
        let audioSession = AVAudioSession.sharedInstance()
        var tapInstalled = false
        let inputNode = audioEngine.inputNode
        
        do {
            // Configure audio session
            try audioSession.setCategory(.record, mode: .measurement, options: [])
            try audioSession.setActive(true)
            
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
            tapInstalled = true
            
            // Start audio engine
            try audioEngine.start()
        } catch {
            // Clean up resources on failure
            if tapInstalled {
                inputNode.removeTap(onBus: 0)
            }
            
            if audioEngine.isRunning {
                audioEngine.stop()
            }
            
            // Best-effort deactivation of audio session on failure
            try? audioSession.setActive(false)
            
            logger.error("Failed to start microphone analysis: \(String(describing: error), privacy: .public)")
            throw error
        }
        
        isRunning = true
        startTime = Date()
        frameIndex = 0
        beatTimestamps.removeAll()
        spectralFluxValues.removeAll()
        lastBeatTime = 0
        averageEnergy = 0.0 // Reset Moving Average
        noiseFloor = 0.005
        
        logger.info("Microphone analysis started")
    }
    
    /// Stops microphone analysis
    func stop() {
        guard isRunning else { return }
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false)
        } catch {
            logger.error("Failed to deactivate AVAudioSession in MicrophoneAnalyzer.stop(): \(error.localizedDescription, privacy: .public)")
        }
        
        isRunning = false
        startTime = nil
        signalEmissionCounter = 0 // Reset counter for next session
        
        logger.info("Microphone analysis stopped")
    }
    
    /// Processes audio buffer for beat detection
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, timestamp: AVAudioTime) {
        guard isRunning,
              let channelData = buffer.floatChannelData else {
            return
        }
        
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Convert to mono by averaging all channels (non-interleaved layout)
        var monoBuffer: [Float]
        if channelCount == 1 {
            // Single-channel audio: just copy the only channel
            let channel = channelData[0]
            monoBuffer = Array(UnsafeBufferPointer(start: channel, count: frameCount))
        } else {
            // Multi-channel audio: average all channels sample-wise into mono
            monoBuffer = [Float](repeating: 0, count: frameCount)
            for channelIndex in 0..<channelCount {
                let channel = channelData[channelIndex]
                for frame in 0..<frameCount {
                    monoBuffer[frame] += channel[frame]
                }
            }
            let scale = 1.0 / Float(channelCount)
            vDSP_vsmul(monoBuffer, 1, [scale], &monoBuffer, 1, vDSP_Length(frameCount))
        }
        
        // Process frames in chunks of fftSize
        // Note: Partial frames at the end are intentionally skipped because FFT
        // requires complete frames of size fftSize for accurate frequency analysis.
        // Incomplete frames would produce invalid spectral data. The next buffer
        // will contain new audio data including samples that would have been in
        // the incomplete frame.
        var bufferIndex = 0
        while bufferIndex + fftSize <= monoBuffer.count {
            let frame = Array(monoBuffer[bufferIndex..<bufferIndex + fftSize])
            
            // Perform FFT
            let magnitude = performFFT(on: frame)
            
            let frameRMS = calculateRMS(frame)
            let normalizedLevel = min(1.0, max(0.0, frameRMS * levelNormalizationFactor))
            
            // Throttle signal level emission to reduce UI/processing load
            // At 44.1kHz with 512 hop size, we get ~86 frames/sec.
            // Emitting every 4th frame gives ~21 updates/sec, which is sufficient for UI and silence detection.
            signalEmissionCounter += 1
            if signalEmissionCounter >= signalEmissionInterval {
                signalLevelPublisher.send(normalizedLevel)
                signalEmissionCounter = 0
            }
            
            noiseFloor = (noiseFloor * (1.0 - noiseFloorSmoothing)) + (frameRMS * noiseFloorSmoothing)
            // NOTE: The noise floor smoothing factor (0.005) results in an adaptation time of ~2.3 seconds
            // to reach 63% of a new noise level (at 44.1kHz with 512-sample hop, ~86 frames/sec).
            // This slow adaptation helps distinguish between brief spikes and sustained environmental changes,
            // but may cause delays when transitioning between very different audio environments.
            
            // Calculate spectral flux
            var spectralFlux: Float = 0
            for i in 0..<min(magnitude.count, previousMagnitude.count) {
                let diff = magnitude[i] - previousMagnitude[i]
                if diff > 0 {
                    spectralFlux += diff
                }
            }
            
            let adjustedFlux = max(0, spectralFlux - (noiseFloor * noiseCompensationFactor))
            spectralFluxValues.append(adjustedFlux)
            
            // Limit spectral flux history to prevent unbounded memory growth
            // Keep last 1000 values (approximately 23 seconds at 512 hop size @ 44.1kHz)
            if spectralFluxValues.count > 1000 {
                spectralFluxValues.removeFirst()
            }
            
            previousMagnitude = magnitude
            
            // Moving Average für dynamischen Threshold (wie von Gemini empfohlen)
            // Der Threshold passt sich kontinuierlich an die aktuelle Lautstärke an
            averageEnergy = (averageEnergy * smoothingFactor) + (adjustedFlux * (1.0 - smoothingFactor))
            
            // Dynamischer Threshold basierend auf Moving Average
            // Funktioniert besser bei Songs, die leise anfangen und laut enden
            let dynamicThreshold = averageEnergy * thresholdMultiplier
            
            // Detect beats mit dynamischem Threshold
            if adjustedFlux > dynamicThreshold {
                let currentTime = Date().timeIntervalSince(startTime ?? Date())
                
                // Prevent duplicate beats (minimum interval: ~100ms)
                if currentTime - lastBeatTime > 0.1 {
                    beatTimestamps.append(currentTime)
                    
                    // Limit beat history to prevent unbounded memory growth.
                    // MicrophoneAnalyzer keeps 1000 timestamps for internal BPM estimation
                    // (covers ≈8-16 minutes at typical BPM rates), while SessionViewModel
                    // maintains a smaller rolling window (100 beats) optimized for
                    // light script generation and display.
                    if beatTimestamps.count > 1000 {
                        beatTimestamps.removeFirst()
                    }
                    
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
            
            bufferIndex += hopSize
            frameIndex += hopSize
        }
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
                guard let realpAddress = realpBuffer.baseAddress,
                      let imagpAddress = imagpBuffer.baseAddress else {
                    logger.error("Failed to get base addresses for FFT buffers")
                    return
                }
                
                var splitComplex = DSPSplitComplex(
                    realp: realpAddress,
                    imagp: imagpAddress
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
    
    private func calculateRMS(_ frame: [Float]) -> Float {
        var result: Float = 0
        vDSP_measqv(frame, 1, &result, vDSP_Length(frame.count))
        return sqrt(result)
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
            return NSLocalizedString("error.microphone.permissionDenied", comment: "Error shown when the user has denied microphone permission")
        case .unsupportedFormat:
            return NSLocalizedString("error.microphone.unsupportedFormat", comment: "Error shown when the microphone audio format is not supported")
        case .engineStartFailed:
            return NSLocalizedString("error.microphone.engineStartFailed", comment: "Error shown when the AVAudioEngine for microphone analysis fails to start")
        }
    }
}
