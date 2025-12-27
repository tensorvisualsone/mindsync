import Foundation
import SwiftUI
import Combine
import MediaPlayer
import AVFoundation
import os.log
import UIKit

/// ViewModel for session view
@MainActor
final class SessionViewModel: ObservableObject {
    // Services
    private let services = ServiceContainer.shared
    private let logger = Logger(subsystem: "com.mindsync", category: "Session")
    private let audioAnalyzer: AudioAnalyzer
    private let audioPlayback: AudioPlaybackService
    private let entrainmentEngine: EntrainmentEngine
    private let microphoneAnalyzer: MicrophoneAnalyzer?
    private let fallDetector: FallDetector
    private let affirmationService: AffirmationOverlayService
    private let audioEnergyTracker: AudioEnergyTracker
    private let historyService: SessionHistoryServiceProtocol
    
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
    @Published var statusMessage: String?  // Non-error status notifications (e.g., cancellation)
    @Published var currentSession: Session?
    @Published var thermalWarningLevel: ThermalWarningLevel = .none
    @Published var playbackProgress: Double = 0.0
    @Published var playbackTimeLabel: String = "0:00 / 0:00"
    @Published var affirmationStatus: String?
    @Published var currentFrequency: Double? = nil
    
    // Screen controller for UI binding (only published when screen mode is active)
    var screenController: ScreenController? {
        lightController as? ScreenController
    }
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Current light controller based on cached preferences
    // Computed once per session to avoid repeated calculations
    private var lightController: LightControlling?
    
    // Vibration controller (optional, based on user preferences)
    private var vibrationController: VibrationController?
    private var currentVibrationScript: VibrationScript?
    
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
    
    // Microphone signal monitoring configuration keys
    private enum MicrophoneConfigKeys {
        static let silenceThreshold = "microphone_silenceThreshold"
        static let autoPauseDelay = "microphone_autoPauseDelay"
        static let autoStopDelay = "microphone_autoStopDelay"
    }
    
    // Microphone signal monitoring configuration
    // These values can be overridden via UserDefaults to adapt to different environments
    // and microphone sensitivities. Values are cached on initialization for performance.
    //
    // Default values:
    // - silenceThreshold: 0.02 (2% of normalized signal level)
    // - autoPauseDelay: 2.0 seconds of silence before pausing
    // - autoStopDelay: 12.0 seconds of silence before stopping
    private let silenceThreshold: Float
    private let autoPauseDelay: TimeInterval
    private let autoStopDelay: TimeInterval
    
    // Lifecycle pause flags
    private var pausedBySystemInterruption = false
    private var pausedByRouteChange = false
    private var pausedByBackground = false
    private var pausedBySilence = false
    private var microphoneSilenceStart: Date?
    private var playbackProgressTimer: Timer?
    private var activeTask: Task<Void, Never>?
    
    // Tracks total duration the session has been paused to adjust elapsed time calculations
    private var totalPauseDuration: TimeInterval = 0
    private var pauseStartTime: Date?
    
