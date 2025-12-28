import Foundation
import CoreHaptics
import os.log

/// Result of finding the current event in a vibration script
struct CurrentVibrationEventResult {
    let event: VibrationEvent?
    let elapsed: TimeInterval
    let isComplete: Bool
}

/// Controller for vibration feedback synchronized with audio and light
@MainActor
final class VibrationController: NSObject {
    // MARK: - Properties
    
    private var hapticEngine: CHHapticEngine?
    private var hapticPlayer: CHHapticAdvancedPatternPlayer?
    private var currentScript: VibrationScript?
    private var scriptStartTime: Date?
    private var totalPauseDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    private var isPaused: Bool = false
    private var currentEventIndex: Int = 0
    private var precisionTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.mindsync.vibration", qos: .userInteractive)
    private let logger = Logger(subsystem: "com.mindsync", category: "VibrationController")
    
    // Transient haptics state
    private var lastTransientTime: TimeInterval = 0
    private let transientCooldown: TimeInterval = 0.05 // 50ms minimum between transients
    
    /// Audio latency offset from user preferences (in seconds)
    /// This value compensates for Bluetooth audio delay by delaying vibration output
    /// to ensure audio and vibration arrive at the user simultaneously
    var audioLatencyOffset: TimeInterval = 0.0
    
    /// AudioPlaybackService reference for precise audio-thread timing (optional)
    /// When set, findCurrentEvent() uses preciseAudioTime instead of Date() for synchronization
    weak var audioPlayback: AudioPlaybackService?
    
    /// Optional callback invoked when engine restart fails after a reset
    var onRestartFailure: ((Error) -> Void)?
    
    // MARK: - Precision Timer Management
    
