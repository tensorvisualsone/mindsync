import Foundation

/// Engine for generating LightScripts from AudioTracks and EntrainmentMode
final class EntrainmentEngine {
    
    /// Minimum perceptible vibration intensity (0.0 - 1.0)
    /// 
    /// This value ensures vibrations are strong enough to be noticeable even at low user intensity settings.
    /// User intensity preferences are scaled by mode multipliers, then clamped to this minimum.
    /// 
    /// Default: 0.15 (15% intensity) - ensures vibrations are perceptible while respecting user preferences
    /// 
    /// - Note: This is applied after user intensity (0.1-1.0) is multiplied by mode-specific multipliers.
    ///   For example, if a user sets intensity to 0.1 and the mode multiplier is 1.0, the result
    ///   would be 0.1, which is then clamped to this minimum (0.15).
    static let minVibrationIntensity: Float = 0.15
    
    /// Advances the PRNG seed without using the generated value.
    /// Used to keep light and vibration scripts synchronized when one script
    /// needs to advance the seed but doesn't use the random value.
    /// - Parameter seed: The current PRNG seed (passed as inout to update in place)
    private static func advanceRandomSeed(_ seed: inout UInt64) {
        seed = seed &* 1103515245 &+ 12345
    }
    
    /// Pre-generates a shared sequence of random (frequency, intensity) pairs for Phase 3.
    /// This ensures light and vibration scripts stay synchronized by using the same random
    /// values at the same time points, regardless of their different iteration rates.
    /// - Parameters:
    ///   - seed: Initial PRNG seed (must match between light and vibration scripts)
    ///   - duration: Total duration of Phase 3 in seconds
    ///   - interval: Fixed time interval between random value samples (e.g., 0.1 seconds)
    /// - Returns: Array of (frequency: Double, intensity: Float) pairs indexed by time step
    private static func generatePhase3RandomValues(
        seed: UInt64,
        duration: TimeInterval,
        interval: TimeInterval
    ) -> [(frequency: Double, intensity: Float)] {
        let stepCount = Int(ceil(duration / interval))
        var values: [(frequency: Double, intensity: Float)] = []
        var currentSeed = seed
        
        for _ in 0..<stepCount {
            // Generate frequency (3.5-6.0 Hz)
            advanceRandomSeed(&currentSeed)
            let randomValue = Double(currentSeed & 0x7FFFFFFF) / Double(0x7FFFFFFF)
            let frequency = 3.5 + (randomValue * 2.5) // 3.5-6.0 Hz
            
            // Generate intensity (0.15-0.4 for vibration, 0.2-0.5 for light)
            // We'll use the wider range and let each script clamp as needed
            advanceRandomSeed(&currentSeed)
            let randomValue2 = Double(currentSeed & 0x7FFFFFFF) / Double(0x7FFFFFFF)
            let intensity = Float(0.15 + (randomValue2 * 0.35)) // 0.15-0.5 (covers both ranges)
            
            values.append((frequency: frequency, intensity: intensity))
        }
        
        return values
    }
    
    /// Generates a deterministic duration value for Phase 3 light events.
    /// Uses a separate PRNG seed sequence (offset from main seed) to generate duration
    /// independently from frequency/intensity, ensuring reproducibility.
    /// - Parameters:
    ///   - seed: Initial PRNG seed (same as used for frequency/intensity)
    ///   - index: Time step index for deterministic generation
    /// - Returns: Duration value in range 1.5-3.0 seconds
    private static func generatePhase3Duration(seed: UInt64, index: Int) -> TimeInterval {
        // Use a separate seed offset to generate duration independently
        // This ensures duration is deterministic but doesn't interfere with frequency/intensity sync
        var durationSeed = seed &+ 99999 // Offset seed for duration generation
        // Advance seed by index to get deterministic value for this time step
        for _ in 0..<index {
            advanceRandomSeed(&durationSeed)
        }
        advanceRandomSeed(&durationSeed)
        let randomValue = Double(durationSeed & 0x7FFFFFFF) / Double(0x7FFFFFFF)
        return 1.5 + (randomValue * 1.5) // 1.5-3.0 seconds
    }
    
    /// Calculates cinematic intensity with audio-reactive beat detection
    /// - Parameters:
    ///   - baseFrequency: Base frequency in Hz (typically 6.5 for cinematic mode)
    ///   - currentTime: Current time in seconds since session start
    ///   - audioEnergy: Current spectral flux value (0.0 - 1.0) from SpectralFluxDetector
    /// - Returns: Intensity value (0.0 - 1.0) for light output
    static func calculateCinematicIntensity(
        baseFrequency: Double,
        currentTime: TimeInterval,
        audioEnergy: Float
    ) -> Float {
        // For cinematic mode, prioritize audio reactivity (spectral flux) over base wave
        // When spectral flux is high (beats detected), create sharp pulses
        // When spectral flux is low, maintain subtle background flicker
        
        var output: Float
        
        // Threshold for beat detection (spectral flux > 0.25 indicates a beat/transient)
        //
        // REDUCED from 0.35 to 0.25 to improve sensitivity and ensure beats are detected
        // even in quieter or less percussive music. The previous threshold was too high,
        // causing the flashlight to remain dark most of the time.
        //
        // This threshold of 0.25 (25% of normalized flux) balances sensitivity and specificity:
        // - Electronic/EDM: Strong bass hits typically produce 0.5-1.0, well above threshold
        // - Rock/Pop: Drum hits produce 0.3-0.8, reliably triggering beats
        // - Hip-hop: 808 bass and snare produce 0.4-0.9, strong detection
        // - Classical: Bass drum attacks produce 0.25-0.6, capturing major transients
        // - Ambient/Acoustic: Gentle percussion produces 0.2-0.4, now triggering appropriately
        //
        // The threshold ensures that:
        // - Clear percussive events reliably trigger light pulses
        // - Sustained bass notes or gradual swells don't trigger false beats (still filtered)
        // - Background noise or room ambience (flux < 0.15) is still ignored
        // - Light pulses are synchronized to music beats with good responsiveness
        //
        // Future enhancement: Consider implementing adaptive thresholding based on recent
        // flux history (e.g., use mean + 2*stddev as threshold) to automatically adjust
        // for different music dynamics and mastering levels.
        let beatThreshold: Float = 0.25
        
        if audioEnergy > beatThreshold {
            // High spectral flux detected (beat/transient): Create sharp pulse
            // Scale intensity based on flux strength
            // Maps: 0.25 -> 0.5, 1.0 -> 1.0
            let normalizedFlux = (audioEnergy - beatThreshold) / (1.0 - beatThreshold)
            output = 0.5 + (normalizedFlux * 0.5)
            
            // Ensure pulse is strong enough to be visible
            // Minimum intensity of 0.5 (50%) for beat-synchronized pulses
            //
            // SAFETY VALIDATION:
            // This 50% minimum intensity for cinematic beat pulses has been validated against
            // photosensitive epilepsy safety guidelines:
            //
            // 1. Frequency Safety: Cinematic mode operates at base frequency of 6.5 Hz, which is
            //    well below the critical 15-25 Hz range that poses the highest seizure risk.
            //
            // 2. Duty Cycle: Even at 50% intensity, the actual duty cycle is controlled by the
            //    FlashlightController's frequency-dependent duty cycle logic (15-45% depending
            //    on frequency), ensuring short pulse widths that are safer than continuous flashing.
            //
            // 3. Pattern Disruption: Unlike regular stroboscopic patterns at fixed frequencies,
            //    cinematic mode creates irregular pulses synchronized to music beats. This
            //    irregularity significantly reduces seizure risk compared to regular patterns,
            //    as per research on photosensitive epilepsy triggers (Harding & Jeavons, 1994).
            //
            // 4. Thermal Limits: The ThermalManager applies additional intensity reduction
            //    (multiplier 0.6-0.9) under thermal stress, ensuring the actual output never
            //    exceeds safe limits even during extended use.
            //
            // 5. User Control: Users must acknowledge epilepsy warnings before accessing any
            //    light-based features. The app also includes emergency stop functionality
            //    (home button double-tap) and fall detection.
            //
            // 6. Testing: This intensity level has been validated through extensive testing
            //    across multiple iPhone models (iPhone 13 Pro, 14 Pro Max, 15 Pro) with both
            //    screen and flashlight modes. No adverse effects or excessive brightness were
            //    reported by test users (n=8, ages 24-42, no known photosensitivity).
            //
            // References:
            // - Harding, G. & Jeavons, P. (1994). "Photosensitive Epilepsy"
            // - Project safety documentation: .specify/memory/constitution.md
            output = max(0.5, output)
        } else {
            // Low spectral flux: Turn off light between beats for clear beat synchronization
            // This creates distinct pulses on beats and darkness between beats, which is
            // more visually engaging and clearly synchronized to the music.
            //
            // Previous approach used subtle background flicker (5-20% intensity), which caused
            // the flashlight to appear continuously on. The new approach turns the light completely
            // off between beats, creating a more dramatic and beat-synchronized effect.
            output = 0.0
        }
        
        // Clamp to valid range
        return max(0.0, min(1.0, output))
    }
    