    init(historyService: SessionHistoryServiceProtocol? = nil) {
        self.audioAnalyzer = services.audioAnalyzer
        self.audioPlayback = services.audioPlayback
        self.cachedPreferences = UserPreferences.load()
        self.historyService = historyService ?? ServiceContainer.shared.sessionHistoryService
        
        // Load microphone monitoring configuration from UserDefaults
        // Note: We validate that values are positive (> 0) to ensure sensible behavior.
        // A silenceThreshold of 0 would never detect silence, and delays of 0 would
        // cause immediate pause/stop. If the key doesn't exist or has an invalid value,
        // we fall back to the documented defaults.
        let defaults = UserDefaults.standard
        let thresholdValue = defaults.float(forKey: MicrophoneConfigKeys.silenceThreshold)
        self.silenceThreshold = thresholdValue > 0 ? thresholdValue : 0.02
        
        let pauseDelayValue = defaults.double(forKey: MicrophoneConfigKeys.autoPauseDelay)
        self.autoPauseDelay = pauseDelayValue > 0 ? pauseDelayValue : 2.0
        
        let stopDelayValue = defaults.double(forKey: MicrophoneConfigKeys.autoStopDelay)
        self.autoStopDelay = stopDelayValue > 0 ? stopDelayValue : 12.0
        
        // EntrainmentEngine from ServiceContainer
        self.entrainmentEngine = services.entrainmentEngine
        
        // MicrophoneAnalyzer and FallDetector
        self.microphoneAnalyzer = services.microphoneAnalyzer
        self.fallDetector = services.fallDetector
        
        // Affirmation Service
        self.affirmationService = services.affirmationService
        
        // Audio Energy Tracker (for Cinematic Mode)
        self.audioEnergyTracker = services.audioEnergyTracker
        
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
        
        NotificationCenter.default.publisher(for: .mindSyncTorchFailed)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleTorchFailureEvent()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAudioSessionInterruption(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handleAudioRouteChange(notification)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppDidEnterBackground()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleAppWillEnterForeground()
            }
            .store(in: &cancellables)
        
        // Listen to fall detection events
        fallDetector.fallEventPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.handleFallDetected()
            }
            .store(in: &cancellables)
        
