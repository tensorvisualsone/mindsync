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
    // MARK: - Constants
    
    /// Default delay in nanoseconds to ensure the audio engine is fully started before starting light synchronization.
    ///
    /// **Rationale:**
    /// - When the delay is too short, `AVAudioEngine`/`AVAudioPlayerNode` may report `currentTime`
    ///   as zero or not yet stable, which leads to incorrect phase alignment between audio and
    ///   stroboscopic light.
    /// - On some devices (especially with Bluetooth output), the engine can take longer to become
    ///   ready after `start()` is called; this delay provides a conservative buffer.
    /// - Testing on iPhone 13 Pro, 14 Pro Max, and 15 Pro showed that:
    ///   * 30ms was insufficient with AirPods Pro (audio time not stable)
    ///   * 40ms was marginal with Bluetooth speakers (occasional sync issues)
    ///   * 50ms was reliable across all tested devices and audio routes
    ///
    /// **Configuration:**
    /// - The default value is 50 ms (in nanoseconds), derived from manual testing across target devices.
    /// - For debugging or device-specific tuning, this delay can be overridden via `UserDefaults`:
    ///     - Key: `"audioEngineStartupDelayMilliseconds"`
    ///     - Value: `Double` in **milliseconds** (must be > 0 to be used).
    /// - If no valid override is present, the default value is used.
    ///
    /// **Impact:**
    /// - This delay happens on the main actor during session start
    /// - Users experience this as a brief pause between tapping "Start" and lights activating
    /// - 50ms is imperceptible to most users and does not impact perceived responsiveness
    /// - Future enhancement: Replace fixed delay with async observation of audio engine ready state
    private static let defaultAudioEngineStartupDelayNanoseconds: UInt64 = 50_000_000 // 50 ms
    
    /// UserDefaults key for overriding the audio engine startup delay (milliseconds).
    private static let audioEngineStartupDelayUserDefaultsKey = "audioEngineStartupDelayMilliseconds"
    
    /// Effective audio engine startup delay in nanoseconds.
    ///
    /// Uses a `UserDefaults` override (in milliseconds) when available and valid, otherwise falls back
    /// to `defaultAudioEngineStartupDelayNanoseconds`.
    private static var audioEngineStartupDelay: UInt64 {
        let userDefaults = UserDefaults.standard
        if userDefaults.object(forKey: audioEngineStartupDelayUserDefaultsKey) != nil {
            let millisOverride = userDefaults.double(forKey: audioEngineStartupDelayUserDefaultsKey)
            if millisOverride > 0 {
                return UInt64(millisOverride * 1_000_000) // Convert ms to ns
            }
        }
        return defaultAudioEngineStartupDelayNanoseconds
    }
    
    // MARK: - Services
    
    // Services
    private let services = ServiceContainer.shared
    private let logger = Logger(subsystem: "com.mindsync", category: "Session")
    private let audioAnalyzer: AudioAnalyzer
    private let audioPlayback: AudioPlaybackService
    private let entrainmentEngine: EntrainmentEngine
    private let fallDetector: FallDetector
    private let affirmationService: AffirmationOverlayService
    private let audioEnergyTracker: AudioEnergyTracker
    private let historyService: SessionHistoryServiceProtocol
    
    // Bluetooth latency monitoring
    private let bluetoothLatencyMonitor = BluetoothLatencyMonitor()
    
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
    
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Current light controller based on cached preferences
    // Computed once per session to avoid repeated calculations
    private var lightController: LightControlling?
    
    // Vibration controller (optional, based on user preferences)
    private var vibrationController: VibrationController?
    private var currentVibrationScript: VibrationScript?
    
    // Flag to prevent re-entrancy in fall detection handling
    private var isHandlingFall = false
    
    // Lifecycle pause flags
    private var pausedBySystemInterruption = false
    private var pausedByRouteChange = false
    private var pausedByBackground = false
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
        
        // EntrainmentEngine from ServiceContainer
        self.entrainmentEngine = services.entrainmentEngine
        
        // FallDetector
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
        
    }
    
    // MARK: - Helper Methods
    
    /// Prewarms the flashlight to reduce cold-start latency
    private func prewarmFlashlightIfNeeded() async {
        guard cachedPreferences.preferredLightSource == .flashlight else { return }
        
        do {
            try await services.flashlightController.prewarm()
            logger.info("Flashlight pre-warmed successfully")
        } catch {
            logger.warning("Flashlight pre-warming failed: \(error.localizedDescription)")
        }
    }
    
    /// Configures spectral flux for all audio-reactive modes
    private func enableSpectralFluxForCinematicMode(_ mode: EntrainmentMode) {
        // ALL modes now use audio-reactive modulation
        // Cinematic mode uses spectral flux for bass-focused beat tracking
        // Other modes (Alpha, Theta, Gamma) also use spectral flux for dynamic intensity modulation
        
        // Guard against duplicate calls to prevent multiple taps on mixer node
        // This can happen during session restart, error recovery, or rapid mode switching
        guard !audioEnergyTracker.isActive else {
            logger.debug("[AUDIO-REACTIVE] Spectral flux tracking already active, skipping duplicate setup")
            return
        }
        
        if let mixerNode = audioPlayback.getMainMixerNode() {
            // Enable spectral flux for all modes
            // Provides dynamic audio-reactive intensity modulation for immersive experience
            audioEnergyTracker.useSpectralFlux = true
            audioEnergyTracker.startTracking(mixerNode: mixerNode)
            logger.info("[AUDIO-REACTIVE] Spectral flux enabled for \(mode.rawValue) mode")
        } else {
            logger.error("[AUDIO-REACTIVE] FAILED to get mixer node - spectral flux will not work!")
        }
        
        // Attach audio energy tracker to light controller for dynamic intensity modulation
        lightController?.audioEnergyTracker = audioEnergyTracker
        logger.info("[AUDIO-REACTIVE] AudioEnergyTracker attached to light controller for \(mode.rawValue) mode")
    }
    
    /// Sets up Bluetooth latency monitoring for dynamic audio synchronization
    private func setupBluetoothLatencyMonitoring() {
        // Start Bluetooth latency monitoring for dynamic synchronization
        bluetoothLatencyMonitor.startMonitoring(interval: 1.0)
        
        // Initial latency offset setup
        updateLatencyOffsets()
        
        // Subscribe to ongoing latency updates for continuous synchronization adjustment
        // This ensures that latency changes due to audio route changes, thermal conditions,
        // or Bluetooth connection quality are automatically incorporated
        bluetoothLatencyMonitor.$smoothedLatency
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newLatency in
                self?.updateLatencyOffsets()
            }
            .store(in: &cancellables)
    }
    
    /// Updates audio latency offsets for all controllers
    /// Called initially and whenever smoothed latency changes
    private func updateLatencyOffsets() {
        let latency = bluetoothLatencyMonitor.smoothedLatency
        
        if let baseController = lightController as? BaseLightController {
            baseController.audioLatencyOffset = latency
        }
        if let vibrationController = vibrationController {
            vibrationController.audioLatencyOffset = latency
        }
        
        logger.debug("Updated audio latency offset to \(latency * 1000)ms")
    }
    
    // MARK: - Thermal & System Event Handlers
    
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
    
    /// Handles critical thermal state - stops session since screen mode is removed
    private func handleCriticalThermalState() {
        guard lightController?.source == .flashlight else {
            return
        }
        
        markSessionAsThermallyLimited()
        // Screen mode removed - stop session instead of switching
        stopSession()
    }
    
    private func handleTorchFailureEvent() {
        guard state == .running,
              lightController?.source == .flashlight else {
            return
        }
        
        thermalWarningLevel = .critical
        markSessionAsThermallyLimited()
        // Screen mode removed - stop session instead of switching
        stopSession()
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
    
    /// Starts frequency updates for UI display
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
        
        // SPECIAL CASE: DMN-Shutdown mode uses fixed script with frequency overrides per phase
        if mode == .dmnShutdown {
            // Find the current event based on elapsed time
            // This gives us the correct frequency from the script's frequencyOverride
            let currentEvent = script.events.first { event in
                elapsed >= event.timestamp && elapsed < (event.timestamp + event.duration)
            }
            
            if let event = currentEvent, let frequencyOverride = event.frequencyOverride {
                // Use the frequency override from the current event
                currentFrequency = frequencyOverride
            } else {
                // Fallback: use target frequency if no event found (shouldn't happen)
                currentFrequency = script.targetFrequency
            }
            return
        }
        
        // Standard ramping calculation for other modes
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
        logger.info("Starting session with local media item - BEGIN")

        guard state == .idle else {
            logger.warning("Attempted to start session while state is \(String(describing: self.state))")
            return
        }

        // Set state to analyzing IMMEDIATELY to show progress UI
        logger.info("Setting state to analyzing")
        state = .analyzing
        analysisProgress = AnalysisProgress(phase: .loading, progress: 0.0, message: NSLocalizedString("analysis.loading", comment: ""))
        stopPlaybackProgressUpdates()

        // Refresh cached preferences to ensure we use current user settings
        logger.info("Loading cached preferences")
        cachedPreferences = UserPreferences.load()

        // Set the light controller based on current preferences
        logger.info("Setting light controller based on preferences: \(self.cachedPreferences.preferredLightSource.rawValue)")
        // Always use flashlight (screen mode removed)
        lightController = services.flashlightController

        // Pre-warm flashlight if needed
        logger.info("Pre-warming flashlight if needed")
        await prewarmFlashlightIfNeeded()

        do {
            logger.info("Getting asset URL for analysis")
            // Update progress to show we're validating the asset
            analysisProgress = AnalysisProgress(phase: .loading, progress: 0.1, message: NSLocalizedString("analysis.loading", comment: ""))
            
            // Check if item can be analyzed with timeout to prevent hanging
            let assetURL = try await withTimeout(seconds: 10.0) {
                try await self.services.mediaLibraryService.assetURLForAnalysis(of: mediaItem)
            }
            logger.info("Asset URL obtained: \(assetURL.lastPathComponent)")

            logger.info("Starting audio analysis")
            // Update progress to show we're analyzing
            analysisProgress = AnalysisProgress(phase: .analyzing, progress: 0.2, message: NSLocalizedString("analysis.analyzing", comment: ""))
            
            // Analyze audio (use quick mode if enabled in preferences)
            let track = try await audioAnalyzer.analyze(url: assetURL, mediaItem: mediaItem, quickMode: cachedPreferences.quickAnalysisEnabled)
            currentTrack = track
            logger.info("Audio analysis completed: \(track.title)")

            // Generate LightScript using cached preferences
            let mode = cachedPreferences.preferredMode
            let lightSource = cachedPreferences.preferredLightSource

            logger.info("Generating light script")
            let script = entrainmentEngine.generateLightScript(
                from: track,
                mode: mode,
                lightSource: lightSource
            )
            currentScript = script
            logger.info("Light script generated")

            // Generate VibrationScript if vibration is enabled
            if cachedPreferences.vibrationEnabled {
                logger.info("Generating vibration script")
                do {
                    let vibrationScript = try entrainmentEngine.generateVibrationScript(
                        from: track,
                        mode: mode,
                        intensity: cachedPreferences.vibrationIntensity
                    )
                    currentVibrationScript = vibrationScript
                    vibrationController = services.vibrationController
                    logger.info("Vibration script generated")
                } catch {
                    logger.error("Failed to generate vibration script: \(error.localizedDescription, privacy: .public)")
                    // Degrade gracefully: continue without vibration instead of blocking session start
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
            logger.info("Creating session object")
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

            // Screen mode removed - no custom color RGB needed

            // Apply audio latency offset from user preferences for Bluetooth compensation
            if let baseController = lightController as? BaseLightController {
                baseController.audioLatencyOffset = cachedPreferences.audioLatencyOffset
                baseController.audioPlayback = audioPlayback
            }

            // Start playback and light (this sets the startTime)
            logger.info("Starting playback and light")
            // Start audio playback and light (startTime is created AFTER audio starts for proper sync)
            let actualStartTime = try await startPlaybackAndLight(url: assetURL, script: script, startTime: Date())
            sessionStartTime = actualStartTime
            updateCurrentFrequency()
            startFrequencyUpdates()
            logger.info("Playback and light started successfully")

            // Start playback progress updates AFTER audio has started
            startPlaybackProgressUpdates(for: track.duration)

            // Start vibration if enabled (using same actualStartTime for synchronization)
            if cachedPreferences.vibrationEnabled, let vibrationController = vibrationController, let vibrationScript = currentVibrationScript {
                vibrationController.audioLatencyOffset = cachedPreferences.audioLatencyOffset
                vibrationController.audioPlayback = audioPlayback

                try await vibrationController.start()
                vibrationController.execute(script: vibrationScript, syncedTo: actualStartTime)
            }

            // Start Bluetooth latency monitoring for dynamic synchronization
            setupBluetoothLatencyMonitoring()

            // Prevent screen from turning off during session
            UIApplication.shared.isIdleTimerDisabled = true

            logger.info("Setting state to running")
            state = .running
            affirmationPlayed = false

            // Start observing for affirmation trigger
            startAffirmationObserver()

            // Haptic feedback for session start (if enabled)
            if cachedPreferences.hapticFeedbackEnabled {
                HapticFeedback.medium()
            }

            logger.info("Session started successfully - END")

        } catch is CancellationError {
            logger.info("Session start cancelled")
            audioPlayback.stop()
            lightController?.stop()
            vibrationController?.stop()
            stopPlaybackProgressUpdates()
            bluetoothLatencyMonitor.stopMonitoring()
            UIApplication.shared.isIdleTimerDisabled = false
            state = .idle
        } catch let timeoutError as TimeoutError {
            logger.error("Session start timed out: \(timeoutError.localizedDescription, privacy: .public)")
            errorMessage = NSLocalizedString("error.audio.timeout", comment: "")
            state = .error

            audioPlayback.stop()
            lightController?.stop()
            vibrationController?.stop()
            stopPlaybackProgressUpdates()
        } catch {
            logger.error("Session start failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            state = .error

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
        // Set state to analyzing IMMEDIATELY to show progress UI
        state = .analyzing
        analysisProgress = AnalysisProgress(phase: .loading, progress: 0.0, message: NSLocalizedString("analysis.loading", comment: ""))
        stopPlaybackProgressUpdates()
        
        // Refresh cached preferences to ensure we use current user settings
        cachedPreferences = UserPreferences.load()
        
        // Set the light controller based on current preferences
        // Always use flashlight (screen mode removed)
        lightController = services.flashlightController
        
        // Pre-warm flashlight if needed
        await prewarmFlashlightIfNeeded()
        
        do {
            // Analyze audio directly from URL (no MediaItem required, use quick mode if enabled)
            let track = try await audioAnalyzer.analyze(url: audioFileURL, quickMode: cachedPreferences.quickAnalysisEnabled)
            currentTrack = track
            
            // Generate LightScript using cached preferences
            let mode = cachedPreferences.preferredMode
            let lightSource = cachedPreferences.preferredLightSource
            
            let script = entrainmentEngine.generateLightScript(
                from: track,
                mode: mode,
                lightSource: lightSource
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
            
            // Screen mode removed - no custom color RGB needed
            
            // Apply audio latency offset from user preferences for Bluetooth compensation
            if let baseController = lightController as? BaseLightController {
                baseController.audioLatencyOffset = cachedPreferences.audioLatencyOffset
                // Set audio playback reference for precise audio-thread timing
                baseController.audioPlayback = audioPlayback
            }
            
            // Start playback and light (this sets the startTime)
            // Start audio playback and light (startTime is created AFTER audio starts for proper sync)
            let actualStartTime = try await startPlaybackAndLight(url: audioFileURL, script: script, startTime: Date())
            sessionStartTime = actualStartTime
            // Update frequency now that sessionStartTime is set (timer will continue updating)
            updateCurrentFrequency()
            startFrequencyUpdates()
            
            // Start playback progress updates AFTER audio has started
            startPlaybackProgressUpdates(for: track.duration)
            
            // Start vibration if enabled (using same actualStartTime for synchronization)
            if cachedPreferences.vibrationEnabled, let vibrationController = vibrationController, let vibrationScript = currentVibrationScript {
                // Apply audio latency offset for Bluetooth compensation
                vibrationController.audioLatencyOffset = cachedPreferences.audioLatencyOffset
                // Set audio playback reference for precise audio-thread timing
                vibrationController.audioPlayback = audioPlayback
                
                try await vibrationController.start()
                vibrationController.execute(script: vibrationScript, syncedTo: actualStartTime)
            }
            
            // Start Bluetooth latency monitoring for dynamic synchronization
            setupBluetoothLatencyMonitoring()
            
            // Prevent screen from turning off during session
            UIApplication.shared.isIdleTimerDisabled = true
            
            state = .running
            affirmationPlayed = false
            
            // Start observing for affirmation trigger
            startAffirmationObserver()
            
            // Haptic feedback for session start (if enabled)
            if cachedPreferences.hapticFeedbackEnabled {
                HapticFeedback.medium()
            }
            
        } catch is CancellationError {
            // Task was cancelled (e.g., view disappeared during startup)
            // Clean up resources but don't set error state
            logger.info("Session start (file) cancelled")
            audioPlayback.stop()
            lightController?.stop()
            vibrationController?.stop()
            stopPlaybackProgressUpdates()
            bluetoothLatencyMonitor.stopMonitoring()
            UIApplication.shared.isIdleTimerDisabled = false
            state = .idle
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
    
    /// Starts an Awakening Flow session (30-minute timeline-based entrainment flow)
    /// This session does not require audio analysis and uses a pre-generated script
    /// with frequency overrides for different phases (12 Hz → 8 Hz → 4 Hz → 40 Hz → 100 Hz → 7.83 Hz)
    func startAwakeningSession() async {
        logger.info("Starting Awakening Flow session - BEGIN")
        
        guard state == .idle else {
            logger.warning("Attempted to start Awakening session while state is \(String(describing: self.state))")
            return
        }
        
        logger.info("Setting state to analyzing")
        state = .analyzing
        analysisProgress = AnalysisProgress(phase: .analyzing, progress: 0.0, message: NSLocalizedString("analysis.analyzing", comment: ""))
        stopPlaybackProgressUpdates()
        
        // Refresh cached preferences to ensure we use current user settings
        logger.info("Loading cached preferences")
        cachedPreferences = UserPreferences.load()
        
        // Set the light controller based on current preferences
        logger.info("Setting light controller based on preferences: \(self.cachedPreferences.preferredLightSource.rawValue)")
        // Always use flashlight (screen mode removed)
        lightController = services.flashlightController
        
        // Pre-warm flashlight if needed
        logger.info("Pre-warming flashlight if needed")
        await prewarmFlashlightIfNeeded()
        
        do {
            // Generate Awakening Script (no audio analysis needed)
            logger.info("Generating Awakening Flow script")
            let script = EntrainmentEngine.generateAwakeningScript()
            currentScript = script
            logger.info("Awakening Flow script generated")
            
            // Create session (no audio track, but we use .localFile as audioSource)
            logger.info("Creating Awakening Flow session object")
            let session = Session(
                mode: .gamma, // Using gamma as container mode for high-energy flow
                lightSource: cachedPreferences.preferredLightSource,
                audioSource: .localFile,
                trackTitle: "Awakening Flow",
                trackArtist: nil,
                trackBPM: nil
            )
            currentSession = session
            updateAffirmationStatusForCurrentPreferences()
            
            // Screen mode removed - no custom color RGB needed
            
            // Apply audio latency offset from user preferences for Bluetooth compensation
            if let baseController = lightController as? BaseLightController {
                baseController.audioLatencyOffset = cachedPreferences.audioLatencyOffset
                // No audio playback for Awakening Flow, but we keep the reference for consistency
                baseController.audioPlayback = nil
            }
            
            // Start light controller and execute script
            logger.info("Starting light controller")
            let startTime = Date()
            sessionStartTime = startTime
            updateCurrentFrequency()
            startFrequencyUpdates()
            
            try await lightController?.start()
            lightController?.execute(script: script, syncedTo: startTime)
            logger.info("Light controller started successfully")
            
            // Start playback progress updates for 30-minute duration
            startPlaybackProgressUpdates(for: script.duration)
            
            // Vibration is optional (if enabled in preferences)
            // Note: We don't generate a vibration script for Awakening Flow as it's audio-independent
            // If vibration is desired, it would need a separate vibration script generator
            vibrationController = nil
            currentVibrationScript = nil
            
            // No audio energy tracking needed (no audio playback)
            // No Bluetooth latency monitoring needed (no audio synchronization)
            
            // Prevent screen from turning off during session
            UIApplication.shared.isIdleTimerDisabled = true
            
            logger.info("Setting state to running")
            state = .running
            affirmationPlayed = false
            
            // Start observing for affirmation trigger
            startAffirmationObserver()
            
            // Haptic feedback for session start (if enabled)
            if cachedPreferences.hapticFeedbackEnabled {
                HapticFeedback.medium()
            }
            
            logger.info("Awakening Flow session started successfully - END")
            
        } catch is CancellationError {
            logger.info("Awakening Flow session start cancelled")
            lightController?.stop()
            vibrationController?.stop()
            stopPlaybackProgressUpdates()
            UIApplication.shared.isIdleTimerDisabled = false
            state = .idle
        } catch {
            logger.error("Awakening Flow session start failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            state = .error
            
            lightController?.stop()
            vibrationController?.stop()
            stopPlaybackProgressUpdates()
        }
    }
    
    /// Starts a DMN-Shutdown session (30-minute timeline-based entrainment flow with Master-Audio)
    /// This session uses a pre-generated script with frequency overrides and loads a fixed
    /// Master-Audio-File from the App-Bundle for synesthetic coherence.
    /// 
    /// Master-Audio: void_master.mp3 (30 minutes, Brown/Pink Noise with isochronic tones)
    func startDMNShutdownSession() async {
        logger.info("Starting DMN-Shutdown session - BEGIN")
        
        guard state == .idle else {
            logger.warning("Attempted to start DMN-Shutdown session while state is \(String(describing: self.state))")
            return
        }
        
        logger.info("Setting state to analyzing")
        state = .analyzing
        analysisProgress = AnalysisProgress(phase: .loading, progress: 0.0, message: NSLocalizedString("analysis.loading", comment: ""))
        stopPlaybackProgressUpdates()
        
        // Refresh cached preferences to ensure we use current user settings
        logger.info("Loading cached preferences")
        cachedPreferences = UserPreferences.load()
        
        // Set the light controller based on current preferences
        logger.info("Setting light controller based on preferences: \(self.cachedPreferences.preferredLightSource.rawValue)")
        // Always use flashlight (screen mode removed)
        lightController = services.flashlightController
        
        // Pre-warm flashlight if needed
        logger.info("Pre-warming flashlight if needed")
        await prewarmFlashlightIfNeeded()
        
        do {
            // Load Master-Audio-File from Bundle
            logger.info("Loading Master-Audio-File from Bundle")
            guard let masterAudioURL = Bundle.main.url(forResource: "void_master", withExtension: "mp3") else {
                throw NSError(
                    domain: "DMNShutdownSession",
                    code: 1,
                    userInfo: [
                        NSLocalizedDescriptionKey: NSLocalizedString(
                            "error.dmnShutdown.audioFileNotFound",
                            comment: "Master audio file 'void_master.mp3' not found in bundle"
                        )
                    ]
                )
            }
            logger.info("Master-Audio-File loaded: \(masterAudioURL.lastPathComponent)")
            
            // Generate DMN-Shutdown Script (no audio analysis needed - script is fixed)
            logger.info("Generating DMN-Shutdown script")
            let script = EntrainmentEngine.generateDMNShutdownScript()
            currentScript = script
            logger.info("DMN-Shutdown script generated")
            
            // Create a dummy AudioTrack for display purposes (so Status Bar works)
            let track = AudioTrack(
                id: UUID(),
                title: NSLocalizedString("mode.dmnShutdown.displayName", comment: ""),
                artist: "MindSync",
                duration: script.duration,
                bpm: 0, // Not applicable for fixed script
                beatTimestamps: []
            )
            currentTrack = track
            logger.info("AudioTrack created for DMN-Shutdown mode")
            
            // Create session with .dmnShutdown mode
            logger.info("Creating DMN-Shutdown session object")
            let session = Session(
                mode: .dmnShutdown,
                lightSource: cachedPreferences.preferredLightSource,
                audioSource: .localFile,
                trackTitle: track.title,
                trackArtist: track.artist,
                trackBPM: track.bpm
            )
            currentSession = session
            updateAffirmationStatusForCurrentPreferences()
            
            // Apply audio latency offset from user preferences for Bluetooth compensation
            if let baseController = lightController as? BaseLightController {
                baseController.audioLatencyOffset = cachedPreferences.audioLatencyOffset
                // Set audio playback reference for precise audio-thread timing
                baseController.audioPlayback = audioPlayback
            }
            
            // Start playback and light (synchronized)
            logger.info("Starting light controller and audio playback")
            // Start audio playback and light synchronization
            // startTime is created AFTER audio has started for proper synchronization
            let actualStartTime = try await startPlaybackAndLight(url: masterAudioURL, script: script, startTime: Date())
            sessionStartTime = actualStartTime
            updateCurrentFrequency()
            startFrequencyUpdates()
            
            // Start playback progress updates for script duration
            // Use actual audio duration if available, otherwise use script duration
            let audioDuration = script.duration // Use script duration for DMN-Shutdown mode
            startPlaybackProgressUpdates(for: audioDuration)
            
            // Note: Spectral flux is NOT enabled for DMN-Shutdown mode since it uses
            // a fixed timeline with frequency overrides rather than audio-reactive behavior
            
            // Setup Bluetooth latency monitoring for dynamic audio synchronization
            setupBluetoothLatencyMonitoring()
            
            // Generate VibrationScript if vibration is enabled in preferences
            // Generate synchronously for DMN-Shutdown to ensure proper timing synchronization
            if cachedPreferences.vibrationEnabled {
                logger.info("Generating DMN-Shutdown vibration script (synchronous)")
                do {
                    let vibrationScript = try EntrainmentEngine.generateDMNShutdownVibrationScript(
                        intensity: cachedPreferences.vibrationIntensity
                    )
                    currentVibrationScript = vibrationScript
                    vibrationController = services.vibrationController
                    logger.info("DMN-Shutdown vibration script generated (\(vibrationScript.events.count) events)")
                    
                    // Start vibration with same actualStartTime for synchronization
                    vibrationController?.audioLatencyOffset = cachedPreferences.audioLatencyOffset
                    vibrationController?.audioPlayback = audioPlayback
                    try await vibrationController?.start()
                    vibrationController?.execute(script: vibrationScript, syncedTo: actualStartTime)
                    logger.info("Vibration controller started for DMN-Shutdown (synchronized)")
                } catch {
                    logger.error("Failed to generate/start vibration script: \(error.localizedDescription, privacy: .public)")
                    // Degrade gracefully: continue without vibration instead of blocking session start
                    vibrationController = nil
                    currentVibrationScript = nil
                    statusMessage = NSLocalizedString("status.vibration.unavailable", comment: "")
                }
            } else {
                vibrationController = nil
                currentVibrationScript = nil
            }
            
            // Prevent screen from turning off during session
            UIApplication.shared.isIdleTimerDisabled = true
            
            logger.info("Setting state to running")
            state = .running
            affirmationPlayed = false
            
            // Start observing for affirmation trigger
            startAffirmationObserver()
            
            // Haptic feedback for session start (if enabled)
            if cachedPreferences.hapticFeedbackEnabled {
                HapticFeedback.medium()
            }
            
            logger.info("DMN-Shutdown session started successfully - END")
            
        } catch is CancellationError {
            logger.info("DMN-Shutdown session start cancelled")
            lightController?.stop()
            vibrationController?.stop()
            audioPlayback.stop()
            stopPlaybackProgressUpdates()
            UIApplication.shared.isIdleTimerDisabled = false
            state = .idle
        } catch {
            logger.error("DMN-Shutdown session start failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
            state = .error
            
            lightController?.stop()
            vibrationController?.stop()
            audioPlayback.stop()
            stopPlaybackProgressUpdates()
            UIApplication.shared.isIdleTimerDisabled = false
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
        
        // CRITICAL: Stop timers FIRST to prevent race conditions
        // This must happen before any other cleanup to avoid hanging
        stopPlaybackProgressUpdates()
        affirmationTimer?.invalidate()
        affirmationTimer = nil
        
        // Cancel any active task (e.g. screen switch) before cleanup
        activeTask?.cancel()
        activeTask = nil
        
        // Re-enable idle timer when session stops
        UIApplication.shared.isIdleTimerDisabled = false
        
        // Stop controllers in order: Light first (stops timer), then audio, then vibration
        // This order prevents race conditions where timer callbacks try to access stopped services
        lightController?.stop()
        
        // CRITICAL: Stop audio energy tracking BEFORE stopping audio playback
        // The tracker needs to remove its tap from the mixer node while the engine is still running
        audioEnergyTracker.stopTracking()
        audioEnergyTracker.useSpectralFlux = false // Reset for next session
        lightController?.audioEnergyTracker = nil
        
        audioPlayback.stop()
        vibrationController?.stop()

        // Stop isochronic audio if active
        IsochronicAudioService.shared.stop()

        // Stop Bluetooth latency monitoring
        bluetoothLatencyMonitor.stopMonitoring()

        // Stop fall detection
        fallDetector.stopMonitoring()
        
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
        sessionStartTime = nil
        affirmationPlayed = false
        pausedBySystemInterruption = false
        pausedByRouteChange = false
        pausedByBackground = false
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
        
        // Cleanup fall detection
        fallDetector.stopMonitoring()
        pausedBySystemInterruption = false
        pausedByRouteChange = false
        pausedByBackground = false
        affirmationStatus = nil
        totalPauseDuration = 0
        pauseStartTime = nil
        
        // Invalidate affirmation timer
        affirmationTimer?.invalidate()
        affirmationTimer = nil
    }
    
    /// Starts audio playback and light synchronization with Master Clock synchronization
    /// Uses a "Future-Start" approach: All systems (Audio, Light, Vibration) synchronize to a common future time point
    /// - Returns: The synchronized start time (future time point that all systems wait for)
    private func startPlaybackAndLight(url: URL, script: LightScript, startTime: Date) async throws -> Date {
        let modeString = self.currentSession?.mode.rawValue ?? "unknown"
        logger.info("startPlaybackAndLight: starting with URL=\(url.lastPathComponent), mode=\(modeString)")

        guard let lightController = lightController else {
            logger.error("No light controller available")
            throw LightControlError.configurationFailed
        }

        // MASTER CLOCK: Calculate future start time (750ms in the future)
        // This gives all systems time to prepare and ensures perfect synchronization.
        // 
        // Rationale for 750ms delay:
        // - Audio scheduling requires hardware buffer preparation (~100-200ms)
        // - Light controller needs display link stabilization (~100ms)
        // - Vibration controller needs haptic engine priming (~50-100ms)
        // - System scheduling jitter tolerance (~50-100ms)
        // - Additional margin for older devices and high system load (~200-250ms)
        // Total: ~500-750ms minimum. 750ms provides comfortable margin for all devices.
        //
        // NOTE: This is currently a fixed value that works reliably across all supported
        // devices (iPhone with iOS 17+). Future enhancement could make this adaptive based
        // on device capabilities or system load, but the fixed 750ms value has proven
        // sufficient in testing on devices ranging from iPhone 13 to iPhone 15 Pro.
        let syncStartDelay: TimeInterval = 0.75 // 750ms delay for synchronization
        let systemUptime = ProcessInfo.processInfo.systemUptime
        let futureStartUptime = systemUptime + syncStartDelay
        let futureStartTime = Date(timeIntervalSinceNow: syncStartDelay)
        
        logger.info("Master Clock: Future start time calculated (delay=\(syncStartDelay)s, uptime=\(systemUptime)s, futureUptime=\(futureStartUptime)s, futureStartTime=\(futureStartTime))")

        // Prepare all systems first (prewarm)
        logger.info("Preparing all systems for synchronized start")
        
        // Prepare audio for playback (load and schedule, but don't start yet)
        try audioPlayback.prepare(url: url)
        logger.info("Audio playback prepared (engine started, file scheduled)")
        
        // Schedule audio to start at the future start time
        // This ensures audio start is aligned with the Master Clock synchronization
        try audioPlayback.schedulePlayback(at: futureStartTime)
        logger.info("Audio playback scheduled to start at futureStartTime: \(futureStartTime)")

        // Start light controller (preparation phase)
        let lightStartTask = Task {
            try await lightController.start()
        }

        var lightControllerStarted = false
        do {
            // Wait for light controller to start with a 5-second timeout
            try await withTimeout(seconds: 5.0) {
                try await lightStartTask.value
            }
            lightControllerStarted = true
            logger.info("Light controller prepared successfully")
        } catch {
            lightStartTask.cancel()
            if error is TimeoutError {
                logger.error("Light controller start timed out after 5 seconds")
            } else {
                logger.error("Light controller start failed with error: \(error.localizedDescription, privacy: .public)")
            }
            statusMessage = NSLocalizedString("status.light.failed", comment: "Light synchronization failed, continuing in audio-only mode")
        }

        // If cinematic mode, attach isochronic audio to the playback engine for perfect sync
        if currentSession?.mode == .cinematic, let engine = audioPlayback.getAudioEngine() {
            IsochronicAudioService.shared.carrierFrequency = 150.0
            IsochronicAudioService.shared.start(mode: currentSession!.mode, attachToEngine: engine)
        }
        
        // Enable audio energy tracking for audio-reactive modes (not for fixed script modes)
        // Fixed script modes use frequencyOverride and don't need audio reactivity
        if let mode = currentSession?.mode, !mode.usesFixedScript {
            enableSpectralFluxForCinematicMode(mode)
        }

        // Wait until the future start time is reached
        let currentUptime = ProcessInfo.processInfo.systemUptime
        let waitTime = max(0.0, futureStartUptime - currentUptime)
        
        if waitTime > 0 {
            logger.info("Master Clock: Waiting \(waitTime)s until synchronized start time")
            do {
                try await Task.sleep(nanoseconds: UInt64(waitTime * 1_000_000_000))
            } catch is CancellationError {
                // The wait was cancelled (e.g. user stopped the session) after audio was scheduled.
                // Stop the audio engine to prevent unsynchronized audio-only playback.
                logger.info("Master Clock: Synchronized start cancelled during wait; stopping audio engine")
                if let engine = audioPlayback.getAudioEngine() {
                    engine.stop()
                }
                throw CancellationError()
            }
            
            // Check for cancellation after sleep completes
            if Task.isCancelled {
                logger.info("Master Clock: Cancellation detected after wait; stopping audio engine before synchronized start")
                if let engine = audioPlayback.getAudioEngine() {
                    engine.stop()
                }
                throw CancellationError()
            }
        }

        // Use futureStartTime instead of Date() to keep light and audio mathematically synchronized,
        // even if this task wakes up a few milliseconds late.
        // The audio has been scheduled in hardware exactly for futureStartTime.
        let synchronizedStartTime = futureStartTime
        logger.info("Master Clock: Synchronized start time reached (planned time: \(synchronizedStartTime), actual wake-up: \(Date()))")

        if lightControllerStarted {
            // Start LightScript execution synchronized to the future start time
            lightController.execute(script: script, syncedTo: synchronizedStartTime)
            logger.info("startPlaybackAndLight: light script execution started with Master Clock synchronization")
        } else {
            logger.info("startPlaybackAndLight: continuing in audio-only mode")
        }
        
        // Return synchronized start time for vibration synchronization
        return synchronizedStartTime
    }

    /// Typed timeout error for better type safety
    enum TimeoutError: LocalizedError {
        case timedOut(seconds: TimeInterval)

        var errorDescription: String? {
            switch self {
            case .timedOut(let seconds):
                return "Operation timed out after \(seconds) seconds"
            }
        }
    }

    /// Helper function to add timeout to async operations
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: Result<T, Error>.self) { group in
            // Start the operation
            group.addTask {
                do {
                    let value = try await operation()
                    return .success(value)
                } catch {
                    return .failure(error)
                }
            }

            // Start the timeout
            group.addTask {
                do {
                    try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                    return .failure(TimeoutError.timedOut(seconds: seconds))
                } catch {
                    // If the sleep is cancelled (because the operation finished first),
                    // we should not propagate the cancellation as a failure.
                    // Instead, we'll just let the task group complete without this result.
                    throw error
                }
            }

            // Wait for the first task to complete
            guard let result = try await group.next() else {
                throw TimeoutError.timedOut(seconds: seconds)
            }

            // Cancel remaining tasks to ensure cleanup
            group.cancelAll()

            // Return the result from the first completed task
            switch result {
            case .success(let value):
                return value
            case .failure(let error):
                throw error
            }
        }
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