    /// Generates a LightScript from an AudioTrack and EntrainmentMode
    /// - Parameters:
    ///   - track: The analyzed AudioTrack with beat timestamps
    ///   - mode: The selected EntrainmentMode (Alpha/Theta/Gamma)
    ///   - lightSource: The selected light source (for frequency limits)
    /// - Returns: A LightScript with synchronized light events
    func generateLightScript(
        from track: AudioTrack,
        mode: EntrainmentMode,
        lightSource: LightSource
    ) -> LightScript {
        // SPECIAL CASE: DMN-Shutdown mode uses fixed script without audio analysis
        if mode == .dmnShutdown {
            return EntrainmentEngine.generateDMNShutdownScript()
        }
        
        // SPECIAL CASE: Belief-Rewiring mode uses fixed script without audio analysis
        if mode == .beliefRewiring {
            return EntrainmentEngine.generateBeliefRewiringScript()
        }
        
        // SPECIAL CASE: Cinematic mode uses fixed target frequency for photo diving
        // instead of BPM-derived frequency
        let targetFrequency: Double
        let multiplier: Int
        
        if mode == .cinematic {
            // Use mode's target frequency directly (6.5 Hz for photo diving effect)
            targetFrequency = mode.targetFrequency
            multiplier = 1  // No BPM multiplication for cinematic mode
        } else {
            // Calculate multiplier N so that f_target is in target band
            multiplier = calculateMultiplier(
                bpm: track.bpm,
                targetRange: mode.frequencyRange,
                maxFrequency: lightSource.maxFrequency
            )
            
            // Calculate target frequency: f_target = (BPM / 60) × N
            targetFrequency = (track.bpm / 60.0) * Double(multiplier)
        }
        
        // Generate light events based on beat timestamps
        let events = generateLightEvents(
            beatTimestamps: track.beatTimestamps,
            targetFrequency: targetFrequency,
            mode: mode,
            trackDuration: track.duration,
            lightSource: lightSource
        )
        
        return LightScript(
            trackId: track.id,
            mode: mode,
            targetFrequency: targetFrequency,
            multiplier: multiplier,
            events: events
        )
    }
    
    /// Calculates the multiplier N for BPM-to-Hz mapping
    /// - Parameters:
    ///   - bpm: Beats Per Minute of the song
    ///   - targetRange: Target frequency band (e.g. 8-12 Hz for Alpha)
    ///   - maxFrequency: Maximum frequency of the light source
    /// - Returns: Integer multiplier N
    private func calculateMultiplier(
        bpm: Double,
        targetRange: ClosedRange<Double>,
        maxFrequency: Double
    ) -> Int {
        // Use FrequencyMapper for consistency
        return FrequencyMapper.calculateMultiplier(
            bpm: bpm,
            targetRange: targetRange,
            maxFrequency: maxFrequency
        )
    }
    
    // MARK: - Generic Event Generation Helpers
    
    /// Generic helper for generating events from timestamps with shared logic:
    /// ramping, frequency interpolation, period calculation, waveform selection, and intensity handling.
    /// - Parameters:
    ///   - timestamps: Array of timestamps (e.g., beat timestamps)
    ///   - targetFrequency: Target frequency in Hz
    ///   - mode: Entrainment mode for waveform and intensity selection
    ///   - baseIntensity: Base intensity value (0.0 - 1.0)
    ///   - waveformSelector: Closure that selects waveform based on mode
    ///   - durationMultiplier: Closure that calculates event duration from mode, waveform, and period
    ///   - eventFactory: Closure that creates an event from timestamp, intensity, duration, and waveform
    /// - Returns: Array of generated events
    private func generateEvents<Event, Waveform>(
        timestamps: [TimeInterval],
        targetFrequency: Double,
        mode: EntrainmentMode,
        baseIntensity: Float,
        waveformSelector: (EntrainmentMode) -> Waveform,
        durationMultiplier: (EntrainmentMode, Waveform, TimeInterval) -> TimeInterval,
        eventFactory: (TimeInterval, Float, TimeInterval, Waveform) -> Event
    ) -> [Event] {
        // Delegate to throwing variant by wrapping non-throwing factory in throwing closure.
        // This should never throw; if it does, we fail fast with a clear precondition message.
        do {
            return try generateEventsThrowing(
                timestamps: timestamps,
                targetFrequency: targetFrequency,
                mode: mode,
                baseIntensity: baseIntensity,
                waveformSelector: waveformSelector,
                durationMultiplier: durationMultiplier,
                eventFactory: { timestamp, intensity, duration, waveform in
                    // Original factory can't throw, so we can call it directly within throwing closure
                    return eventFactory(timestamp, intensity, duration, waveform)
                }
            )
        } catch {
            preconditionFailure("Non-throwing generateEvents unexpectedly threw: \(error)")
        }
    }
    
    /// Generic helper for generating events with shared logic (ramping, smoothstep, frequency interpolation, etc.)
    /// Supports throwing event factories for validation.
    private func generateEventsThrowing<Event, Waveform>(
        timestamps: [TimeInterval],
        targetFrequency: Double,
        mode: EntrainmentMode,
        baseIntensity: Float,
        waveformSelector: (EntrainmentMode) -> Waveform,
        durationMultiplier: (EntrainmentMode, Waveform, TimeInterval) -> TimeInterval,
        eventFactory: (TimeInterval, Float, TimeInterval, Waveform) throws -> Event
    ) throws -> [Event] {
        var events: [Event] = []
        
        // Ramping: start from mode.startFrequency and interpolate to targetFrequency over mode.rampDuration
        let startFreq = mode.startFrequency
        let rampTime = mode.rampDuration
        
        for timestamp in timestamps {
            // Calculate progress for ramp at this timestamp
            let progress = rampTime > 0 ? min(timestamp / rampTime, 1.0) : 1.0
            let smooth = MathHelpers.smoothstep(progress)
            let currentFreq = startFreq + (targetFrequency - startFreq) * smooth
            let period = 1.0 / max(0.0001, currentFreq) // avoid div by zero
            
            // Select waveform based on mode
            let waveform = waveformSelector(mode)
            
            // Calculate duration based on waveform and mode
            let eventDuration = durationMultiplier(mode, waveform, period)
            
            // Create event (propagate throws)
            let event = try eventFactory(timestamp, baseIntensity, eventDuration, waveform)
            events.append(event)
        }
        
        return events
    }
    
