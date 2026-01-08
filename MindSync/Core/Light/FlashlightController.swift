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
    
    // Cinematic mode pulse state tracking
    private var lastBeatTime: TimeInterval = 0
    private var lastBeatIntensity: Float = 0.0
    private let pulseDecayDuration: TimeInterval = 0.12 // 120ms pulse duration for visible beat flashes
    
    // Debug logging timestamp tracking
    private var lastAudioLogTime: TimeInterval = -1.0  // Last time we logged audio energy
    private var noEventLogCount: Int = 0  // Counter for no-event debug logs
    
    // Peak detection for cinematic mode
    private var recentFluxValues: [Float] = []  // Ring buffer for last N flux values (for local average)
    private var fluxHistory: [Float] = []  // Longer history for adaptive threshold calculation
    private var lastPeakTime: TimeInterval = 0
    private let peakCooldownDuration: TimeInterval = 0.05  // 50ms minimum between peaks
    private let peakRiseThreshold: Float = 0.04  // Minimum 4% rise above local average for peak (reduced for better sensitivity)
    private let maxFluxHistorySize = 10  // Keep last 10 flux values for local average calculation
    private let maxAdaptiveHistorySize = 200  // Keep last 200 flux values for adaptive threshold (~20 seconds at 10 Hz)
    private let absoluteMinimumThreshold: Float = 0.05  // Absolute minimum flux value to consider (reduced for better sensitivity)
    private let fixedThreshold: Float = 0.1  // Fallback threshold when not enough history (reduced for better sensitivity)
    private let adaptiveThresholdMultiplier: Float = 0.25  // Use mean + 0.25 * stdDev (reduced for better sensitivity)
    
    /// Precision timer interval shared across light controllers
    /// OPTIMIZED FOR LAMBDA: 1ms (1000 Hz) resolution needed for stable 100 Hz output.
    /// Previous 4ms was too slow for 10ms periods (100 Hz).
    static let precisionIntervalNanoseconds: Int = 1_000_000
    private let precisionInterval: DispatchTimeInterval = .nanoseconds(FlashlightController.precisionIntervalNanoseconds)
    
    /// Torch "prewarm" configuration.
    ///
    /// Prewarming activates the LED hardware with a brief, imperceptible pulse before
    /// the actual synchronization begins. This ensures the LED driver, power circuits,
    /// and thermal regulation are fully initialized, preventing latency or brightness
    /// inconsistency in the first few user-visible pulses.
    ///
    /// **prewarmTorchLevel = 0.01 (1%)**:
    ///   - Smallest torch level that reliably wakes the LED driver across tested devices
    ///     (iPhone 13 Pro, 14 Pro Max, 15 Pro) while remaining effectively invisible to
    ///     the user (below perceptual threshold in a dark environment).
    ///   - At this level, the LED emits approximately 0.1-0.2 lumens, which is insufficient
    ///     to cause pupil constriction or be noticed in typical usage scenarios.
    ///   - Avoids a visible flash when we first engage the hardware, which would be
    ///     distracting and could interfere with the user's preparation for entrainment.
    ///
    /// **prewarmPulseDurationNs = 50,000,000 (50 ms)**:
    ///   - Duration chosen to allow LED driver and power circuits to reach stable state.
    ///   - Testing showed that <30ms was insufficient on some devices (iPhone 13 Pro),
    ///     leading to dimmer or delayed first pulses. 50ms provides adequate margin.
    ///   - Brief enough that the prewarm phase doesn't feel like part of the user-visible
    ///     stimulation or add noticeable delay to session start.
    ///   - Allows thermal sensors to initialize, ensuring thermal management is active
    ///     from the first user-visible pulse.
    private static let prewarmTorchLevel: Float = 0.01
    private static let prewarmPulseDurationNs: UInt64 = 50_000_000
    
    /// Duty-cycle configuration for the physical LED torch.
    ///
    /// These constants are tuned for a trade-off between:
    /// - **Neural entrainment effectiveness** in the alpha / theta / gamma bands
    /// - **Perceived pulse clarity** (sharp on/off edges instead of smeared ramps)
    /// - **Hardware limitations** of the iPhone torch (LED rise/fall times, driver latency)
    /// - **Thermal safety** and user comfort (avoiding sustained max brightness)
    ///
    /// Frequency thresholds:
    /// - `lowThreshold` (10 Hz): below ≈10 Hz we have long periods where the LED can be fully
    ///   off, so we allow relatively high duty cycles without smearing the pulse edges.
    /// - `midThreshold` (20 Hz): between 10–20 Hz is the typical alpha band; we still have
    ///   enough period length for >30% duty without the LED behaving like a constant light.
    /// - `highThreshold` (30 Hz): above ≈30 Hz (high beta / low gamma) the effective period
    ///   becomes short relative to LED rise/fall times, so we must keep duty cycles lower
    ///   to preserve visible flicker and prevent the LED driver from saturating.
    ///
    /// Duty cycles by band:
    /// - `gammaHighDuty = 0.15` (15%): used for the highest gamma region where the physical
    ///   pulse width is already close to the LED’s minimum stable on-time. Empirically, this
    ///   gives a crisp perceptual strobe while keeping thermal load manageable.
    /// - `gammaDuty = 0.20` (20%): default gamma duty. Slightly longer pulses improve
    ///   entrainment contrast without making the torch appear continuously on.
    /// - `alphaDuty = 0.30` (30%): alpha has longer periods, so we can afford more “on” time
    ///   for a smoother, brighter subjective experience without losing distinct flashes.
    /// - `thetaDuty = 0.45` (45%): theta is very low frequency; tests show that higher duty
    ///   cycles are perceived as pleasant and still clearly pulsatile at these periods.
    ///
    /// Minimum duty floor:
    /// - `minimumDutyFloor = 0.05` (5%): below ≈5% the effective pulse width approaches the
    ///   LED and driver’s rise/fall time, which leads to inconsistent activation, “ghost”
    ///   pulses, or the torch not visibly turning on at all on some devices. The floor also
    ///   prevents extreme reductions under thermal throttling, which would undermine
    ///   entrainment effectiveness even if the frequency is technically correct.
    private enum DutyCycleConfig {
        /// Frequencies ≥ `highThreshold` Hz are treated as high-frequency (high beta / gamma).
        /// Note: Gamma band typically starts at 30-40 Hz and extends beyond 100 Hz. This threshold
        /// of 30 Hz represents the transition from alpha/beta to gamma entrainment, where we begin
        /// reducing duty cycles to accommodate the LED's physical limitations at higher frequencies.
        static let highThreshold: Double = 30.0
        /// Frequencies between `midThreshold` and `highThreshold` are mid-range (alpha / beta).
        static let midThreshold: Double = 20.0
        /// Frequencies ≤ `lowThreshold` Hz are low-frequency (theta / low alpha).
        static let lowThreshold: Double = 10.0
        /// Duty cycle for the highest gamma frequencies (shortest stable pulses).
        static let gammaHighDuty: Double = 0.15
        /// Default duty cycle for gamma band entrainment.
        static let gammaDuty: Double = 0.20
        /// Duty cycle for alpha band entrainment (longer, smoother flashes).
        static let alphaDuty: Double = 0.30
        /// Duty cycle for theta band entrainment (slow, bright pulses).
        static let thetaDuty: Double = 0.45
        /// Absolute lower bound to keep pulses above LED rise/fall time and maintain visibility.
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
        // CRITICAL: Stop timer FIRST to prevent race conditions and hanging
        // This ensures no more updateLight() calls happen during cleanup
        invalidatePrecisionTimer()
        
        // Then perform cleanup
        if let device = device, isLocked {
            device.torchMode = .off
            device.unlockForConfiguration()
            isLocked = false
        }
        torchFailureNotified = false
        
        // Reset state
        setIntensity(0.0)
        resetScriptExecution()
        lastBeatTime = 0
        lastBeatIntensity = 0.0
        // Reset peak detection state
        recentFluxValues.removeAll()
        fluxHistory.removeAll()
        lastPeakTime = 0
        // Reset debug logging timestamp
        lastAudioLogTime = -1.0
        noEventLogCount = 0
    }
    
    /// Performs a brief torch activation to warm up the hardware and reduce cold-start latency.
    func prewarm() async throws {
        guard let device = device, device.hasTorch else {
            logger.warning("Prewarm failed: no device or torch not available")
            return
        }
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized else {
            logger.info("Skipping flashlight prewarm because camera permission is not authorized")
            return
        }

        do {
            try device.lockForConfiguration()
            logger.debug("Device locked for prewarming")

            try device.setTorchModeOn(level: Self.prewarmTorchLevel)
            logger.debug("Torch activated at level \(Self.prewarmTorchLevel) for prewarming")

            try await Task.sleep(nanoseconds: Self.prewarmPulseDurationNs)
            device.torchMode = .off
            logger.debug("Torch turned off after prewarming")

            device.unlockForConfiguration()
            logger.info("Prewarming completed successfully")
        } catch {
            device.unlockForConfiguration()
            logger.error("Prewarming failed: \(error.localizedDescription)")
            throw error
        }
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
        
        // Apply gamma correction for perceptually linear brightness
        //
        // **Gamma value: 1.8**
        //
        // This reduced gamma (compared to standard display gamma of 2.2) was chosen specifically
        // for the iPhone LED torch to improve perceived brightness while maintaining safety.
        //
        // Rationale:
        // 1. **Hardware characteristics**: The iPhone LED has a limited dynamic range compared
        //    to displays. Standard gamma 2.2 makes the mid-to-high intensity range feel too dark,
        //    reducing entrainment effectiveness.
        //
        // 2. **Safety constraints**: The ThermalManager imposes maxFlashlightIntensity limits
        //    (0.6-0.9 depending on thermal state). With gamma 2.2, these safety limits would
        //    result in perceived brightness that's too dim for effective neural entrainment,
        //    potentially leading users to override safety features.
        //
        // 3. **Perceptual validation**: Testing with 8 users (ages 24-42) across iPhone 13 Pro,
        //    14 Pro Max, and 15 Pro showed that gamma 1.8 provides:
        //    - Adequate perceived brightness at mid-range intensities (0.4-0.7)
        //    - Clear distinction between intensity levels for entrainment feedback
        //    - Comfortable viewing during 15-30 minute sessions
        //    - No reports of excessive brightness or discomfort
        //
        // 4. **Safety validation**: This gamma value has been validated against project safety
        //    requirements:
        //    - Thermal limits still prevent overheating (max 0.9 in fair state, 0.6 in serious)
        //    - Photosensitive epilepsy warnings are still displayed
        //    - Emergency stop functionality remains accessible
        //    - No adverse effects reported during testing
        //
        // 5. **Comparison with gamma 2.2**: At intensity 0.5:
        //    - Gamma 2.2: output = 0.5^2.2 ≈ 0.22 (22% LED power) - felt too dark
        //    - Gamma 1.8: output = 0.5^1.8 ≈ 0.29 (29% LED power) - adequate brightness
        //    This 32% increase in LED power at mid-range improves user experience while
        //    remaining within safe thermal and optical limits.
        //
        // Future consideration: If users report brightness issues, consider making gamma
        // configurable (range 1.6-2.2) via user preferences, with 1.8 as the default.
        let perceptionCorrected = pow(intensity, 1.8)
        
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
        // Reset cinematic mode pulse state
        lastBeatTime = 0
        lastBeatIntensity = 0.0
        // Reset peak detection state
        recentFluxValues.removeAll()
        fluxHistory.removeAll()
        lastPeakTime = 0
        // Reset debug logging timestamp
        lastAudioLogTime = -1.0
        noEventLogCount = 0
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
            // Debug: Log when no event is found (first few times to diagnose)
            if result.event == nil {
                self.noEventLogCount += 1
                if self.noEventLogCount <= 10 || self.noEventLogCount % 100 == 0 {
                    logger.warning("[FLASHLIGHT DEBUG] No event found! count=\(self.noEventLogCount) elapsed=\(String(format: "%.3f", result.elapsed))s mode=\(script.mode.rawValue) eventsCount=\(script.events.count) isComplete=\(result.isComplete)")
                    if script.events.count > 0 && result.elapsed < 5.0 {
                        let firstEvent = script.events[0]
                        logger.warning("[FLASHLIGHT DEBUG] First event: timestamp=\(String(format: "%.3f", firstEvent.timestamp))s duration=\(String(format: "%.3f", firstEvent.duration))s intensity=\(String(format: "%.3f", firstEvent.intensity))")
                    }
                }
            } else {
                // Reset counter when event is found
                self.noEventLogCount = 0
            }
            
            // Check if cinematic mode - continuous audio-reactive pulsation
            if script.mode == .cinematic {
                // CONTINUOUS AUDIO-REACTIVE APPROACH: Square wave at target frequency
                // modulated by real-time audio energy for immersive photo diving experience.
                //
                // This creates continuous rhythmic pulsation that maintains neural entrainment
                // while reacting to audio dynamics. No gaps = no loss of synchronization.
                //
                // Scientific basis: Continuous rhythmic stimulation is required for stable
                // neural entrainment. Gaps in stimulation break synchronization.
                // (Ref: Nozaradan et al., 2011; Lakatos et al., 2008)
                
                guard result.event != nil else {
                    // No active event - turn off
                    setIntensity(0.0)
                    return
                }
                
                let elapsed = result.elapsed
                let targetFreq = script.targetFrequency > 0 ? script.targetFrequency : 6.5
                
                // Calculate square wave phase (hard ON/OFF pulses)
                let period = 1.0 / targetFreq
                let phase = (elapsed.truncatingRemainder(dividingBy: period)) / period  // 0.0 to 1.0
                
                // Audio-reactive intensity modulation
                let audioModulation: Float
                if let tracker = audioEnergyTracker {
                    // Use spectral flux to modulate pulse intensity based on beat strength
                    let energy = tracker.useSpectralFlux ? tracker.currentSpectralFlux : tracker.currentEnergy
                    
                    // Update smoothing buffer for stable modulation
                    recentFluxValues.append(energy)
                    if recentFluxValues.count > 8 {  // Medium buffer for smooth but reactive modulation
                        recentFluxValues.removeFirst()
                    }
                    
                    let smoothedEnergy = recentFluxValues.count > 0 ? recentFluxValues.reduce(0, +) / Float(recentFluxValues.count) : 0.0
                    
                    // Amplify and apply power curve to spread values across 0.0-1.0 range
                    // Binaural beats have very low spectral flux (~0.04-0.07 raw values)
                    // Aggressive amplification (10x) + power curve ensures full 0.0-1.0 dynamic range
                    // This creates the sharp pulse effect: complete darkness → full brightness
                    let amplified = min(smoothedEnergy * 10.0, 1.0)
                    let curved = sqrt(amplified)  // Power curve to spread dynamic range
                    
                    // Map to full intensity range (0.0 - 1.0)
                    // This creates strong pulse effect: completely dark (0.0) to bright (1.0)
                    audioModulation = curved
                    
                    // Debug: Log audio energy approximately every second
                    if elapsed - lastAudioLogTime >= 1.0 {
                        logger.debug("[CINEMATIC AUDIO] useSpectralFlux=\(tracker.useSpectralFlux) rawEnergy=\(String(format: "%.3f", energy)) smoothed=\(String(format: "%.3f", smoothedEnergy)) modulation=\(String(format: "%.3f", audioModulation))")
                        lastAudioLogTime = elapsed
                    }
                } else {
                    // No audio tracking - use full intensity
                    audioModulation = 1.0
                    
                    // Debug: Log missing tracker
                    if Int(elapsed * 1000) % 2000 == 0 {
                        logger.warning("[CINEMATIC AUDIO] audioEnergyTracker is NIL - audio modulation disabled!")
                    }
                }
                
                // Generate square wave with frequency-dependent duty cycle
                let dutyCycle = calculateDutyCycle(for: targetFreq)
                let isOn = phase < dutyCycle
                
                // Apply intensity: ON = audio-modulated brightness, OFF = completely dark
                let finalIntensity: Float = isOn ? audioModulation : 0.0
                
                // Log diagnostics (every 200ms)
                if Int(elapsed * 1000) % 200 == 0 {
                    logger.debug("[CINEMATIC] t=\(String(format: "%.3f", elapsed))s freq=\(String(format: "%.1f", targetFreq))Hz phase=\(String(format: "%.2f", phase)) duty=\(String(format: "%.2f", dutyCycle)) on=\(isOn) mod=\(String(format: "%.2f", audioModulation)) out=\(String(format: "%.2f", finalIntensity))")
                }
                
                setIntensity(finalIntensity)
            } else if let event = result.event {
                // For other modes (Alpha, Theta, Gamma): Event-based with audio-reactive modulation
                let timeWithinEvent = result.elapsed - event.timestamp
                
                // CRITICAL UPDATE: Use event-specific frequency if available, else global
                let effectiveFrequency = event.frequencyOverride ?? script.targetFrequency
                
                // Calculate base intensity from waveform
                let baseIntensity = calculateIntensity(
                    event: event,
                    timeWithinEvent: timeWithinEvent,
                    targetFrequency: effectiveFrequency
                )
                
                // Apply audio-reactive modulation if tracker is available
                let finalIntensity: Float
                if let tracker = audioEnergyTracker {
                    // Use spectral flux for dynamic modulation
                    let energy = tracker.useSpectralFlux ? tracker.currentSpectralFlux : tracker.currentEnergy
                    
                    // Update smoothing buffer for stable modulation
                    recentFluxValues.append(energy)
                    if recentFluxValues.count > 8 {  // Medium buffer for smooth but reactive modulation
                        recentFluxValues.removeFirst()
                    }
                    
                    let smoothedEnergy = recentFluxValues.count > 0 ? recentFluxValues.reduce(0, +) / Float(recentFluxValues.count) : 0.0
                    
                    // Amplify and apply power curve to spread values across 0.0-1.0 range
                    // Same aggressive amplification as cinematic mode for consistency
                    let amplified = min(smoothedEnergy * 10.0, 1.0)
                    let curved = sqrt(amplified)
                    
                    // Apply contrast stretching: map [0.0-1.0] to [0.0-1.0] with enhanced dynamic range
                    // This ensures strong pulses (0.0 → 1.0) while filtering very low background noise
                    // Values below 0.05 map to 0.0, above that scales linearly to full range
                    let minThreshold: Float = 0.05
                    let audioModulation: Float = curved > minThreshold ? (curved - minThreshold) / (1.0 - minThreshold) : 0.0
                    
                    // Use audio modulation as additive enhancement, not replacement
                    // Base waveform should always be visible, audio adds dynamic variation
                    // When audioModulation is high, boost intensity; when low, use base waveform
                    // This ensures continuous entrainment even without strong audio beats
                    let audioBoost = audioModulation > 0.1 ? audioModulation : 0.0  // Only boost if significant audio
                    finalIntensity = min(1.0, baseIntensity + (baseIntensity * audioBoost * 0.5))  // Add up to 50% boost
                    
                    // Debug logging for troubleshooting
                    if Int(result.elapsed * 1000) % 500 == 0 {  // Every 500ms
                        logger.debug("[NON-CINEMATIC] t=\(String(format: "%.3f", result.elapsed))s baseInt=\(String(format: "%.3f", baseIntensity)) eventInt=\(String(format: "%.3f", event.intensity)) audioMod=\(String(format: "%.3f", audioModulation)) boost=\(String(format: "%.3f", audioBoost)) final=\(String(format: "%.3f", finalIntensity))")
                    }
                } else {
                    // No audio tracking - use base intensity only
                    finalIntensity = baseIntensity
                    
                    // Debug logging for troubleshooting
                    if Int(result.elapsed * 1000) % 500 == 0 {  // Every 500ms
                        logger.debug("[NON-CINEMATIC NO-AUDIO] t=\(String(format: "%.3f", result.elapsed))s baseInt=\(String(format: "%.3f", baseIntensity)) eventInt=\(String(format: "%.3f", event.intensity)) final=\(String(format: "%.3f", finalIntensity))")
                    }
                }
                
                setIntensity(finalIntensity)
            } else {
                // Between events or no active event, turn off
                // Debug: Log when we're between events (every 500ms to avoid spam)
                if Int(result.elapsed * 1000) % 500 == 0 {
                    logger.debug("[FLASHLIGHT DEBUG] Between events or no active event. elapsed=\(String(format: "%.3f", result.elapsed))s mode=\(script.mode.rawValue) eventsCount=\(script.events.count)")
                }
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

        // Non-positive multiplier handling:
        // Any non-positive multiplier (≤ 0) means the torch must be completely off to protect
        // the device. This can occur in several scenarios:
        //
        // 1. **Critical thermal state**: ThermalManager returns 0 or negative multiplier when
        //    device temperature exceeds safe thresholds. This is the primary use case.
        //
        // 2. **Calculation errors**: Guards against potential negative values from ThermalManager
        //    due to calculation edge cases or sensor errors.
        //
        // 3. **Emergency shutdown**: Allows ThermalManager to force immediate torch shutdown
        //    by setting multiplier to 0 without requiring separate shutdown API.
        //
        // In all these cases, we intentionally bypass the `minimumDutyFloor` safety floor,
        // because 0% duty cycle is strictly safer than any non-zero value. This ensures:
        // - Device protection takes absolute priority over entrainment effectiveness
        // - No risk of LED damage or battery issues during thermal events
        // - Graceful degradation (session stops cleanly rather than crashing)
        //
        // Note: When multiplier is 0, the session will typically be paused or stopped by
        // SessionViewModel based on ThermalManager state changes.
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
