import Foundation
import CoreHaptics
import QuartzCore
import os.log

/// Result of finding the current event in a vibration script
struct CurrentVibrationEventResult {
    let event: VibrationEvent?
    let elapsed: TimeInterval
    let isComplete: Bool
}

/// Weak reference wrapper for CADisplayLink target to avoid retain cycles
private final class WeakVibrationDisplayLinkTarget {
    weak var target: VibrationController?
    
    init(target: VibrationController) {
        self.target = target
    }
    
    @objc func updateVibration() {
        // CADisplayLink runs on main run loop, so we can assume MainActor isolation
        MainActor.assumeIsolated {
            target?.updateVibration()
        }
    }
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
    private var displayLink: CADisplayLink?
    private var displayLinkTarget: WeakVibrationDisplayLinkTarget?
    private let logger = Logger(subsystem: "com.mindsync", category: "VibrationController")
    
    /// Optional callback invoked when engine restart fails after a reset
    var onRestartFailure: ((Error) -> Void)?
    
    // MARK: - Display Link Management
    
    @MainActor func setupDisplayLink(target: AnyObject, selector: Selector) {
        displayLink = CADisplayLink(target: target, selector: selector)
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: 120,
            preferred: 120
        )
        displayLink?.add(to: .main, forMode: .common)
    }
    
    func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - Haptic Engine Management
    
    func start() async throws {
        // Check if device supports haptics
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            throw VibrationError.hapticsUnavailable
        }
        
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
        
        // Setup display link for continuous updates
        let target = WeakVibrationDisplayLinkTarget(target: self)
        displayLinkTarget = target
        setupDisplayLink(target: target, selector: #selector(WeakVibrationDisplayLinkTarget.updateVibration))
    }
    
    func cancelExecution() {
        invalidateDisplayLink()
        displayLinkTarget = nil
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
        invalidateDisplayLink()
        stopCurrentPattern()
    }
    
    func resumeExecution() {
        guard isPaused, let pauseStart = pauseStartTime else { return }
        isPaused = false
        totalPauseDuration += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
        
        // Re-setup display link
        let target = WeakVibrationDisplayLinkTarget(target: self)
        displayLinkTarget = target
        setupDisplayLink(target: target, selector: #selector(WeakVibrationDisplayLinkTarget.updateVibration))
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
            setIntensity(intensity)
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
        
        let baseIntensity = event.intensity
        
        switch event.waveform {
        case .square:
            // Hard on/off
            return baseIntensity
            
        case .sine:
            // Smooth sine wave with frequency-based timing (same as FlashlightController)
            // Use the script's target frequency so pulsation rate is independent of event duration
            guard targetFrequency > 0 else {
                // Fallback: constant intensity if frequency is not valid
                return baseIntensity
            }
            let sineValue = sin(eventElapsed * 2.0 * .pi * targetFrequency)
            // Map sine value from [-1, 1] to [0, 1], then scale by intensity
            let normalizedSine = (sineValue + 1.0) / 2.0
            return baseIntensity * Float(normalizedSine)
            
        case .triangle:
            // Triangle wave based on absolute elapsed time, independent of event duration
            // One full cycle (0 -> 1 -> 0) per period based on target frequency for consistent timing
            guard targetFrequency > 0 else {
                // Fallback: constant intensity if frequency is not valid (to avoid division-by-zero)
                return baseIntensity
            }
            let period: TimeInterval = 1.0 / targetFrequency
            let phase = (eventElapsed.truncatingRemainder(dividingBy: period)) / period  // [0, 1)
            let triangleValue = phase < 0.5
                ? Float(phase * 2.0)              // 0 to 1
                : Float(2.0 - (phase * 2.0))      // 1 to 0
            return baseIntensity * triangleValue
        }
    }
    
    // MARK: - Haptic Pattern Generation
    
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
        guard let engine = hapticEngine else { return }
        
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
        
        // Calculate elapsed time accounting for pauses
        let realElapsed = Date().timeIntervalSince(startTime) - totalPauseDuration
        
        // Check if script is finished
        if realElapsed >= script.duration {
            return CurrentVibrationEventResult(event: nil, elapsed: realElapsed, isComplete: true)
        }
        
        // Skip past events to find current event using index tracking
        var foundEventIndex = currentEventIndex
        while foundEventIndex < script.events.count {
            let event = script.events[foundEventIndex]
            let eventEnd = event.timestamp + event.duration
            
            if realElapsed < eventEnd {
                if realElapsed >= event.timestamp {
                    // Current event is active
                    currentEventIndex = foundEventIndex
                    return CurrentVibrationEventResult(event: event, elapsed: realElapsed, isComplete: false)
                } else {
                    // Between events
                    return CurrentVibrationEventResult(event: nil, elapsed: realElapsed, isComplete: false)
                }
            } else {
                // Move to next event
                foundEventIndex += 1
            }
        }
        
        // Passed all events
        return CurrentVibrationEventResult(event: nil, elapsed: realElapsed, isComplete: true)
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