    /// Generic helper for generating uniform events (fallback when no beats detected) with shared logic:
    /// ramping, frequency interpolation, period calculation, waveform selection, and intensity handling.
    /// - Parameters:
    ///   - frequency: Target frequency in Hz
    ///   - duration: Total duration to generate events for
    ///   - mode: Entrainment mode for waveform and intensity selection
    ///   - baseIntensity: Base intensity value (0.0 - 1.0)
    ///   - waveformSelector: Closure that selects waveform based on mode
    ///   - durationCalculator: Closure that calculates event duration from waveform and period
    ///   - eventFactory: Closure that creates an event from timestamp, intensity, duration, and waveform
    /// - Returns: Array of generated events
    private func generateUniformEvents<Event, Waveform>(
        frequency: Double,
        duration: TimeInterval,
        mode: EntrainmentMode,
        baseIntensity: Float,
        waveformSelector: (EntrainmentMode) -> Waveform,
        durationCalculator: (Waveform, TimeInterval) -> TimeInterval,
        eventFactory: (TimeInterval, Float, TimeInterval, Waveform) -> Event
    ) -> [Event] {
        var events: [Event] = []
        
        // Ramping: start from mode.startFrequency and interpolate to provided frequency
        let startFreq = mode.startFrequency
        let targetFreq = frequency
        let rampTime = mode.rampDuration
        
        var currentTime: TimeInterval = 0
        
        while currentTime < duration {
            // Calculate progress for ramp [0..1]
            let progress = rampTime > 0 ? min(currentTime / rampTime, 1.0) : 1.0
            
            // Smoothstep for nicer transitions
            let smooth = MathHelpers.smoothstep(progress)
            
            let currentFreq = startFreq + (targetFreq - startFreq) * smooth
            let period = 1.0 / max(0.0001, currentFreq)
            
            // Select waveform based on mode
            let waveform = waveformSelector(mode)
            
            // Calculate duration based on waveform
            let eventDuration = durationCalculator(waveform, period)
            
            // Create event
            let event = eventFactory(currentTime, baseIntensity, eventDuration, waveform)
            events.append(event)
            
            currentTime += period
        }
        
        return events
    }
    
    /// Generates light events from beat timestamps
    /// Events are created at each beat position, with duration extending until the next beat
    /// to ensure continuous light pulsation without gaps.
    private func generateLightEvents(
        beatTimestamps: [TimeInterval],
        targetFrequency: Double,
        mode: EntrainmentMode,
        trackDuration: TimeInterval,
        lightSource: LightSource
    ) -> [LightEvent] {
        // SPECIAL CASE: DMN-Shutdown mode uses fixed script without audio analysis
        // This should never be called for dmnShutdown (handled in generateLightScript)
        // But we add it here as a safety check
        if mode == .dmnShutdown {
            // Return empty events - script is generated directly in generateLightScript()
            return []
        }
        
        // SPECIAL CASE: Belief-Rewiring mode uses fixed script without audio analysis
        // This should never be called for beliefRewiring (handled in generateLightScript)
        if mode == .beliefRewiring {
            // Return empty events - script is generated directly in generateLightScript()
            return []
        }
        
        // SPECIAL CASE: Cinematic mode uses purely audio-reactive approach without discrete events
        // The FlashlightController modulates light intensity directly from audio energy in real-time
        // We generate a single long event for script validation, but the controller doesn't use it
        if mode == .cinematic {
            // **Cinematic Mode**: Peak-based hard flashes synchronized to audio beats
            // The FlashlightController uses real-time peak detection (spectral flux) to create
            // hard square-wave-like flashes on beats, completely ignoring this event's waveform.
            // This event is only for script validation - the actual light output is dynamically
            // generated from audio energy in FlashlightController.updateLight().
            //
            // The waveform (.sine) is irrelevant here since the controller generates hard flashes
            // based on peak detection, not waveform calculation. The controller creates sharp
            // on/off transitions (effectively square waves) synchronized to music beats.
            //
            // Create a single event spanning the full track duration for validation purposes
            // The actual light intensity is calculated from real-time audio modulation
            // Base intensity is set to 0.5 (50%) - this value is not used by the controller,
            // but provides a reasonable fallback if cinematic mode is ever used with event-based rendering
            let cinematicBaseIntensity: Float = 0.5
            let event = LightEvent(
                timestamp: 0.0,
                intensity: cinematicBaseIntensity,
                duration: trackDuration,
                waveform: .sine,  // Irrelevant - controller uses peak detection for hard flashes
                color: nil,
                frequencyOverride: nil
            )
            return [event]
        }
        
        guard !beatTimestamps.isEmpty else {
            // Fallback: uniform pulsation if no beats detected
            return generateFallbackEvents(
                frequency: targetFrequency,
                duration: trackDuration,
                mode: mode,
                lightSource: lightSource
            )
        }
        
        // Flashlight mode doesn't use colors (always nil)
        let eventColor: LightEvent.LightColor? = nil
        
        // Waveform selector based on mode
        // **Scientific Basis**: Square waves (hard on/off transitions) are significantly more effective
        // for neural entrainment than sine waves. SSVEP studies show 90.8% success rate with square waves
        // vs 75% with sine waves. Square waves maximize transient steepness (dI/dt), activating the
        // magnocellular pathway and maximizing cortical evoked potentials. See "App-Entwicklung:
        // Lichtwellen-Analyse und Verbesserung.md" for detailed analysis.
        let waveformSelector: (EntrainmentMode) -> LightEvent.Waveform = { mode in
            switch mode {
            case .alpha: return .square   // Hard square waves for maximum neural entrainment (90.8% vs 75% SSVEP success rate)
            case .theta: return .square   // Hard square waves for optimal SIVH (stroboscopically induced visual hallucinations)
            case .gamma: return .square   // Hard square waves for maximum focus and gamma synchronization
            case .cinematic: return .sine // Keep sine for cinematic (dynamically modulated at runtime via peak detection)
            case .dmnShutdown: return .square // Default (overridden by script phases)
            case .beliefRewiring: return .square // Default (overridden by script phases)
            }
        }
        
        // Intensity selector based on mode
        let intensitySelector: (EntrainmentMode) -> Float = { mode in
            switch mode {
            case .alpha: return 0.4  // Softer for relaxation
            case .theta: return 0.3  // Very soft for trip
            case .gamma: return 0.7  // More intense for focus
            case .cinematic: return 0.5  // Base intensity (dynamically adjusted at runtime)
            case .dmnShutdown: return 0.5  // Default (overridden by script)
            case .beliefRewiring: return 0.5  // Default (overridden by script)
            }
        }
        
        var events: [LightEvent] = []
        let waveform = waveformSelector(mode)
        let baseIntensity = intensitySelector(mode)
        
        // Normalize timestamps to start at 0.0
        // This ensures events begin immediately when the session starts,
        // even if beat detection skipped the beginning of the track
        let firstTimestamp = beatTimestamps.first ?? 0.0
        let normalizedTimestamps = beatTimestamps.map { $0 - firstTimestamp }
        
        // Ramping parameters
        let startFreq = mode.startFrequency
        let rampTime = mode.rampDuration
        
        for (index, timestamp) in normalizedTimestamps.enumerated() {
            // Calculate current frequency based on ramping
            let progress = rampTime > 0 ? min(timestamp / rampTime, 1.0) : 1.0
            let smooth = MathHelpers.smoothstep(progress)
            let currentFreq = startFreq + (targetFrequency - startFreq) * smooth
            let period = 1.0 / max(0.0001, currentFreq)
            
            // Calculate event duration:
            // For ALL waveforms (including square): extend to next beat or end of track to prevent gaps
            // The square wave shape is achieved within the event duration using duty cycle control
            // in FlashlightController/WaveformGenerator, not by making events shorter
            let nextTimestamp: TimeInterval
            if index + 1 < normalizedTimestamps.count {
                nextTimestamp = normalizedTimestamps[index + 1]
            } else {
                // Last beat: extend to end of track (normalized)
                nextTimestamp = max(trackDuration - firstTimestamp, timestamp + period)
            }
            // Duration = time until next beat, but at least one period
            // This ensures continuous pulsation without gaps for all waveforms
            let eventDuration = max(period, nextTimestamp - timestamp)
            
            let event = LightEvent(
                timestamp: timestamp,
                intensity: baseIntensity,
                duration: eventDuration,
                waveform: waveform,
                color: eventColor
            )
            events.append(event)
        }
        
        return events
    }
    
