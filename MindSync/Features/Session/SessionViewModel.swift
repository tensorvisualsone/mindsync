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
    private let affirmationService: AffirmationOverlayService
    
    // Affirmation state
    private var affirmationPlayed = false
    private var sessionStartTime: Date?
    private var affirmationTimer: Timer?
    
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
    
    init() {
        self.audioAnalyzer = services.audioAnalyzer
        self.audioPlayback = services.audioPlayback
        self.cachedPreferences = UserPreferences.load()
        
        // EntrainmentEngine from ServiceContainer
        self.entrainmentEngine = services.entrainmentEngine
        
        // MicrophoneAnalyzer and FallDetector
        self.microphoneAnalyzer = services.microphoneAnalyzer
        self.fallDetector = services.fallDetector
        
        // Affirmation Service
        self.affirmationService = services.affirmationService
        
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
            sessionStartTime = Date()
            affirmationPlayed = false
            
            // Start observing for affirmation trigger
            startAffirmationObserver()
            
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
        
        // Invalidate affirmation timer
        affirmationTimer?.invalidate()
        affirmationTimer = nil
        
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
        sessionStartTime = nil
        affirmationPlayed = false
        
        // Stop affirmation if playing
        affirmationService.stop()
        
        // Haptic feedback for session stop (if enabled)
        if cachedPreferences.hapticFeedbackEnabled {
            HapticFeedback.heavy()
        }
    }
    
    /// Starts a microphone-based session
    func startMicrophoneSession() async {
        guard state == .idle else { return }
        
        guard let microphoneAnalyzer = microphoneAnalyzer else {
            errorMessage = "Mikrofon-Analyse ist nicht verfügbar"
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
            sessionStartTime = Date()
            affirmationPlayed = false
            
            // Start observing for affirmation trigger
            startAffirmationObserver()
            
            // Haptic feedback for session start (if enabled)
            if cachedPreferences.hapticFeedbackEnabled {
                HapticFeedback.medium()
            }
            
        } catch {
            errorMessage = error.localizedDescription
            state = .error
            microphoneAnalyzer.stop()
            fallDetector.stopMonitoring()
            lightController?.stop()
        }
    }
    
    /// Handles beat events from microphone analyzer
    private func handleMicrophoneBeat(timestamp: TimeInterval) {
        microphoneBeatTimestamps.append(timestamp)
        
        // Keep only recent beats (last 20 seconds)
        let cutoffTime = timestamp - 20.0
        microphoneBeatTimestamps = microphoneBeatTimestamps.filter { $0 >= cutoffTime }
        
        // Generate new light event for this beat
        guard currentScript != nil,
              let startTime = microphoneStartTime else {
            return
        }
        
        // Create a new light event for this beat
        let mode = cachedPreferences.preferredMode
        let lightSource = cachedPreferences.preferredLightSource
        let screenColor = cachedPreferences.screenColor
        
        // Generate updated script with new beat
        let updatedScript = generateMicrophoneLightScript(
            mode: mode,
            lightSource: lightSource,
            screenColor: screenColor,
            bpm: microphoneBPM
        )
        currentScript = updatedScript
        
        // Update light controller with new script
        lightController?.cancelExecution()
        lightController?.execute(script: updatedScript, syncedTo: startTime)
    }
    
    /// Handles BPM updates from microphone analyzer
    private func handleMicrophoneBPM(bpm: Double) {
        microphoneBPM = bpm
        
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
        // Create a dummy track with current BPM and beat timestamps
        let dummyTrack = AudioTrack(
            title: "Live Audio",
            artist: "Mikrofon",
            duration: 0,
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
        guard state == .running || state == .paused else { return }
        
        // Stop the session
        if var session = currentSession {
            session.endedAt = Date()
            session.endReason = .fallDetected
            services.sessionHistoryService.save(session: session)
        }
        
        stopSession()
        
        // Show error message
        errorMessage = "Sturz erkannt. Session wurde aus Sicherheitsgründen beendet."
        state = .error
        
        // Haptic feedback
        if cachedPreferences.hapticFeedbackEnabled {
            HapticFeedback.error()
        }
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
        
        // Invalidate affirmation timer
        affirmationTimer?.invalidate()
        affirmationTimer = nil
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
    
    /// Startet den Observer für Affirmationen während Theta-Phase
    private func startAffirmationObserver() {
        // Invalidate existing timer if any
        affirmationTimer?.invalidate()
        
        // Timer, der alle 10 Sekunden prüft, ob Affirmation abgespielt werden soll
        affirmationTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            // Stoppe Timer wenn Session beendet
            guard self.state == .running else {
                timer.invalidate()
                return
            }
            
            // Prüfe ob Affirmation abgespielt werden soll
            self.checkAndPlayAffirmation()
        }
    }
    
    /// Prüft ob Affirmation abgespielt werden soll und spielt sie ab
    private func checkAndPlayAffirmation() {
        // Nur einmal pro Session
        guard !affirmationPlayed else { return }
        
        // Nur im Theta-Modus
        guard cachedPreferences.preferredMode == .theta else { return }
        
        // Nur wenn Session mindestens 5 Minuten läuft (Stabilität)
        guard let startTime = sessionStartTime else { return }
        let sessionDuration = Date().timeIntervalSince(startTime)
        guard sessionDuration >= 300 else { return } // 5 Minuten
        
        // Nur wenn Affirmation-URL vorhanden
        guard let affirmationURL = cachedPreferences.selectedAffirmationURL,
              let audioPlayer = audioPlayback.audioPlayer else { return }
        
        // Affirmation abspielen
        affirmationService.playAffirmation(url: affirmationURL, musicPlayer: audioPlayer)
        affirmationPlayed = true
        
        print("--- MindSync: Theta-Infiltration gestartet ---")
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

