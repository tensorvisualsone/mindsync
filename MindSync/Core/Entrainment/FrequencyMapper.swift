import Foundation

/// Utility for mapping BPM to target frequencies based on EntrainmentMode
enum FrequencyMapper {
    /// Calculates the multiplier N to map BPM to target frequency band
    /// - Parameters:
    ///   - bpm: Beats Per Minute of the song
    ///   - targetRange: Target frequency band (e.g. 8-12 Hz for Alpha)
    ///   - maxFrequency: Maximum frequency of the light source
    /// - Returns: Integer multiplier N such that (BPM / 60) × N is in targetRange
    static func calculateMultiplier(
        bpm: Double,
        targetRange: ClosedRange<Double>,
        maxFrequency: Double
    ) -> Int {
        // Base frequency: BPM / 60 (Hz)
        let baseFrequency = bpm / 60.0
        
        guard baseFrequency > 0 else {
            // Fallback for invalid BPM
            let targetMid = (targetRange.lowerBound + targetRange.upperBound) / 2.0
            return max(1, Int((targetMid / 1.0).rounded()))
        }
        
        // Find smallest multiplier that leads to target band
        var multiplier = 1
        while true {
            let frequency = baseFrequency * Double(multiplier)
            
            // If we're in the target band, use this multiplier
            if targetRange.contains(frequency) {
                return multiplier
            }
            
            // If we're above the target band, use the previous one
            if frequency > targetRange.upperBound {
                return max(1, multiplier - 1)
            }
            
            // If we're above max frequency, limit
            if frequency > maxFrequency {
                return max(1, multiplier - 1)
            }
            
            multiplier += 1
            
            // Safety check: prevent infinite loop with reasonable upper bound.
            // With typical BPM ranges (30–200) and target frequencies (≈4–60 Hz),
            // a multiplier above 30 would only be needed for pathological inputs.
            if multiplier > 30 {
                // Fallback: use multiplier for middle target frequency
                let targetMid = (targetRange.lowerBound + targetRange.upperBound) / 2.0
                let fallbackMultiplier = Int((targetMid / baseFrequency).rounded())
                return max(1, fallbackMultiplier)
            }
        }
    }
    
    /// Maps BPM to target frequency for a given mode and light source
    /// - Parameters:
    ///   - bpm: Beats Per Minute
    ///   - mode: EntrainmentMode (Alpha, Theta, Gamma)
    ///   - lightSource: LightSource (flashlight or screen)
    /// - Returns: Target frequency in Hz
    static func mapBPMToFrequency(
        bpm: Double,
        mode: EntrainmentMode,
        lightSource: LightSource
    ) -> Double {
        let multiplier = calculateMultiplier(
            bpm: bpm,
            targetRange: mode.frequencyRange,
            maxFrequency: lightSource.maxFrequency
        )
        
        return (bpm / 60.0) * Double(multiplier)
    }
    
    /// Validates frequency against safety limits
    /// - Parameter frequency: Frequency in Hz to validate
    /// - Returns: Tuple (isValid, isPSEZone, warningMessage)
    static func validateFrequency(_ frequency: Double) -> (isValid: Bool, isPSEZone: Bool, warningMessage: String?) {
        // Check absolute limits
        if frequency < SafetyLimits.absoluteMinFrequency {
            let minFrequency = Int(SafetyLimits.absoluteMinFrequency)
            let message = String(
                format: NSLocalizedString(
                    "frequency.tooLow",
                    comment: "Warning shown when selected strobe frequency is below the absolute minimum safe frequency. Uses %d for the minimum frequency in Hz."
                ),
                minFrequency
            )
            return (false, false, message)
        }
        
        if frequency > SafetyLimits.absoluteMaxFrequency {
            let maxFrequency = Int(SafetyLimits.absoluteMaxFrequency)
            let message = String(
                format: NSLocalizedString(
                    "frequency.tooHigh",
                    comment: "Warning shown when selected strobe frequency is above the absolute maximum safe frequency. Uses %d for the maximum frequency in Hz."
                ),
                maxFrequency
            )
            return (false, false, message)
        }
        
        // Check PSE danger zone
        let isPSEZone = frequency >= SafetyLimits.pseMinFrequency && frequency <= SafetyLimits.pseMaxFrequency
        
        if isPSEZone {
            let pseMin = Int(SafetyLimits.pseMinFrequency)
            let pseMax = Int(SafetyLimits.pseMaxFrequency)
            let message = String(
                format: NSLocalizedString(
                    "frequency.pseWarning",
                    comment: "Warning shown when selected strobe frequency is within the PSE (photosensitive epilepsy) danger zone. Uses %d and %d for the lower and upper bounds in Hz."
                ),
                pseMin,
                pseMax
            )
            return (true, true, message)
        }
        
        return (true, false, nil)
    }
    
    /// Gets recommended frequency range for a mode, clamped to light source limits
    /// - Parameters:
    ///   - mode: EntrainmentMode
    ///   - lightSource: LightSource
    /// - Returns: Recommended frequency range (may be narrower than mode.frequencyRange)
    static func recommendedFrequencyRange(
        mode: EntrainmentMode,
        lightSource: LightSource
    ) -> ClosedRange<Double> {
        let modeRange = mode.frequencyRange
        let maxFreq = min(modeRange.upperBound, lightSource.maxFrequency)
        let minFreq = max(modeRange.lowerBound, SafetyLimits.absoluteMinFrequency)
        
        return minFreq...maxFreq
    }
}

