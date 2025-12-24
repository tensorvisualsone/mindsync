import Foundation
import SwiftUI
import Combine
import MediaPlayer

/// ViewModel for session view
@MainActor
final class SessionViewModel: ObservableObject {
    // Services
    private let services = ServiceContainer.shared
    private let audioAnalyzer: AudioAnalyzer
    private let audioPlayback: AudioPlaybackService
    private let entrainmentEngine: EntrainmentEngine
    private let microphoneAnalyzer: MicrophoneAnalyzer?
    private let fallDetector: FallDetector
    
    // Cached preferences to avoid repeated UserDefaults access
    // Updated when starting a session to ensure current values are used
    private var cachedPreferences: UserPreferences
    
    // Published State
    @Published var state: SessionState = .idle
    @Published var currentTrack: AudioTrack?
    @Published var currentScript: LightScript?
    @Published var analysisProgress: AnalysisProgress?
    @Published var errorMessage: String?
    @Published var currentSession: Session?
    @Published var thermalWarningLevel: ThermalWarningLevel = .none
    
    // Screen controller for UI binding (only published when screen mode is active)
    var screenController: ScreenController? {
        lightController as? ScreenController
    }
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Current light controller based on cached preferences
    // Computed once per session to avoid repeated calculations
    private var lightController: LightControlling?
    
    // Microphone mode state
    private var microphoneBeatTimestamps: [TimeInterval] = []
    private var microphoneBPM: Double = 120.0
    private var microphoneStartTime: Date?
    private var lastScriptBPM: Double?
    
    // Maximum number of beat timestamps to keep in memory for BPM estimation.
    // This limit prevents unbounded memory growth during long microphone sessions
    // while maintaining sufficient history for accurate tempo estimation.
    // At typical BPM rates (60-150), 100 beats represent ≈40-100 seconds of audio.
    private let maxBeatHistoryCount = 100
    
    // Flag to prevent re-entrancy in fall detection handling
    private var isHandlingFall = false
    
    init() {
        self.audioAnalyzer = services.audioAnalyzer
        self.audioPlayback = services.audioPlayback
        self.cachedPreferences = UserPreferences.load()
        
        // EntrainmentEngine from ServiceContainer
        self.entrainmentEngine = services.entrainmentEngine
        
        // MicrophoneAnalyzer and FallDetector
        self.microphoneAnalyzer = services.microphoneAnalyzer
        self.fallDetector = services.fallDetector
        
        // Setup playback completion callback
        audioPlayback.onPlaybackComplete = { [weak self] in
            Task { @MainActor in
                self?.handlePlaybackComplete()
            }
        }
        
        // Listen to analysis progress
        audioAnalyzer.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.analysisProgress = progress
            }
            .store(in: &cancellables)
        
