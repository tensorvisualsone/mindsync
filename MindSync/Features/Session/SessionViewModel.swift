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
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Current light controller based on cached preferences
    // Computed once per session to avoid repeated calculations
    private var lightController: LightControlling?
    
    init() {
        self.audioAnalyzer = services.audioAnalyzer
        self.audioPlayback = services.audioPlayback
        self.cachedPreferences = UserPreferences.load()
        
        // EntrainmentEngine from ServiceContainer
        self.entrainmentEngine = services.entrainmentEngine
        
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
    }
    
    deinit {
        // Ensure playback is stopped before clearing callback to avoid delegate callbacks after deallocation
        audioPlayback.stop()
        // Clear callback to prevent stale references
        audioPlayback.onPlaybackComplete = nil
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
            let script = entrainmentEngine.generateLightScript(
                from: track,
                mode: mode,
                lightSource: lightSource
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
    
    /// Stops the current session
    func stopSession() {
        // Allow cleanup from any state except .idle to prevent resource leaks
        guard state != .idle else { return }
        
        audioPlayback.stop()
        lightController?.stop()
        
        // End session and save to history only if it was running
        if var session = currentSession, state == .running {
            session.endedAt = Date()
            session.endReason = .userStopped
            services.sessionHistoryService.save(session: session)
        }
        
        state = .idle
        currentTrack = nil
        currentScript = nil
        currentSession = nil
        lightController = nil
    }
    
    /// Resets the session state (called when view is dismissed)
    func reset() {
        errorMessage = nil
        state = .idle
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

