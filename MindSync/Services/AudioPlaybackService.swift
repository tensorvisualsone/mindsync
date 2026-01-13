import Foundation
import AVFoundation
import os.log
import Darwin

@MainActor
final class AudioPlaybackService: NSObject {
    private let logger = Logger(subsystem: "com.mindsync", category: "AudioPlaybackService")
    
    // MARK: - Constants
    
    /// Maximum time to wait for audio playback to start before falling back (in seconds)
    /// Reduced from 10s to 3s for better user experience - if audio hasn't started
    /// within 3 seconds, something is likely wrong and waiting longer frustrates users
    private static let playbackStartTimeout: TimeInterval = 3.0
    
    /// Fallback time offset when hardware render time is unavailable (in seconds)
    /// Assumes audio started approximately 100ms ago when we detect it's rendering
    /// but can't get precise hardware timing
    static let fallbackRenderTimeOffset: TimeInterval = 0.1
    
    /// Minimum time audio must be rendering stably before we trust the timing (in seconds)
    /// This prevents using timestamps when audio just started but isn't stable yet
    /// Used by both AudioPlaybackService and BaseLightController for consistency
    static let minimumStableAudioTime: TimeInterval = 0.1 // 100ms
    
    /// Polling interval for checking if audio has started rendering (in nanoseconds)
    /// 50ms provides good responsiveness while limiting CPU usage
    /// Calculation: 50 milliseconds * 1,000,000 nanoseconds/millisecond = 50,000,000 nanoseconds
    private static let renderCheckPollingInterval: UInt64 = 50 * 1_000_000
    
    /// Playback state to distinguish between scheduled and actually playing
    private enum PlaybackState {
        case idle           // No playback prepared
        case scheduled      // Scheduled to start at a future time (not yet playing)
        case playing        // Currently playing
        case paused         // Paused during playback
    }
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var playbackTimer: Timer?
    
    // Thread-safe state management using OSAllocatedUnfairLock (heap-allocated, memory-safe)
    // Note: All state access is now protected by stateLock to prevent race conditions
    // between UI thread, timer callbacks, and audio render thread
    // OSAllocatedUnfairLock is heap-allocated and maintains a stable memory address,
    // making it safe to use in a class (unlike os_unfair_lock_s which is memory-unsafe)
    private let stateLock = OSAllocatedUnfairLock(initialState: PlaybackState.idle)
    private var playbackState: PlaybackState {
        get {
            stateLock.withLock { $0 }
        }
        set {
            stateLock.withLock { state in
                let oldValue = state
                if oldValue != newValue {
                    logger.debug("PlaybackState transition: \(String(describing: oldValue)) → \(String(describing: newValue))")
                }
                state = newValue
            }
        }
    }
    
    /// Callback when playback completes
    var onPlaybackComplete: (() -> Void)?
    
    /// Deprecated: Use getMainMixerNode() instead for volume control
    /// Kept for backward compatibility with AffirmationService
    @available(*, deprecated, message: "Use getMainMixerNode() for volume control instead")
    var audioPlayer: AVAudioPlayer? {
        // Return nil to signal that AVAudioPlayer is no longer used
        // AffirmationService should be updated to use MixerNode volume control
        return nil
    }
    
    /// Returns the main mixer node for installing taps or controlling volume
    /// - Returns: The main mixer node of the audio engine, or nil if engine is not initialized
    func getMainMixerNode() -> AVAudioMixerNode? {
        return audioEngine?.mainMixerNode
    }

    /// Returns the internal AVAudioEngine instance if available. Useful for attaching
    /// additional nodes (e.g., isochronic source) for perfectly synchronized audio.
    func getAudioEngine() -> AVAudioEngine? {
        return audioEngine
    }

    /// Prepares audio for playback without starting it
    /// This allows scheduling playback to start at a specific time for synchronization
    /// - Parameter url: URL of the audio file
    /// - Throws: Error if preparation is not possible
    func prepare(url: URL) throws {
        stop()
        
        // Configure audio session to ensure audio plays even in silent mode
        // and handles interruptions appropriately for a safety-critical app
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default, options: [])
        try audioSession.setActive(true)
        
        // Create audio engine and player node
        let engine = AVAudioEngine()
        let node = AVAudioPlayerNode()
        
        // Attach player node to engine
        engine.attach(node)
        
        // Load audio file
        let file = try AVAudioFile(forReading: url)
        audioFile = file
        
