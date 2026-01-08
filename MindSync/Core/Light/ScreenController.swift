import Foundation
import SwiftUI
import Combine

/// Controller for screen strobe control using fullscreen color flashing
@MainActor
final class ScreenController: BaseLightController, LightControlling, ObservableObject {
    var source: LightSource { .screen }
    
    /// Published color for SwiftUI view
    @Published var currentColor: Color = .black
    @Published var isActive: Bool = false
    
    private var defaultColor: LightEvent.LightColor = .white
    private var customColorRGB: CustomColorRGB?
    
    /// Precision timer interval shared across light controllers (250 Hz)
    private let precisionInterval: DispatchTimeInterval = .nanoseconds(FlashlightController.precisionIntervalNanoseconds)
    
    // Cinematic mode smoothing buffers (matching FlashlightController)
    private var recentFluxValues: [Float] = []
    private var fluxHistory: [Float] = []
    private let maxAdaptiveHistorySize = 200
    
    override init() {
        super.init()
        // Screen controller uses SwiftUI views for display
    }

    func start() async throws {
        // Screen mode doesn't require hardware setup
        // Just mark as active so views can observe
        isActive = true
    }

    func stop() {
        isActive = false
        cancelExecution()
    }

    func setIntensity(_ intensity: Float) {
        // Note: Intensity control is not supported for screen mode as an independent operation.
        // For screen strobe, intensity is embedded in each LightEvent and applied during
        // script execution in updateScreen() via opacity calculations.
        // If real-time intensity adjustment is needed, this would require modifying
        // the active script's event intensities or applying a global intensity multiplier.
    }

    func setColor(_ color: LightEvent.LightColor) {
        defaultColor = color
    }
    
    /// Sets custom color RGB values for custom color mode
    func setCustomColorRGB(_ rgb: CustomColorRGB?) {
        customColorRGB = rgb
    }

    func execute(script: LightScript, syncedTo startTime: Date) {
        initializeScriptExecution(script: script, startTime: startTime)

        setupPrecisionTimer(interval: precisionInterval) { [weak self] in
            self?.updateScreen()
        }
    }

    func cancelExecution() {
        invalidatePrecisionTimer()
        resetScriptExecution()
        currentColor = .black
        // Reset cinematic mode buffers
        recentFluxValues.removeAll()
        fluxHistory.removeAll()
    }
    
    func pauseExecution() {
        pauseScriptExecution()
        invalidatePrecisionTimer()
        currentColor = .black
    }
    
    func resumeExecution() {
        guard let _ = currentScript, let _ = scriptStartTime else { return }
        resumeScriptExecution()
        setupPrecisionTimer(interval: precisionInterval) { [weak self] in
            self?.updateScreen()
        }
    }

