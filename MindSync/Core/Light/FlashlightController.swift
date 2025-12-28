import Foundation
import AVFoundation
import os.log

extension Notification.Name {
    static let mindSyncTorchFailed = Notification.Name("com.mindsync.notifications.torchFailed")
}

/// Controller for flashlight control
@MainActor
final class FlashlightController: BaseLightController, LightControlling {
    var source: LightSource { .flashlight }

    private lazy var device: AVCaptureDevice? = {
        // Lazy initialization to avoid crashes during app startup
        // AVCaptureDevice.default can fail if called too early
        return AVCaptureDevice.default(for: .video)
    }()
    private var isLocked = false
    private let thermalManager: ThermalManager
    private let logger = Logger(subsystem: "com.mindsync", category: "FlashlightController")
    private var torchFailureNotified = false
    private let precisionInterval: DispatchTimeInterval = .nanoseconds(4_000_000) // ~250 Hz for crisp pulses
    private static let prewarmTorchLevel: Float = 0.01
    private static let prewarmPulseDurationNs: UInt64 = 50_000_000
    
    private enum DutyCycleConfig {
        static let highThreshold: Double = 30.0
        static let midThreshold: Double = 20.0
        static let lowThreshold: Double = 10.0
        static let gammaHighDuty: Double = 0.15
        static let gammaDuty: Double = 0.20
        static let alphaDuty: Double = 0.30
        static let thetaDuty: Double = 0.45
        static let minimumDutyFloor: Double = 0.05
    }

    init(thermalManager: ThermalManager) {
        self.thermalManager = thermalManager
        super.init()
        // Device is now lazy-initialized when first accessed
    }

    func start() async throws {
        logger.info("FlashlightController.start() called")
        guard let device = device else {
            logger.error("No AVCaptureDevice available for video")
            throw LightControlError.torchUnavailable
        }

        guard device.hasTorch else {
            logger.error("Device does not have torch capability")
            throw LightControlError.torchUnavailable
        }

        logger.info("Device has torch, proceeding with configuration")
        
        let attempts = 3
        var lastError: Error?
        
        for attempt in 1...attempts {
            do {
                try device.lockForConfiguration()
                isLocked = true
                torchFailureNotified = false
                return
            } catch {
                lastError = error
                logger.error("Torch lock failed (attempt \(attempt)/\(attempts)): \(error.localizedDescription, privacy: .public)")
                // Exponential backoff before retrying: 40ms, 80ms, 120ms for attempts 1-3
                if attempt < attempts {
                    try? await Task.sleep(nanoseconds: UInt64(0.04 * Double(attempt) * 1_000_000_000))
                }
            }
        }
        
        if let lastError {
            logger.error("All \(attempts) torch lock attempts failed. Last error: \(lastError.localizedDescription, privacy: .public)")
        }
        throw LightControlError.configurationFailed
    }

    func stop() {
        if let device = device, isLocked {
            device.torchMode = .off
            device.unlockForConfiguration()
            isLocked = false
        }
        torchFailureNotified = false
        cancelExecution()
    }
    
