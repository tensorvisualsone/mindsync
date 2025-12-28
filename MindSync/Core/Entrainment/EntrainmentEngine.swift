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
    
    /// Calculates cinematic intensity with frequency drift and audio reactivity
    /// - Parameters:
    ///   - baseFrequency: Base frequency in Hz (typically 6.5 for cinematic mode)
    ///   - currentTime: Current time in seconds since session start
    ///   - audioEnergy: Current audio energy value (0.0 - 1.0)
    /// - Returns: Intensity value (0.0 - 1.0) for light output
    static func calculateCinematicIntensity(
        baseFrequency: Double,
        currentTime: TimeInterval,
        audioEnergy: Float
    ) -> Float {
        // 1. Frequency Drift: Slow oscillation between 5.5-7.5 Hz over 5-10 seconds
        let drift = sin(currentTime * 0.2) * 1.0
        let currentFreq = baseFrequency + drift
        
        // 2. Base Wave: Cosine wave for smoother transitions
        // Phase offset for cosine (shift by π/2)
        let phase = (currentTime * currentFreq * 2.0 * .pi) + (.pi / 2.0)
        let cosineValue = cos(phase)
        
        // Normalize cosine from [-1, 1] to [0, 1]
        let normalizedWave = Float((cosineValue + 1.0) / 2.0)
        
        // 3. Audio Reactivity: Base intensity based on audio energy
        // Minimum 30%, scales up to 100% with audio energy
        let baseIntensity: Float = 0.3 + (audioEnergy * 0.7)
        
        // 4. Mix wave with base intensity
        var output = normalizedWave * baseIntensity
        
        // 4b. Enforce a minimum dark phase to guarantee visible flicker in cinematic mode
        let minOffTime: TimeInterval = 0.08
        let enforcedFlickerFrequency: Double = 8.0
        let cycleDuration: TimeInterval = 1.0 / enforcedFlickerFrequency
        let cyclePhase = currentTime.truncatingRemainder(dividingBy: cycleDuration)
        if cyclePhase < minOffTime {
            return 0.0
        }
        
        // 5. Lens Flare: Gamma correction for bright areas (crispness)
        // When output > 0.8, apply inverse gamma to brighten highlights
        if output > 0.8 {
            output = pow(output, 0.5)
        }
        
        // Clamp to valid range
        return max(0.0, min(1.0, output))
    }
    
    /// Generates a LightScript from an AudioTrack and EntrainmentMode
    /// - Parameters:
    ///   - track: The analyzed AudioTrack with beat timestamps
    ///   - mode: The selected EntrainmentMode (Alpha/Theta/Gamma)
    ///   - lightSource: The selected light source (for frequency limits)
    ///   - screenColor: Color to use for screen mode (optional)
    /// - Returns: A LightScript with synchronized light events
    func generateLightScript(
        from track: AudioTrack,
        mode: EntrainmentMode,
        lightSource: LightSource,
        screenColor: LightEvent.LightColor? = nil
    ) -> LightScript {
        // Calculate multiplier N so that f_target is in target band
        let multiplier = calculateMultiplier(
            bpm: track.bpm,
            targetRange: mode.frequencyRange,
            maxFrequency: lightSource.maxFrequency
        )
        
        // Calculate target frequency: f_target = (BPM / 60) × N
        let targetFrequency = (track.bpm / 60.0) * Double(multiplier)
        
        // Generate light events based on beat timestamps
        let events = generateLightEvents(
            beatTimestamps: track.beatTimestamps,
            targetFrequency: targetFrequency,
            mode: mode,
            trackDuration: track.duration,
            lightSource: lightSource,
            screenColor: screenColor
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
        lightSource: LightSource,
        screenColor: LightEvent.LightColor?
    ) -> [LightEvent] {
        guard !beatTimestamps.isEmpty else {
            // Fallback: uniform pulsation if no beats detected
            return generateFallbackEvents(
                frequency: targetFrequency,
                duration: trackDuration,
                mode: mode,
                lightSource: lightSource,
                screenColor: screenColor
            )
        }
        
        // Determine color: use provided screenColor for screen mode, nil for flashlight
        let eventColor: LightEvent.LightColor? = (lightSource == .screen) ? (screenColor ?? .white) : nil
        
        // Waveform selector based on mode
        let waveformSelector: (EntrainmentMode) -> LightEvent.Waveform = { mode in
            switch mode {
            case .alpha: return .sine      // Smooth for relaxation
            case .theta: return .sine     // Smooth for trip
            case .gamma: return .square   // Hard for focus
            case .cinematic: return .sine // Smooth for cinematic (dynamically modulated at runtime)
            }
        }
        
        // Intensity selector based on mode
        let intensitySelector: (EntrainmentMode) -> Float = { mode in
            switch mode {
            case .alpha: return 0.4  // Softer for relaxation
            case .theta: return 0.3  // Very soft for trip
            case .gamma: return 0.7  // More intense for focus
            case .cinematic: return 0.5  // Base intensity (dynamically adjusted at runtime)
            }
        }
        
        var events: [LightEvent] = []
        let waveform = waveformSelector(mode)
        let baseIntensity = intensitySelector(mode)
        
        // Ramping parameters
        let startFreq = mode.startFrequency
        let rampTime = mode.rampDuration
        
        for (index, timestamp) in beatTimestamps.enumerated() {
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
                // This ensures continuous pulsation without gaps
                let nextTimestamp: TimeInterval
                if index + 1 < beatTimestamps.count {
                    nextTimestamp = beatTimestamps[index + 1]
                } else {
                    // Last beat: extend to end of track
                    nextTimestamp = trackDuration
                }
                // Duration = time until next beat, but at least one period
                eventDuration = max(period, nextTimestamp - timestamp)
            }
            
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
        lightSource: LightSource,
        screenColor: LightEvent.LightColor?
    ) -> [LightEvent] {
        let eventColor: LightEvent.LightColor? = (lightSource == .screen) ? (screenColor ?? .white) : nil

        // Waveform selector for fallback based on mode
        let waveformSelector: (EntrainmentMode) -> LightEvent.Waveform = { mode in
            switch mode {
            case .alpha, .theta, .cinematic: return .sine
            case .gamma: return .square
            }
        }
        
        // Intensity selector for fallback based on mode
        let intensitySelector: (EntrainmentMode) -> Float = { mode in
            switch mode {
            case .alpha: return 0.4
            case .theta: return 0.3
            case .gamma: return 0.7
            case .cinematic: return 0.5
            }
        }
        
        // Duration calculator: half period for square, 2x period for sine/triangle to match beat-based logic
        let durationCalculator: (LightEvent.Waveform, TimeInterval) -> TimeInterval = { waveform, period in
            switch waveform {
            case .square: return period / 2.0  // Short for hard blink
            case .sine, .triangle: return period * 2.0  // Approx 2x period for fallback (approximation of next-beat logic)
            }
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
            }
        }
        
        // Ensure minimum intensity for vibration to be noticeable
        let baseIntensity = max(Self.minVibrationIntensity, intensity)
        
        var events: [VibrationEvent] = []
        let waveform = waveformSelector(mode)
        
        // Ramping parameters
        let startFreq = mode.startFrequency
        let rampTime = mode.rampDuration
        
        for (index, timestamp) in beatTimestamps.enumerated() {
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
                if index + 1 < beatTimestamps.count {
                    nextTimestamp = beatTimestamps[index + 1]
                } else {
                    nextTimestamp = trackDuration
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
            case .alpha, .theta, .cinematic: return .sine
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
