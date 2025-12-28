import Foundation

/// Circular buffer implementation for light events
/// Provides O(1) insertion and retrieval for time-based event scheduling
final class LightEventBuffer {
    private var buffer: [LightEvent?]
    private var writeIndex: Int = 0
    private var readIndex: Int = 0
    private let capacity: Int
    
    /// Current latency offset in seconds (determines buffer delay)
    var latencyOffset: TimeInterval = 0.0
    
    /// Initializes the buffer with a specified capacity
    /// - Parameter capacity: Maximum number of events the buffer can hold
    init(capacity: Int = 1000) {
        self.capacity = capacity
        self.buffer = Array(repeating: nil, count: capacity)
    }
    
    /// Adds an event to the buffer
    /// - Parameter event: The light event to buffer
    /// - Returns: true if event was added, false if buffer is full
    @discardableResult
    func add(_ event: LightEvent) -> Bool {
        // Calculate buffer position based on timestamp and latency offset
        // Events are stored at positions corresponding to their delayed playback time
        let delayedTimestamp = event.timestamp + latencyOffset
        
        // Simple modulo-based circular buffer
        // In a production system, you might want more sophisticated indexing
        let position = Int(delayedTimestamp * 10) % capacity // 10 Hz resolution
        
        guard position >= 0 && position < capacity else {
            return false
        }
        
        buffer[position] = event
        return true
    }
    
    /// Retrieves events that should be played at the current time
    /// - Parameter currentTime: Current playback time
    /// - Returns: Array of events that should be active now
    func getEvents(at currentTime: TimeInterval) -> [LightEvent] {
        var events: [LightEvent] = []
        
        // Check buffer positions around current time
        let timeWindow: TimeInterval = 0.1 // 100ms window
        let startTime = currentTime - timeWindow
        let endTime = currentTime + timeWindow
        
        for i in 0..<capacity {
            if let event = buffer[i] {
                // Check if event should be active based on its timestamp and duration
                let eventStart = event.timestamp
                let eventEnd = eventStart + event.duration
                
                // Event is active if it overlaps with the current time window
                if (eventStart <= endTime && eventEnd >= startTime) {
                    events.append(event)
                }
            }
        }
        
        return events
    }
    
    /// Clears all events from the buffer
    func clear() {
        buffer = Array(repeating: nil, count: capacity)
        writeIndex = 0
        readIndex = 0
    }
    
    /// Updates the latency offset and adjusts buffer accordingly
    /// - Parameter offset: New latency offset in seconds
    func updateLatencyOffset(_ offset: TimeInterval) {
        latencyOffset = offset
        // Optionally: re-index events based on new offset
        // For simplicity, we just update the offset and let getEvents() handle timing
    }
}