        // Connect player node to main mixer
        engine.connect(node, to: engine.mainMixerNode, format: file.processingFormat)
        
        // Schedule file for playback (but don't start yet)
        node.scheduleFile(file, at: nil) { [weak self] in
            DispatchQueue.main.async {
                self?.handlePlaybackComplete()
            }
        }
        
        // Start engine (but don't start playback yet)
        try engine.start()
        
        // Store references
        audioEngine = engine
        playerNode = node
        
        logger.info("Audio prepared for playback: \(url.lastPathComponent, privacy: .public)")
    }
    
    /// Plays an audio file immediately
    /// - Parameter url: URL of the audio file
    /// - Throws: Error if playback is not possible
    func play(url: URL) throws {
        try prepare(url: url)
        
        // Start playback immediately
        playerNode?.play()
        
        // Track playback position for currentTime property
        startPlaybackTimer()
        playbackState = .playing
        
        logger.info("Audio playback started: \(url.lastPathComponent, privacy: .public)")
    }
    
    /// Schedules audio playback to start at a specific future time
    /// This enables Master Clock synchronization by aligning audio start with other systems
    /// - Parameters:
    ///   - futureStartTime: The Date when playback should start
    ///   - Throws: Error if scheduling is not possible
    func schedulePlayback(at futureStartTime: Date) throws {
        guard audioEngine != nil,  // Engine must be running
              let node = playerNode,
              let file = audioFile else {
            throw NSError(
                domain: "AudioPlaybackService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Audio not prepared. Call prepare(url:) first."]
            )
        }
        
        // Calculate delay from now to future start time
        let delay = futureStartTime.timeIntervalSinceNow
        
        guard delay >= 0 else {
            throw NSError(
                domain: "AudioPlaybackService",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Future start time must be in the future"]
            )
        }
        
        // Get current audio time from the engine with host-time context
        // This ensures reliable scheduling by maintaining the host-time reference
        let sampleRate = file.fileFormat.sampleRate
        let engine = audioEngine!
        
        // Get hostTime from node's lastRenderTime, or fallback to engine's outputNode
        let currentHostTime: UInt64
        let currentSampleTime: AVAudioFramePosition
        let currentSampleRate: Double
        
        if let nodeLastRenderTime = node.lastRenderTime {
            // Node has rendered, use its hostTime and sampleTime
            currentHostTime = nodeLastRenderTime.hostTime
            currentSampleTime = nodeLastRenderTime.sampleTime
            currentSampleRate = nodeLastRenderTime.sampleRate
        } else if let outputLastRenderTime = engine.outputNode.lastRenderTime {
            // Node hasn't rendered yet, use engine's outputNode hostTime
            currentHostTime = outputLastRenderTime.hostTime
            currentSampleTime = outputLastRenderTime.sampleTime
            currentSampleRate = outputLastRenderTime.sampleRate
        } else {
            // Engine hasn't rendered yet, use current mach time as baseline
            currentHostTime = mach_absolute_time()
            currentSampleTime = 0
            currentSampleRate = sampleRate
        }
        
        // Convert delay (seconds) to host ticks for precise scheduling using mach timebase
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        let nanosecondsPerTick = Double(timebaseInfo.numer) / Double(timebaseInfo.denom)
        let delayInNanoseconds = delay * 1_000_000_000.0
        let delayInHostTicks = UInt64(delayInNanoseconds / nanosecondsPerTick)
        
        // Compute future host time with explicit overflow handling to avoid incorrect scheduling.
        let futureHostTime: UInt64
        if delayInHostTicks > UInt64.max - currentHostTime {
            // Overflow would occur: this indicates an invalidly large delay.
            // Log the issue and fall back to starting as soon as possible instead of scheduling "never".
            logger.error("AudioPlaybackService.schedulePlayback: delayInHostTicks (\(delayInHostTicks)) would overflow hostTime (currentHostTime=\(currentHostTime)). Starting immediately instead of applying delay.")
            futureHostTime = currentHostTime
        } else {
            futureHostTime = currentHostTime + delayInHostTicks
        }
        
        // Calculate future sample time at the current render sample rate
        let delayInSamples = AVAudioFramePosition(delay * currentSampleRate)
        let futureSampleTime = currentSampleTime + delayInSamples
        
        // Create AVAudioTime with both sampleTime and hostTime for reliable scheduling
        // This maintains host-time context which makes node.play(at:) reliable
        let futureAudioTime = AVAudioTime(
            hostTime: futureHostTime,
            sampleTime: futureSampleTime,
            atRate: currentSampleRate
        )
        
        // Start playback at the scheduled time
        node.play(at: futureAudioTime)
        
        // Track playback position for currentTime property
        // Adjust start time to account for the delay
        playbackStartTime = futureStartTime
        segmentStartTime = 0
        
        // Get file duration
        fileDuration = Double(file.length) / sampleRate
        
        // Set state to scheduled (not yet playing, waiting for futureStartTime)
        playbackState = .scheduled
        
        logger.info("Audio playback scheduled to start at: \(futureStartTime) (delay=\(delay)s, sampleTime=\(futureSampleTime), state=scheduled)")
    }

    /// Stops playback
    func stop() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        
        playerNode?.stop()
        
        // Disconnect and detach nodes before stopping engine
        if let engine = audioEngine, let node = playerNode {
            engine.disconnectNodeInput(node)
            engine.detach(node)
        }
        
        audioEngine?.stop()
        audioEngine = nil
        playerNode = nil
        audioFile = nil
        
        // Reset timing tracking
        playbackStartTime = nil
        accumulatedPauseTime = 0
        lastPauseTime = nil
        fileDuration = 0
        playbackState = .idle
        
        logger.info("Audio playback stopped")
    }

    /// Pauses playback
    func pause() {
        guard let node = playerNode else { return }
        
        let currentState = playbackState
        guard currentState == .playing || currentState == .scheduled else { return }
        
        // If scheduled but not yet playing, stop the scheduled playback
        if currentState == .scheduled {
            // Cancel the scheduled playback by stopping and clearing the node
            node.stop()
            playbackState = .paused
            logger.info("Audio playback paused (was scheduled)")
            return
        }
        
        // Track pause time for accurate resume
        lastPauseTime = Date()
        
        node.pause()
        playbackTimer?.invalidate()
        playbackTimer = nil
        playbackState = .paused
        
        logger.info("Audio playback paused")
    }

    /// Resumes playback
    func resume() {
        guard let engine = audioEngine, let node = playerNode, let file = audioFile else { return }
        
        // Calculate paused position
        let pausedPosition = currentTime
        segmentStartTime = pausedPosition
        
        // If we were paused, we need to reschedule from the paused position
        if let lastPause = lastPauseTime {
            // Adjust accumulated pause time
            let pauseDuration = Date().timeIntervalSince(lastPause)
            accumulatedPauseTime += pauseDuration
            lastPauseTime = nil
        }
        
        // Engine might have stopped, restart if needed
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                logger.error("Failed to restart audio engine: \(error.localizedDescription, privacy: .public)")
                return
            }
        }
        
        // If we need to resume from a specific position, schedule the remaining segment
        if pausedPosition > 0 && pausedPosition < fileDuration {
            let startFrame = AVAudioFramePosition(pausedPosition * file.fileFormat.sampleRate)
            let remainingFrames = file.length - startFrame
            
            if remainingFrames > 0 {
                node.scheduleSegment(
                    file,
                    startingFrame: startFrame,
                    frameCount: AVAudioFrameCount(remainingFrames),
                    at: nil
                ) { [weak self] in
                    DispatchQueue.main.async {
                        self?.handlePlaybackComplete()
                    }
                }
            }
        }
        
        node.play()
        // IMPORTANT: Do NOT call startPlaybackTimer() here, as it would reset
        // playbackStartTime and segmentStartTime, corrupting timing after resume.
        // We only update segmentStartTime from pausedPosition above and keep
        // the original playbackStartTime to preserve absolute timing.
        playbackState = .playing
        logger.info("Audio playback resumed from position: \(pausedPosition, privacy: .public) seconds")
    }

    /// Current playback time in seconds (based on Date() timing)
    /// Returns 0 if playback is scheduled but not yet started (waiting for futureStartTime)
    var currentTime: TimeInterval {
        guard let startTime = playbackStartTime else { return 0 }
        
        let now = Date()
        
        // Thread-safe check and update of playback state
        let currentState = stateLock.withLock { state -> PlaybackState in
            // If scheduled, check if the start time has been reached
            if state == .scheduled {
                if now >= startTime {
                    // Start time reached, transition to playing state
                    state = .playing
                    logger.info("Audio playback transitioned from scheduled to playing at: \(now)")
                } else {
                    // Still waiting for start time
                    return .scheduled
                }
            }
            return state
        }
        
        // If still scheduled, return 0 (waiting for start time)
        if currentState == .scheduled {
            return 0
        }
        
        let elapsed = now.timeIntervalSince(startTime)
        let totalElapsed = elapsed - accumulatedPauseTime
        
        // If currently paused, don't count time since pause
        if let pauseTime = lastPauseTime {
            let pauseDuration = now.timeIntervalSince(pauseTime)
            return max(0, totalElapsed - pauseDuration)
        }
        
        // Clamp to file duration if available
        if fileDuration > 0 {
            return min(max(0, totalElapsed), fileDuration)
        }
        
        return max(0, totalElapsed)
    }
    
    /// Precise audio time in seconds (derived from AVAudioPlayerNode's render time)
    /// This provides audio-thread accurate timing, eliminating drift between audio and display threads
    /// Note: totalTime is already the absolute position in the file, so we don't subtract accumulatedPauseTime
    var preciseAudioTime: TimeInterval {
        // Thread-safe state check
        if playbackState == .scheduled {
            return 0
        }
        
        guard let node = playerNode,
              let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime) else {
            // Fallback to currentTime if render time is not available
            // This will also handle the scheduled -> playing transition
            return currentTime
        }
        
        // If we have render time, audio is actually playing - update state if needed
        stateLock.withLock { state in
            if state == .scheduled {
                state = .playing
                logger.info("Audio playback transitioned from scheduled to playing (detected via render time)")
            }
        }
        
        // Time elapsed in current segment (Samples / Rate)
        let segmentElapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
        
        // Total time in file (segmentStartTime is the file position where we started the current segment)
        // This is already the absolute position in the file, so no need to subtract accumulatedPauseTime
        let totalTime = segmentStartTime + segmentElapsed
        
        // Note: totalTime already represents the absolute position in the file.
        // We don't subtract pause time here because segmentStartTime is already adjusted on resume.
        // The previous implementation incorrectly subtracted accumulatedPauseTime, causing double-counting
        // since segmentStartTime already accounts for all previous pause adjustments.
        let adjustedTime = totalTime
        
        // Clamp to file duration if available
        if fileDuration > 0 {
            return min(max(0, adjustedTime), fileDuration)
        }
        
        return max(0, adjustedTime)
    }
    
    private var playbackStartTime: Date?
    private var accumulatedPauseTime: TimeInterval = 0
    private var lastPauseTime: Date?
    private var fileDuration: TimeInterval = 0
    private var segmentStartTime: TimeInterval = 0
    
    private func startPlaybackTimer() {
        // Track playback start time and file duration
        playbackStartTime = Date()
        segmentStartTime = 0
        
        // Get file duration
        if let file = audioFile {
            fileDuration = Double(file.length) / file.fileFormat.sampleRate
        }
    }

    /// Is playback active?
    /// Returns true only when actually playing (not when scheduled but waiting to start)
    var isPlaying: Bool {
        return playbackState == .playing
    }
    
    /// Is playback scheduled to start in the future?
    var isScheduled: Bool {
        return playbackState == .scheduled
    }
    
    /// Gets the actual audio render start time from AVAudioPlayerNode's lastRenderTime
    /// Converts the audio hardware render time to a Date using mach timebase conversion
    /// Uses playerTime.sampleTime and elapsed time to calculate when playback actually started
    /// - Returns: The actual audio render start time as Date, or nil if not available
    private func getActualAudioRenderStartTime() -> Date? {
        guard let node = playerNode,
              let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime) else {
            return nil
        }
        
        // Convert hostTime (mach_absolute_time) to Date
        // hostTime is in mach time units, need to convert to nanoseconds then to Date
        var timebaseInfo = mach_timebase_info_data_t()
        mach_timebase_info(&timebaseInfo)
        
        // Calculate when playback actually started
        // playerTime.sampleTime is the number of samples that have been rendered
        // If sampleTime is small (e.g., < 0.1 seconds worth), playback just started
        let samplesElapsed = Double(playerTime.sampleTime)
        let secondsElapsed = samplesElapsed / playerTime.sampleRate
        
        // Convert the hostTime to Date
        let nanoseconds = (Double(nodeTime.hostTime) * Double(timebaseInfo.numer)) / Double(timebaseInfo.denom)
        
        // Convert nanoseconds to Date
        // Note: mach_absolute_time() provides nanosecond precision, but systemUptime
        // is in seconds (TimeInterval/Double). This conversion may lose sub-millisecond
        // precision in the final Date. For audio sync purposes, millisecond-level
        // precision is generally sufficient (human perception ~20ms). If sub-millisecond
        // precision becomes critical, consider using mach times throughout instead of Date.
        // mach_absolute_time() is relative to boot time, so we need to add boot time offset
        let bootTime = Date(timeIntervalSinceNow: -ProcessInfo.processInfo.systemUptime)
        let renderTime = bootTime.addingTimeInterval(nanoseconds / 1_000_000_000.0)
        
        // Subtract the elapsed playback time to get the actual start time
        let actualStartTime = renderTime.addingTimeInterval(-secondsElapsed)
        
        return actualStartTime
    }
    
    /// Helper function to safely update playback state from async context
    /// Since we're @MainActor, we can use a Task with MainActor isolation
    /// to safely update state without deadlocks
    private func updatePlaybackStateIfScheduled() {
        // Update state using heap-allocated OSAllocatedUnfairLock (memory-safe)
        stateLock.withLock { state in
            if state == .scheduled {
                state = .playing
                logger.info("Audio playback transitioned from scheduled to playing (detected via render time)")
            }
        }
    }
    
    /// Checks if audio has actually started rendering by checking lastRenderTime
    /// This is more reliable than checking isPlaying state, which may lag behind
    /// Validates that we have valid timing information from the audio hardware
    /// - Returns: True if audio is rendering with valid timing data, false otherwise
    private func isAudioActuallyRendering() -> Bool {
        guard let node = playerNode,
              let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime) else {
            return false
        }
        
        // Audio is rendering if we have a valid playerTime
        // Check that sampleTime is reasonable (not negative and not too large)
        return playerTime.sampleTime >= 0 && playerTime.sampleTime < Int64.max / 2
    }
    
    /// Waits for audio to actually start playing after being scheduled
    /// This is necessary because AVAudioPlayerNode.play(at:) may not start immediately
    /// Uses direct checking of lastRenderTime for more reliable detection
    /// 
    /// ## Polling Strategy
    /// This method uses a polling approach with 50ms intervals (configurable via `renderCheckPollingInterval`).
    /// While polling is not the most efficient mechanism, it was chosen because:
    /// - AVAudioPlayerNode does not provide KVO or notifications for render state changes
    /// - The polling interval (50ms) balances responsiveness with CPU efficiency
    /// - Polling duration is limited by timeout (default 3s), minimizing battery impact
    /// - Task.sleep yields control, preventing UI blocking
    /// 
    /// ## Future Improvements
    /// If AVFoundation adds notification support for render events, consider migrating to:
    /// - KVO on AVAudioPlayerNode.lastRenderTime
    /// - NotificationCenter observers for render state changes
    /// - Completion handlers or Combine publishers for render events
    /// 
    /// For now, polling provides the most reliable cross-iOS-version compatibility.
    /// 
    /// ## Stability Check
    /// This method now waits for audio to render for at least 100ms before returning the start time.
    /// This ensures that the calculated start time is stable and accurate, preventing synchronization
    /// issues where the light script starts before audio is actually playing.
    /// 
    /// - Parameter timeout: Maximum time to wait in seconds (default: 3.0 for better UX)
    /// - Returns: The actual audio render start time (from hardware) if audio started, nil if timeout
    @MainActor
    func waitForPlaybackToStart(timeout: TimeInterval? = nil) async -> Date? {
        let actualTimeout = timeout ?? AudioPlaybackService.playbackStartTimeout
        let waitStartTime = Date()
        
        var firstRenderDetectedTime: Date?
        var firstRenderStartTime: Date?
        
        // Poll until audio is rendering stably or timeout
        while Date().timeIntervalSince(waitStartTime) < actualTimeout {
            // Check if audio has actually started rendering by checking lastRenderTime directly
            // This is more reliable than checking isPlaying state
            if isAudioActuallyRendering() {
                // Update state if needed (using synchronous helper to avoid async locking issues)
                updatePlaybackStateIfScheduled()
                
                // Get the current precise audio time to check if it's stable
                let currentPreciseTime = preciseAudioTime
                
                // If this is the first time we detect rendering, record it
                if firstRenderDetectedTime == nil {
                    firstRenderDetectedTime = Date()
                    // Try to get the actual start time, but we'll validate it after stability check
                    firstRenderStartTime = getActualAudioRenderStartTime()
                    logger.info("Audio rendering detected for the first time at: \(firstRenderDetectedTime!), preciseAudioTime: \(currentPreciseTime)s")
                }
                
                // Wait for audio to render for at least minimumStableAudioTime before returning
                // This ensures the start time calculation is stable and accurate
                if let firstDetected = firstRenderDetectedTime {
                    let renderDuration = Date().timeIntervalSince(firstDetected)
                    if renderDuration >= Self.minimumStableAudioTime {
                        // Audio has been rendering stably - return the start time
                        if let startTime = checkStableAudioAndReturnStartTime(
                            firstDetected: firstDetected,
                            firstRenderStartTime: firstRenderStartTime,
                            renderDuration: renderDuration,
                            waitStartTime: waitStartTime
                        ) {
                            return startTime
                        }
                    } else {
                        // Audio is rendering but not stable yet, continue waiting
                        logger.debug("Audio rendering detected but not yet stable (duration: \(renderDuration)s, need: \(Self.minimumStableAudioTime)s)")
                    }
                }
            }
            
            // Check if state changed (backup check)
            if isPlaying {
                // State says playing, but lastRenderTime might not be available yet
                // Wait a bit more and check again
                try? await Task.sleep(nanoseconds: Self.renderCheckPollingInterval)
                if isAudioActuallyRendering() {
                    // Re-check stability if we already detected rendering
                    if let firstDetected = firstRenderDetectedTime {
                        let renderDuration = Date().timeIntervalSince(firstDetected)
                        if renderDuration >= Self.minimumStableAudioTime {
                            if let startTime = checkStableAudioAndReturnStartTime(
                                firstDetected: firstDetected,
                                firstRenderStartTime: firstRenderStartTime,
                                renderDuration: renderDuration,
                                waitStartTime: waitStartTime
                            ) {
                                return startTime
                            }
                        }
                    }
                }
            }
            
            // Wait a short time before checking again (using configured polling interval)
            try? await Task.sleep(nanoseconds: Self.renderCheckPollingInterval)
        }
        
        // Final check after timeout
        if isAudioActuallyRendering(), let firstDetected = firstRenderDetectedTime {
            let renderDuration = Date().timeIntervalSince(firstDetected)
            if renderDuration >= Self.minimumStableAudioTime {
                if let actualStartTime = firstRenderStartTime ?? getActualAudioRenderStartTime() {
                    let waitDuration = Date().timeIntervalSince(waitStartTime)
                    logger.info("Audio playback confirmed started and stable after \(waitDuration)s wait (timeout reached, stable for \(renderDuration)s), actual render start: \(actualStartTime)")
                    return actualStartTime
                }
            }
        }
        
        logger.warning("Audio playback did not start within \(actualTimeout)s timeout")
        return nil
    }
    
    /// Helper method to check if audio is stable and return the start time
    /// Extracts common logic for returning audio start time once stability is confirmed
    private func checkStableAudioAndReturnStartTime(
        firstDetected: Date,
        firstRenderStartTime: Date?,
        renderDuration: TimeInterval,
        waitStartTime: Date
    ) -> Date? {
        // Audio has been rendering stably for at least minimumStableAudioTime
        // Now we can confidently return the start time
        if let actualStartTime = firstRenderStartTime ?? getActualAudioRenderStartTime() {
            let waitDuration = Date().timeIntervalSince(waitStartTime)
            logger.info("Audio playback confirmed started and stable after \(waitDuration)s wait (stable for \(renderDuration)s), actual render start: \(actualStartTime)")
            return actualStartTime
        } else {
            // Fallback: use first detected time minus a small offset
            let fallbackTime = firstDetected.addingTimeInterval(-Self.fallbackRenderTimeOffset)
            logger.info("Audio playback confirmed stable but hardware time unavailable, using fallback: \(fallbackTime)")
            return fallbackTime
        }
    }
    
    /// Total duration of the currently loaded file
    var duration: TimeInterval {
        fileDuration
    }
    
    /// Handles playback completion
    private func handlePlaybackComplete() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        logger.info("Audio playback completed")
        onPlaybackComplete?()
    }
}
