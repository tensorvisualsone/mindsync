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
    private(set) var displayLink: CADisplayLink?
    private var precisionTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.mindsync.entrainment", qos: .userInteractive)
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
    
    /// Sets up a high-priority DispatchSourceTimer for precise timing decoupled from the display refresh rate.
    /// - Parameters:
    ///   - interval: Repetition interval for the timer.
    ///   - handler: Callback executed on the main actor for UI-safe updates.
    @MainActor
    func setupPrecisionTimer(
        interval: DispatchTimeInterval,
        handler: @escaping @MainActor () -> Void
    ) {
        invalidatePrecisionTimer()
        
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: timerQueue)
        timer.schedule(deadline: .now(), repeating: interval)
        timer.setEventHandler {
            Task { @MainActor in
                handler()
            }
        }
        timer.resume()
        precisionTimer = timer
    }
    
    /// Invalidates and cleans up the precision timer
    @MainActor
    func invalidatePrecisionTimer() {
        precisionTimer?.cancel()
        precisionTimer = nil
    }
    
    /// Invalidates and cleans up the display link
    func invalidateDisplayLink() {
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
        invalidatePrecisionTimer()
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
            // CRITICAL FIX: Wait for audio to actually start playing and render stably before using precise timing
            // This ensures light and audio start at exactly the same time
            // 
            // Stability check: Require preciseAudioTime to be at least minimumStableAudioTime before using it.
            // This prevents the light script from starting before audio is actually playing, which can
            // happen if there's a delay between when isPlaying is set and when audio actually starts rendering.
            // The threshold ensures audio has been rendering stably and the timing is accurate.
            
            if audioPlayback.isPlaying {
                // Use audio-thread precise timing while audio is actually playing
                // IMPORTANT: Only use preciseAudioTime if it's >= minimumStableAudioTime, indicating audio has been rendering stably
                let preciseTime = audioPlayback.preciseAudioTime
                if preciseTime >= AudioPlaybackService.minimumStableAudioTime {
                    // Audio is actually rendering stably - use precise timing
                    currentTime = preciseTime
                } else if preciseTime > 0 {
                    // Audio just started rendering but not stable yet - wait to prevent desync
                    // Return nil event to prevent light from starting prematurely
                    return CurrentEventResult(event: nil, elapsed: 0, isComplete: false)
                } else {
                    // Audio state says "playing" but preciseAudioTime is 0 - audio hasn't started rendering yet
                    // Wait to prevent desync (return nil event)
                    // This can happen if there's a delay between when isPlaying is set and when audio actually starts rendering
                    return CurrentEventResult(event: nil, elapsed: 0, isComplete: false)
                }
            } else if audioPlayback.isScheduled {
                // Audio is scheduled but not yet playing - check if preciseAudioTime is available
                // If preciseAudioTime >= minimumStableAudioTime, audio has started and is stable (state transition pending)
                let preciseTime = audioPlayback.preciseAudioTime
                if preciseTime >= minimumStableAudioTime {
                    // Audio is actually playing stably (state just transitioned) - use precise timing
                    currentTime = preciseTime
                } else {
                    // Audio is scheduled but hasn't started yet or not stable - wait (return nil) to prevent desync
                    return CurrentEventResult(event: nil, elapsed: 0, isComplete: false)
                }
            } else {
                // Audio not scheduled and not playing - fallback to Date() timing
                // This handles cases like pause or audio-only modes
                currentTime = Date().timeIntervalSince(startTime) - totalPauseDuration
            }
        } else {
            // No audio playback reference - use Date() timing (e.g., Awakening Flow mode)
            currentTime = Date().timeIntervalSince(startTime) - totalPauseDuration
        }
        
        // Apply audio latency compensation: Delay light to match audio arrival time
        // Formula: adjustedTime = currentTime - audioLatencyOffset
        // Example: If audio has 200ms delay and player is at 10.2s,
        //          the user hears 10.0s, so we show light for 10.0s
        let adjustedElapsed = currentTime - audioLatencyOffset
        
        // Safety: Don't go negative (at start of track before latency compensation kicks in)
        // IMPORTANT: Use 0.0 instead of returning nil, so events starting at timestamp=0.0 are found
        // The audioLatencyOffset is typically small (15-20ms), so clamping to 0.0 is safe
        let clampedElapsed = max(0.0, adjustedElapsed)
        
        // Check if script is finished (use clamped time)
        if clampedElapsed >= script.duration {
            return CurrentEventResult(event: nil, elapsed: clampedElapsed, isComplete: true)
        }
        
        // Skip past events to find current event using index tracking
        var foundEventIndex = currentEventIndex
        while foundEventIndex < script.events.count {
            let event = script.events[foundEventIndex]
            let eventEnd = event.timestamp + event.duration
            
            if clampedElapsed < eventEnd {
                if clampedElapsed >= event.timestamp {
                    // Current event is active
                    currentEventIndex = foundEventIndex
                    return CurrentEventResult(event: event, elapsed: clampedElapsed, isComplete: false)
                } else {
                    // Between events
                    return CurrentEventResult(event: nil, elapsed: clampedElapsed, isComplete: false)
                }
            } else {
                // Move to next event
                foundEventIndex += 1
            }
        }
        
        // Passed all events
        return CurrentEventResult(event: nil, elapsed: clampedElapsed, isComplete: true)
    }
}