    /// Performs a brief torch activation to warm up the hardware and reduce cold-start latency.
    func prewarm() async throws {
        guard let device = device, device.hasTorch else { return }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            logger.info("Skipping flashlight prewarm because camera permission is not authorized")
            return
        }
        
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        try device.setTorchModeOn(level: Self.prewarmTorchLevel)
        try await Task.sleep(nanoseconds: Self.prewarmPulseDurationNs)
        device.torchMode = .off
    }

    func setIntensity(_ intensity: Float) {
        logger.debug("setIntensity called with \(intensity)")
        guard let device = device, isLocked else {
            logger.warning("setIntensity failed: device=\(self.device != nil), isLocked=\(self.isLocked)")
            return
        }

        if thermalManager.maxFlashlightIntensity <= 0 {
            logger.warning("Thermal manager blocking flashlight: maxIntensity=\(self.thermalManager.maxFlashlightIntensity)")
            handleTorchSystemShutdown(error: LightControlError.thermalShutdown)
            return
        }
        
        // Gamma 2.2 Korrektur für natürliche Wahrnehmung
        // Das menschliche Auge funktioniert logarithmisch, daher wirken 50% LED-Power
        // wie 70-80% Helligkeit. Die Gamma-Korrektur macht Fades weicher und organischer.
        let perceptionCorrected = pow(intensity, 2.2)
        
        // Apply thermal limits
        let maxIntensity = thermalManager.maxFlashlightIntensity
        let clampedIntensity = max(0.0, min(maxIntensity, perceptionCorrected))
        
        do {
            if clampedIntensity <= 0 {
                device.torchMode = .off
                logger.debug("Torch turned off (intensity <= 0)")
            } else {
                try device.setTorchModeOn(level: clampedIntensity)
                logger.debug("Torch set to intensity: \(clampedIntensity)")
            }
        } catch {
            logger.error("Failed to set torch intensity \(clampedIntensity): \(error.localizedDescription, privacy: .public)")
            handleTorchSystemShutdown(error: error)
        }
    }

    func setColor(_ color: LightEvent.LightColor) {
        // Flashlight does not support colors
    }

    func execute(script: LightScript, syncedTo startTime: Date) {
        initializeScriptExecution(script: script, startTime: startTime)

        setupPrecisionTimer(interval: precisionInterval) { [weak self] in
            self?.updateLight()
        }
    }

    func cancelExecution() {
        invalidatePrecisionTimer()
        resetScriptExecution()
        setIntensity(0.0)
    }
    
    func pauseExecution() {
        pauseScriptExecution()
        invalidatePrecisionTimer()
        setIntensity(0.0)
    }
    
    func resumeExecution() {
        guard let _ = currentScript, let _ = scriptStartTime else { return }
        resumeScriptExecution()
        setupPrecisionTimer(interval: precisionInterval) { [weak self] in
            self?.updateLight()
        }
    }

    fileprivate func updateLight() {
        let result = findCurrentEvent()
        
        if result.isComplete {
            cancelExecution()
            return
        }
        
        if let script = currentScript {
            // Check if cinematic mode - apply dynamic intensity modulation
            if script.mode == .cinematic {
                // For cinematic mode, use continuous wave regardless of events
                // This ensures smooth synchronization even if beat detection is imperfect
                let audioEnergy = audioEnergyTracker?.currentEnergy ?? 0.0
                let baseFreq = script.targetFrequency
                let elapsed = result.elapsed
                
                // Calculate cinematic intensity (continuous wave)
                let cinematicIntensity = EntrainmentEngine.calculateCinematicIntensity(
                    baseFrequency: baseFreq,
                    currentTime: elapsed,
                    audioEnergy: audioEnergy
                )
                
                // Use cinematic intensity directly (it already includes wave modulation)
                setIntensity(cinematicIntensity)
            } else if let event = result.event {
                // For other modes, use event-based intensity with waveform
                let timeWithinEvent = result.elapsed - event.timestamp
                
                // Apply waveform-based intensity modulation (similar to ScreenController)
                let intensity = calculateIntensity(
                    event: event,
                    timeWithinEvent: timeWithinEvent,
                    targetFrequency: script.targetFrequency
                )
                
                setIntensity(intensity)
            } else {
                // Between events or no active event, turn off
                setIntensity(0.0)
            }
        } else {
            // No script, turn off
            setIntensity(0.0)
        }
    }
    
    /// Calculates intensity based on waveform and time within event
    /// Uses WaveformGenerator for consistency, with frequency-dependent duty cycle for square wave
    private func calculateIntensity(
        event: LightEvent,
        timeWithinEvent: TimeInterval,
        targetFrequency: Double
    ) -> Float {
        // Calculate frequency-dependent duty cycle for square wave (FlashlightController-specific)
        let dutyCycle = calculateDutyCycle(for: targetFrequency)
        
        // Use centralized WaveformGenerator for consistency
        return WaveformGenerator.calculateIntensity(
            waveform: event.waveform,
            time: timeWithinEvent,
            frequency: targetFrequency,
            baseIntensity: event.intensity,
            dutyCycle: dutyCycle
        )
    }
    
    /// Calculates optimal duty cycle based on frequency to compensate for LED rise/fall times
    /// At high frequencies, the LED doesn't fully turn off between pulses, causing blur
    /// Reducing duty cycle creates sharper, more distinct flashes for better cortical evoked potentials
    private func calculateDutyCycle(for frequency: Double) -> Double {
        // High frequency (Gamma): Very short pulses for maximum crispness
        // The LED barely turns on, but the brain detects the rapid transitions
        let baseDuty: Double
        if frequency > DutyCycleConfig.highThreshold {
            baseDuty = DutyCycleConfig.gammaHighDuty  // 15% on for >30Hz
        } else if frequency > DutyCycleConfig.midThreshold {
            baseDuty = DutyCycleConfig.gammaDuty  // 20% on for 20-30Hz
        } else if frequency > DutyCycleConfig.lowThreshold {
            baseDuty = DutyCycleConfig.alphaDuty  // 30% on for 10-20Hz
        } else {
            // Low frequency (Theta): Standard pulse width
            // LED has time to fully turn on/off, no compensation needed
            baseDuty = DutyCycleConfig.thetaDuty  // 45% on, 55% off
        }

        let multiplier = thermalManager.recommendedDutyCycleMultiplier

        // Critical thermal state handling:
        // A non-positive multiplier indicates that the torch must be completely off
        // to protect the device. In this state we intentionally bypass the
        // `minimumDutyFloor` safety floor, because 0% duty is strictly safer than
        // any non-zero value.
        if multiplier <= 0 {
            return 0
        }

        let adjustedDuty = baseDuty * multiplier
        return max(adjustedDuty, DutyCycleConfig.minimumDutyFloor)
    }
    
    // MARK: - Helpers
    
    /// Handles torch system shutdown and notifies observers.
    ///
    /// This method is called when the torch fails during operation. The `torchFailureNotified` flag
    /// prevents duplicate notifications for the same failure event.
    ///
    /// - Parameter error: The error that caused the shutdown, if available.
    ///
    /// - Note: The `torchFailureNotified` flag is reset in two scenarios:
    ///   1. When `stop()` is called (user manually stops the session)
    ///   2. When `start()` succeeds (new session begins successfully)
    ///   This ensures that each new session can properly report torch failures, while preventing
    ///   duplicate notifications within a single session.
    ///
    /// - Note: Thread Safety
    ///   This method is isolated to the main actor (as is the entire `FlashlightController` class),
    ///   ensuring that all torch operations (`setIntensity`, `start`, `stop`) and flag access
    ///   happen on the main thread. This prevents race conditions on `torchFailureNotified` and
    ///   ensures safe interaction with asynchronous update timers.
    private func handleTorchSystemShutdown(error: Error?) {
        guard !torchFailureNotified else { return }
        torchFailureNotified = true
        
        if let error {
            logger.error("Torch shutdown detected: \(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("Torch shutdown detected without explicit error")
        }
        
        if let device = device, isLocked {
            device.torchMode = .off
            device.unlockForConfiguration()
            isLocked = false
        }
        
        cancelExecution()
        NotificationCenter.default.post(name: .mindSyncTorchFailed, object: error)
    }
}