        microphoneAnalyzer?.signalLevelPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] level in
                self?.handleMicrophoneSignalLevel(level)
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
        
        markSessionAsThermallyLimited()
        switchToScreenController(using: currentScript, session: session)
    }
    
    private func handleTorchFailureEvent() {
        guard state == .running,
              let currentScript = currentScript,
              let session = currentSession,
              lightController?.source == .flashlight else {
            return
        }
        
        thermalWarningLevel = .critical
        markSessionAsThermallyLimited()
        switchToScreenController(using: currentScript, session: session)
    }
    
    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            guard state == .running else { return }
            pausedBySystemInterruption = true
            pauseSession()
        case .ended:
            guard pausedBySystemInterruption else { return }
            pausedBySystemInterruption = false
            if state == .paused {
                if let optionValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionValue)
                    if options.contains(.shouldResume) {
                        resumeSession()
                    }
                }
            }
        @unknown default:
            break
        }
    }
    
    private func handleAudioRouteChange(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        switch reason {
        case .oldDeviceUnavailable:
            guard state == .running else { return }
            pausedByRouteChange = true
            pauseSession()
        case .newDeviceAvailable:
            guard pausedByRouteChange else { return }
            pausedByRouteChange = false
            if state == .paused {
                resumeSession()
            }
        default:
            break
        }
    }
    
    private func handleAppDidEnterBackground() {
        guard state == .running else { return }
        pausedByBackground = true
        pauseSession()
    }
    
    private func handleAppWillEnterForeground() {
        guard pausedByBackground else { return }
        pausedByBackground = false
        if state == .paused {
            resumeSession()
        }
    }
    
    private func handleMicrophoneSignalLevel(_ level: Float) {
        guard currentSession?.audioSource == .microphone,
              state == .running else {
            microphoneSilenceStart = nil
            pausedBySilence = false
            return
        }
        
        if level < silenceThreshold {
            if microphoneSilenceStart == nil {
                microphoneSilenceStart = Date()
            }
            
            guard let silenceStart = microphoneSilenceStart else { return }
            let elapsed = Date().timeIntervalSince(silenceStart)
            
            if elapsed >= autoPauseDelay, !pausedBySilence {
                pausedBySilence = true
                lightController?.pauseExecution()
            }
            
            if elapsed >= autoStopDelay {
                microphoneSilenceStart = nil
                pausedBySilence = false
                errorMessage = NSLocalizedString("session.microphone.noSignal", comment: "")
                stopSession()
            }
        } else {
            microphoneSilenceStart = nil
            if pausedBySilence {
                pausedBySilence = false
                lightController?.resumeExecution()
            }
        }
    }
    
    private func switchToScreenController(using script: LightScript, session: Session) {
        // Prevent race conditions by checking if a task is already running
        // Bail out if there's an active task that hasn't been cancelled
        if let task = activeTask, !task.isCancelled {
            logger.warning("switchToScreenController called while previous task is still running")
            return
        }
        
        lightController?.stop()
        lightController = services.screenController
        
        // Cancel any existing task
        activeTask?.cancel()
        activeTask = Task {
            do {
                try await lightController?.start()
                
                // Resume from current session position using original session start time
                lightController?.execute(script: script, syncedTo: session.startedAt)
                
            } catch {
                // If screen controller also fails, inform the user and stop the session
                errorMessage = NSLocalizedString("session.screenController.error", 
                                                comment: "Shown when switching to the screen-based light controller fails")
                stopSession()
            }
        }
    }
    
    private func markSessionAsThermallyLimited() {
        if var session = currentSession {
            session.thermalWarningOccurred = true
            if session.endReason == nil {
                session.endReason = .thermalShutdown
            }
            currentSession = session
        }
    }
    
    private func updateAffirmationStatusForCurrentPreferences() {
        guard cachedPreferences.selectedAffirmationURL != nil,
              cachedPreferences.preferredMode == .theta else {
            affirmationStatus = nil
            return
        }
        
        if affirmationPlayed {
            affirmationStatus = NSLocalizedString("session.affirmation.playing", comment: "")
        } else {
            affirmationStatus = NSLocalizedString("session.affirmation.waiting", comment: "")
        }
    }
    
    private func startPlaybackProgressUpdates(for duration: TimeInterval) {
        stopPlaybackProgressUpdates(reset: false)
        guard duration > 0 else {
            playbackProgress = 0
            playbackTimeLabel = "0:00 / 0:00"
            return
        }
        
        updatePlaybackProgress(duration: duration)
        // Note: updateCurrentFrequency() is called in the timer below, not here,
        // because sessionStartTime may not be set yet when this method is called
        
        // Create timer and add to main RunLoop to ensure it fires even during UI interactions
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updatePlaybackProgress(duration: duration)
                self.updateCurrentFrequency()  // Will update once sessionStartTime is set
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        playbackProgressTimer = timer
    }
    
    private func stopPlaybackProgressUpdates(reset: Bool = true) {
        playbackProgressTimer?.invalidate()
        playbackProgressTimer = nil
        if reset {
            playbackProgress = 0
            playbackTimeLabel = "0:00 / 0:00"
        }
    }
    
    /// Starts frequency updates for microphone mode
    private func startFrequencyUpdates() {
        // Stop any existing timer first
        playbackProgressTimer?.invalidate()
        
        // Initial update
        updateCurrentFrequency()
        
        // Create timer and add to main RunLoop to ensure it fires even during UI interactions
        let timer = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.updateCurrentFrequency()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        playbackProgressTimer = timer
    }

    private func updatePlaybackProgress(duration: TimeInterval) {
        let current = audioPlayback.currentTime
        let clampedDuration = max(duration, 0.1)
        playbackProgress = min(1.0, max(0.0, current / clampedDuration))
        playbackTimeLabel = "\(formatTime(current)) / \(formatTime(duration))"
    }
    
    /// Calculates and updates the current frequency based on ramping
    private func updateCurrentFrequency() {
        guard let script = currentScript,
              let session = currentSession,
              let startTime = sessionStartTime else {
            currentFrequency = nil
            return
        }
        
        let elapsed = Date().timeIntervalSince(startTime) - totalPauseDuration
        let mode = session.mode
        
        // Calculate ramping progress
        let rampTime = mode.rampDuration
        let progress = rampTime > 0 ? min(elapsed / rampTime, 1.0) : 1.0
        
        // Smoothstep interpolation
        let smooth = MathHelpers.smoothstep(progress)
        
        // Interpolate from startFrequency to targetFrequency
        let startFreq = mode.startFrequency
        let targetFreq = script.targetFrequency
        currentFrequency = startFreq + (targetFreq - startFreq) * smooth
    }
    
    private func formatTime(_ value: TimeInterval) -> String {
        let totalSeconds = Int(max(0, value))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    deinit {
        // Skip resetting published properties during deallocation to avoid issues with
        // potentially active observers. The properties will be cleaned up with the view model.
        // Only invalidate the timer (non-MainActor operation) to avoid Swift 6 concurrency errors.
        playbackProgressTimer?.invalidate()
        playbackProgressTimer = nil
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
    
    /// Cancels the current analysis
    func cancelAnalysis() {
        guard state == .analyzing else { return }
        logger.info("User cancelled analysis")
        audioAnalyzer.cancel()
        state = .idle
        analysisProgress = nil
        statusMessage = NSLocalizedString("status.audio.cancelled", comment: "")
    }
    
    /// Starts a session with a selected media item
    func startSession(with mediaItem: MPMediaItem) async {
        guard state == .idle else { 
            logger.warning("Attempted to start session while state is \(String(describing: self.state))")
            return 
        }
        
        logger.info("Starting session with local media item")
        state = .analyzing
        stopPlaybackProgressUpdates()
        
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
            let assetURL = try await services.mediaLibraryService.assetURLForAnalysis(of: mediaItem)
            
            // Analyze audio (use quick mode if enabled in preferences)
            let track = try await audioAnalyzer.analyze(url: assetURL, mediaItem: mediaItem, quickMode: cachedPreferences.quickAnalysisEnabled)
            currentTrack = track
            startPlaybackProgressUpdates(for: track.duration)
            
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
            
            // Generate VibrationScript if vibration is enabled
            if cachedPreferences.vibrationEnabled {
                do {
                    let vibrationScript = try entrainmentEngine.generateVibrationScript(
                        from: track,
                        mode: mode,
                        intensity: cachedPreferences.vibrationIntensity
                    )
                    currentVibrationScript = vibrationScript
                    vibrationController = services.vibrationController
                } catch {
                    logger.error("Failed to generate vibration script: \(error.localizedDescription, privacy: .public)")
                    // Degrade gracefully: continue without vibration instead of blocking session start
                    vibrationController = nil
                    currentVibrationScript = nil
                    statusMessage = NSLocalizedString("status.vibration.unavailable", comment: "")
                    // Clear any previous critical error state to avoid stale UI: we're showing a non-critical
                    // status message and continuing the session, so old error messages should not be displayed
                    errorMessage = nil
                }
            } else {
                vibrationController = nil
                currentVibrationScript = nil
            }
            
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
            updateAffirmationStatusForCurrentPreferences()
            
            // Set custom color RGB if screen mode and custom color is selected
            if lightSource == .screen, screenColor == .custom,
               let screenController = lightController as? ScreenController {
                screenController.setCustomColorRGB(cachedPreferences.customColorRGB)
            }
            
            // Apply audio latency offset from user preferences for Bluetooth compensation
            lightController?.audioLatencyOffset = cachedPreferences.audioLatencyOffset
            
            // Start playback and light (this sets the startTime)
            let startTime = Date()
            sessionStartTime = startTime
            // Update frequency now that sessionStartTime is set (timer will continue updating)
            updateCurrentFrequency()
            try await startPlaybackAndLight(url: assetURL, script: script, startTime: startTime)
            
            // Start vibration if enabled (using same startTime for synchronization)
            if cachedPreferences.vibrationEnabled, let vibrationController = vibrationController, let vibrationScript = currentVibrationScript {
                try await vibrationController.start()
                // Apply audio latency offset for Bluetooth compensation
                vibrationController.audioLatencyOffset = cachedPreferences.audioLatencyOffset
                vibrationController.execute(script: vibrationScript, syncedTo: startTime)
            }
            
            // If cinematic mode, start audio energy tracking and attach to light controller
            if mode == .cinematic {
                if let mixerNode = audioPlayback.getMainMixerNode() {
                    audioEnergyTracker.startTracking(mixerNode: mixerNode)
                }
                // Attach audio energy tracker to light controller for dynamic intensity modulation
                lightController?.audioEnergyTracker = audioEnergyTracker
            }
            
            state = .running
            affirmationPlayed = false
            
            // Start observing for affirmation trigger
            startAffirmationObserver()
            
            // Haptic feedback for session start (if enabled)
            if cachedPreferences.hapticFeedbackEnabled {
                HapticFeedback.medium()
            }
            
        } catch {
            // Set error state first to ensure it's always set, even if cleanup fails
            logger.error("Session start failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            state = .error
            
            // Cleanup resources - errors during cleanup are silently ignored
            // to ensure the error state from the original failure is preserved
            audioPlayback.stop()
            lightController?.stop()
            vibrationController?.stop()
            stopPlaybackProgressUpdates()
        }
    }
    
    /// Starts a session with a local audio file URL (from Document Picker)
    func startSession(with audioFileURL: URL) async {
        guard state == .idle else { 
            logger.warning("Attempted to start session while state is \(String(describing: self.state))")
            return 
        }
        
        logger.info("Starting session with audio file: \(audioFileURL.lastPathComponent)")
        state = .analyzing
        stopPlaybackProgressUpdates()
        
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
            // Analyze audio directly from URL (no MediaItem required, use quick mode if enabled)
            let track = try await audioAnalyzer.analyze(url: audioFileURL, quickMode: cachedPreferences.quickAnalysisEnabled)
            currentTrack = track
            startPlaybackProgressUpdates(for: track.duration)
            
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
            
            // Generate VibrationScript if vibration is enabled
            if cachedPreferences.vibrationEnabled {
                do {
                    let vibrationScript = try entrainmentEngine.generateVibrationScript(
                        from: track,
                        mode: mode,
                        intensity: cachedPreferences.vibrationIntensity
                    )
                    currentVibrationScript = vibrationScript
                    vibrationController = services.vibrationController
                } catch {
                    logger.error("Failed to generate vibration script: \(error.localizedDescription, privacy: .public)")
                    // Degrade gracefully: continue without vibration instead of blocking session start
                    vibrationController = nil
                    currentVibrationScript = nil
                    statusMessage = NSLocalizedString("status.vibration.unavailable", comment: "")
                    // Clear any previous critical error state to avoid stale UI
                    errorMessage = nil
                }
            } else {
                vibrationController = nil
                currentVibrationScript = nil
            }
            
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
            updateAffirmationStatusForCurrentPreferences()
            
            // Set custom color RGB if screen mode and custom color is selected
            if lightSource == .screen, screenColor == .custom,
               let screenController = lightController as? ScreenController {
                screenController.setCustomColorRGB(cachedPreferences.customColorRGB)
            }
            
            // Apply audio latency offset from user preferences for Bluetooth compensation
            lightController?.audioLatencyOffset = cachedPreferences.audioLatencyOffset
            
            // Start playback and light (this sets the startTime)
            let startTime = Date()
            sessionStartTime = startTime
            // Update frequency now that sessionStartTime is set (timer will continue updating)
            updateCurrentFrequency()
            try await startPlaybackAndLight(url: audioFileURL, script: script, startTime: startTime)
            
            // Start vibration if enabled (using same startTime for synchronization)
            if cachedPreferences.vibrationEnabled, let vibrationController = vibrationController, let vibrationScript = currentVibrationScript {
                try await vibrationController.start()
                // Apply audio latency offset for Bluetooth compensation
                vibrationController.audioLatencyOffset = cachedPreferences.audioLatencyOffset
                vibrationController.execute(script: vibrationScript, syncedTo: startTime)
            }
            
            // If cinematic mode, start audio energy tracking and attach to light controller
            if mode == .cinematic {
                if let mixerNode = audioPlayback.getMainMixerNode() {
                    audioEnergyTracker.startTracking(mixerNode: mixerNode)
                }
                lightController?.audioEnergyTracker = audioEnergyTracker
            }
            
            state = .running
            affirmationPlayed = false
            
            // Start observing for affirmation trigger
            startAffirmationObserver()
            
            // Haptic feedback for session start (if enabled)
            if cachedPreferences.hapticFeedbackEnabled {
                HapticFeedback.medium()
            }
            
        } catch {
            logger.error("Session start (file) failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            state = .error
            
            audioPlayback.stop()
            lightController?.stop()
            vibrationController?.stop()
            stopPlaybackProgressUpdates()
        }
    }
    
    /// Pauses the current session
    func pauseSession() {
        guard state == .running else { return }
        
        logger.info("Pausing session")
        audioPlayback.pause()
        lightController?.pauseExecution()
        vibrationController?.pauseExecution()
        
        // Note: Audio energy tracking continues during pause (tracker remains attached)
        // This ensures smooth transition when resuming
        
        state = .paused
        pauseStartTime = Date()
        
        // Haptic feedback for pause (if enabled)
        if cachedPreferences.hapticFeedbackEnabled {
            HapticFeedback.light()
        }
    }
    
    /// Resumes the current session
    func resumeSession() {
        guard state == .paused else { return }
        
        logger.info("Resuming session")
        audioPlayback.resume()
        lightController?.resumeExecution()
        vibrationController?.resumeExecution()
        
        // User manually resumed, so clear all auto-pause flags
        pausedBySystemInterruption = false
        pausedByRouteChange = false
        pausedByBackground = false
        pausedBySilence = false
        
        state = .running
        
        if let pauseStart = pauseStartTime {
            totalPauseDuration += Date().timeIntervalSince(pauseStart)
            pauseStartTime = nil
        }
        
        // Haptic feedback for resume (if enabled)
        if cachedPreferences.hapticFeedbackEnabled {
            HapticFeedback.medium()
        }
    }
    
    /// Stops the current session
    func stopSession() {
        // Allow cleanup from any state except .idle to prevent resource leaks
        guard state != .idle else { return }
        
        logger.info("Stopping session")
        audioPlayback.stop()
        lightController?.stop()
        vibrationController?.stop()

        // Stop isochronic audio if active
        IsochronicAudioService.shared.stop()
        
        // Stop audio energy tracking if active (cinematic mode)
        audioEnergyTracker.stopTracking()
        lightController?.audioEnergyTracker = nil
        
        // Stop microphone and fall detection
        microphoneAnalyzer?.stop()
        fallDetector.stopMonitoring()
        
        // Invalidate affirmation timer
        affirmationTimer?.invalidate()
        affirmationTimer = nil
        
        // Cancel any active task (e.g. screen switch)
        activeTask?.cancel()
        activeTask = nil
        
        // End session and save to history only if it was running or paused
        let shouldSaveSession = state == .running || state == .paused
        if var session = currentSession, shouldSaveSession {
            session.endedAt = Date()
            if session.endReason == nil {
                session.endReason = .userStopped
            }
            historyService.save(session: session)
        }
        
        state = .idle
        currentTrack = nil
        currentScript = nil
        currentVibrationScript = nil
        currentSession = nil
        lightController = nil
        vibrationController = nil
        microphoneBeatTimestamps.removeAll()
        microphoneStartTime = nil
        sessionStartTime = nil
        affirmationPlayed = false
        pausedBySystemInterruption = false
        pausedByRouteChange = false
        pausedByBackground = false
        pausedBySilence = false
        microphoneSilenceStart = nil
        totalPauseDuration = 0
        pauseStartTime = nil
        
        // Stop affirmation if playing
        affirmationService.stop()
        stopPlaybackProgressUpdates()  // Stops both playback progress and frequency updates (both use playbackProgressTimer)
        affirmationStatus = nil
        
        // Haptic feedback for session stop (if enabled)
        if cachedPreferences.hapticFeedbackEnabled {
            HapticFeedback.heavy()
        }
    }
    
    /// Starts a microphone-based session
    func startMicrophoneSession() async {
        guard state == .idle else { 
            logger.warning("Attempted to start microphone session while state is \(String(describing: self.state))")
            return 
        }
        
        logger.info("Starting microphone session")
        
        guard let microphoneAnalyzer = microphoneAnalyzer else {
            logger.error("Microphone analyzer not available")
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
            
            // Generate initial VibrationScript if vibration is enabled
            if cachedPreferences.vibrationEnabled {
                do {
                    let initialVibrationScript = try generateMicrophoneVibrationScript(
                        mode: mode,
                        bpm: microphoneBPM,
                        intensity: cachedPreferences.vibrationIntensity
                    )
                    currentVibrationScript = initialVibrationScript
                    vibrationController = services.vibrationController
                } catch {
                    logger.error("Failed to generate initial vibration script: \(error.localizedDescription, privacy: .public)")
                    // Degrade gracefully: continue without vibration
                    vibrationController = nil
                    currentVibrationScript = nil
                    statusMessage = NSLocalizedString("status.vibration.unavailable", comment: "")
                    errorMessage = nil
                }
            } else {
                vibrationController = nil
                currentVibrationScript = nil
            }
            
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
            updateAffirmationStatusForCurrentPreferences()
            
            // Set custom color RGB if screen mode and custom color is selected
            if lightSource == .screen, mode != .cinematic, screenColor == .custom,
               let screenController = lightController as? ScreenController {
                screenController.setCustomColorRGB(cachedPreferences.customColorRGB)
            }
            
            // Apply audio latency offset from user preferences for Bluetooth compensation
            lightController?.audioLatencyOffset = cachedPreferences.audioLatencyOffset

            // Start light controller
            try await lightController?.start()
            
            // Start LightScript execution
            let startTime = Date()

            // Start optional isochronic audio for microphone sessions (no music playback)
            IsochronicAudioService.shared.carrierFrequency = 150.0
            IsochronicAudioService.shared.start(mode: mode)

            lightController?.execute(script: initialScript, syncedTo: startTime)
            
            // Start vibration if enabled
            if cachedPreferences.vibrationEnabled, let vibrationController = vibrationController, let vibrationScript = currentVibrationScript {
                try await vibrationController.start()
                // Apply audio latency offset for Bluetooth compensation
                vibrationController.audioLatencyOffset = cachedPreferences.audioLatencyOffset
                vibrationController.execute(script: vibrationScript, syncedTo: startTime)
            }
            
            // Note: Cinematic mode is not supported for microphone sessions
            // as it requires audio file playback with mixer node access
            
            sessionStartTime = startTime
            affirmationPlayed = false
            state = .running
            
            // Start frequency updates for UI display
            startFrequencyUpdates()
            
            // Start observing for affirmation trigger
            startAffirmationObserver()
            
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
            vibrationController?.stop()
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
        
        // Update vibration script if enabled
        if cachedPreferences.vibrationEnabled {
            do {
                let updatedVibrationScript = try generateMicrophoneVibrationScript(
                    mode: mode,
                    bpm: bpm,
                    intensity: cachedPreferences.vibrationIntensity
                )
                currentVibrationScript = updatedVibrationScript
                vibrationController?.cancelExecution()
                vibrationController?.execute(script: updatedVibrationScript, syncedTo: startTime)
            } catch {
                logger.error("Failed to update vibration script: \(error.localizedDescription, privacy: .public)")
                // Stop any active vibration and clear state to prevent stale script execution
                vibrationController?.cancelExecution()
                currentVibrationScript = nil
                // Don't stop the session, just log the error and continue without vibration
            }
        }
    }
    
    /// Creates a dummy AudioTrack for microphone mode with estimated duration
    private func createMicrophoneDummyTrack(bpm: Double) -> AudioTrack {
        // Estimate a non-zero duration for the dummy track based on live analysis
        let estimatedDuration: TimeInterval
        if let lastBeat = microphoneBeatTimestamps.last {
            let beatDuration = bpm > 0 ? 60.0 / bpm : 0
            // Extend duration one beat beyond the last detected beat
            estimatedDuration = lastBeat + beatDuration
        } else if bpm > 0 {
            // No beats yet: use a relatively short duration (60 seconds) to ensure events are generated
            // without creating excessive overhead (which 1 hour would cause).
            // This will be regenerated as needed when BPM changes or beats are detected.
            estimatedDuration = 60.0
        } else {
            // Fallback duration when no timing information is available
            estimatedDuration = 60.0
        }
        
        // Create a dummy track with current BPM and beat timestamps
        return AudioTrack(
            title: NSLocalizedString("session.liveAudio", comment: "Title for live audio track in microphone mode"),
            artist: NSLocalizedString("session.microphone", comment: "Artist name for live audio track in microphone mode"),
            duration: estimatedDuration,
            bpm: bpm,
            beatTimestamps: microphoneBeatTimestamps
        )
    }
    
    /// Generates a LightScript for microphone mode
    private func generateMicrophoneLightScript(
        mode: EntrainmentMode,
        lightSource: LightSource,
        screenColor: LightEvent.LightColor?,
        bpm: Double
    ) -> LightScript {
        let dummyTrack = createMicrophoneDummyTrack(bpm: bpm)
        
        return entrainmentEngine.generateLightScript(
            from: dummyTrack,
            mode: mode,
            lightSource: lightSource,
            screenColor: lightSource == .screen ? screenColor : nil
        )
    }
    
    /// Generates a VibrationScript for microphone mode
    /// - Throws: VibrationScriptError if validation fails
    private func generateMicrophoneVibrationScript(
        mode: EntrainmentMode,
        bpm: Double,
        intensity: Float
    ) throws -> VibrationScript {
        let dummyTrack = createMicrophoneDummyTrack(bpm: bpm)
        
        return try entrainmentEngine.generateVibrationScript(
            from: dummyTrack,
            mode: mode,
            intensity: intensity
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
            historyService.save(session: session)
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
        statusMessage = nil
        state = .idle
        
        // Cleanup microphone and fall detection
        microphoneAnalyzer?.stop()
        fallDetector.stopMonitoring()
        microphoneBeatTimestamps.removeAll()
        microphoneStartTime = nil
        pausedBySystemInterruption = false
        pausedByRouteChange = false
        pausedByBackground = false
        pausedBySilence = false
        microphoneSilenceStart = nil
        affirmationStatus = nil
        totalPauseDuration = 0
        pauseStartTime = nil
        
        // Invalidate affirmation timer
        affirmationTimer?.invalidate()
        affirmationTimer = nil
    }
    
    /// Starts audio playback and light synchronization
    private func startPlaybackAndLight(url: URL, script: LightScript, startTime: Date) async throws {
        guard let lightController = lightController else {
            throw LightControlError.configurationFailed
        }
        
        // Start audio playback
        try audioPlayback.play(url: url)
        
        // If cinematic mode, attach isochronic audio to the playback engine for perfect sync
        if currentSession?.mode == .cinematic, let engine = audioPlayback.getAudioEngine() {
            IsochronicAudioService.shared.carrierFrequency = 150.0
            IsochronicAudioService.shared.start(mode: currentSession!.mode, attachToEngine: engine)
        }

        // Start light controller
        try await lightController.start()
        
        // Start LightScript execution synchronized with audio
        lightController.execute(script: script, syncedTo: startTime)
    }
    
    /// Startet den Observer für Affirmationen während Theta-Phase
    private func startAffirmationObserver() {
        // Invalidate existing timer if any
        affirmationTimer?.invalidate()
        
        // Timer, der alle 10 Sekunden prüft, ob Affirmation abgespielt werden soll
        let timer = Timer(timeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self else {
                    return
                }
                
                // Stoppe Timer wenn Session beendet
                guard self.state == .running else {
                    self.affirmationTimer?.invalidate()
                    self.affirmationTimer = nil
                    return
                }
                
                // Prüfe ob Affirmation abgespielt werden soll
                self.checkAndPlayAffirmation()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        affirmationTimer = timer
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
        guard let affirmationURL = cachedPreferences.selectedAffirmationURL else { return }
        
        // Affirmation abspielen (mit MixerNode für Ducking)
        let mixerNode = audioPlayback.getMainMixerNode()
        affirmationService.playAffirmation(url: affirmationURL, musicMixerNode: mixerNode)
        affirmationPlayed = true
        affirmationStatus = NSLocalizedString("session.affirmation.playing", comment: "")
        
        print("--- MindSync: Theta-Infiltration gestartet ---")
    }
}

/// Session states
enum SessionState: Equatable {
    case idle           // No active session
    case analyzing      // Audio is being analyzed
    case running        // Session is running
    case paused        // Session paused
    case error         // Error occurred
}

