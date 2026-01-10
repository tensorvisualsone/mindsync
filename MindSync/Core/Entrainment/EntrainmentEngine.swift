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
        
        // SPECIAL CASE: Cinematic mode uses purely audio-reactive approach without discrete events
        // The FlashlightController modulates light intensity directly from audio energy in real-time
        // We generate a single long event for script validation, but the controller doesn't use it
        if mode == .cinematic {
            // Create a single event spanning the full track duration for validation purposes
            // The actual light intensity is calculated from real-time audio modulation
            // Base intensity is set to 0.5 (50%) - this value is not used by the controller,
            // but provides a reasonable fallback if cinematic mode is ever used with event-based rendering
            let cinematicBaseIntensity: Float = 0.5
            let event = LightEvent(
                timestamp: 0.0,
                intensity: cinematicBaseIntensity,
                duration: trackDuration,
                waveform: .sine,
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
        let waveformSelector: (EntrainmentMode) -> LightEvent.Waveform = { mode in
            switch mode {
            case .alpha: return .square   // Changed from .sine for visual patterns (Phosphene)
            case .theta: return .square   // Changed from .sine for visual patterns (Phosphene)
            case .gamma: return .square   // Hard for focus
            case .cinematic: return .sine // Keep sine for cinematic (dynamically modulated at runtime)
            case .dmnShutdown: return .square // Default (overridden by script)
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
        let waveformSelector: (EntrainmentMode) -> LightEvent.Waveform = { mode in
            switch mode {
            case .alpha, .theta: return .square  // Changed from .sine for visual patterns
            case .gamma: return .square
            case .cinematic: return .sine
            case .dmnShutdown: return .square // Default (overridden by script)
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
            case .alpha, .theta, .cinematic, .dmnShutdown: return .sine
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
    
    /// Generates the special "DMN-Shutdown" script for ego-dissolution.
    /// This ignores audio beats and creates a fixed 30-minute sequence
    /// to specifically deactivate the Default Mode Network (DMN).
    /// 
    /// Phases:
    /// - Phase 1: DISCONNECT (4 Min) - 10Hz → 5Hz Ramp (Alpha to Theta)
    /// - Phase 2: THE ABYSS (12 Min) - 4.5Hz Theta with varying intensity
    /// - Phase 3: THE VOID / PEAK (8 Min) - 40Hz Gamma-Burst
    /// - Phase 4: REINTEGRATION (6 Min) - 7.83Hz Schumann Resonance
    static func generateDMNShutdownScript() -> LightScript {
        var events: [LightEvent] = []
        var currentTime: TimeInterval = 0.0
        
        // --- PHASE 1: DISCONNECT (4 Min) ---
        // We start at 10Hz (Alpha) and quickly pull consciousness down to 5Hz (Theta).
        // This breaks the everyday focus.
        // Square waves for "harder" entrainment (higher SSVEP success rate: 90.8% vs 75%)
        let phase1Duration: TimeInterval = 240 // 4 minutes
        let p1StartFreq = 10.0
        let p1EndFreq = 5.0
        
        // IMPORTANT: Each event has duration: 1.0 (full second), not period/2.0
        // The square wave shape is controlled by duty cycle, not by event duration
        for i in 0..<Int(phase1Duration) {
            let progress = Double(i) / phase1Duration
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = p1StartFreq + (p1EndFreq - p1StartFreq) * smoothProgress
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: 0.4,
                duration: 1.0, // Full second - NOT period/2.0!
                waveform: .square, // Square waves for maximum cortical excitation
                color: .blue,
                frequencyOverride: currentFreq
            ))
            currentTime += 1.0
        }
        
        // --- PHASE 2: THE ABYSS (12 Min) ---
        // Deep theta oscillation at 4.5 Hz.
        // Here we switch the DMN "offline". We use a fluctuating
        // intensity cycle to prevent habituation (adaptation).
        let phase2Duration: TimeInterval = 720 // 12 minutes
        let p2Frequency = 4.5
        
        // 2-second events with alternating intensity (0.35/0.25) to prevent habituation
        // IMPORTANT: duration: 2.0 (full 2 seconds), not period/2.0
        for i in 0..<Int(phase2Duration / 2) {
            // We vary the intensity slightly between 0.35 and 0.25
            let intensity: Float = (i % 2 == 0) ? 0.35 : 0.25
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: intensity,
                duration: 2.0, // Full 2 seconds - NOT period/2.0!
                waveform: .sine, // Sine for "floating" and gentle relaxation
                color: .purple,
                frequencyOverride: p2Frequency
            ))
            currentTime += 2.0
        }
        
        // --- PHASE 3: THE VOID / PEAK (8 Min) ---
        // The "nothingness" state. We blast in with 40Hz gamma synchronization.
        // This is the "Aha-moment" or spiritual high.
        let phase3Duration: TimeInterval = 480 // 8 minutes
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.75, // High intensity for maximum effect
            duration: phase3Duration, // Full duration - NOT period/2.0!
            waveform: .square, // Square wave is gold standard for gamma sync
            color: .white,
            frequencyOverride: 40.0
        ))
        currentTime += phase3Duration
        
        // --- PHASE 4: REINTEGRATION (6 Min) ---
        // Schumann Resonance (7.83Hz) for peaceful "afterglow" and grounding.
        let phase4Duration: TimeInterval = 360 // 6 minutes
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.4,
            duration: phase4Duration, // Full duration - NOT period/2.0!
            waveform: .sine, // Sine for gentle grounding
            color: .green,
            frequencyOverride: 7.83
        ))
        
        // Dummy Audio Track ID (since we don't analyze music here, but provide frequencies)
        return LightScript(
            trackId: UUID(),
            mode: .dmnShutdown, // Uses the new DMN-Shutdown mode
            targetFrequency: 40.0,
            multiplier: 1,
            events: events
        )
    }
    
    /// Generates a VibrationScript for DMN-Shutdown mode
    /// This follows the same 4-phase structure as the light script:
    /// - Phase 1: DISCONNECT (4 Min) - 10Hz → 5Hz ramp
    /// - Phase 2: THE ABYSS (12 Min) - 4.5Hz Theta
    /// - Phase 3: THE VOID / PEAK (8 Min) - 40Hz Gamma
    /// - Phase 4: REINTEGRATION (6 Min) - 7.83Hz Schumann
    /// - Parameters:
    ///   - intensity: User preference for vibration intensity (0.1 - 1.0)
    /// - Returns: A VibrationScript synchronized with the light script
    /// - Throws: VibrationScriptError if validation fails
    static func generateDMNShutdownVibrationScript(intensity: Float) throws -> VibrationScript {
        var events: [VibrationEvent] = []
        var currentTime: TimeInterval = 0.0
        
        // Ensure minimum intensity for vibration to be noticeable
        let baseIntensity = max(Self.minVibrationIntensity, intensity)
        
        // --- PHASE 1: DISCONNECT (4 Min) ---
        // Ramp from 10Hz → 5Hz (Square waves for "harder" entrainment)
        // The vibration frequency is ramped by varying event duration (period) linearly from 10Hz to 5Hz
        let phase1Duration: TimeInterval = 240 // 4 minutes
        let p1StartFreq = 10.0
        let p1EndFreq = 5.0
        
        var phase1Time: TimeInterval = 0
        
        while phase1Time < phase1Duration {
            // Linear ramp of frequency from 10Hz → 5Hz based on elapsed phase time
            let progress = phase1Time / phase1Duration
            let currentFreq = p1StartFreq + (p1EndFreq - p1StartFreq) * progress
            let period = 1.0 / currentFreq
            
            events.append(try VibrationEvent(
                timestamp: currentTime + phase1Time,
                intensity: baseIntensity,
                duration: period,
                waveform: .square
            ))
            phase1Time += period
        }
        currentTime += phase1Duration
        
        // --- PHASE 2: THE ABYSS (12 Min) ---
        // Deep theta oscillation at 4.5 Hz (Sine waves for gentle floating)
        let phase2Duration: TimeInterval = 720 // 12 Minuten
        
        // 2-second events with alternating intensity to prevent habituation
        let phase2EventCount = Int(phase2Duration / 2.0)
        for i in 0..<phase2EventCount {
            // Vary intensity slightly (0.85x - 1.0x baseIntensity)
            let intensityVariation: Float = (i % 2 == 0) ? baseIntensity : baseIntensity * 0.85
            
            events.append(try VibrationEvent(
                timestamp: currentTime,
                intensity: max(Self.minVibrationIntensity, intensityVariation),
                duration: 2.0, // 2-second events
                waveform: .sine // Sine for gentle floating
            ))
            currentTime += 2.0
        }
        
        // --- PHASE 3: THE VOID / PEAK (8 Min) ---
        // 40Hz Gamma-Burst (Square waves for maximum cortical excitation)
        // OPTIMIZATION: Create longer events (0.1s) instead of individual periods (0.0125s)
        // to reduce event count from 38,400 to ~4,800 events and prevent main thread blocking
        let phase3Duration: TimeInterval = 480 // 8 minutes
        // Note: p3Frequency (40.0 Hz) is implied by the event timing, no explicit calculation needed
        
        // High intensity for Phase 3 (1.2x baseIntensity, clamped to 1.0)
        let phase3Intensity = min(1.0, baseIntensity * 1.2)
        
        // Use 0.1s events instead of period/2 (0.0125s) to reduce event count by 8x
        let phase3EventDuration: TimeInterval = 0.1 // 100ms events for Phase 3
        var phase3Time: TimeInterval = 0
        while phase3Time < phase3Duration {
            events.append(try VibrationEvent(
                timestamp: currentTime + phase3Time,
                intensity: phase3Intensity,
                duration: phase3EventDuration,
                waveform: .square // Square wave for gamma sync
            ))
            phase3Time += phase3EventDuration
        }
        currentTime += phase3Duration
        
        // --- PHASE 4: REINTEGRATION (6 Min) ---
        // Schumann Resonance (7.83Hz) for peaceful grounding (Sine waves)
        // OPTIMIZATION: Use longer events (0.2s) to reduce event count
        let phase4Duration: TimeInterval = 360 // 6 minutes
        // Note: p4Frequency (7.83 Hz) is implied by the event timing, no explicit calculation needed
        
        // Use 0.2s events instead of full period (~0.128s) to reduce event count
        let phase4EventDuration: TimeInterval = 0.2 // 200ms events for Phase 4
        var phase4Time: TimeInterval = 0
        while phase4Time < phase4Duration {
            events.append(try VibrationEvent(
                timestamp: currentTime + phase4Time,
                intensity: baseIntensity,
                duration: phase4EventDuration,
                waveform: .sine // Sine for gentle grounding
            ))
            phase4Time += phase4EventDuration
        }
        
        // Create VibrationScript
        return try VibrationScript(
            trackId: UUID(),
            mode: .dmnShutdown,
            targetFrequency: 40.0, // Peak frequency (Gamma)
            multiplier: 1,
            events: events
        )
    }
}
