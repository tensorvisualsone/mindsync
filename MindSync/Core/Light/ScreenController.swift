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
            // Check if cinematic mode - continuous audio-reactive pulsation
            if script.mode == .cinematic {
                // Same approach as FlashlightController: direct audio-reactive intensity mapping
                let audioEnergy: Float
                if let tracker = audioEnergyTracker {
                    if tracker.useSpectralFlux {
                        audioEnergy = tracker.currentSpectralFlux
                    } else {
                        audioEnergy = tracker.currentEnergy
                    }
                } else {
                    // No tracker - use base frequency oscillation as fallback
                    let elapsed = result.elapsed
                    let baseFreq = script.targetFrequency > 0 ? script.targetFrequency : 6.5
                    let phase = elapsed * baseFreq * 2.0 * .pi
                    audioEnergy = Float((sin(phase) + 1.0) / 2.0) * 0.5
                }
                
                // Update smoothing buffer
                recentFluxValues.append(audioEnergy)
                if recentFluxValues.count > 5 {
                    recentFluxValues.removeFirst()
                }
                
                let smoothedEnergy = recentFluxValues.reduce(0, +) / Float(recentFluxValues.count)
                
                // Update running statistics
                fluxHistory.append(smoothedEnergy)
                if fluxHistory.count > maxAdaptiveHistorySize {
                    fluxHistory.removeFirst()
                }
                
                // Adaptive normalization
                let recentMin: Float
                let recentMax: Float
                if fluxHistory.count >= 10 {
                    recentMin = fluxHistory.min() ?? 0.0
                    recentMax = max(fluxHistory.max() ?? 0.1, recentMin + 0.05)
                } else {
                    recentMin = 0.0
                    recentMax = 0.3
                }
                
                let normalizedEnergy = (smoothedEnergy - recentMin) / (recentMax - recentMin)
                let clampedEnergy = max(0.0, min(1.0, normalizedEnergy))
                let curvedEnergy = pow(clampedEnergy, 0.7)
                
                let minIntensity: Float = 0.05
                let maxIntensity: Float = 1.0
                let finalIntensity = minIntensity + curvedEnergy * (maxIntensity - minIntensity)
                
                // Get color from default
                let lightColor = defaultColor
                let baseColor = lightColor.swiftUIColor(customRGB: customColorRGB?.tuple)
                
                currentColor = baseColor.opacity(Double(finalIntensity))
            } else if let event = result.event {
                // For other modes, use event-based intensity with waveform
                let lightColor = event.color ?? defaultColor
                let baseColor = lightColor.swiftUIColor(customRGB: customColorRGB?.tuple)
                
                // CRITICAL UPDATE: Use event-specific frequency if available, else global
                let effectiveFrequency = event.frequencyOverride ?? script.targetFrequency
                
                // Apply intensity as opacity for smoother transitions
                // Waveform affects how intensity is applied over time
                let opacity = calculateOpacity(
                    event: event,
                    elapsed: result.elapsed - event.timestamp,
                    targetFrequency: effectiveFrequency
                )
                
                currentColor = baseColor.opacity(opacity)
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
