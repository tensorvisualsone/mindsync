import Foundation
import QuartzCore

/// Result of finding the current event in a script
struct CurrentEventResult {
    let event: LightEvent?
    let elapsed: TimeInterval
    let isComplete: Bool
}

/// Base class for light controllers to reduce code duplication
@MainActor
class BaseLightController: NSObject {
    // MARK: - Shared Properties
    
    @MainActor private(set) var currentScript: LightScript?
    @MainActor private(set) var scriptStartTime: Date?
    @MainActor private(set) var totalPauseDuration: TimeInterval = 0
    @MainActor private(set) var pauseStartTime: Date?
    @MainActor private(set) var isPaused: Bool = false
    nonisolated(unsafe) private(set) var displayLink: CADisplayLink?
    @MainActor private(set) var currentEventIndex: Int = 0
    
    /// AudioEnergyTracker for cinematic mode dynamic intensity modulation (optional)
    weak var audioEnergyTracker: AudioEnergyTracker?
    
    // MARK: - Display Link Management
    
    /// Sets up the display link with a weak target wrapper
    /// 
    /// WICHTIG: CADisplayLink wird pausiert, sobald die App in den Hintergrund geht oder der Screen ausgeht.
    /// Das Audio läuft weiter, aber das Licht friert ein oder geht aus. Die Synchronisation bricht.
    /// 
    /// LÖSUNG: Für eine robuste Synchronisation sollte das Timing vom Audio-Thread abgeleitet werden,
    /// nicht von der Video-Refresh-Rate (Display). Alternativ kann `UIApplication.shared.isIdleTimerDisabled = true`
    /// gesetzt werden, damit der Screen an bleibt (User muss das wissen).
    /// 
    /// Pro-Solution: Nutze einen AVAudioSourceNode oder einen Timer auf einem Background-Thread,
    /// der mit der Audio-Engine synchronisiert ist.
    @MainActor func setupDisplayLink(target: AnyObject, selector: Selector) {
        displayLink = CADisplayLink(target: target, selector: selector)
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: 120,
            preferred: 120
        )
        displayLink?.add(to: .main, forMode: .common)
    }
    
    /// Invalidates and cleans up the display link
    nonisolated func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - Script Execution Helpers
    
    /// Initializes script execution state
    @MainActor func initializeScriptExecution(script: LightScript, startTime: Date) {
        currentScript = script
        scriptStartTime = startTime
        currentEventIndex = 0
    }
    
    /// Resets script execution state
    @MainActor func resetScriptExecution() {
        currentScript = nil
        scriptStartTime = nil
        currentEventIndex = 0
        totalPauseDuration = 0
        pauseStartTime = nil
        isPaused = false
    }
    
    /// Pauses script execution by stopping the display link
    /// - Note: Calls `invalidateDisplayLink()` which is `nonisolated` for safe cross-actor access.
    ///   This is safe because CADisplayLink's invalidate() can be called from any thread.
    @MainActor func pauseScriptExecution() {
        guard !isPaused else { return }
        isPaused = true
        pauseStartTime = Date()
        invalidateDisplayLink()
    }
    
    /// Resumes script execution by adjusting start time to account for pause duration
    @MainActor func resumeScriptExecution() {
        guard isPaused, let pauseStart = pauseStartTime else { return }
        isPaused = false
        // Add the pause duration to the total pause time
        totalPauseDuration += Date().timeIntervalSince(pauseStart)
        pauseStartTime = nil
    }
    
    /// Finds the current event in the script based on elapsed time
    /// - Returns: CurrentEventResult containing the event (if active), elapsed time, and completion status
    @MainActor func findCurrentEvent() -> CurrentEventResult {
        guard let script = currentScript,
              let startTime = scriptStartTime else {
            return CurrentEventResult(event: nil, elapsed: 0, isComplete: false)
        }
        
        // Calculate elapsed time accounting for pauses
        let realElapsed = Date().timeIntervalSince(startTime) - totalPauseDuration
        
        // Check if script is finished
        if realElapsed >= script.duration {
            return CurrentEventResult(event: nil, elapsed: realElapsed, isComplete: true)
        }
        
        // Skip past events to find current event using index tracking
        var foundEventIndex = currentEventIndex
        while foundEventIndex < script.events.count {
            let event = script.events[foundEventIndex]
            let eventEnd = event.timestamp + event.duration
            
            if realElapsed < eventEnd {
                if realElapsed >= event.timestamp {
                    // Current event is active
                    currentEventIndex = foundEventIndex
                    return CurrentEventResult(event: event, elapsed: realElapsed, isComplete: false)
                } else {
                    // Between events
                    return CurrentEventResult(event: nil, elapsed: realElapsed, isComplete: false)
                }
            } else {
                // Move to next event
                foundEventIndex += 1
            }
        }
        
        // Passed all events
        return CurrentEventResult(event: nil, elapsed: realElapsed, isComplete: true)
    }
}
