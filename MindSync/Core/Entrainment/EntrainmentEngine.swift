import Foundation

/// Engine for generating LightScripts from AudioTracks and EntrainmentMode
final class EntrainmentEngine {
    
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
                }
            }()
            
            // Intensity based on mode
            let intensity: Float = {
                switch mode {
                case .alpha: return 0.4  // Softer for relaxation
                case .theta: return 0.3  // Very soft for trip
                case .gamma: return 0.7  // More intense for focus
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
        
        while currentTime < duration {
            let event = LightEvent(
                timestamp: currentTime,
                intensity: 0.4,
                duration: period / 2.0,
                waveform: .sine,
                color: eventColor
            )
            events.append(event)
            currentTime += period
        }
        
        return events
    }
}