        // Listen to thermal state changes
        services.thermalManager.$warningLevel
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.handleThermalWarning(level)
            }
            .store(in: &cancellables)
        
        // Listen to fall detection events
        fallDetector.fallEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleFallDetected()
            }
            .store(in: &cancellables)
    }
    
    /// Handles thermal warning level changes during session
    private func handleThermalWarning(_ level: ThermalWarningLevel) {
        thermalWarningLevel = level
        
        // Only handle thermal events during running sessions
        guard state == .running else { return }
        
        switch level {
        case .none:
            // All good, no action needed
            break
            
        case .reduced:
            // Intensity is automatically reduced by FlashlightController
            // Just show the warning banner (handled by published property)
            break
            
        case .critical:
            // Automatic fallback to screen mode if available
            handleCriticalThermalState()
        }
    }
    
    /// Handles critical thermal state - attempts fallback to screen mode
    private func handleCriticalThermalState() {
        guard let currentScript = currentScript,
              let session = currentSession,
              lightController?.source == .flashlight else {
            return
        }
        
        // Stop flashlight
        lightController?.stop()
        
        // Switch to screen controller
        lightController = services.screenController
        
        do {
            try lightController?.start()
            
            // Resume from current session position using original session start time
            lightController?.execute(script: currentScript, syncedTo: session.startedAt)
            
        } catch {
            // If screen controller also fails, stop the session
            stopSession()
        }
    }
    
    deinit {
        // Note: Cleanup is handled by stopSession() which should be called before deallocation.
        // The AudioPlaybackService handles its own lifecycle and will stop when deallocated.
        // We intentionally don't call MainActor-isolated methods from deinit to avoid
        // Swift 6 concurrency warnings.
    }
    
    /// Handles playback completion
    private func handlePlaybackComplete() {
        guard state == .running else { return }
        stopSession()
    }
    
    /// Starts a session with a selected media item
    func startSession(with mediaItem: MPMediaItem) async {
        guard state == .idle else { return }
        
        state = .analyzing
        
        // Refresh cached preferences to ensure we use current user settings
        cachedPreferences = UserPreferences.load()
        
        // Set the light controller based on current preferences
        switch cachedPreferences.preferredLightSource {
        case .flashlight:
            lightController = services.flashlightController
        case .screen:
            lightController = services.screenController
        }
        
        do {
            // Check if item can be analyzed
            guard services.mediaLibraryService.canAnalyze(item: mediaItem),
                  let assetURL = services.mediaLibraryService.getAssetURL(for: mediaItem) else {
                errorMessage = "Dieser Titel ist durch DRM geschützt und kann nicht analysiert werden. Bitte nutze den Mikrofonmodus oder wähle einen anderen Titel."
                state = .error
                return
            }
            
            // Analyze audio
            let track = try await audioAnalyzer.analyze(url: assetURL, mediaItem: mediaItem)
            currentTrack = track
            
            // Generate LightScript using cached preferences
            let mode = cachedPreferences.preferredMode
            let lightSource = cachedPreferences.preferredLightSource
            let screenColor = cachedPreferences.screenColor
            
            let script = entrainmentEngine.generateLightScript(
                from: track,
                mode: mode,
                lightSource: lightSource,
                screenColor: lightSource == .screen ? screenColor : nil
            )
            currentScript = script
            
            // Create session
            let session = Session(
                mode: mode,
                lightSource: lightSource,
                audioSource: .localFile,
                trackTitle: track.title,
                trackArtist: track.artist,
                trackBPM: track.bpm
            )
            currentSession = session
            
            // Start playback and light
            try startPlaybackAndLight(url: assetURL, script: script)
            
            state = .running
            
            // Haptic feedback for session start (if enabled)
            if cachedPreferences.hapticFeedbackEnabled {
                HapticFeedback.medium()
            }
            
        } catch {
            // Set error state first to ensure it's always set, even if cleanup fails
            errorMessage = error.localizedDescription
            state = .error
            
            // Cleanup resources - errors during cleanup are silently ignored
            // to ensure the error state from the original failure is preserved
            audioPlayback.stop()
            lightController?.stop()
        }
    }
    
    /// Pauses the current session
    func pauseSession() {
        guard state == .running else { return }
        
        audioPlayback.pause()
        lightController?.pauseExecution()
        
        state = .paused
        
        // Haptic feedback for pause (if enabled)
        if cachedPreferences.hapticFeedbackEnabled {
            HapticFeedback.light()
        }
    }
    
    /// Resumes the current session
    func resumeSession() {
        guard state == .paused else { return }
        
        audioPlayback.resume()
        lightController?.resumeExecution()
        
        state = .running
        
        // Haptic feedback for resume (if enabled)
        if cachedPreferences.hapticFeedbackEnabled {
            HapticFeedback.medium()
        }
    }
    
    /// Stops the current session
    func stopSession() {
        // Allow cleanup from any state except .idle to prevent resource leaks
        guard state != .idle else { return }
        
        audioPlayback.stop()
        lightController?.stop()
        
        // Stop microphone and fall detection
        microphoneAnalyzer?.stop()
        fallDetector.stopMonitoring()
        
        // End session and save to history only if it was running or paused
        let shouldSaveSession = state == .running || state == .paused
        if var session = currentSession, shouldSaveSession {
            session.endedAt = Date()
            if session.endReason == nil {
                session.endReason = .userStopped
            }
            services.sessionHistoryService.save(session: session)
        }
        
        state = .idle
        currentTrack = nil
        currentScript = nil
        currentSession = nil
        lightController = nil
        microphoneBeatTimestamps.removeAll()
        microphoneStartTime = nil
        
        // Haptic feedback for session stop (if enabled)
        if cachedPreferences.hapticFeedbackEnabled {
            HapticFeedback.heavy()
        }
    }
    
    /// Starts a microphone-based session
    func startMicrophoneSession() async {
        guard state == .idle else { return }
        
        guard let microphoneAnalyzer = microphoneAnalyzer else {
            errorMessage = NSLocalizedString(
                "error.microphoneUnavailable",
                comment: "Shown when microphone analysis is not available for starting a microphone-based session"
            )
            state = .error
            return
        }
        
        state = .analyzing
        
        // Refresh cached preferences
        cachedPreferences = UserPreferences.load()
        
        // Set the light controller based on current preferences
        switch cachedPreferences.preferredLightSource {
        case .flashlight:
            lightController = services.flashlightController
        case .screen:
            lightController = services.screenController
        }
        
        do {
            // Start microphone analysis
            try await microphoneAnalyzer.start()
            
            // Start fall detection if enabled
            if cachedPreferences.fallDetectionEnabled {
                fallDetector.startMonitoring()
            }
            
            // Create a dummy AudioTrack for microphone mode
            let dummyTrack = AudioTrack(
                title: "Live Audio",
                artist: "Mikrofon",
                duration: 0, // Unknown duration
                bpm: 120.0, // Initial BPM, will be updated
                beatTimestamps: []
            )
            currentTrack = dummyTrack
            
            // Subscribe to beat events
            microphoneAnalyzer.beatEventPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] timestamp in
                    self?.handleMicrophoneBeat(timestamp: timestamp)
                }
                .store(in: &cancellables)
            
            // Subscribe to BPM updates
            microphoneAnalyzer.bpmPublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] bpm in
                    self?.handleMicrophoneBPM(bpm: bpm)
                }
                .store(in: &cancellables)
            
            // Generate initial LightScript
            let mode = cachedPreferences.preferredMode
            let lightSource = cachedPreferences.preferredLightSource
            let screenColor = cachedPreferences.screenColor
            
            let initialScript = generateMicrophoneLightScript(
                mode: mode,
                lightSource: lightSource,
                screenColor: screenColor,
                bpm: microphoneBPM
            )
            currentScript = initialScript
            
            // Create session
            let session = Session(
                mode: mode,
                lightSource: lightSource,
                audioSource: .microphone,
                trackTitle: "Live Audio",
                trackArtist: "Mikrofon",
                trackBPM: microphoneBPM
            )
            currentSession = session
            microphoneStartTime = Date()
            
            // Start light controller
            try lightController?.start()
            
            // Start LightScript execution
            let startTime = Date()
            lightController?.execute(script: initialScript, syncedTo: startTime)
            
            state = .running
            
            // Haptic feedback for session start (if enabled)
            if cachedPreferences.hapticFeedbackEnabled {
                HapticFeedback.medium()
            }
            
        } catch {
            errorMessage = error.localizedDescription
            state = .error
            fallDetector.stopMonitoring()
            microphoneAnalyzer.stop()
            lightController?.stop()
        }
    }
    
    /// Handles beat events from microphone analyzer
    private func handleMicrophoneBeat(timestamp: TimeInterval) {
        microphoneBeatTimestamps.append(timestamp)
        
        // Keep only recent beats (last 20 seconds)
        let cutoffTime = timestamp - 20.0
        microphoneBeatTimestamps = microphoneBeatTimestamps.filter { $0 >= cutoffTime }
        
        // Additionally, cap the history size to prevent unbounded growth
        if microphoneBeatTimestamps.count > maxBeatHistoryCount {
            microphoneBeatTimestamps = Array(microphoneBeatTimestamps.suffix(maxBeatHistoryCount))
        }
        
        // Beats are used for BPM estimation; avoid regenerating the light script
        // and restarting the light controller on every single beat to prevent
        // visual flicker and unnecessary work. Script updates are handled in
        // handleMicrophoneBPM(bpm:) when there is a significant BPM change.
    }
    
    /// Handles BPM updates from microphone analyzer
    private func handleMicrophoneBPM(bpm: Double) {
        microphoneBPM = bpm
        
        // Debounce script updates: only regenerate when BPM changes significantly
        // to avoid frequent cancel/restart cycles and visible flicker.
        // Threshold: 5 BPM difference from the last script BPM.
        // Check if BPM change is significant enough to warrant regeneration
        // A 5 BPM threshold prevents excessive restarts from minor tempo variations.
        // Note: While this approach uses cancelExecution/restart which could cause
        // brief flickering, it ensures the light frequency remains synchronized with
        // the detected tempo. More sophisticated smoothing (e.g., gradual frequency
        // interpolation) would add complexity and may compromise the entrainment
        // effect by temporarily using off-target frequencies. The 5 BPM threshold
        // strikes a balance between responsiveness and stability.
        if let previousBPM = lastScriptBPM, abs(bpm - previousBPM) < 5.0 {
            return
        }
        lastScriptBPM = bpm
        
        // Regenerate LightScript with new BPM
        guard currentScript != nil,
              let startTime = microphoneStartTime else {
            return
        }
        
        let mode = cachedPreferences.preferredMode
        let lightSource = cachedPreferences.preferredLightSource
        let screenColor = cachedPreferences.screenColor
        
        let updatedScript = generateMicrophoneLightScript(
            mode: mode,
            lightSource: lightSource,
            screenColor: screenColor,
            bpm: bpm
        )
        currentScript = updatedScript
        
        // Update light controller
        lightController?.cancelExecution()
        lightController?.execute(script: updatedScript, syncedTo: startTime)
    }
    
    /// Generates a LightScript for microphone mode
    private func generateMicrophoneLightScript(
        mode: EntrainmentMode,
        lightSource: LightSource,
        screenColor: LightEvent.LightColor?,
        bpm: Double
    ) -> LightScript {
        // Estimate a non-zero duration for the dummy track based on live analysis
        let estimatedDuration: TimeInterval
        if let lastBeat = microphoneBeatTimestamps.last {
            let beatDuration = bpm > 0 ? 60.0 / bpm : 0
            // Extend duration one beat beyond the last detected beat
            estimatedDuration = lastBeat + beatDuration
        } else if bpm > 0 {
            // No beats yet: assume a short window of several beats
            let beatDuration = 60.0 / bpm
            estimatedDuration = beatDuration * 8.0
        } else {
            // Fallback duration when no timing information is available
            estimatedDuration = 60.0
        }
        
        // Create a dummy track with current BPM and beat timestamps
        let dummyTrack = AudioTrack(
            title: NSLocalizedString("session.liveAudio", comment: ""),
            artist: NSLocalizedString("session.microphone", comment: ""),
            duration: estimatedDuration,
            bpm: bpm,
            beatTimestamps: microphoneBeatTimestamps
        )
        
        return entrainmentEngine.generateLightScript(
            from: dummyTrack,
            mode: mode,
            lightSource: lightSource,
            screenColor: lightSource == .screen ? screenColor : nil
        )
    }
    
    /// Handles fall detection event
    private func handleFallDetected() {
        // Prevent re-entrancy if we're already handling a fall
        guard !isHandlingFall else { return }
        guard state == .running || state == .paused else { return }
        
        isHandlingFall = true
        
        // Stop the session
        if var session = currentSession {
            session.endedAt = Date()
            session.endReason = .fallDetected
            services.sessionHistoryService.save(session: session)
        }
        
        stopSession()
        
        // Show error message
        errorMessage = NSLocalizedString("session.fallDetected", comment: "")
        state = .error
        
        // Haptic feedback
        if cachedPreferences.hapticFeedbackEnabled {
            HapticFeedback.error()
        }
        
        isHandlingFall = false
    }
    
    /// Resets the session state (called when view is dismissed)
    func reset() {
        errorMessage = nil
        state = .idle
        
        // Cleanup microphone and fall detection
        microphoneAnalyzer?.stop()
        fallDetector.stopMonitoring()
        microphoneBeatTimestamps.removeAll()
        microphoneStartTime = nil
    }
    
    /// Starts audio playback and light synchronization
    private func startPlaybackAndLight(url: URL, script: LightScript) throws {
        guard let lightController = lightController else {
            throw LightControlError.configurationFailed
        }
        
        // Start audio playback
        try audioPlayback.play(url: url)
        
        // Start light controller
        try lightController.start()
        
        // Start LightScript execution synchronized with audio
        let startTime = Date()
        lightController.execute(script: script, syncedTo: startTime)
    }
}

/// Session states
enum SessionState {
    case idle           // No active session
    case analyzing      // Audio is being analyzed
    case running        // Session is running
    case paused        // Session paused
    case error         // Error occurred
}

