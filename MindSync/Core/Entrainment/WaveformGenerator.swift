import Foundation

/// Utility for generating waveform intensity values over time
enum WaveformGenerator {
    /// Calculates intensity for a given waveform at a specific time
    /// - Parameters:
    ///   - waveform: The waveform type (square, sine, triangle)
    ///   - time: Time within the waveform cycle (0.0 to 1.0, where 1.0 is one full period)
    ///   - frequency: Target frequency in Hz
    ///   - baseIntensity: Base intensity value (0.0 to 1.0)
    ///   - dutyCycle: Optional duty cycle for square wave (0.0 to 1.0). Default: 0.5 (50% on, 50% off)
    /// - Returns: Intensity value (0.0 to 1.0)
    static func calculateIntensity(
        waveform: LightEvent.Waveform,
        time: TimeInterval,
        frequency: Double,
        baseIntensity: Float,
        dutyCycle: Double = 0.5
    ) -> Float {
        guard frequency > 0 else {
            return baseIntensity
        }
        
        let period = 1.0 / frequency
        let phase = (time.truncatingRemainder(dividingBy: period)) / period // 0.0 to 1.0
        
        let intensity: Float
        switch waveform {
        case .square:
            // Hard on/off with configurable duty cycle
            // For FlashlightController: frequency-dependent duty cycle (20% for >20Hz, 35% for >10Hz, 50% default)
            // For other controllers: standard 50% duty cycle
            intensity = phase < dutyCycle ? baseIntensity : 0.0
            
        case .sine:
            // Smooth sine wave pulsation
            let sineValue = sin(phase * 2.0 * .pi)
            // Map from [-1, 1] to [0, 1], then scale by base intensity
            let normalizedSine = Float((sineValue + 1.0) / 2.0)
            intensity = baseIntensity * normalizedSine
            
        case .triangle:
            // Linear ramp up and down
            let triangleValue: Float
            if phase < 0.5 {
                // Ramp up: 0 to 1
                triangleValue = Float(phase * 2.0)
            } else {
                // Ramp down: 1 to 0
                triangleValue = Float(2.0 - (phase * 2.0))
            }
            intensity = baseIntensity * triangleValue
        }
        
        return max(0.0, min(1.0, intensity)) // Clamp to valid range
    }
    
    /// Calculates intensity for vibration waveform (delegates to calculateIntensity with mapping)
    /// - Parameters:
    ///   - waveform: The vibration waveform type
    ///   - time: Time within the waveform cycle
    ///   - frequency: Target frequency in Hz
    ///   - baseIntensity: Base intensity value (0.0 to 1.0)
    ///   - dutyCycle: Optional duty cycle for square wave (0.0 to 1.0). Default: 0.5 (50% on, 50% off)
    /// - Returns: Intensity value (0.0 to 1.0)
    static func calculateVibrationIntensity(
        waveform: VibrationEvent.Waveform,
        time: TimeInterval,
        frequency: Double,
        baseIntensity: Float,
        dutyCycle: Double = 0.5
    ) -> Float {
        // Map vibration waveform to light waveform to reuse the core implementation
        let lightWaveform: LightEvent.Waveform
        switch waveform {
        case .square:
            lightWaveform = .square
        case .sine:
            lightWaveform = .sine
        case .triangle:
            lightWaveform = .triangle
        }
        
        // Use frequency-dependent duty cycle for square wave coherence with light
        return calculateIntensity(
            waveform: lightWaveform,
            time: time,
            frequency: frequency,
            baseIntensity: baseIntensity,
            dutyCycle: dutyCycle
        )
    }
        )
    }
    
    /// Calculates intensity with smooth fade-out for signal pausing (microphone mode)
    /// - Parameters:
    ///   - waveform: The waveform type
    ///   - time: Time within the waveform cycle
    ///   - frequency: Target frequency in Hz
    ///   - baseIntensity: Base intensity value
    ///   - fadeOutProgress: Fade-out progress (0.0 = no fade, 1.0 = fully faded)
    /// - Returns: Intensity value with fade applied
    static func calculateIntensityWithFade(
        waveform: LightEvent.Waveform,
        time: TimeInterval,
        frequency: Double,
        baseIntensity: Float,
        fadeOutProgress: Float
    ) -> Float {
        let base = calculateIntensity(
            waveform: waveform,
            time: time,
            frequency: frequency,
            baseIntensity: baseIntensity
        )
        
        // Apply fade-out: multiply by (1 - fadeOutProgress)
        return base * (1.0 - fadeOutProgress)
    }
    
    /// Generates a sequence of intensity values for a given duration
    /// - Parameters:
    ///   - waveform: The waveform type
    ///   - frequency: Target frequency in Hz
    ///   - duration: Duration in seconds
    ///   - sampleRate: Sample rate for intensity values (e.g., 60 Hz for screen updates)
    ///   - baseIntensity: Base intensity value
    /// - Returns: Array of intensity values sampled at the specified rate
    static func generateIntensitySequence(
        waveform: LightEvent.Waveform,
        frequency: Double,
        duration: TimeInterval,
        sampleRate: Double = 60.0,
        baseIntensity: Float
    ) -> [Float] {
        guard frequency > 0, duration > 0, sampleRate > 0 else {
            return []
        }
        
        let sampleCount = Int(duration * sampleRate)
        let sampleInterval = 1.0 / sampleRate
        
        var intensities: [Float] = []
        intensities.reserveCapacity(sampleCount)
        
        for i in 0..<sampleCount {
            let time = Double(i) * sampleInterval
            let intensity = calculateIntensity(
                waveform: waveform,
                time: time,
                frequency: frequency,
                baseIntensity: baseIntensity
            )
            intensities.append(intensity)
        }
        
        return intensities
    }
}

