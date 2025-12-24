import Foundation
import Combine

/// Zentraler Service-Container für MindSync
final class ServiceContainer: ObservableObject {
    nonisolated(unsafe) static var shared: ServiceContainer {
        // Thread-safe lazy initialization using a lock
        _lock.lock()
        defer { _lock.unlock() }
        
        if _sharedInstance == nil {
            // Initialize on Main Actor
            // This ensures all @MainActor services (like ScreenController) are initialized correctly
            if Thread.isMainThread {
                _sharedInstance = MainActor.assumeIsolated {
                    ServiceContainer()
                }
            } else {
                // If called from background thread, we need to dispatch to main
                // But we can't use sync here as it could cause deadlocks
                // So we use async and wait with a semaphore
                let semaphore = DispatchSemaphore(value: 0)
                var instance: ServiceContainer?
                DispatchQueue.main.async {
                    instance = MainActor.assumeIsolated {
                        ServiceContainer()
                    }
                    semaphore.signal()
                }
                semaphore.wait()
                _sharedInstance = instance
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
