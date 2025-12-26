import Foundation
import Combine

/// Zentraler Service-Container für MindSync
final class ServiceContainer: ObservableObject {
    nonisolated(unsafe) static var shared: ServiceContainer {
        // Simple thread-safe lazy initialization
        // Use a lock to ensure only one thread initializes
        _lock.lock()
        defer { _lock.unlock() }
        
        if _sharedInstance == nil {
            // Initialize on main thread
            if Thread.isMainThread {
                _sharedInstance = ServiceContainer()
            } else {
                // Dispatch to main thread and wait
                let semaphore = DispatchSemaphore(value: 0)
                DispatchQueue.main.async {
                    _sharedInstance = ServiceContainer()
                    semaphore.signal()
                }
                semaphore.wait()
            }
        }
        return _sharedInstance!
    }
    
    nonisolated(unsafe) private static var _sharedInstance: ServiceContainer?
    nonisolated(unsafe) private static let _lock = NSLock()

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
    
    // Audio Energy Tracking (for Cinematic Mode)
    let audioEnergyTracker: AudioEnergyTracker
    
    // Affirmationen
    let affirmationService: AffirmationOverlayService

    private init() {
        // Audio
        self.audioAnalyzer = AudioAnalyzer()
        self.microphoneAnalyzer = MicrophoneAnalyzer() // May be nil if FFT setup fails
        if microphoneAnalyzer == nil {
            NSLog("MindSync: MicrophoneAnalyzer initialization failed – Mikrofon-Modus ist deaktiviert (FFT-Setup fehlgeschlagen).")
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
        
        // Audio Energy Tracking (for Cinematic Mode)
        self.audioEnergyTracker = AudioEnergyTracker()
        
        // Affirmationen
        self.affirmationService = AffirmationOverlayService()
    }
}
