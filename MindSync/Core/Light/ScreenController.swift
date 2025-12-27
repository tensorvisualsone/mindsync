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
    private var customColorRGB: CustomColorRGB?
    
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
        invalidateDisplayLink()
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
        
        if let script = currentScript {
            // Check if cinematic mode - apply dynamic intensity modulation
            if script.mode == .cinematic {
                // For cinematic mode, use continuous wave regardless of events
                // This ensures smooth synchronization even if beat detection is imperfect
                let audioEnergy = audioEnergyTracker?.currentEnergy ?? 0.0
                let baseFreq = script.targetFrequency
                let elapsed = result.elapsed
                
                // Calculate cinematic intensity (continuous wave)
                let cinematicIntensity = EntrainmentEngine.calculateCinematicIntensity(
                    baseFrequency: baseFreq,
                    currentTime: elapsed,
                    audioEnergy: audioEnergy
                )
                
                // Get color from default (cinematic mode doesn't use event colors)
                let lightColor = defaultColor
                let baseColor = lightColor.swiftUIColor(customRGB: customColorRGB?.tuple)
                
                // Use cinematic intensity directly as opacity
                currentColor = baseColor.opacity(Double(cinematicIntensity))
            } else if let event = result.event {
                // For other modes, use event-based intensity with waveform
                let lightColor = event.color ?? defaultColor
                let baseColor = lightColor.swiftUIColor(customRGB: customColorRGB?.tuple)
                
                // Apply intensity as opacity for smoother transitions
                // Waveform affects how intensity is applied over time
                let opacity = calculateOpacity(
                    event: event,
                    elapsed: result.elapsed - event.timestamp,
                    targetFrequency: script.targetFrequency
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
        // Use centralized WaveformGenerator (standard 50% duty cycle for square wave)
        return Double(WaveformGenerator.calculateIntensity(
            waveform: event.waveform,
            time: elapsed,
            frequency: targetFrequency,
            baseIntensity: event.intensity,
            dutyCycle: 0.5 // Standard duty cycle for screen
        ))
    }
}
