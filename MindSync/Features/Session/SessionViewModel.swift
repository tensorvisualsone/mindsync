import Foundation
import SwiftUI
import Combine
import MediaPlayer

/// ViewModel für die Session-Ansicht
@MainActor
final class SessionViewModel: ObservableObject {
    // Services
    private let services = ServiceContainer.shared
    private let audioAnalyzer: AudioAnalyzer
    private let audioPlayback: AudioPlaybackService
    private let entrainmentEngine: EntrainmentEngine
    
    // Cached preferences to avoid repeated UserDefaults access
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
    private var lightController: LightControlling {
        switch cachedPreferences.preferredLightSource {
        case .flashlight:
            return services.flashlightController
        case .screen:
            return services.screenController
        }
    }
    
    init() {
        self.audioAnalyzer = services.audioAnalyzer
        self.audioPlayback = services.audioPlayback
        self.cachedPreferences = UserPreferences.load()
        
        // EntrainmentEngine aus ServiceContainer
        self.entrainmentEngine = services.entrainmentEngine
        
        // Setup playback completion callback
        audioPlayback.onPlaybackComplete = { [weak self] in
            Task { @MainActor in
                self?.handlePlaybackComplete()
            }
        }
        
        // Höre auf Analyse-Fortschritt
        audioAnalyzer.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.analysisProgress = progress
            }
            .store(in: &cancellables)
    }
    
    /// Handles playback completion
    private func handlePlaybackComplete() {
        guard state == .running else { return }
        stopSession()
    }
    
    /// Startet eine Session mit einem ausgewählten Song
    func startSession(with mediaItem: MPMediaItem) async {
        guard state == .idle else { return }
        
        state = .analyzing
        
        do {
            // Prüfe ob Song analysierbar ist
            guard services.mediaLibraryService.canAnalyze(item: mediaItem),
                  let assetURL = services.mediaLibraryService.getAssetURL(for: mediaItem) else {
                errorMessage = "Dieser Song ist DRM-geschützt und kann nicht analysiert werden. Bitte verwenden Sie den Mikrofon-Modus oder einen anderen Song."
                state = .error
                return
            }
            
            // Analysiere Audio
            let track = try await audioAnalyzer.analyze(url: assetURL, mediaItem: mediaItem)
            currentTrack = track
            
            // Generiere LightScript using cached preferences
            let mode = cachedPreferences.preferredMode
            let lightSource = cachedPreferences.preferredLightSource
            let script = entrainmentEngine.generateLightScript(
                from: track,
                mode: mode,
                lightSource: lightSource
            )
            currentScript = script
            
            // Erstelle Session
            let session = Session(
                mode: mode,
                lightSource: lightSource,
                audioSource: .localFile,
                trackTitle: track.title,
                trackArtist: track.artist,
                trackBPM: track.bpm
            )
            currentSession = session
            
            // Starte Wiedergabe und Licht
            try startPlaybackAndLight(url: assetURL, script: script)
            
            state = .running
            
            // Auto-save session immediately when running state is reached
            services.sessionHistoryService.save(session: session)
            
        } catch {
            // Ensure cleanup if starting playback or light controller fails
            audioPlayback.stop()
            lightController.stop()
            
            errorMessage = error.localizedDescription
            state = .error
        }
    }
    
    /// Stoppt die aktuelle Session
    func stopSession() {
        guard state == .running else { return }
        
        audioPlayback.stop()
        lightController.stop()
        
        // Session beenden
        if var session = currentSession {
            session.endedAt = Date()
            session.endReason = .userStopped
            services.sessionHistoryService.save(session: session)
        }
        
        state = .idle
        currentTrack = nil
        currentScript = nil
        currentSession = nil
    }
    
    /// Resets the session state (called when view is dismissed)
    func reset() {
        errorMessage = nil
        state = .idle
    }
    
    /// Startet Audio-Wiedergabe und Licht-Synchronisation
    private func startPlaybackAndLight(url: URL, script: LightScript) throws {
        // Starte Audio-Wiedergabe
        try audioPlayback.play(url: url)
        
        // Starte Licht-Controller
        try lightController.start()
        
        // Starte LightScript-Ausführung synchronisiert mit Audio
        let startTime = Date()
        lightController.execute(script: script, syncedTo: startTime)
    }
}

/// Zustände einer Session
enum SessionState {
    case idle           // Keine aktive Session
    case analyzing      // Audio wird analysiert
    case running        // Session läuft
    case paused        // Session pausiert
    case error         // Fehler aufgetreten
}

