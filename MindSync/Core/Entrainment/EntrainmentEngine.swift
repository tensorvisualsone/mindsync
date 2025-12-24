import Foundation

/// Engine for generating LightScripts from AudioTracks and EntrainmentMode
final class EntrainmentEngine {
    
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
    
    /// Generates light events from beat timestamps
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
        
        var events: [LightEvent] = []
        let period = 1.0 / targetFrequency  // Duration of one cycle in seconds
        
        // Create a light event for each beat
        for beatTimestamp in beatTimestamps {
            // Select waveform based on mode
            let waveform: LightEvent.Waveform = {
                switch mode {
                case .alpha: return .sine      // Smooth for relaxation
                case .theta: return .sine     // Smooth for trip
                case .gamma: return .square   // Hard for focus
                case .cinematic: return .sine // Smooth for cinematic (dynamically modulated at runtime)
                }
            }()
            
            // Intensity based on mode
            // For cinematic mode, use base intensity 0.5 (will be dynamically modulated at runtime)
            let intensity: Float = {
                switch mode {
                case .alpha: return 0.4  // Softer for relaxation
                case .theta: return 0.3  // Very soft for trip
                case .gamma: return 0.7  // More intense for focus
                case .cinematic: return 0.5  // Base intensity (dynamically adjusted at runtime)
                }
            }()
            
            // Duration: half period for square, full period for sine
            let duration: TimeInterval = {
                switch waveform {
                case .square: return period / 2.0  // Short for hard blink
                case .sine: return period         // Longer for soft pulse
                case .triangle: return period
                }
            }()
            
            let event = LightEvent(
                timestamp: beatTimestamp,
                intensity: intensity,
                duration: duration,
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
        var events: [LightEvent] = []
        let period = 1.0 / frequency
        var currentTime: TimeInterval = 0
        
        let eventColor: LightEvent.LightColor? = (lightSource == .screen) ? (screenColor ?? .white) : nil
        
        // Determine intensity and waveform for fallback based on mode
        let fallbackIntensity: Float = {
            switch mode {
            case .alpha: return 0.4
            case .theta: return 0.3
            case .gamma: return 0.7
            case .cinematic: return 0.5  // Base intensity for cinematic mode
            }
        }()
        
        let fallbackWaveform: LightEvent.Waveform = {
            switch mode {
            case .alpha, .theta, .cinematic: return .sine
            case .gamma: return .square
            }
        }()
        
        while currentTime < duration {
            let event = LightEvent(
                timestamp: currentTime,
                intensity: fallbackIntensity,
                duration: period / 2.0,
                waveform: fallbackWaveform,
                color: eventColor
            )
            events.append(event)
            currentTime += period
        }
        
        return events
    }
}
