import Foundation

/// Result of finding the current event in a script
struct CurrentEventResult {
    let event: LightEvent?
    let elapsed: TimeInterval
    let isComplete: Bool
}

/// Base class for light controllers to reduce code duplication
class BaseLightController: NSObject {
    // MARK: - Shared Properties
    
    private(set) var currentScript: LightScript?
    private(set) var scriptStartTime: Date?
    private(set) var displayLink: CADisplayLink?
    private(set) var currentEventIndex: Int = 0
    
    // MARK: - Display Link Management
    
    /// Sets up the display link with a weak target wrapper
    func setupDisplayLink(target: AnyObject, selector: Selector) {
        displayLink = CADisplayLink(target: target, selector: selector)
        displayLink?.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60,
            maximum: 120,
            preferred: 120
        )
        displayLink?.add(to: .main, forMode: .common)
    }
    
    /// Invalidates and cleans up the display link
    func invalidateDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }
    
    // MARK: - Script Execution Helpers
    
    /// Initializes script execution state
    func initializeScriptExecution(script: LightScript, startTime: Date) {
        currentScript = script
        scriptStartTime = startTime
        currentEventIndex = 0
    }
    
    /// Resets script execution state
    func resetScriptExecution() {
        currentScript = nil
        scriptStartTime = nil
        currentEventIndex = 0
    }
    
    /// Finds the current event in the script based on elapsed time
    /// - Returns: CurrentEventResult containing the event (if active), elapsed time, and completion status
    func findCurrentEvent() -> CurrentEventResult {
        guard let script = currentScript,
              let startTime = scriptStartTime else {
            return CurrentEventResult(event: nil, elapsed: 0, isComplete: false)
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        
        // Check if script is finished
        if elapsed >= script.duration {
            return CurrentEventResult(event: nil, elapsed: elapsed, isComplete: true)
        }
        
        // Skip past events to find current event using index tracking
        var foundEventIndex = currentEventIndex
        while foundEventIndex < script.events.count {
            let event = script.events[foundEventIndex]
            let eventEnd = event.timestamp + event.duration
            
            if elapsed < eventEnd {
                if elapsed >= event.timestamp {
                    // Current event is active
                    currentEventIndex = foundEventIndex
                    return CurrentEventResult(event: event, elapsed: elapsed, isComplete: false)
                } else {
                    // Between events
                    return CurrentEventResult(event: nil, elapsed: elapsed, isComplete: false)
                }
            } else {
                // Move to next event
                foundEventIndex += 1
            }
        }
        
        // Passed all events
        return CurrentEventResult(event: nil, elapsed: elapsed, isComplete: true)
    }
}