    @MainActor
    private func setupPrecisionTimer(handler: @escaping @MainActor () -> Void) {
        invalidatePrecisionTimer()
        
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: .nanoseconds(4_000_000))
        timer.setEventHandler {
            Task { @MainActor in
                handler()
            }
        }
        timer.resume()
        precisionTimer = timer
    }
    
    @MainActor
    private func invalidatePrecisionTimer() {
        precisionTimer?.cancel()
        precisionTimer = nil
    }
    
    // MARK: - Haptic Engine Management
    
    func start() async throws {
        logger.info("VibrationController.start() called")
        // Check if device supports haptics
        let capabilities = CHHapticEngine.capabilitiesForHardware()
        logger.info("Haptic capabilities: supportsHaptics=\(capabilities.supportsHaptics), supportsAudio=\(capabilities.supportsAudio)")

        guard capabilities.supportsHaptics else {
            logger.error("Device does not support haptics")
            throw VibrationError.hapticsUnavailable
        }

        logger.info("Device supports haptics, proceeding with engine creation")
        
        // Create and configure haptic engine
        do {
            let engine = try CHHapticEngine()
            
            // Handle engine reset (e.g., when app goes to background)
            engine.resetHandler = { [weak self] in
                Task { @MainActor in
                    self?.logger.warning("Haptic engine reset")
                    // Restart engine with proper error handling
                    do {
                        try await self?.restartEngine()
                    } catch {
                        self?.logger.error("Failed to restart haptic engine after reset: \(error.localizedDescription, privacy: .public)")
                        if let self = self, let failureCallback = self.onRestartFailure {
                            failureCallback(error)
                        }
                    }
                }
            }
            
            // Handle engine stopped (e.g., audio interruption)
            engine.stoppedHandler = { [weak self] reason in
                Task { @MainActor in
                    self?.logger.warning("Haptic engine stopped: \(reason.rawValue)")
                }
            }
            
            // Start the engine
            try await engine.start()
            self.hapticEngine = engine
        } catch {
            logger.error("Failed to create haptic engine: \(error.localizedDescription, privacy: .public)")
            throw VibrationError.engineCreationFailed
        }
    }
    
    func stop() {
        stopCurrentPattern()
        hapticEngine?.stop()
        hapticEngine = nil
        cancelExecution()
    }
    
    private func restartEngine() async throws {
        guard let engine = hapticEngine else { return }
        try await engine.start()
    }
    
    // MARK: - Script Execution
    
    func execute(script: VibrationScript, syncedTo startTime: Date) {
        currentScript = script
        scriptStartTime = startTime
        currentEventIndex = 0
        totalPauseDuration = 0
        pauseStartTime = nil
        isPaused = false
        
        setupPrecisionTimer { [weak self] in
            self?.updateVibration()
        }
    }
    
    func cancelExecution() {
        invalidatePrecisionTimer()
        stopCurrentPattern()
        currentScript = nil
        scriptStartTime = nil
        currentEventIndex = 0
        totalPauseDuration = 0
        pauseStartTime = nil
        isPaused = false
    }
    
    func pauseExecution() {
        guard !isPaused else { return }
        isPaused = true
        pauseStartTime = Date()
        invalidatePrecisionTimer()
        stopCurrentPattern()
    }
    
    func resumeExecution() {
        guard isPaused, let pauseStart = pauseStartTime else { return }
        isPaused = false
        totalPauseDuration += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
        
        setupPrecisionTimer { [weak self] in
            self?.updateVibration()
        }
    }
    
    // MARK: - Vibration Update
    
    fileprivate func updateVibration() {
        let result = findCurrentEvent()
        
        if result.isComplete {
            cancelExecution()
            return
        }
        
        if let event = result.event, let script = currentScript {
            // Calculate intensity based on waveform and elapsed time within event
            // Use target frequency for frequency-based timing (same as FlashlightController)
            let intensity = calculateIntensity(
                for: event,
                elapsed: result.elapsed,
                targetFrequency: script.targetFrequency
            )
            
            // Use transient haptics for square waves (sharp, percussive beats)
            // Use continuous haptics for sine/triangle waves (smooth pulsation)
            if event.waveform == .square && intensity > 0.1 {
                setTransientIntensity(intensity, at: result.elapsed)
            } else {
                setIntensity(intensity)
            }
        } else {
            // Between events, turn off vibration
            setIntensity(0.0)
        }
    }
    
    // MARK: - Intensity Calculation
    
    private func calculateIntensity(for event: VibrationEvent, elapsed: TimeInterval, targetFrequency: Double) -> Float {
        let eventElapsed = elapsed - event.timestamp
        
        guard eventElapsed >= 0 && eventElapsed <= event.duration else {
            return 0.0
        }
        
        // Use centralized WaveformGenerator for consistency
        return WaveformGenerator.calculateVibrationIntensity(
            waveform: event.waveform,
            time: eventElapsed,
            frequency: targetFrequency,
            baseIntensity: event.intensity
        )
    }
    
    // MARK: - Haptic Pattern Generation
    
    /// Sets transient haptic intensity for square wave events
    /// Creates short, sharp haptic impulses (20ms) for percussive beats
    private func setTransientIntensity(_ intensity: Float, at time: TimeInterval) {
        guard let engine = hapticEngine else { return }
        
        // Cooldown: prevent too many transients in quick succession
        // Note: Uses session elapsed time which may jump on pause/resume; this is acceptable
        // as cooldown is primarily for preventing haptic overload, not precise timing
        guard time - lastTransientTime >= transientCooldown else {
            return
        }
        
        let clampedIntensity = max(0.0, min(1.0, intensity))
        
        // Create transient event (short, sharp impulse)
        let hapticEvent = CHHapticEvent(
            eventType: .hapticTransient,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: clampedIntensity),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8) // High sharpness for crisp feel
            ],
            relativeTime: 0,
            duration: 0.02 // 20ms impulse as recommended in plan
        )
        
        do {
            let pattern = try CHHapticPattern(events: [hapticEvent], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            try player.start(atTime: 0)
            
            // Update last transient time
            lastTransientTime = time
            
            logger.debug("Transient haptic triggered: intensity=\(clampedIntensity)")
        } catch {
            logger.error("Failed to create transient haptic: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func setIntensity(_ intensity: Float) {
        guard hapticEngine != nil else { return }
        
        let clampedIntensity = max(0.0, min(1.0, intensity))
        
        // Stop current pattern if intensity is zero
        if clampedIntensity <= 0.0 {
            stopCurrentPattern()
            return
        }
        
        // If we already have a pattern playing, update it
        // Otherwise create a new continuous pattern
        if hapticPlayer == nil {
            createContinuousPattern(intensity: clampedIntensity)
        } else {
            // Update intensity of current pattern
            updatePatternIntensity(clampedIntensity)
        }
    }
    
    private func createContinuousPattern(intensity: Float) {
        guard let engine = hapticEngine else {
            self.logger.warning("Cannot create haptic pattern: engine is nil")
            return
        }

        logger.debug("Creating haptic pattern with intensity: \(intensity)")

        // Create a continuous haptic event with the specified intensity
        // Use longer duration (1.0s) with loopEnabled = true so the pattern continues
        // between display-link updates, preventing gaps if updates are delayed
        let hapticEvent = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(intensity)),
                CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
            ],
            relativeTime: 0,
            duration: 1.0 // Longer duration with loop enabled prevents gaps
        )

        do {
            let pattern = try CHHapticPattern(events: [hapticEvent], parameters: [])
            let player = try engine.makeAdvancedPlayer(with: pattern)
            player.loopEnabled = true // Enable looping so pattern continues between updates
            try player.start(atTime: 0)
            hapticPlayer = player
            logger.debug("Haptic pattern started successfully")
        } catch {
            logger.error("Failed to create haptic pattern: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func updatePatternIntensity(_ intensity: Float) {
        guard let player = hapticPlayer else { return }
        
        do {
            // Update intensity parameter
            try player.sendParameters(
                [
                    CHHapticDynamicParameter(parameterID: .hapticIntensityControl, value: intensity, relativeTime: 0)
                ],
                atTime: 0
            )
        } catch {
            logger.error("Failed to update haptic pattern intensity: \(error.localizedDescription, privacy: .public)")
            // If update fails, stop and recreate
            stopCurrentPattern()
            createContinuousPattern(intensity: intensity)
        }
    }
    
    private func stopCurrentPattern() {
        do {
            try hapticPlayer?.stop(atTime: 0)
        } catch {
            logger.error("Failed to stop haptic pattern: \(error.localizedDescription, privacy: .public)")
        }
        hapticPlayer = nil
    }
    
    // MARK: - Event Finding
    
    private func findCurrentEvent() -> CurrentVibrationEventResult {
        guard let script = currentScript,
              let startTime = scriptStartTime else {
            return CurrentVibrationEventResult(event: nil, elapsed: 0, isComplete: false)
        }
        
        // Use precise audio time if available (audio-thread accurate), otherwise fall back to Date()
        // This eliminates drift between audio and display threads
        let currentTime: TimeInterval
        if let audioPlayback = audioPlayback, audioPlayback.isPlaying {
            // Use audio-thread precise timing
            currentTime = audioPlayback.preciseAudioTime
        } else {
            // Fallback to Date() timing (e.g., during pause or before audio starts)
            currentTime = Date().timeIntervalSince(startTime) - totalPauseDuration
        }
        
        // Apply audio latency compensation: Delay vibration to match audio arrival time
        // Formula: adjustedTime = currentTime - audioLatencyOffset
        // Example: If audio has 200ms delay and player is at 10.2s,
        //          the user hears 10.0s, so we trigger vibration for 10.0s
        let adjustedElapsed = currentTime - audioLatencyOffset
        
        // Safety: Don't go negative (at start of session before latency compensation kicks in)
        guard adjustedElapsed >= 0 else {
            return CurrentVibrationEventResult(event: nil, elapsed: 0, isComplete: false)
        }
        
        // Check if script is finished (use adjusted time)
        if adjustedElapsed >= script.duration {
            return CurrentVibrationEventResult(event: nil, elapsed: adjustedElapsed, isComplete: true)
        }
        
        // Skip past events to find current event using index tracking
        var foundEventIndex = currentEventIndex
        while foundEventIndex < script.events.count {
            let event = script.events[foundEventIndex]
            let eventEnd = event.timestamp + event.duration
            
            if adjustedElapsed < eventEnd {
                if adjustedElapsed >= event.timestamp {
                    // Current event is active
                    currentEventIndex = foundEventIndex
                    return CurrentVibrationEventResult(event: event, elapsed: adjustedElapsed, isComplete: false)
                } else {
                    // Between events
                    return CurrentVibrationEventResult(event: nil, elapsed: adjustedElapsed, isComplete: false)
                }
            } else {
                // Move to next event
                foundEventIndex += 1
            }
        }
        
        // Passed all events
        return CurrentVibrationEventResult(event: nil, elapsed: adjustedElapsed, isComplete: true)
    }
}

// MARK: - Vibration Errors

enum VibrationError: Error {
    case hapticsUnavailable
    case engineCreationFailed
}

extension VibrationError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .hapticsUnavailable:
            return NSLocalizedString("error.vibration.hapticsUnavailable", comment: "")
        case .engineCreationFailed:
            return NSLocalizedString("error.vibration.engineCreationFailed", comment: "")
        }
    }
}