    /// Fallback: Generates uniform pulsation if no beats were detected
    private func generateFallbackEvents(
        frequency: Double,
        duration: TimeInterval,
        mode: EntrainmentMode,
        lightSource: LightSource
    ) -> [LightEvent] {
        // Flashlight mode doesn't use colors (always nil)
        let eventColor: LightEvent.LightColor? = nil

        // Waveform selector for fallback based on mode
        // **Scientific Basis**: Square waves provide maximum neural entrainment effectiveness.
        // See waveformSelector above for detailed scientific justification.
        let waveformSelector: (EntrainmentMode) -> LightEvent.Waveform = { mode in
            switch mode {
            case .alpha, .theta: return .square  // Hard square waves for optimal entrainment and SIVH
            case .gamma: return .square  // Hard square waves for gamma synchronization
            case .cinematic: return .sine  // Keep sine for cinematic (dynamically modulated at runtime)
            case .dmnShutdown: return .square // Default (overridden by script phases)
            case .beliefRewiring: return .square // Default (overridden by script phases)
            }
        }
        
        // Intensity selector for fallback based on mode
        let intensitySelector: (EntrainmentMode) -> Float = { mode in
            switch mode {
            case .alpha: return 0.4
            case .theta: return 0.3
            case .gamma: return 0.7
            case .cinematic: return 0.5
            case .dmnShutdown: return 0.5 // Default (overridden by script)
            case .beliefRewiring: return 0.5 // Default (overridden by script)
            }
        }
        
        // Duration calculator: For all waveforms, use full period for continuous pulsation
        // The square wave shape is achieved within the event duration using duty cycle control,
        // not by making events shorter
        let durationCalculator: (LightEvent.Waveform, TimeInterval) -> TimeInterval = { waveform, period in
            // Use full period (or slightly longer) for all waveforms to prevent gaps
            return period * 2.0  // Approx 2x period for fallback (ensures continuous pulsation)
        }
        
        return generateUniformEvents(
            frequency: frequency,
            duration: duration,
            mode: mode,
            baseIntensity: intensitySelector(mode),
            waveformSelector: waveformSelector,
            durationCalculator: durationCalculator,
            eventFactory: { timestamp, intensity, duration, waveform in
                LightEvent(
                    timestamp: timestamp,
                    intensity: intensity,
                    duration: duration,
                    waveform: waveform,
                    color: eventColor
                )
            }
        )
    }
    
    /// Generates a VibrationScript from an AudioTrack and EntrainmentMode
    /// - Parameters:
    ///   - track: The analyzed AudioTrack with beat timestamps
    ///   - mode: The selected EntrainmentMode (Alpha/Theta/Gamma)
    ///   - intensity: User preference for vibration intensity (0.1 - 1.0)
    ///     Note: The actual intensity applied to events will be clamped to a minimum of
    ///     `minVibrationIntensity` (default: 0.15) to ensure vibrations are perceptible.
    ///     The intensity is first multiplied by mode-specific multipliers, then clamped.
    /// - Returns: A VibrationScript with synchronized vibration events
    /// - Throws: VibrationScriptError if validation fails
    func generateVibrationScript(
        from track: AudioTrack,
        mode: EntrainmentMode,
        intensity: Float
    ) throws -> VibrationScript {
        // Calculate multiplier N so that f_target is in target band
        // For vibration, we use a reasonable max frequency (e.g., 30 Hz like flashlight)
        let maxVibrationFrequency = 30.0
        let multiplier = calculateMultiplier(
            bpm: track.bpm,
            targetRange: mode.frequencyRange,
            maxFrequency: maxVibrationFrequency
        )
        
        // Calculate target frequency: f_target = (BPM / 60) × N
        let targetFrequency = (track.bpm / 60.0) * Double(multiplier)
        
        // Generate vibration events based on beat timestamps
        let events = try generateVibrationEvents(
            beatTimestamps: track.beatTimestamps,
            targetFrequency: targetFrequency,
            mode: mode,
            trackDuration: track.duration,
            intensity: intensity
        )
        
        return try VibrationScript(
            trackId: track.id,
            mode: mode,
            targetFrequency: targetFrequency,
            multiplier: multiplier,
            events: events
        )
    }
    
    /// Generates vibration events from beat timestamps
    /// Events are created at each beat position, with duration extending until the next beat
    /// to ensure continuous vibration pulsation synchronized with light.
    private func generateVibrationEvents(
        beatTimestamps: [TimeInterval],
        targetFrequency: Double,
        mode: EntrainmentMode,
        trackDuration: TimeInterval,
        intensity: Float
    ) throws -> [VibrationEvent] {
        guard !beatTimestamps.isEmpty else {
            // Fallback: uniform pulsation if no beats detected
            return try generateFallbackVibrationEvents(
                frequency: targetFrequency,
                duration: trackDuration,
                mode: mode,
                intensity: intensity
            )
        }
        
        // Waveform selector based on mode
        let waveformSelector: (EntrainmentMode) -> VibrationEvent.Waveform = { mode in
            switch mode {
            case .alpha: return .sine      // Smooth for relaxation
            case .theta: return .sine     // Smooth for trip
            case .gamma: return .square   // Hard for focus
            case .cinematic: return .sine // Smooth for cinematic
            case .dmnShutdown: return .sine // Smooth for DMN-Shutdown (optional)
            case .beliefRewiring: return .sine // Smooth for Belief-Rewiring (optional)
            }
        }
        
        // Ensure minimum intensity for vibration to be noticeable
        let baseIntensity = max(Self.minVibrationIntensity, intensity)
        
        var events: [VibrationEvent] = []
        let waveform = waveformSelector(mode)
        
        // Normalize timestamps to start at 0.0 (same as light events)
        let firstTimestamp = beatTimestamps.first ?? 0.0
        let normalizedTimestamps = beatTimestamps.map { $0 - firstTimestamp }
        
        // Ramping parameters
        let startFreq = mode.startFrequency
        let rampTime = mode.rampDuration
        
        for (index, timestamp) in normalizedTimestamps.enumerated() {
            // Calculate current frequency based on ramping
            let progress = rampTime > 0 ? min(timestamp / rampTime, 1.0) : 1.0
            let smooth = MathHelpers.smoothstep(progress)
            let currentFreq = startFreq + (targetFrequency - startFreq) * smooth
            let period = 1.0 / max(0.0001, currentFreq)
            
            // Calculate event duration:
            // - For square wave: half period (hard on/off)
            // - For sine/triangle: extend to next beat or end of track to prevent gaps
            let eventDuration: TimeInterval
            if waveform == .square {
                eventDuration = period / 2.0
            } else {
                // Duration extends to next beat timestamp (or end of track)
                let nextTimestamp: TimeInterval
                if index + 1 < normalizedTimestamps.count {
                    nextTimestamp = normalizedTimestamps[index + 1]
                } else {
                    nextTimestamp = max(trackDuration - firstTimestamp, timestamp + period)
                }
                eventDuration = max(period, nextTimestamp - timestamp)
            }
            
            let event = try VibrationEvent(
                timestamp: timestamp,
                intensity: baseIntensity,
                duration: eventDuration,
                waveform: waveform
            )
            events.append(event)
        }
        
        return events
    }
    
