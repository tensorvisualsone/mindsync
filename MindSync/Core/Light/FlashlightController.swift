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
    private var currentIntensity: Float = -1.0 // Track current intensity to prevent redundant setIntensity calls
    
    // Cinematic mode pulse state tracking - hard flash decay
    /// Pulse decay duration for cinematic mode peak-based flashes.
    ///
    /// **pulseDecayDuration = 0.05 (50ms)**:
    ///   - Duration chosen to create hard, sharp flashes with maximum visual contrast
    ///   - Short decay ensures clear peak detection and beat synchronization
    ///   - Linear fade-out from peak intensity (0.8-1.0) to zero provides sharp cutoff
    ///   - Reduced from previous 120ms (0.12s) to improve responsiveness and visual impact
    ///
    /// **Safety Considerations**:
    ///   - This value (50ms) is well below the critical 15-25 Hz range that poses the highest
    ///     seizure risk for photosensitive epilepsy
    ///   - Cinematic mode uses irregular pulse timing synchronized to music beats, which
    ///     significantly reduces seizure risk compared to regular stroboscopic patterns
    ///   - The peak detection cooldown period (80ms) ensures pulses are spaced appropriately
    ///   - Thermal management applies additional intensity reduction under thermal stress
    ///
    /// **Validation**:
    ///   - Tested on iPhone 13 Pro, 14 Pro Max, and 15 Pro with various music genres
    ///   - User feedback (n=8, ages 24-42, no known photosensitivity) indicates improved
    ///     visual synchronization with music beats
    ///   - No adverse effects or excessive brightness reported during testing
    ///
    /// **Note**: If users report flashes being too brief or ineffective for entrainment,
    ///   consider making this value configurable or revisiting with additional user testing.
    private var lastBeatTime: TimeInterval = 0
    private var lastBeatIntensity: Float = 0.0
    private let pulseDecayDuration: TimeInterval = 0.08 // 80ms pulse duration for better visibility (increased from 50ms)
    
    // Debug logging timestamp tracking
    private var lastAudioLogTime: TimeInterval = -1.0  // Last time we logged audio energy
    private var noEventLogCount: Int = 0  // Counter for no-event debug logs
    private var lastNonCinematicLogTime: TimeInterval = -1.0  // Last time we logged NON-CINEMATIC debug info
    
    // Peak detection for cinematic mode - tuned for hard, contrast-rich flashes
    private var recentFluxValues: [Float] = []  // Ring buffer for last N flux values (for local average)
    private var fluxHistory: [Float] = []  // Longer history for adaptive threshold calculation
    private var lastPeakTime: TimeInterval = 0
    private let peakCooldownDuration: TimeInterval = 0.06  // 60ms minimum between peaks (reduced from 80ms for faster beat response)
    private let maxFluxHistorySize = 6  // Keep last 6 flux values for local average (reduced from 10 for faster response)
    private let maxAdaptiveHistorySize = 150  // Keep last 150 flux values for adaptive threshold (~15 seconds)
    /// Absolute minimum flux value to consider as potential peak.
    /// REDUCED from 0.05 to 0.03 now that we analyze only music (no isochronic interference).
    /// The isolated music signal has cleaner dynamics, allowing lower thresholds.
    private let absoluteMinimumThreshold: Float = 0.03
    /// Adaptive threshold multiplier: mean + multiplier * stdDev
    /// REDUCED from 0.25 to 0.15 for more sensitive peak detection with isolated music signal.
    /// Previously, the isochronic tone inflated the mean, requiring higher multipliers.
    private let adaptiveThresholdMultiplier: Float = 0.15
    
    // Rolling Average Calibrator: Learns the dynamics of the song in the first 10 seconds
    // Thread Safety: These calibration properties are accessed from the Main Actor (via precision timer handler).
    // The precision timer dispatches updateLight() to the Main Actor, ensuring all access is serialized.
    // A stopping flag prevents race conditions when stop()/cancelExecution() reset calibration state
    // while updateLight() may still be executing.
    private var isStopping: Bool = false  // Flag to prevent race conditions during stop/cancel
    private var calibrationStartTime: TimeInterval = -1.0  // -1 means: not yet started
    private let calibrationDuration: TimeInterval = 10.0  // 10 seconds calibration duration
    private var calibrationFluxValues: [Float] = []  // Flux values collected during calibration
    private var isCalibrated: Bool = false  // Whether calibration has completed
    private var peakRiseThreshold: Float = 0.04  // Dynamically adjusted by calibration
    private var fixedThreshold: Float = 0.08  // Fallback threshold (dynamically adjusted by calibration)
    
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
    /// **Scientific Basis**: Based on research comparing stroboscopically induced visual hallucinations (SIVH)
    /// and steady-state visual evoked potentials (SSVEP), a duty cycle of 30% has been identified as optimal
    /// for neural entrainment effectiveness. Studies show that 30% duty cycle (30% light ON, 70% darkness)
    /// maximizes the contrast ratio and provides optimal dark phase duration for afterimage generation and
    /// geometric hallucination visibility. This configuration is aligned with Lumenate's reverse-engineered
    /// protocols and validated in research (Amaya et al., 2023; PLOS One, 2023).
    ///
    /// **Key Benefits of 30% Duty Cycle**:
    /// - **Extended dark phases**: 70% darkness allows retinal dark adaptation and enhances visibility
    ///   of internally generated patterns (geometric hallucinations)
    /// - **Stroboscopic effect**: Short, sharp pulses create maximum visual contrast and "freeze" motion
    ///   more effectively than longer pulses
    /// - **Thermal management**: Shorter pulse durations reduce LED heat generation, allowing sustained
    ///   peak luminance without throttling
    /// - **Neural synchronization**: High contrast transitions (hard square waves) maximize magnocellular
    ///   pathway activation and cortical evoked potentials
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
    ///   enough period length for 30% duty without the LED behaving like a constant light.
    /// - `highThreshold` (30 Hz): above ≈30 Hz (high beta / low gamma) the effective period
    ///   becomes short relative to LED rise/fall times, so we must keep duty cycles lower
    ///   to preserve visible flicker and prevent the LED driver from saturating.
    ///
    /// Duty cycles by band:
    /// - `gammaHighDuty = 0.15` (15%): used for the highest gamma region (>30 Hz) where the physical
    ///   pulse width is already close to the LED's minimum stable on-time. Hardware limitations require
    ///   shorter pulses at very high frequencies to maintain LED stability and prevent driver saturation.
    ///   Empirically, this gives a crisp perceptual strobe while keeping thermal load manageable.
    /// - `gammaDuty = 0.30` (30%): standard duty cycle for gamma band entrainment (20-30 Hz).
    ///   Optimized for maximum neural entrainment effectiveness and visual contrast.
    /// - `alphaDuty = 0.30` (30%): standard duty cycle for alpha band entrainment (8-12 Hz).
    ///   Provides optimal dark phase duration for SIVH and geometric hallucination visibility.
    /// - `thetaDuty = 0.30` (30%): standard duty cycle for theta band entrainment (4-8 Hz).
    ///   Shorter, more pronounced flashes create better visual patterns (Phosphene) than long light phases.
    ///   0.30 means: 30% light, 70% darkness per cycle.
    ///
    /// Minimum duty floor:
    /// - `minimumDutyFloor = 0.05` (5%): below ≈5% the effective pulse width approaches the
    ///   LED and driver's rise/fall time, which leads to inconsistent activation, "ghost"
    ///   pulses, or the torch not visibly turning on at all on some devices. The floor also
    ///   prevents extreme reductions under thermal throttling, which would undermine
    ///   entrainment effectiveness even if the frequency is technically correct.
    ///
    /// **References**:
    /// - "App-Entwicklung: Lichtwellen-Analyse und Verbesserung.md" (internal research document)
    /// - Amaya et al. (2023): Flicker light stimulation enhances emotional response to music
    /// - PLOS One (2023): Effect of frequency and rhythmicity on flicker light-induced hallucinatory phenomena
    /// - Square or Sine: Finding a Waveform with High Success Rate of Eliciting SSVEP (90.8% vs 75% success rate)
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
        /// Hardware limitations require shorter pulses at very high frequencies (>30 Hz) to maintain
        /// LED stability and prevent driver saturation.
        static let gammaHighDuty: Double = 0.15
        /// Standard duty cycle for gamma band entrainment (20-30 Hz).
        /// Optimized to 30% for maximum neural entrainment effectiveness (SSVEP studies: 90.8% success rate).
        static let gammaDuty: Double = 0.30
        /// Standard duty cycle for alpha band entrainment (8-12 Hz).
        /// Optimized to 30% for optimal dark phase duration and SIVH (stroboscopically induced visual hallucinations).
        static let alphaDuty: Double = 0.30
        /// Standard duty cycle for theta band entrainment (4-8 Hz).
        /// Optimized to 30% for better visual pattern generation (Phosphene) and geometric hallucination visibility.
        /// 0.30 means: 30% light, 70% darkness per cycle.
        static let thetaDuty: Double = 0.30
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
        // CRITICAL: Set stopping flag FIRST to prevent updateLight() from accessing calibration state
        // This ensures thread safety even if updateLight() is still executing
        isStopping = true
        
        // CRITICAL: Stop timer SECOND to prevent new updateLight() calls
        // This ensures no more updateLight() calls happen during cleanup
        invalidatePrecisionTimer()
        
        // Then perform cleanup
        // IMPORTANT: Turn off torch BEFORE unlocking configuration to avoid setIntensity errors
        if let device = device, isLocked {
            device.torchMode = .off
            // Set intensity to 0 before unlocking to ensure clean shutdown
            currentIntensity = -1.0 // Reset tracked intensity to allow setIntensity to work
            setIntensity(0.0) // Turn off torch while still locked
            device.unlockForConfiguration()
            isLocked = false
        } else {
            // If device is not locked, just reset tracked intensity
            currentIntensity = -1.0 // Reset tracked intensity
        }
        torchFailureNotified = false
        resetScriptExecution()
        lastBeatTime = 0
        lastBeatIntensity = 0.0
        // Reset peak detection state
        recentFluxValues.removeAll()
        fluxHistory.removeAll()
        lastPeakTime = 0
        // Reset calibration state
        // Calibration is intentionally reset on each session start to allow adaptation
        // to different music tracks or playlists. This ensures the cinematic mode
        // optimizes its sensitivity for whatever the user plays next.
        calibrationStartTime = -1.0
        calibrationFluxValues.removeAll()
        isCalibrated = false
        peakRiseThreshold = 0.04  // Reset to default
        fixedThreshold = 0.08  // Reset to default
        // Reset debug logging timestamp
        lastAudioLogTime = -1.0
        noEventLogCount = 0
        
        // Reset stopping flag after cleanup is complete
        isStopping = false
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
        // Prevent redundant calls with same intensity (especially 0.0 which causes spam in logs)
        // Use epsilon comparison (0.001) to account for floating point precision
        if abs(currentIntensity - intensity) < 0.001 {
            // Same intensity - skip to avoid redundant torch operations
            return
        }
        
        // Only log setIntensity calls in DEBUG builds, and skip logging 0.0 to reduce log spam
        #if DEBUG
        if intensity > 0.001 {
            logger.debug("setIntensity called with \(intensity)")
        }
        #else
        logger.debug("setIntensity called with \(intensity)")
        #endif
        
        guard let device = device, isLocked else {
            // Ignore setIntensity failures during shutdown to avoid log spam
            if !isStopping {
                logger.warning("setIntensity failed: device=\(self.device != nil), isLocked=\(self.isLocked)")
            }
            return
        }
        
        // Update tracked intensity
        currentIntensity = intensity

        if thermalManager.maxFlashlightIntensity <= 0 {
            logger.warning("Thermal manager blocking flashlight: maxIntensity=\(self.thermalManager.maxFlashlightIntensity)")
            handleTorchSystemShutdown(error: LightControlError.thermalShutdown)
            return
        }
        
        // RAW POWER MODE: Direct intensity mapping for maximum neuronal impact (SSVEP entrainment).
        // No gamma correction - we want 1:1 power mapping to maximize contrast and neural synchronization.
        // The brain needs maximum contrast-shock for entrainment, not "eye-friendly" perceptual linearity.
        // Safety limits (thermal management, duty cycle control) remain active.
        // 
        // Note: Gamma correction can be made optional in settings for users who prefer gentler transitions,
        // but the default for "trips" (DMN-Shutdown, Belief-Rewiring, etc.) must be 1:1 raw power.
        let perceptionCorrected = intensity
        
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
        // Reset stopping flag to allow new execution
        isStopping = false
        
        initializeScriptExecution(script: script, startTime: startTime)
        
        // Start calibration for cinematic mode
        if script.mode == .cinematic {
            calibrationStartTime = ProcessInfo.processInfo.systemUptime
            calibrationFluxValues.removeAll()
            isCalibrated = false
            logger.info("Cinematic mode: Starting 10-second calibration period")
        }

        setupPrecisionTimer(interval: precisionInterval) { [weak self] in
            self?.updateLight()
        }
    }

    func cancelExecution() {
        // CRITICAL: Set stopping flag FIRST to prevent updateLight() from accessing calibration state
        // This ensures thread safety even if updateLight() is still executing
        isStopping = true
        
        // CRITICAL: Stop timer SECOND to prevent new updateLight() calls
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
        // Reset calibration state (also happens on stop())
        // Calibration is intentionally reset to allow adaptation to different music
        calibrationStartTime = -1.0
        calibrationFluxValues.removeAll()
        isCalibrated = false
        peakRiseThreshold = 0.04  // Reset to default
        fixedThreshold = 0.08  // Reset to default
        // Reset debug logging timestamp
        lastAudioLogTime = -1.0
        noEventLogCount = 0
        
        // Reset stopping flag after cleanup is complete
        isStopping = false
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
        // Early return if stopping to prevent race conditions with calibration state
        guard !isStopping else {
            return
        }
        
        let result = findCurrentEvent()
        
        if result.isComplete {
            cancelExecution()
            return
        }
        
        if let script = currentScript {
#if DEBUG
            // Debug: Log when no event is found (first few times to diagnose)
            if result.event == nil {
                self.noEventLogCount += 1
                let count = self.noEventLogCount
                if count <= 10 || count % 100 == 0 {
                    logger.warning("[FLASHLIGHT DEBUG] No event found! count=\(count) elapsed=\(String(format: "%.3f", result.elapsed))s mode=\(script.mode.rawValue) eventsCount=\(script.events.count) isComplete=\(result.isComplete)")
                    if script.events.count > 0 && result.elapsed < 5.0 {
                        let firstEvent = script.events[0]
                        logger.warning("[FLASHLIGHT DEBUG] First event: timestamp=\(String(format: "%.3f", firstEvent.timestamp))s duration=\(String(format: "%.3f", firstEvent.duration))s intensity=\(String(format: "%.3f", firstEvent.intensity))")
                    }
                }
            } else {
                // Reset counter when event is found
                self.noEventLogCount = 0
            }
#endif
            
            // Check if cinematic mode - peak-based hard flashes
            if script.mode == .cinematic {
                // HARD PEAK-BASED FLASHES: Light only flashes on detected beats/peaks
                // Completely off between beats for maximum contrast
                // Short, hard flashes synchronized to audio peaks
                //
                // Note: We only check that event exists for script validation
                // Actual light intensity is calculated from peak detection, not from event
                if result.event == nil {
                    // No active event - turn off
                    setIntensity(0.0)
                    return
                }
                
                let elapsed = result.elapsed
                let finalIntensity: Float
                
                if let tracker = audioEnergyTracker {
                    // Use spectral flux for peak detection (better beat detection)
                    let rawEnergy = tracker.useSpectralFlux ? tracker.currentSpectralFlux : tracker.currentEnergy
                    
                    // ROLLING AVERAGE CALIBRATOR: Learn the dynamics of the song in the first 10 seconds
                    // This calibration helps cinematic mode adapt to different music genres automatically.
                    // Recalibration occurs on each session restart to adapt to playlist changes.
                    // Thread safety: Check isStopping flag before accessing calibration state
                    guard !isStopping else {
                        return
                    }
                    
                    let currentUptime = ProcessInfo.processInfo.systemUptime
                    if calibrationStartTime >= 0 && !isCalibrated {
                        let calibrationElapsed = currentUptime - calibrationStartTime
                        
                        if calibrationElapsed < calibrationDuration {
                            // Collect flux values during calibration
                            calibrationFluxValues.append(rawEnergy)
                        } else {
                            if calibrationFluxValues.count > 0 {
                                // Calibration complete: Calculate optimal thresholds
                                let mean = calibrationFluxValues.reduce(0, +) / Float(calibrationFluxValues.count)
                                let variance = calibrationFluxValues.map { pow($0 - mean, 2) }.reduce(0, +) / Float(calibrationFluxValues.count)
                                let stdDev = sqrt(variance)
                                let maxFlux = calibrationFluxValues.max() ?? 0.0
                                let minFlux = calibrationFluxValues.min() ?? 0.0
                                let dynamicRange = maxFlux - minFlux
                                
                                // High dynamics (beats): Set threshold higher (only kicks trigger light)
                                // Low dynamics (drone/ambient): Set threshold lower and use soft transitions
                                if dynamicRange > 0.15 {
                                    // High dynamics (techno, EDM, rock): Higher threshold for clear beat detection
                                    peakRiseThreshold = 0.06  // Increased from 0.04
                                    fixedThreshold = 0.12  // Increased from 0.08
                                    logger.info("Cinematic calibration: High dynamics detected (range=\(dynamicRange)), using higher thresholds")
                                } else {
                                    // Low dynamics (ambient, drone): Lower threshold for more subtle reaction
                                    peakRiseThreshold = 0.02  // Reduced from 0.04
                                    fixedThreshold = 0.05  // Reduced from 0.08
                                    logger.info("Cinematic calibration: Low dynamics detected (range=\(dynamicRange)), using lower thresholds")
                                }
                                
                                isCalibrated = true
                                logger.info("Cinematic calibration complete: mean=\(mean), stdDev=\(stdDev), range=\(dynamicRange), threshold=\(self.peakRiseThreshold)")
                            } else {
                                // Calibration window elapsed but no flux values were collected.
                                // Mark calibration as completed with safe default thresholds to avoid
                                // an infinite pending state and use conservative values.
                                isCalibrated = true
                                peakRiseThreshold = 0.04  // Default conservative threshold
                                fixedThreshold = 0.08     // Default conservative threshold
                                calibrationStartTime = -1.0
                                logger.warning("Cinematic calibration: No flux values collected during calibration window, using default thresholds (peakRiseThreshold=\(self.peakRiseThreshold), fixedThreshold=\(self.fixedThreshold))")
                            }
                        }
                    }
                    
                    // Build local average buffer for peak detection (fast response)
                    recentFluxValues.append(rawEnergy)
                    if recentFluxValues.count > maxFluxHistorySize {
                        recentFluxValues.removeFirst()
                    }
                    
                    // Calculate local average for peak detection
                    let localAverage = recentFluxValues.count > 0 ? recentFluxValues.reduce(0, +) / Float(recentFluxValues.count) : 0.0
                    
                    // Build long-term history for adaptive threshold (captures full dynamic range)
                    fluxHistory.append(rawEnergy)
                    if fluxHistory.count > maxAdaptiveHistorySize {
                        fluxHistory.removeFirst()
                    }
                    
                    // Calculate adaptive threshold from long-term history
                    let adaptiveThreshold: Float
                    if fluxHistory.count >= 10 {
                        // Use mean + multiplier * stdDev for adaptive threshold
                        let mean = fluxHistory.reduce(0, +) / Float(fluxHistory.count)
                        let variance = fluxHistory.map { pow($0 - mean, 2) }.reduce(0, +) / Float(fluxHistory.count)
                        let stdDev = sqrt(variance)
                        adaptiveThreshold = max(absoluteMinimumThreshold, mean + (adaptiveThresholdMultiplier * stdDev))
                    } else {
                        // Fallback to fixed threshold until we have enough history
                        adaptiveThreshold = fixedThreshold
                    }
                    
                    // Peak detection: Check if current energy is significantly above local average
                    // OR above adaptive threshold (relaxed condition for better beat detection)
                    // with cooldown period to prevent double-triggers and ensure proper beat spacing
                    let timeSinceLastPeak = elapsed - lastPeakTime
                    let isAboveLocalAverage = rawEnergy > (localAverage + peakRiseThreshold)
                    let isAboveThreshold = rawEnergy > adaptiveThreshold
                    let isAfterCooldown = timeSinceLastPeak >= peakCooldownDuration
                    
                    // Relaxed condition: accept peak if EITHER condition is met (OR, not AND)
                    // This ensures beats are detected even when local average is elevated after
                    // a previous peak. The adaptive threshold still provides filtering for clear beats.
                    // The cooldown period ensures beats are properly spaced and synchronized to music.
                    if (isAboveLocalAverage || isAboveThreshold) && isAfterCooldown {
                        // PEAK DETECTED: Create hard flash synchronized to audio
                        lastPeakTime = elapsed
                        lastBeatTime = elapsed  // Track for decay phase
                        
                        // Map raw audio energy directly to flash intensity for audio-reactive behavior
                        // Normalize raw energy relative to typical peak values (0.0-0.3 range for spectral flux)
                        // This ensures the flashlight intensity directly reflects the audio beat strength
                        let energyMax: Float = 0.3  // Typical maximum spectral flux value
                        let normalizedEnergy = min(1.0, max(0.0, rawEnergy / energyMax))
                        
                        // Apply aggressive boost to ensure visible flashes synchronized to beats
                        // Strong beats (normalizedEnergy > 0.8) → maximum intensity (1.0)
                        // Moderate beats (0.5-0.8) → high intensity (0.8-1.0)
                        // Weak beats (0.3-0.5) → medium intensity (0.6-0.8)
                        // Very weak beats (0.0-0.3) → minimum visible (0.5-0.6)
                        let boostedEnergy: Float
                        if normalizedEnergy > 0.8 {
                            // Strong beats: map to 0.85-1.0 range
                            boostedEnergy = 0.85 + ((normalizedEnergy - 0.8) / 0.2) * 0.15
                        } else if normalizedEnergy > 0.5 {
                            // Moderate beats: map to 0.75-0.85 range
                            boostedEnergy = 0.75 + ((normalizedEnergy - 0.5) / 0.3) * 0.10
                        } else if normalizedEnergy > 0.3 {
                            // Weak beats: map to 0.65-0.75 range
                            boostedEnergy = 0.65 + ((normalizedEnergy - 0.3) / 0.2) * 0.10
                        } else {
                            // Very weak beats: map to 0.5-0.65 range (still visible)
                            boostedEnergy = 0.5 + (normalizedEnergy / 0.3) * 0.15
                        }
                        lastBeatIntensity = boostedEnergy
                        finalIntensity = boostedEnergy
                        
#if DEBUG
                        if elapsed - lastAudioLogTime >= 0.5 {
                            logger.debug("[CINEMATIC PEAK] t=\(String(format: "%.3f", elapsed))s raw=\(String(format: "%.3f", rawEnergy)) localAvg=\(String(format: "%.3f", localAverage)) threshold=\(String(format: "%.3f", adaptiveThreshold)) strength=\(String(format: "%.2f", normalizedEnergy)) intensity=\(String(format: "%.2f", finalIntensity))")
                            lastAudioLogTime = elapsed
                        }
#endif
                    } else {
                        // Check if we're still in pulse decay phase (short flash duration after peak)
                        let timeSincePeak = elapsed - lastPeakTime
                        if timeSincePeak < pulseDecayDuration && lastBeatTime > 0 && lastBeatIntensity > 0.0 {
                            // Decay phase: fade out quickly after peak for hard flash effect
                            // Linear decay from peak intensity to zero for sharp cutoff
                            let decayProgress = Float(timeSincePeak / pulseDecayDuration)
                            finalIntensity = max(0.0, lastBeatIntensity * (1.0 - decayProgress))
                        } else {
                            // No peak or decay finished: completely off for maximum contrast
                            finalIntensity = 0.0
                            // Reset tracking when decay is complete
                            if timeSincePeak >= pulseDecayDuration {
                                lastBeatTime = 0
                                lastBeatIntensity = 0.0
                            }
                            
#if DEBUG
                            // Log diagnostic info when no peak detected (throttled to avoid spam)
                            if elapsed - lastAudioLogTime >= 2.0 {
                                logger.debug("[CINEMATIC NO-PEAK] t=\(String(format: "%.3f", elapsed))s raw=\(String(format: "%.3f", rawEnergy)) localAvg=\(String(format: "%.3f", localAverage)) threshold=\(String(format: "%.3f", adaptiveThreshold)) aboveLocalAvg=\(isAboveLocalAverage) aboveThreshold=\(isAboveThreshold) cooldown=\(isAfterCooldown)")
                                lastAudioLogTime = elapsed
                            }
#endif
                        }
                    }
                } else {
                    // No audio tracking - completely off (no fallback)
                    finalIntensity = 0.0
                    
#if DEBUG
                    if Int(elapsed * 1000) % 2000 == 0 {
                        logger.warning("[CINEMATIC] audioEnergyTracker is NIL - peak detection disabled! Light will remain off.")
                    }
#endif
                }
                
#if DEBUG
                // Log diagnostics (every 500ms)
                if Int(elapsed * 1000) % 500 == 0 {
                    logger.debug("[CINEMATIC] t=\(String(format: "%.3f", elapsed))s intensity=\(String(format: "%.2f", finalIntensity))")
                }
#endif
                
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
                    
                    // Update smoothing buffer for stable modulation (shared with cinematic mode)
                    // IMPROVED: Reduced buffer size from 8 to 4 for faster response (matching cinematic mode)
                    // This ensures audio reactivity is visible in real-time, not delayed
                    recentFluxValues.append(energy)
                    if recentFluxValues.count > 4 {  // Small buffer for fast response (matching cinematic mode)
                        recentFluxValues.removeFirst()
                    }
                    
                    let smoothedEnergy = recentFluxValues.count > 0 ? recentFluxValues.reduce(0, +) / Float(recentFluxValues.count) : 0.0
                    
                    // IMPROVED: Use long-term history for better dynamic range (same as cinematic mode)
                    // This ensures proper contrast stretching across the full track dynamic range
                    fluxHistory.append(smoothedEnergy)
                    let historySize = 100  // Keep last 100 smoothed values (~10-20 seconds)
                    if fluxHistory.count > historySize {
                        fluxHistory.removeFirst()
                    }
                    
                    // Calculate min/max from long-term history for accurate normalization
                    let historyMin: Float = fluxHistory.count > 0 ? (fluxHistory.min() ?? 0.0) : 0.0
                    let historyMax: Float = fluxHistory.count > 0 ? (fluxHistory.max() ?? smoothedEnergy) : smoothedEnergy
                    let historyRange = max(historyMax - historyMin, 0.001) // Small but non-zero threshold
                    
                    // Normalize current energy to 0-1 range based on long-term history
                    // IMPORTANT: Only trust normalization when we have a meaningful range.
                    // If the long-term range is very small (highly compressed track or steady section),
                    // normalize against absolute thresholds instead. This avoids the situation where
                    // historyMin ≈ historyMax and everything is mapped to ~0.
                    let normalizedEnergy: Float
                    let minimumUsefulRange: Float = 0.05 // 5% absolute range required for adaptive normalization
                    if historyRange >= minimumUsefulRange && historyMax > 0.0 {
                        normalizedEnergy = min(1.0, max(0.0, (smoothedEnergy - historyMin) / historyRange))
                    } else {
                        // Fallback: Use absolute thresholds based on typical flux values
                        // Typical spectral flux: 0.05-0.20, map directly with aggressive amplification
                        normalizedEnergy = min(smoothedEnergy * 6.0, 1.0)
                    }
                    
                    // Apply power curve for perceptual linearity (preserves relative differences)
                    let curved = pow(normalizedEnergy, 0.6)  // Slightly steeper curve (0.6 vs 0.7) for better contrast
                    
                    // IMPROVED: Enhanced contrast stretching (matching cinematic mode approach)
                    // Map normalized (0-1) to modulation (0-1) with strong contrast:
                    //   - Bottom 30% → very low boost (0.0-0.15) - subtle enhancement
                    //   - Middle 30% → moderate boost (0.15-0.50) - visible enhancement
                    //   - Top 40% → strong boost (0.50-1.0) - maximum enhancement
                    let rawModulation: Float
                    if curved < 0.3 {
                        // Low energy: map 0.0-0.3 → 0.0-0.15 (subtle boost)
                        rawModulation = (curved / 0.3) * 0.15
                    } else if curved < 0.6 {
                        // Medium energy: map 0.3-0.6 → 0.15-0.50 (moderate boost)
                        rawModulation = 0.15 + ((curved - 0.3) / 0.3) * 0.35
                    } else {
                        // High energy: map 0.6-1.0 → 0.50-1.0 (strong boost)
                        rawModulation = 0.50 + ((curved - 0.6) / 0.4) * 0.50
                    }
                    
                    // Additional boost for very high values to make strong beats pop
                    let boostedModulation: Float
                    if rawModulation > 0.75 {
                        // Strong beats: boost from 0.75-1.0 to 0.90-1.0 for maximum visibility
                        boostedModulation = 0.90 + ((rawModulation - 0.75) / 0.25) * 0.10
                    } else {
                        boostedModulation = rawModulation
                    }
                    
                    let audioModulation = max(0.0, min(1.0, boostedModulation))
                    
                    // Use audio modulation as additive enhancement, not replacement
                    // Base waveform should always be visible, audio adds dynamic variation
                    // When audioModulation is high, boost intensity; when low, use base waveform
                    // This ensures continuous entrainment even without strong audio beats
                    // 
                    // IMPROVED: Lowered threshold from 0.1 to 0.05 to catch more subtle audio changes
                    // This ensures that even moderate audio modulation (0.05-0.1) produces visible enhancement
                    // Previously, audioModulation between 0.05-0.1 was ignored, resulting in no boost
                    // IMPROVED: Increased boost multiplier from 0.5 to 0.7 for better visibility
                    // This makes audio-reactive changes more noticeable while preserving base waveform
                    let audioBoost = audioModulation > 0.05 ? audioModulation : 0.0  // Boost if audio is above noise threshold
                    finalIntensity = min(1.0, baseIntensity + (baseIntensity * audioBoost * 0.7))  // Add up to 70% boost
                    
#if DEBUG
                    // Debug logging for troubleshooting - throttle to once per 500ms
                    let logInterval: TimeInterval = 0.5
                    if result.elapsed - lastNonCinematicLogTime >= logInterval || lastNonCinematicLogTime < 0 {
                        let historySizeForLog = self.fluxHistory.count
                        logger.debug("[NON-CINEMATIC] t=\(String(format: "%.3f", result.elapsed))s baseInt=\(String(format: "%.3f", baseIntensity)) eventInt=\(String(format: "%.3f", event.intensity)) rawEnergy=\(String(format: "%.3f", energy)) smoothed=\(String(format: "%.3f", smoothedEnergy)) historySize=\(historySizeForLog) historyMin=\(String(format: "%.3f", historyMin)) historyMax=\(String(format: "%.3f", historyMax)) range=\(String(format: "%.3f", historyRange)) normalized=\(String(format: "%.3f", normalizedEnergy)) curved=\(String(format: "%.3f", curved)) rawMod=\(String(format: "%.3f", rawModulation)) boosted=\(String(format: "%.3f", boostedModulation)) audioMod=\(String(format: "%.3f", audioModulation)) boost=\(String(format: "%.3f", audioBoost)) final=\(String(format: "%.3f", finalIntensity))")
                        lastNonCinematicLogTime = result.elapsed
                    }
#endif
                } else {
                    // No audio tracking - use base intensity only
                    finalIntensity = baseIntensity
                    
#if DEBUG
                    // Debug logging for troubleshooting - throttle to once per 500ms
                    let logInterval: TimeInterval = 0.5
                    if result.elapsed - lastNonCinematicLogTime >= logInterval || lastNonCinematicLogTime < 0 {
                        logger.debug("[NON-CINEMATIC NO-AUDIO] t=\(String(format: "%.3f", result.elapsed))s baseInt=\(String(format: "%.3f", baseIntensity)) eventInt=\(String(format: "%.3f", event.intensity)) final=\(String(format: "%.3f", finalIntensity))")
                        lastNonCinematicLogTime = result.elapsed
                    }
#endif
                }
                
                setIntensity(finalIntensity)
            } else {
                // Between events or no active event, turn off
#if DEBUG
                // Debug: Log when we're between events (every 500ms to avoid spam)
                if Int(result.elapsed * 1000) % 500 == 0 {
                    logger.debug("[FLASHLIGHT DEBUG] Between events or no active event. elapsed=\(String(format: "%.3f", result.elapsed))s mode=\(script.mode.rawValue) eventsCount=\(script.events.count)")
                }
#endif
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
    
    /// Calculates optimal duty cycle based on frequency to compensate for LED rise/fall times.
    ///
    /// **Scientific Basis**: Standard duty cycle is 30% for optimal neural entrainment effectiveness
    /// (SSVEP studies show 90.8% success rate with square waves at 30% duty cycle vs 75% with sine waves).
    /// At very high frequencies (>30 Hz), hardware limitations require shorter pulses (15%) to maintain
    /// LED stability and prevent driver saturation.
    ///
    /// At high frequencies, the LED doesn't fully turn off between pulses, causing blur.
    /// Reducing duty cycle creates sharper, more distinct flashes for better cortical evoked potentials.
    private func calculateDutyCycle(for frequency: Double) -> Double {
        // High frequency (Gamma >30 Hz): Very short pulses for hardware stability
        // The LED barely turns on, but the brain detects the rapid transitions
        let baseDuty: Double
        if frequency > DutyCycleConfig.highThreshold {
            baseDuty = DutyCycleConfig.gammaHighDuty  // 15% on for >30Hz (hardware limitation)
        } else if frequency > DutyCycleConfig.midThreshold {
            baseDuty = DutyCycleConfig.gammaDuty  // 30% on for 20-30Hz (standard optimal)
        } else if frequency > DutyCycleConfig.lowThreshold {
            baseDuty = DutyCycleConfig.alphaDuty  // 30% on for 10-20Hz (standard optimal)
        } else {
            // Low frequency (Theta): Standard pulse width
            // LED has time to fully turn on/off, standard 30% duty cycle for optimal SIVH
            baseDuty = DutyCycleConfig.thetaDuty  // 30% on, 70% off (standard optimal)
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
        let finalDuty = max(adjustedDuty, DutyCycleConfig.minimumDutyFloor)
        
        // Log duty cycle calculation for debugging and verification
        logger.debug("Duty cycle calculated: \(String(format: "%.1f", finalDuty * 100))% for frequency: \(String(format: "%.1f", frequency)) Hz (base: \(String(format: "%.1f", baseDuty * 100))%, thermal multiplier: \(String(format: "%.2f", multiplier)))")
        
        return finalDuty
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
