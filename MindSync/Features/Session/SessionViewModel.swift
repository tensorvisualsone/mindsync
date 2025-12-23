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
    
    // Published State
    @Published var state: SessionState = .idle
    @Published var currentTrack: AudioTrack?
    @Published var currentScript: LightScript?
    @Published var analysisProgress: AnalysisProgress?
    @Published var errorMessage: String?
    @Published var currentSession: Session?
    
    // Cancellables
    private var cancellables = Set<AnyCancellable>()
    
    // Aktuelle Lichtquelle
    private var lightController: LightControlling {
        switch UserPreferences.load().preferredLightSource {
        case .flashlight:
            return services.flashlightController
        case .screen:
            return services.screenController
        }
    }
    
    init() {
        self.audioAnalyzer = services.audioAnalyzer
        self.audioPlayback = AudioPlaybackService()
        
        // EntrainmentEngine aus ServiceContainer
        self.entrainmentEngine = services.entrainmentEngine
        
        // Höre auf Analyse-Fortschritt
        audioAnalyzer.progressPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] progress in
                self?.analysisProgress = progress
            }
            .store(in: &cancellables)
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
            
            // Generiere LightScript
            let mode = UserPreferences.load().preferredMode
            let lightSource = UserPreferences.load().preferredLightSource
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
            
        } catch {
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