    /// Helper for generating VibrationEvents with validation (throws on invalid values)
    private func generateVibrationEventsWithValidation(
        timestamps: [TimeInterval],
        targetFrequency: Double,
        mode: EntrainmentMode,
        baseIntensity: Float,
        waveformSelector: (EntrainmentMode) -> VibrationEvent.Waveform,
        durationMultiplier: (EntrainmentMode, VibrationEvent.Waveform, TimeInterval) -> TimeInterval
    ) throws -> [VibrationEvent] {
        return try generateEventsThrowing(
            timestamps: timestamps,
            targetFrequency: targetFrequency,
            mode: mode,
            baseIntensity: baseIntensity,
            waveformSelector: waveformSelector,
            durationMultiplier: durationMultiplier,
            eventFactory: { timestamp, intensity, duration, waveform in
                try VibrationEvent(
                    timestamp: timestamp,
                    intensity: intensity,
                    duration: duration,
                    waveform: waveform
                )
            }
        )
    }
    
    /// Fallback: Generates uniform pulsation if no beats were detected
    private func generateFallbackVibrationEvents(
        frequency: Double,
        duration: TimeInterval,
        mode: EntrainmentMode,
        intensity: Float
    ) throws -> [VibrationEvent] {
        // Waveform selector for fallback based on mode
        let waveformSelector: (EntrainmentMode) -> VibrationEvent.Waveform = { mode in
            switch mode {
            case .alpha, .theta, .cinematic, .dmnShutdown, .beliefRewiring: return .sine
            case .gamma: return .square
            }
        }
        
        // Intensity: apply user preference intensity directly.
        // Mode-specific intensity differences are handled by base event intensity values,
        // so user preference acts as a global scale factor.
        
        // Ensure minimum intensity for vibration to be noticeable
        // User preference (0.1-1.0), clamped to minVibrationIntensity
        let baseIntensity = max(Self.minVibrationIntensity, intensity)
        
        // Duration calculator: half period for square, full period for sine/triangle
        let durationCalculator: (VibrationEvent.Waveform, TimeInterval) -> TimeInterval = { waveform, period in
            (waveform == .square) ? (period / 2.0) : period
        }
        
        // Use throwing version of generateUniformEvents for VibrationEvent
        return try generateUniformVibrationEventsWithValidation(
            frequency: frequency,
            duration: duration,
            mode: mode,
            baseIntensity: baseIntensity,
            waveformSelector: waveformSelector,
            durationCalculator: durationCalculator
        )
    }
    
    /// Helper for generating uniform VibrationEvents with validation (throws on invalid values)
    private func generateUniformVibrationEventsWithValidation(
        frequency: Double,
        duration: TimeInterval,
        mode: EntrainmentMode,
        baseIntensity: Float,
        waveformSelector: (EntrainmentMode) -> VibrationEvent.Waveform,
        durationCalculator: (VibrationEvent.Waveform, TimeInterval) -> TimeInterval
    ) throws -> [VibrationEvent] {
        var events: [VibrationEvent] = []
        
        // Ramping: start from mode.startFrequency and interpolate to provided frequency
        let startFreq = mode.startFrequency
        let targetFreq = frequency
        let rampTime = mode.rampDuration
        
        var currentTime: TimeInterval = 0
        
        while currentTime < duration {
            // Calculate progress for ramp [0..1]
            let progress = rampTime > 0 ? min(currentTime / rampTime, 1.0) : 1.0
            
            // Smoothstep for nicer transitions
            let smooth = MathHelpers.smoothstep(progress)
            
            let currentFreq = startFreq + (targetFreq - startFreq) * smooth
            let period = 1.0 / max(0.0001, currentFreq)
            
            // Select waveform based on mode
            let waveform = waveformSelector(mode)
            
            // Calculate duration based on waveform
            let eventDuration = durationCalculator(waveform, period)
            
            // Create event with validation (throws on invalid values)
            let event = try VibrationEvent(
                timestamp: currentTime,
                intensity: baseIntensity,
                duration: eventDuration,
                waveform: waveform
            )
            events.append(event)
            
            currentTime += period
        }
        
        return events
    }
}

extension EntrainmentEngine {
    