    /// Updates the screen color based on the current event in the script.
    ///
    /// Thread Safety: This method is invoked from the precision timer callback configured in
    /// `execute(script:syncedTo:)` / `resumeExecution()`, which dispatches work onto the main
    /// actor. All property accesses are therefore main-thread safe, and `fileprivate` keeps
    /// this helper scoped to `ScreenController` while still callable from the timer closure.
    fileprivate func updateScreen() {
        let result = findCurrentEvent()
        
        if result.isComplete {
            cancelExecution()
            return
        }
        
        if let script = currentScript {
            // Check if cinematic mode - rhythmic strobe synchronized to audio
            if script.mode == .cinematic {
                // Same photo diving approach as FlashlightController
                let elapsed = result.elapsed
                let targetFreq = script.targetFrequency > 0 ? script.targetFrequency : 6.5
                
                // Calculate square wave phase
                let period = 1.0 / targetFreq
                let phase = (elapsed.truncatingRemainder(dividingBy: period)) / period
                
                // Audio modulation (same improved logic as FlashlightController)
                let audioModulation: Float
                if let tracker = audioEnergyTracker {
                    let energy = tracker.useSpectralFlux ? tracker.currentSpectralFlux : tracker.currentEnergy
                    
                    // Smoothing buffer for stable modulation
                    recentFluxValues.append(energy)
                    if recentFluxValues.count > 4 {  // Small buffer for fast response (matching FlashlightController)
                        recentFluxValues.removeFirst()
                    }
                    
                    let smoothedEnergy = recentFluxValues.count > 0 ? recentFluxValues.reduce(0, +) / Float(recentFluxValues.count) : 0.0
                    
                    // Use long-term history for better dynamic range (same as FlashlightController)
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
                    let normalizedEnergy: Float
                    if historyRange > 0.001 && historyMax > 0.0 {
                        normalizedEnergy = min(1.0, max(0.0, (smoothedEnergy - historyMin) / historyRange))
                    } else {
                        // Fallback: Use absolute thresholds based on typical flux values
                        normalizedEnergy = min(smoothedEnergy * 5.0, 1.0)
                    }
                    
                    // Apply power curve for perceptual linearity
                    let curved = pow(normalizedEnergy, 0.7)
                    
                    // EXTREME contrast stretching for maximum visual impact (matching FlashlightController)
                    let rawModulation: Float
                    if curved < 0.3 {
                        // Quiet: map 0.0-0.3 → 0.0-0.15 (nearly dark)
                        rawModulation = (curved / 0.3) * 0.15
                    } else if curved < 0.6 {
                        // Medium: map 0.3-0.6 → 0.15-0.50 (dim to moderate)
                        rawModulation = 0.15 + ((curved - 0.3) / 0.3) * 0.35
                    } else {
                        // Loud: map 0.6-1.0 → 0.50-1.0 (bright to maximum)
                        rawModulation = 0.50 + ((curved - 0.6) / 0.4) * 0.50
                    }
                    
                    // Additional boost for very high values to make strong beats pop
                    if rawModulation > 0.75 {
                        // Strong beats: boost from 0.75-1.0 to 0.90-1.0
                        audioModulation = 0.90 + ((rawModulation - 0.75) / 0.25) * 0.10
                    } else {
                        audioModulation = rawModulation
                    }
                } else {
                    // No audio tracking - use moderate intensity (not full, to show difference)
                    audioModulation = 0.5
                }
                
                // Square wave with duty cycle
                let dutyCycle = calculateDutyCycle(for: targetFreq)
                let isOn = phase < dutyCycle
                
                let finalIntensity: Float = isOn ? audioModulation : 0.0
                
                // Get color
                let lightColor = defaultColor
                let baseColor = lightColor.swiftUIColor(customRGB: customColorRGB?.tuple)
                
                currentColor = baseColor.opacity(Double(finalIntensity))
            } else if let event = result.event {
                // For other modes (Alpha, Theta, Gamma): Event-based with audio-reactive modulation
                let lightColor = event.color ?? defaultColor
                let baseColor = lightColor.swiftUIColor(customRGB: customColorRGB?.tuple)
                
                // CRITICAL UPDATE: Use event-specific frequency if available, else global
                let effectiveFrequency = event.frequencyOverride ?? script.targetFrequency
                
                // Calculate base opacity from waveform
                let baseOpacity = calculateOpacity(
                    event: event,
                    elapsed: result.elapsed - event.timestamp,
                    targetFrequency: effectiveFrequency
                )
                
                // Apply audio-reactive modulation if tracker is available (same logic as FlashlightController)
                let finalOpacity: Double
                if let tracker = audioEnergyTracker {
                    let energy = tracker.useSpectralFlux ? tracker.currentSpectralFlux : tracker.currentEnergy
                    
                    // Update smoothing buffer (shared with cinematic mode)
                    recentFluxValues.append(energy)
                    if recentFluxValues.count > 8 {  // Medium buffer for smooth but reactive modulation
                        recentFluxValues.removeFirst()
                    }
                    
                    let smoothedEnergy = recentFluxValues.count > 0 ? recentFluxValues.reduce(0, +) / Float(recentFluxValues.count) : 0.0
                    
                    // Use long-term history for better dynamic range (same as FlashlightController)
                    fluxHistory.append(smoothedEnergy)
                    let historySize = 100  // Keep last 100 smoothed values (~10-20 seconds)
                    if fluxHistory.count > historySize {
                        fluxHistory.removeFirst()
                    }
                    
                    // Calculate min/max from long-term history
                    let historyMin: Float = fluxHistory.count > 0 ? (fluxHistory.min() ?? 0.0) : 0.0
                    let historyMax: Float = fluxHistory.count > 0 ? (fluxHistory.max() ?? smoothedEnergy) : smoothedEnergy
                    let historyRange = max(historyMax - historyMin, 0.001)
                    
                    // Normalize current energy to 0-1 range
                    let normalizedEnergy: Float
                    if historyRange > 0.001 && historyMax > 0.0 {
                        normalizedEnergy = min(1.0, max(0.0, (smoothedEnergy - historyMin) / historyRange))
                    } else {
                        normalizedEnergy = min(smoothedEnergy * 5.0, 1.0)
                    }
                    
                    // Apply power curve for perceptual linearity
                    let curved = pow(normalizedEnergy, 0.7)
                    
                    // Contrast stretching for visible audio reactivity
                    let rawModulation: Float
                    if curved < 0.4 {
                        // Low energy: map 0.0-0.4 → 0.0-0.3 (subtle boost)
                        rawModulation = (curved / 0.4) * 0.3
                    } else {
                        // High energy: map 0.4-1.0 → 0.3-1.0 (strong boost)
                        rawModulation = 0.3 + ((curved - 0.4) / 0.6) * 0.7
                    }
                    
                    let audioModulation = max(0.0, min(1.0, rawModulation))
                    
                    // Use audio modulation as additive enhancement (matching FlashlightController)
                    let audioBoost = audioModulation > 0.1 ? audioModulation : 0.0
                    let boostedOpacity = min(1.0, Double(baseOpacity) + (baseOpacity * Double(audioBoost) * 0.7))  // Add up to 70% boost
                    finalOpacity = boostedOpacity
                } else {
                    // No audio tracking - use base opacity only
                    finalOpacity = baseOpacity
                }
                
                currentColor = baseColor.opacity(finalOpacity)
            } else {
                // Between events or no active event, show black
                currentColor = .black
            }
        } else {
            // No script, show black
            currentColor = .black
        }
    }
    
