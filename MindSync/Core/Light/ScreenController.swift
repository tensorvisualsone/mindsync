import Foundation
import SwiftUI
import Combine

/// Weak reference wrapper for CADisplayLink target to avoid retain cycles
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
final class ScreenController: NSObject, LightControlling, ObservableObject {
    var source: LightSource { .screen }
    
    /// Published color for SwiftUI view
    @Published var currentColor: Color = .black
    @Published var isActive: Bool = false
    
    private var currentScript: LightScript?
    private var scriptStartTime: Date?
    private var displayLink: CADisplayLink?
    private var displayLinkTarget: WeakDisplayLinkTarget?
    private var currentEventIndex: Int = 0
    private var defaultColor: LightEvent.LightColor = .white
    
    override init() {
        super.init()
        // Screen controller uses SwiftUI views for display
    }
    
    deinit {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
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
        // For screen mode, intensity affects opacity
        // The color opacity will be adjusted during event execution
        // This is handled in updateScreen() based on event.intensity
    }

    func setColor(_ color: LightEvent.LightColor) {
        defaultColor = color
    }

    func execute(script: LightScript, syncedTo startTime: Date) {
        currentScript = script
        scriptStartTime = startTime
        currentEventIndex = 0

        // CADisplayLink for precise timing with weak reference wrapper to avoid retain cycle
        let target = WeakDisplayLinkTarget(target: self)
        displayLinkTarget = target
        displayLink = CADisplayLink(target: target, selector: #selector(WeakDisplayLinkTarget.updateScreen))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: 120,
            preferred: 120
        )
        displayLink?.add(to: .main, forMode: .common)
    }

    func cancelExecution() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
        currentScript = nil
        scriptStartTime = nil
        currentEventIndex = 0
        currentColor = .black
    }

    fileprivate func updateScreen() {
        guard let script = currentScript,
              let startTime = scriptStartTime else {
            currentColor = .black
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Check if script is finished
        if elapsed >= script.duration {
            cancelExecution()
            return
        }

        // Find current event
        var currentEvent: LightEvent?
        var foundEventIndex = currentEventIndex
        
        // Skip past events to find current event using index tracking
        while foundEventIndex < script.events.count {
            let event = script.events[foundEventIndex]
            let eventEnd = event.timestamp + event.duration
            
            if elapsed < eventEnd {
                if elapsed >= event.timestamp {
                    // Current event is active
                    currentEvent = event
                    currentEventIndex = foundEventIndex
                } else {
                    // Between events, turn off (black)
                    currentColor = .black
                }
                break
            } else {
                // Move to next event
                foundEventIndex += 1
            }
        }
        
        // Update display based on current event
        if let event = currentEvent {
            // Get color from event or use default
            let lightColor = event.color ?? defaultColor
            let baseColor = lightColor.swiftUIColor
            
            // Apply intensity as opacity for smoother transitions
            // Waveform affects how intensity is applied over time
            let opacity = calculateOpacity(
                event: event,
                elapsed: elapsed - event.timestamp
            )
            
            currentColor = baseColor.opacity(Double(opacity))
        } else {
            // No active event, show black
            currentColor = .black
        }
        
        // If we've passed all events, turn off
        if foundEventIndex >= script.events.count {
            currentColor = .black
        }
    }
    
    /// Calculates opacity based on waveform and time within event
    private func calculateOpacity(event: LightEvent, elapsed: TimeInterval) -> Double {
        let normalizedTime = min(1.0, max(0.0, elapsed / event.duration))
        
        switch event.waveform {
        case .square:
            // Hard on/off based on intensity
            return Double(event.intensity)
            
        case .sine:
            // Smooth sine wave pulsation
            let sineValue = sin(normalizedTime * .pi * 2.0)
            // Map from [-1, 1] to [0, intensity]
            let normalizedSine = (sineValue + 1.0) / 2.0
            return Double(event.intensity) * normalizedSine
            
        case .triangle:
            // Linear ramp up then down
            let triangleValue = normalizedTime < 0.5 
                ? normalizedTime * 2.0  // 0 to 1
                : 2.0 - (normalizedTime * 2.0)  // 1 to 0
            return Double(event.intensity) * triangleValue
        }
    }
}
