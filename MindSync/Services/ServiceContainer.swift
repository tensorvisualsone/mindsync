import Foundation
import Combine

/// Zentraler Service-Container für MindSync
@MainActor
final class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()

    // Core Services
    let audioAnalyzer: AudioAnalyzer
    let microphoneAnalyzer: MicrophoneAnalyzer?
    let audioPlayback: AudioPlaybackService
    let sessionHistoryService: SessionHistoryService
    let mediaLibraryService: MediaLibraryService
    let permissionsService: PermissionsService

    // Light & Entrainment
    let flashlightController: FlashlightController
    let screenController: ScreenController
    let entrainmentEngine: EntrainmentEngine
    let thermalManager: ThermalManager
    let fallDetector: FallDetector
    
    // Affirmationen
    let affirmationService: AffirmationOverlayService

    private init() {
        // Audio
        self.audioAnalyzer = AudioAnalyzer()
        self.microphoneAnalyzer = MicrophoneAnalyzer() // May be nil if FFT setup fails
        if microphoneAnalyzer == nil {
            NSLog("MindSync: MicrophoneAnalyzer initialisation failed – Mikrofon-Modus ist deaktiviert (FFT-Setup fehlgeschlagen).")
        }
        self.audioPlayback = AudioPlaybackService()

        // Sessions & History
        self.sessionHistoryService = SessionHistoryService()
        self.mediaLibraryService = MediaLibraryService()
        self.permissionsService = PermissionsService()

        // Light & Safety - Initialize ThermalManager first to avoid circular dependency
        self.thermalManager = ThermalManager()
        self.flashlightController = FlashlightController(thermalManager: self.thermalManager)
        self.screenController = ScreenController()
        self.entrainmentEngine = EntrainmentEngine()
        self.fallDetector = FallDetector()
        
        // Affirmationen
        self.affirmationService = AffirmationOverlayService()
    }
}