    /// Calculates opacity based on waveform and time within event
    /// Uses WaveformGenerator for consistency with other controllers
    private func calculateOpacity(event: LightEvent, elapsed: TimeInterval, targetFrequency: Double) -> Double {
        // Calculate frequency-dependent duty cycle (same logic as FlashlightController)
        let dutyCycle = calculateDutyCycle(for: targetFrequency)
        
        return Double(WaveformGenerator.calculateIntensity(
            waveform: event.waveform,
            time: elapsed,
            frequency: targetFrequency,
            baseIntensity: event.intensity,
            dutyCycle: dutyCycle
        ))
    }
    
    /// Calculates optimal duty cycle based on frequency
    /// Matches FlashlightController logic for consistent entrainment effectiveness
    /// At high frequencies, shorter duty cycles create sharper visual pulses
    private func calculateDutyCycle(for frequency: Double) -> Double {
        // Frequency thresholds (same as FlashlightController)
        let highThreshold: Double = 30.0  // Gamma band
        let midThreshold: Double = 20.0   // Alpha/Beta boundary
        let lowThreshold: Double = 10.0   // Theta/Alpha boundary
        
        // Duty cycles by frequency band
        if frequency > highThreshold {
            return 0.15  // 15% for gamma (>30 Hz)
        } else if frequency > midThreshold {
            return 0.20  // 20% for high alpha/beta (20-30 Hz)
        } else if frequency > lowThreshold {
            return 0.30  // 30% for alpha (10-20 Hz)
        } else {
            return 0.45  // 45% for theta (<10 Hz)
        }
    }
}
