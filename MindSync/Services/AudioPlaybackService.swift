import Foundation
import AVFoundation
import os.log

@MainActor
final class AudioPlaybackService: NSObject {
    private let logger = Logger(subsystem: "com.mindsync", category: "AudioPlaybackService")
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var audioFile: AVAudioFile?
    private var playbackTimer: Timer?
    
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

    /// Plays an audio file
    /// - Parameter url: URL of the audio file
    /// - Throws: Error if playback is not possible
    func play(url: URL) throws {
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
        
        // Schedule file for playback
        node.scheduleFile(file, at: nil) { [weak self] in
            DispatchQueue.main.async {
                self?.handlePlaybackComplete()
            }
        }
        
        // Start engine
        try engine.start()
        
        // Start playback
        node.play()
        
        // Store references
        audioEngine = engine
        playerNode = node
        
        // Track playback position for currentTime property
        startPlaybackTimer()
        
        logger.info("Audio playback started: \(url.lastPathComponent, privacy: .public)")
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
        
        logger.info("Audio playback stopped")
    }

    /// Pauses playback
    func pause() {
        guard let node = playerNode, node.isPlaying else { return }
        
        // Track pause time for accurate resume
        lastPauseTime = Date()
        
        node.pause()
        playbackTimer?.invalidate()
        playbackTimer = nil
        
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
        startPlaybackTimer()
        logger.info("Audio playback resumed from position: \(pausedPosition, privacy: .public) seconds")
    }

    /// Current playback time in seconds (based on Date() timing)
    var currentTime: TimeInterval {
        guard let startTime = playbackStartTime else { return 0 }
        
        let elapsed = Date().timeIntervalSince(startTime)
        let totalElapsed = elapsed - accumulatedPauseTime
        
        // If currently paused, don't count time since pause
        if let pauseTime = lastPauseTime {
            let pauseDuration = Date().timeIntervalSince(pauseTime)
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
    var preciseAudioTime: TimeInterval {
        guard let node = playerNode,
              let nodeTime = node.lastRenderTime,
              let playerTime = node.playerTime(forNodeTime: nodeTime) else {
            // Fallback to currentTime if render time is not available
            return currentTime
        }
        
        // Time elapsed in current segment
        let segmentElapsed = Double(playerTime.sampleTime) / playerTime.sampleRate
        
        // Total time in file (segmentStartTime is the file position where we started the current segment)
        let totalTime = segmentStartTime + segmentElapsed
        
        // Clamp to file duration if available
        if fileDuration > 0 {
            return min(max(0, totalTime), fileDuration)
        }
        
        return max(0, totalTime)
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
    var isPlaying: Bool {
        return playerNode?.isPlaying ?? false
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
