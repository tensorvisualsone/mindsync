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
    
    /// Audio latency offset from user preferences (in seconds)
    /// This value compensates for Bluetooth audio delay by delaying light output
    /// to ensure audio and light arrive at the user simultaneously
    var audioLatencyOffset: TimeInterval = 0.0
    
    /// AudioPlaybackService reference for precise audio-thread timing (optional)
    /// When set, findCurrentEvent() uses preciseAudioTime instead of Date() for synchronization
    weak var audioPlayback: AudioPlaybackService?
    
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
        
        // Use precise audio time if available (audio-thread accurate), otherwise fall back to Date()
        // This eliminates drift between audio and display threads
        let currentTime: TimeInterval
        if let audioPlayback = audioPlayback {
            // Use audio-thread precise timing
            currentTime = audioPlayback.preciseAudioTime
        } else {
            // Fallback to Date() timing (e.g., during pause or before audio starts)
            currentTime = Date().timeIntervalSince(startTime) - totalPauseDuration
        }
        
        // Apply audio latency compensation: Delay light to match audio arrival time
        // Formula: adjustedTime = currentTime - audioLatencyOffset
        // Example: If audio has 200ms delay and player is at 10.2s,
        //          the user hears 10.0s, so we show light for 10.0s
        let adjustedElapsed = currentTime - audioLatencyOffset
        
        // Safety: Don't go negative (at start of track before latency compensation kicks in)
        guard adjustedElapsed >= 0 else {
            return CurrentEventResult(event: nil, elapsed: 0, isComplete: false)
        }
        
        // Check if script is finished (use adjusted time)
        if adjustedElapsed >= script.duration {
            return CurrentEventResult(event: nil, elapsed: adjustedElapsed, isComplete: true)
        }
        
        // Skip past events to find current event using index tracking
        var foundEventIndex = currentEventIndex
        while foundEventIndex < script.events.count {
            let event = script.events[foundEventIndex]
            let eventEnd = event.timestamp + event.duration
            
            if adjustedElapsed < eventEnd {
                if adjustedElapsed >= event.timestamp {
                    // Current event is active
                    currentEventIndex = foundEventIndex
                    return CurrentEventResult(event: event, elapsed: adjustedElapsed, isComplete: false)
                } else {
                    // Between events
                    return CurrentEventResult(event: nil, elapsed: adjustedElapsed, isComplete: false)
                }
            } else {
                // Move to next event
                foundEventIndex += 1
            }
        }
        
        // Passed all events
        return CurrentEventResult(event: nil, elapsed: adjustedElapsed, isComplete: true)
    }
}
