import Foundation
import SwiftUI
import Combine

/// Weak reference wrapper for CADisplayLink target to avoid retain cycles.
///
/// CADisplayLink retains its target strongly, which would create a retain cycle if we passed
/// ScreenController directly (ScreenController -> displayLink -> ScreenController).
/// This wrapper breaks the cycle by holding only a weak reference to ScreenController,
/// allowing proper deallocation when the controller is no longer needed.
private final class WeakDisplayLinkTarget {
    weak var target: ScreenController?
    
    init(target: ScreenController) {
        self.target = target
    }
    
    @objc func updateScreen() {
        target?.updateScreen()
    }
}

/// Controller for screen strobe control using fullscreen color flashing
@MainActor
final class ScreenController: BaseLightController, LightControlling, ObservableObject {
    var source: LightSource { .screen }
    
    /// Published color for SwiftUI view
    @Published var currentColor: Color = .black
    @Published var isActive: Bool = false
    
    private var displayLinkTarget: WeakDisplayLinkTarget?
    private var defaultColor: LightEvent.LightColor = .white
    
    override init() {
        super.init()
        // Screen controller uses SwiftUI views for display
    }

    func start() throws {
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

    func execute(script: LightScript, syncedTo startTime: Date) {
        initializeScriptExecution(script: script, startTime: startTime)

        // CADisplayLink for precise timing with weak reference wrapper to avoid retain cycle
        let target = WeakDisplayLinkTarget(target: self)
        displayLinkTarget = target
        setupDisplayLink(target: target, selector: #selector(WeakDisplayLinkTarget.updateScreen))
    }

    func cancelExecution() {
        invalidateDisplayLink()
        displayLinkTarget = nil
        resetScriptExecution()
        currentColor = .black
    }
    
    func pauseExecution() {
        pauseScriptExecution()
        displayLinkTarget = nil
        currentColor = .black
    }
    
    func resumeExecution() {
        guard let _ = currentScript, let _ = scriptStartTime else { return }
        resumeScriptExecution()
        // Re-setup display link
        let target = WeakDisplayLinkTarget(target: self)
        displayLinkTarget = target
        setupDisplayLink(target: target, selector: #selector(WeakDisplayLinkTarget.updateScreen))
    }

    /// Updates the screen color based on the current event in the script.
    /// `fileprivate` allows `WeakDisplayLinkTarget` in this file to call via selector without widening access.
    ///
    /// Thread Safety: This method is called from the CADisplayLink callback on the main thread
    /// (displayLink is added to .main run loop). All property accesses are safe because:
    /// - @Published properties are accessed from main thread
    /// - BaseLightController properties are only modified from main thread via UI interactions
    fileprivate func updateScreen() {
        let result = findCurrentEvent()
        
        if result.isComplete {
            cancelExecution()
            return
        }
        
        if let event = result.event, let script = currentScript {
            // Get color from event or use default
            let lightColor = event.color ?? defaultColor
            let baseColor = lightColor.swiftUIColor
            
            // Check if cinematic mode - apply dynamic intensity modulation
            let baseIntensity: Float
            if script.mode == .cinematic {
                // Get audio energy and calculate dynamic intensity
                let audioEnergy = audioEnergyTracker?.currentEnergy ?? 0.0
                let baseFreq = script.targetFrequency
                let elapsed = result.elapsed
                
                // Calculate cinematic intensity
                let cinematicIntensity = EntrainmentEngine.calculateCinematicIntensity(
                    baseFrequency: baseFreq,
                    currentTime: elapsed,
                    audioEnergy: audioEnergy
                )
                
                // Multiply base event intensity with cinematic modulation
                baseIntensity = event.intensity * cinematicIntensity
            } else {
                baseIntensity = event.intensity
            }
            
            // Create modified event with cinematic intensity for opacity calculation
            let modifiedEvent = LightEvent(
                timestamp: event.timestamp,
                intensity: baseIntensity,
                duration: event.duration,
                waveform: event.waveform,
                color: event.color
            )
            
            // Apply intensity as opacity for smoother transitions
            // Waveform affects how intensity is applied over time
            let opacity = calculateOpacity(
                event: modifiedEvent,
                elapsed: result.elapsed - event.timestamp,
                targetFrequency: script.targetFrequency
            )
            
            currentColor = baseColor.opacity(Double(opacity))
        } else {
            // Between events or no active event, show black
            currentColor = .black
        }
    }
    
    /// Calculates opacity based on waveform and time within event
    private func calculateOpacity(event: LightEvent, elapsed: TimeInterval, targetFrequency: Double) -> Double {
        switch event.waveform {
        case .square:
            // Hard on/off based on intensity
            return Double(event.intensity)
            
        case .sine:
            // Smooth sine wave pulsation with time-based frequency
            // Use the script's target frequency so pulsation rate is independent of event duration
            guard targetFrequency > 0 else {
                // Fallback: constant intensity if frequency is not valid
                return Double(event.intensity)
            }
            let sineValue = sin(elapsed * 2.0 * .pi * targetFrequency)
            // Map sine value from [-1, 1] to [0, 1], then scale by intensity
            let normalizedSine = (sineValue + 1.0) / 2.0
            return Double(event.intensity) * normalizedSine
            
        case .triangle:
            // Triangle wave based on absolute elapsed time, independent of event duration
            // One full cycle (0 -> 1 -> 0) per period based on target frequency for consistent strobe timing
            let period: TimeInterval = 1.0 / targetFrequency
            let phase = (elapsed.truncatingRemainder(dividingBy: period)) / period  // [0, 1)
            let triangleValue = phase < 0.5
                ? phase * 2.0              // 0 to 1
                : 2.0 - (phase * 2.0)      // 1 to 0
            return Double(event.intensity) * triangleValue
        }
    }
}