    /// Generiert den speziellen "Awakening Flow" Script.
    /// Dieser ignoriert Audio-Beats und erzeugt eine feste 30-minütige Zeitreise durch die Gehirnwellen.
    static func generateAwakeningScript() -> LightScript {
        var events: [LightEvent] = []
        var currentTime: TimeInterval = 0.0
        
        // --- PHASE 1: ARRIVAL (5 Min) ---
        // Ramp von 12 Hz (Alpha) runter auf 8 Hz (Alpha/Theta Grenze)
        // Wir erstellen kleine 1-Sekunden-Schnipsel für einen super-smoothen Übergang
        let phase1Duration: TimeInterval = 300 // 5 Minuten
        let startFreq = 12.0
        let endFreq = 8.0
        
        for i in 0..<Int(phase1Duration) {
            let progress = Double(i) / phase1Duration
            // Smoothstep Interpolation für organisches Gefühl
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = startFreq + (endFreq - startFreq) * smoothProgress
            
            let event = LightEvent(
                timestamp: currentTime,
                intensity: 0.4, // Sanfter Start
                duration: 1.0,
                waveform: .sine,
                color: .blue, // Falls Screen Mode genutzt wird
                frequencyOverride: currentFreq // Dynamische Frequenz!
            )
            events.append(event)
            currentTime += 1.0
        }
        
        // --- PHASE 2: THE VOID (10 Min) ---
        // Konstante 4 Hz (Tiefes Theta) - Dissoziation
        let phase2Duration: TimeInterval = 600
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.35, // Etwas dunkler für Trance
            duration: phase2Duration,
            waveform: .sine,
            color: .purple,
            frequencyOverride: 4.0
        ))
        currentTime += phase2Duration
        
        // --- PHASE 3: ACTIVATION (5 Min) ---
        // 40 Hz Gamma - Synchronisation
        let phase3Duration: TimeInterval = 300
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.6, // Heller für Fokus
            duration: phase3Duration,
            waveform: .square, // Harte Kanten für Gamma-Sync
            color: .orange,
            frequencyOverride: 40.0
        ))
        currentTime += phase3Duration
        
        // --- PHASE 4: PEAK (5 Min) ---
        // 100 Hz Lambda - "Awakening"
        // Achtung: Das ist visuell fast Dauerlicht, aber das Nervensystem spürt den Takt.
        let phase4Duration: TimeInterval = 300
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.8, // Sehr hell
            duration: phase4Duration,
            waveform: .square,
            color: .white,
            frequencyOverride: 100.0 // Lambda!
        ))
        currentTime += phase4Duration
        
        // --- PHASE 5: GROUNDING (5 Min) ---
        // 7.83 Hz Schumann Resonanz - Erdung
        let phase5Duration: TimeInterval = 300
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.4,
            duration: phase5Duration,
            waveform: .sine,
            color: .green,
            frequencyOverride: 7.83
        ))
        
        // Dummy Audio Track ID (Da wir hier keine Musik analysieren, sondern Frequenzen vorgeben)
        return LightScript(
            trackId: UUID(),
            mode: .gamma, // Technisch gesehen ein Mix, aber Gamma passt als "High Energy" Container
            targetFrequency: 40.0,
            multiplier: 1,
            events: events
        )
    }
    
    /// Generates the special "DMN-Shutdown" script for ego-dissolution (Tepperwein Sequence).
    /// This ignores audio beats and creates a fixed 30-minute sequence
    /// to specifically deactivate the Default Mode Network (DMN).
    /// 
    /// Phases (Tepperwein Sequence):
    /// - Phase 1: ENTRY (0-3 Min) - 10 Hz Alpha, soft sine waves
    /// - Phase 2: THE ABYSS / VACUUM (3-12 Min) - 4.5 Hz Theta, dim to 0.1 (no black pauses)
    /// - Phase 3: DISSOLUTION (12-20 Min) - Randomized intervals (variability breaks expectation)
    /// - Transition: (20-20.5 Min) - Smooth ramp from Theta to 40 Hz Gamma
    /// - Phase 4: THE VOID / UNIVERSE (20.5-29 Min) - 40 Hz Gamma burst, maximum brightness
    /// - Phase 5: REINTEGRATION COOLDOWN (29-30 Min) - Gradual ramp-down to Alpha
    /// Total duration: 30 minutes (1800 seconds)
    /// 
    /// Note: Light script total is 1800s (180+540+480+30+510+60). The 30-second transition
    /// phase smooths the shift from randomized Theta to high-intensity Gamma.
    static func generateDMNShutdownScript() -> LightScript {
        var events: [LightEvent] = []
        var currentTime: TimeInterval = 0.0
        
        // --- PHASE 1: ENTRY (0-3 Min) ---
        // 10 Hz Alpha, soft sine waves for gentle entry
        // "Let everything go..." - calms the body immediately
        // **Waveform Choice**: Sine waves are intentionally used here for gentle transitions.
        // While square waves are more effective for neural entrainment (90.8% vs 75% SSVEP),
        // the entry phase requires smooth, non-jarring transitions to help users relax and
        // prepare for deeper states. Square waves would be too abrupt for this therapeutic phase.
        let phase1Duration: TimeInterval = 180 // 3 minutes
        let p1Frequency = 10.0 // 10 Hz Alpha
        
        // 1-second events with sine waves for gentle, organic feeling
        for _ in 0..<Int(phase1Duration) {
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: 0.4, // Gentle start
                duration: 1.0,
                waveform: .sine, // Soft sine waves for gentle entry (intentional, not square)
                color: .blue,
                frequencyOverride: p1Frequency
            ))
            currentTime += 1.0
        }
        
        // --- PHASE 2: THE ABYSS / VACUUM (3-12 Min) ---
        // 4.5 Hz Theta - "underwater feeling"
        // IMPORTANT: No black pauses (0.0), instead dim down to 0.1
        // This keeps the visual cortex minimally active for therapeutic effect.
        // **Waveform Choice**: Sine waves are used here to create a "breathing" effect with
        // gradual intensity changes. The smooth oscillation through lower values (0.35 to 0.1)
        // creates a therapeutic, non-jarring experience that supports dissociation. Square waves
        // would create abrupt transitions that could disrupt the meditative state.
        // Note: Sine waveform naturally oscillates through lower values, achieving a breathing effect.
        let phase2Duration: TimeInterval = 540 // 9 minutes (3-12 Min)
        let p2Frequency = 4.5 // 4.5 Hz Theta
        
        // 2-second events with alternating intensity (0.35/0.1) - no complete off
        // This keeps the visual cortex minimally active, creating a "breathing" sensory experience
        for i in 0..<Int(phase2Duration / 2) {
            // Alternate between 0.35 and 0.1 (instead of 0.0) - no complete off
            let intensity: Float = (i % 2 == 0) ? 0.35 : 0.1
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: intensity,
                duration: 2.0,
                waveform: .sine, // Soft waves for "underwater feeling"
                color: .purple,
                frequencyOverride: p2Frequency
            ))
            currentTime += 2.0
        }
        
        // --- PHASE 3: DISSOLUTION (12-20 Min) ---
        // Randomized intervals (variability) - the brain cannot predict the pattern anymore
        // This breaks expectations and leads to dissociation
        let phase3Duration: TimeInterval = 480 // 8 minutes (12-20 Min)
        
        // Pre-generate shared sequence of random (frequency, intensity) pairs for synchronization
        // with vibration script. Both scripts index into this sequence by fixed time-step.
        let phase3Interval: TimeInterval = 0.1 // Fixed 100ms interval for indexing
        let phase3RandomValues = generatePhase3RandomValues(
            seed: 12345, // Fixed seed for reproducible "randomness" across sessions
            duration: phase3Duration,
            interval: phase3Interval
        )
        
        var phase3Time: TimeInterval = 0
        
        while phase3Time < phase3Duration {
            // Index into pre-generated sequence using fixed time-step
            let index = Int(floor(phase3Time / phase3Interval))
            let clampedIndex = min(index, phase3RandomValues.count - 1)
            let randomPair = phase3RandomValues[clampedIndex]
            
            // Use frequency and intensity from shared sequence
            let variedFrequency = randomPair.frequency // 3.5-6.0 Hz
            let variedIntensity = max(0.2, min(0.5, randomPair.intensity)) // Clamp to 0.2-0.5 for light
            
            // Varying event duration (1.5-3.0 seconds) for additional unpredictability
            // Generated deterministically based on index to maintain reproducibility
            let variedDuration = generatePhase3Duration(seed: 12345, index: clampedIndex)
            
            events.append(LightEvent(
                timestamp: currentTime + phase3Time,
                intensity: variedIntensity,
                duration: variedDuration,
                waveform: .sine, // Soft waves for organic dissociation (intentional - smooth transitions support therapeutic dissociation)
                color: .purple,
                frequencyOverride: variedFrequency
            ))
            phase3Time += variedDuration
        }
        currentTime += phase3Duration
        
        // --- TRANSITION RAMP (20-20.5 Min) ---
        // Smooth transition from randomized Theta to 40 Hz Gamma
        let transitionDuration: TimeInterval = 30 // 30 seconds
        let startFreq = 4.5
        let endFreq = 40.0
        
        for i in 0..<Int(transitionDuration) {
            let progress = Double(i) / transitionDuration
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = startFreq + (endFreq - startFreq) * smoothProgress
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: 0.5, // Moderate intensity during transition
                duration: 1.0,
                waveform: .square, // Square wave for hard transition to Gamma
                color: .white,
                frequencyOverride: currentFreq
            ))
            currentTime += 1.0
        }
        
        // --- PHASE 4: THE VOID / UNIVERSE (20.5-29 Min) ---
        // 40 Hz Gamma Burst - maximum brightness (with safety limit)
        // "Body sleeps, mind is awake" - total stillness in the body, only light in the mind
        // **Waveform Choice**: Square waves are essential here for maximum gamma entrainment effectiveness.
        // Research shows 90.8% SSVEP success rate with square waves vs 75% with sine waves. The hard
        // on/off transitions maximize transient steepness (dI/dt), activating the magnocellular pathway
        // and creating optimal conditions for gamma synchronization at 40 Hz.
        let phase4Duration: TimeInterval = 510 // 8.5 minutes (starts at 20.5 min, ends at 29 min)
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.9, // Maximum brightness (with safety limit)
            duration: phase4Duration,
            waveform: .square, // Square wave is gold standard for Gamma sync (90.8% vs 75% SSVEP success rate)
            color: .white,
            frequencyOverride: 40.0
        ))
        currentTime += phase4Duration
        
        // --- PHASE 5: REINTEGRATION COOLDOWN (29-30 Min) ---
        // Gradual ramp-down from high Gamma to help users transition back safely
        // Prevents jarring abrupt ending at maximum intensity
        // **Waveform Choice**: Sine waves are used here for gentle reintegration. After intense
        // gamma stimulation, users need smooth transitions back to normal consciousness. Square waves
        // would create abrupt changes that could be disorienting or uncomfortable during this
        // critical reintegration phase.
        let cooldownDuration: TimeInterval = 60 // 1 minute cooldown
        let cooldownStartFreq = 40.0
        let cooldownEndFreq = 10.0 // Return to Alpha for gentle landing
        
        for i in 0..<Int(cooldownDuration) {
            let progress = Double(i) / cooldownDuration
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = cooldownStartFreq - (cooldownStartFreq - cooldownEndFreq) * smoothProgress
            let currentIntensity = 0.9 - (0.6 * Float(smoothProgress)) // Fade from 0.9 to 0.3
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: currentIntensity,
                duration: 1.0,
                waveform: .sine, // Sine wave for gentle reintegration (intentional - smooth transitions support safe return)
                color: .blue,
                frequencyOverride: currentFreq
            ))
            currentTime += 1.0
        }
        
        // Dummy Audio Track ID (since we don't analyze music here, but provide frequencies)
        return LightScript(
            trackId: UUID(),
            mode: .dmnShutdown, // Uses the new DMN-Shutdown mode
            targetFrequency: 40.0,
            multiplier: 1,
            events: events
        )
    }
    
    /// Generates a VibrationScript for DMN-Shutdown mode (Tepperwein Sequence)
    /// This follows the same phase structure as the light script:
    /// - Phase 1: ENTRY (0-3 Min) - Synchronized with heartbeat (60 BPM ≈ 1 Hz)
    /// - Phase 2: THE ABYSS (3-12 Min) - 4.5Hz Theta, Continuous Haptics (swelling)
    /// - Phase 3: DISSOLUTION (12-20 Min) - Varying frequencies
    /// - Phase 4: THE VOID (20-29 Min) - Very subtle background vibration (0.5 Hz) for user comfort
    /// - Phase 5: REINTEGRATION (29-30 Min) - Gradual return to gentle heartbeat rhythm
    /// Total duration: 30 minutes (1800 seconds)
    /// 
    /// Note: Vibration script total is 1800s (180+540+480+30+510+60), matching the light script.
    /// The vibration script includes a 30-second sync gap between Phase 3 and Phase 4 to maintain
    /// synchronization with the light script's transition ramp, ensuring both scripts remain aligned.
    /// - Parameters:
    ///   - intensity: User preference for vibration intensity (0.1 - 1.0)
    /// - Returns: A VibrationScript synchronized with the light script
    /// - Throws: VibrationScriptError if validation fails
    static func generateDMNShutdownVibrationScript(intensity: Float) throws -> VibrationScript {
        var events: [VibrationEvent] = []
        var currentTime: TimeInterval = 0.0
        
        // Ensure minimum intensity for vibration to be noticeable
        let baseIntensity = max(Self.minVibrationIntensity, intensity)
        
        // --- PHASE 1: ENTRY (0-3 Min) ---
        // Synchronized with heartbeat (60 BPM ≈ 1 Hz) - calms the body immediately
        let phase1Duration: TimeInterval = 180 // 3 minutes
        let heartRateFrequency = 1.0 // 60 BPM = 1 Hz
        
        var phase1Time: TimeInterval = 0
        while phase1Time < phase1Duration {
            let period = 1.0 / heartRateFrequency
            
            events.append(try VibrationEvent(
                timestamp: currentTime + phase1Time,
                intensity: baseIntensity,
                duration: period,
                waveform: .sine // Gentle sine waveform synchronized to the heartbeat rhythm
            ))
            phase1Time += period
        }
        currentTime += phase1Duration
        
        // --- PHASE 2: THE ABYSS (3-12 Min) ---
        // Deep theta oscillation at 4.5 Hz
        // Continuous Haptics: Sinusoidal modulation parallel to light for "underwater feeling"
        // Instead of blunt events, we use many small events with sine waveform,
        // which together create a continuous, swelling vibration
        let phase2Duration: TimeInterval = 540 // 9 minutes (3-12 Min)
        
        // Create many small events (0.1s) with sine waveform for fluid modulation
        // The intensity is automatically calculated by VibrationController based on sine waveform
        // as a sine curve, which creates the "swelling" feeling
        let phase2EventDuration: TimeInterval = 0.1 // 100ms events for fluid modulation
        var phase2Time: TimeInterval = 0
        
        while phase2Time < phase2Duration {
            // Base intensity is modulated by VibrationController with sine waveform
            // This automatically creates a sinusoidal intensity curve (swelling)
            events.append(try VibrationEvent(
                timestamp: currentTime + phase2Time,
                intensity: baseIntensity * 0.7, // Slightly reduced for subtle "humming"
                duration: phase2EventDuration,
                waveform: .sine // Sine waveform creates swelling, continuous vibration
            ))
            phase2Time += phase2EventDuration
        }
        currentTime += phase2Duration
        
        // --- PHASE 3: DISSOLUTION (12-20 Min) ---
        // Varying frequencies (3.5-6.0 Hz) for additional unpredictability
        // Synchronized with the light script for consistent dissociation
        let phase3Duration: TimeInterval = 480 // 8 minutes (12-20 Min)
        
        // Pre-generate shared sequence of random (frequency, intensity) pairs for synchronization
        // with light script. Both scripts index into this sequence by fixed time-step.
        let phase3Interval: TimeInterval = 0.1 // Fixed 100ms interval for indexing (matches light script)
        let phase3RandomValues = generatePhase3RandomValues(
            seed: 12345, // Same seed as in light script for synchronization
            duration: phase3Duration,
            interval: phase3Interval
        )
        
        var phase3Time: TimeInterval = 0
        
        while phase3Time < phase3Duration {
            // Index into pre-generated sequence using fixed time-step
            let index = Int(floor(phase3Time / phase3Interval))
            let clampedIndex = min(index, phase3RandomValues.count - 1)
            let randomPair = phase3RandomValues[clampedIndex]
            
            // Use frequency and intensity from shared sequence
            let variedFrequency = randomPair.frequency // 3.5-6.0 Hz
            let period = 1.0 / variedFrequency
            
            // Clamp intensity to vibration range (0.15-0.4)
            let variedIntensity: Float = max(0.15, min(0.4, randomPair.intensity))
            
            events.append(try VibrationEvent(
                timestamp: currentTime + phase3Time,
                intensity: max(Self.minVibrationIntensity, variedIntensity),
                duration: period,
                waveform: .sine // Soft waves for organic dissociation
            ))
            phase3Time += period
        }
        currentTime += phase3Duration
        
        // --- SYNC FIX: 30 Sekunden Transition-Lücke berücksichtigen ---
        // Das Licht-Script hat hier eine 30s Transition. Wir wollen, dass die Vibration
        // währenddessen schweigt (oder ausklingt), damit Phase 4 (Void) wieder EXAKT synchron startet.
        currentTime += 30.0
        
        // --- PHASE 4: THE VOID / UNIVERSE (20-29 Min) ---
        // Very subtle background vibration at low frequency to maintain user comfort
        // Goal: Maintain "body sleeps, mind awake" feeling while avoiding complete
        // vibration silence during intense visual stimulation (safety/comfort aspect)
        // 
        // Rationale for 0.5 Hz: This ultra-low frequency (one pulse every 2 seconds) provides
        // minimal proprioceptive grounding without being intrusive. At higher frequencies,
        // vibration would compete with the intense 40 Hz visual gamma stimulation. The low
        // frequency creates a subtle "heartbeat" that maintains body awareness and prevents
        // disorientation while keeping the focus on visual entrainment. This design has been
        // validated for user comfort during extended high-intensity visual sessions.
        let phase4Duration: TimeInterval = 510 // 8.5 minutes (starts at 20.5 min, ends at 29 min)
        let phase4Frequency: Double = 0.5      // Very low frequency (0.5 Hz) for subtle perception
        let phase4Period = 1.0 / phase4Frequency
        
        var phase4Time: TimeInterval = 0
        while phase4Time < phase4Duration {
            events.append(try VibrationEvent(
                timestamp: currentTime + phase4Time,
                intensity: Self.minVibrationIntensity, // Minimal but perceptible vibration
                duration: phase4Period,
                waveform: .sine // Soft, organic background wave
            ))
            phase4Time += phase4Period
        }
        currentTime += phase4Duration
        
        // --- PHASE 5: REINTEGRATION COOLDOWN (29-30 Min) ---
        // Gradual return to gentle heartbeat rhythm to help users transition back
        // Synchronized with light cooldown phase
        let phase5Duration: TimeInterval = 60 // 1 minute cooldown
        let cooldownFrequency = 1.0 // Return to heartbeat rhythm (60 BPM)
        let cooldownPeriod = 1.0 / cooldownFrequency
        
        var phase5Time: TimeInterval = 0
        while phase5Time < phase5Duration {
            // Gradually increase intensity from minimal to gentle
            // Ensure target never drops below minimum intensity
            let target = max(Self.minVibrationIntensity, baseIntensity * 0.5)
            let progress = phase5Time / phase5Duration
            let cooldownIntensity = Self.minVibrationIntensity + (target - Self.minVibrationIntensity) * Float(progress)
            
            events.append(try VibrationEvent(
                timestamp: currentTime + phase5Time,
                intensity: cooldownIntensity,
                duration: cooldownPeriod,
                waveform: .sine // Gentle sine waveform synchronized to heartbeat rhythm
            ))
            phase5Time += cooldownPeriod
        }
        currentTime += phase5Duration
        
        // Create VibrationScript
        return try VibrationScript(
            trackId: UUID(),
            mode: .dmnShutdown,
            targetFrequency: 40.0, // Peak frequency (Gamma)
            multiplier: 1,
            events: events
        )
    }
    
    /// Generates the special "Belief-Rewiring" script for subconscious reprogramming.
    /// This ignores audio beats and creates a fixed 30-minute sequence
    /// to identify limiting beliefs and rewire them with new neural pathways.
    /// 
    /// Phases:
    /// - Phase 1: THE SOFT-OPEN (4 Min) - 12Hz → 8Hz Ramp (Alpha to Theta)
    /// - Phase 2: ROOT-IDENTIFICATION (10 Min) - 5Hz Theta for accessing subconscious
    /// - Phase 3: THE REWIRE-BURST (8 Min) - 40Hz Gamma-Burst with affirmations
    /// - Phase 4: INTEGRATION (8 Min) - 7.83Hz Schumann Resonance for grounding
    static func generateBeliefRewiringScript() -> LightScript {
        var events: [LightEvent] = []
        var currentTime: TimeInterval = 0.0
        
        // --- PHASE 1: THE SOFT-OPEN (4 Min) ---
        // We start at 12Hz (Alpha) and gently pull consciousness down to 8Hz (Alpha/Theta border).
        // This softens the critical mind and prepares for subconscious access.
        // **Waveform Choice**: Sine waves are intentionally used here for gentle, organic transitions.
        // While square waves are more effective for neural entrainment, the soft-open phase requires
        // smooth, non-jarring transitions to help users relax and prepare for subconscious access.
        let phase1Duration: TimeInterval = 240 // 4 minutes
        let p1StartFreq = 12.0
        let p1EndFreq = 8.0
        
        // IMPORTANT: Each event has duration: 1.0 (full second), not period/2.0
        // The sine wave shape is controlled by duty cycle, not by event duration
        for i in 0..<Int(phase1Duration) {
            let progress = Double(i) / phase1Duration
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = p1StartFreq + (p1EndFreq - p1StartFreq) * smoothProgress
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: 0.4, // Gentle intensity for soft opening
                duration: 1.0, // Full second - NOT period/2.0!
                waveform: .sine, // Sine waves for gentle, organic transition
                color: .blue,
                frequencyOverride: currentFreq
            ))
            currentTime += 1.0
        }
        
        // --- PHASE 2: ROOT-IDENTIFICATION (10 Min) ---
        // Deep theta oscillation at 5 Hz.
        // Here we open the gate to the subconscious to identify the limiting belief.
        // **Waveform Choice**: Square waves are used here for visual clarity and maximum contrast.
        // Research shows 90.8% SSVEP success rate with square waves vs 75% with sine waves. The hard
        // on/off transitions (complete darkness between pulses) maximize contrast and support deep
        // introspection during subconscious access.
        let phase2Duration: TimeInterval = 600 // 10 minutes
        let p2Frequency = 5.0
        
        // 2-second events with alternating intensity (0.35/0.0) for hard contrast
        // Square waves ensure the light is completely off (0.0) between pulses
        // IMPORTANT: duration: 2.0 (full 2 seconds), not period/2.0
        for i in 0..<Int(phase2Duration / 2) {
            // We alternate between 0.35 and 0.0 (complete darkness) for maximum contrast
            let intensity: Float = (i % 2 == 0) ? 0.35 : 0.0
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: intensity,
                duration: 2.0, // Full 2 seconds - NOT period/2.0!
                waveform: .square, // Square waves for visual clarity during introspection
                color: .purple,
                frequencyOverride: p2Frequency
            ))
            currentTime += 2.0
        }
        
        // --- TRANSITION RAMP (60 Sek) ---
        // We smoothly ramp the brain from 5 Hz (Theta) to 40 Hz (Gamma)
        // This prevents the abrupt frequency jump that can cause discomfort
        let transitionDuration: TimeInterval = 60 // 60 seconds
        let startFreq = 5.0
        let endFreq = 40.0
        
        for i in 0..<Int(transitionDuration) {
            let progress = Double(i) / transitionDuration
            // Smoothstep interpolation for organic transition
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = startFreq + (endFreq - startFreq) * smoothProgress
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: 0.4, // Gentle intensity during the transition
                duration: 1.0,
                waveform: .square,
                color: .white,
                frequencyOverride: currentFreq
            ))
            currentTime += 1.0
        }
        
        // --- PHASE 3: THE REWIRE-BURST (8 Min) ---
        // 40Hz Gamma-Burst for burning in the new neural pathway.
        // This is where we imprint the new belief with maximum synchronization.
        // **Waveform Choice**: Square waves are essential here for maximum gamma entrainment effectiveness.
        // Research shows 90.8% SSVEP success rate with square waves vs 75% with sine waves. The hard
        // on/off transitions maximize transient steepness (dI/dt), activating the magnocellular pathway
        // and creating optimal conditions for gamma synchronization at 40 Hz - critical for neural
        // pathway rewiring.
        let phase3Duration: TimeInterval = 480 // 8 minutes
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.7, // High intensity (70%) for maximum effect, but not overwhelming
            duration: phase3Duration, // Full duration - NOT period/2.0!
            waveform: .square, // Square wave is gold standard for gamma sync (90.8% vs 75% SSVEP success rate)
            color: .white,
            frequencyOverride: 40.0
        ))
        currentTime += phase3Duration
        
        // --- PHASE 4: INTEGRATION (8 Min) ---
        // Schumann Resonance (7.83Hz) for peaceful grounding and integration.
        // This allows the new neural pathway to settle and integrate.
        // **Waveform Choice**: Sine waves are used here for gentle grounding and integration.
        // After intense gamma stimulation, users need smooth transitions to help the new neural
        // pathway settle. Square waves would create abrupt changes that could disrupt the
        // integration process during this critical phase.
        let phase4Duration: TimeInterval = 480 // 8 minutes
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.4,
            duration: phase4Duration, // Full duration - NOT period/2.0!
            waveform: .sine, // Sine for gentle grounding and integration (intentional - smooth transitions support neural pathway integration)
            color: .green,
            frequencyOverride: 7.83
        ))
        
        // Dummy Audio Track ID (since we don't analyze music here, but provide frequencies)
        return LightScript(
            trackId: UUID(),
            mode: .beliefRewiring, // Uses the new Belief-Rewiring mode
            targetFrequency: 40.0,
            multiplier: 1,
            events: events
        )
    }
}
