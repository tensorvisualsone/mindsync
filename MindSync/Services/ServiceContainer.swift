import Foundation
import Combine

/// Zentraler Service-Container für MindSync
@MainActor
final class ServiceContainer: ObservableObject {
    /// Shared instance guaranteed to be main-actor isolated.
    static let shared: ServiceContainer = ServiceContainer()

    // Core Services
    let audioAnalyzer: AudioAnalyzer
    let audioPlayback: AudioPlaybackService
    let sessionHistoryService: SessionHistoryService
    let mediaLibraryService: MediaLibraryService
    let permissionsService: PermissionsService

    // Light & Entrainment
    let flashlightController: FlashlightController
    let entrainmentEngine: EntrainmentEngine
    let thermalManager: ThermalManager
    let fallDetector: FallDetector
    
    // Vibration
    let vibrationController: VibrationController
    
    // Audio Energy Tracking (for Cinematic Mode)
    let audioEnergyTracker: AudioEnergyTracker
    
    // Affirmationen
    let affirmationService: AffirmationOverlayService

    private init() {
        // Audio
        self.audioAnalyzer = AudioAnalyzer()
        self.audioPlayback = AudioPlaybackService()

        // Sessions & History
        self.sessionHistoryService = SessionHistoryService()
        self.mediaLibraryService = MediaLibraryService()
        self.permissionsService = PermissionsService()

        // Light & Safety - Initialize ThermalManager first to avoid circular dependency
        self.thermalManager = ThermalManager()
        self.flashlightController = FlashlightController(thermalManager: self.thermalManager)
        self.entrainmentEngine = EntrainmentEngine()
        self.fallDetector = FallDetector()
        
        // Vibration
        self.vibrationController = VibrationController()
        
        // Audio Energy Tracking (for Cinematic Mode)
        self.audioEnergyTracker = AudioEnergyTracker()
        
        // Affirmationen
        self.affirmationService = AffirmationOverlayService()
        
        // Pre-warm the flashlight hardware to reduce cold-start latency
        // Must be after all properties are initialized to avoid capturing 'self' prematurely
        Task { [weak self] in
            do {
                try await self?.flashlightController.prewarm()
            } catch {
                // Log prewarm failure for diagnostics
                //
                // Failures can occur due to:
                // - Camera permissions not granted (most common)
                // - Device doesn't have a torch (e.g., iPad)
                // - Torch hardware is busy or malfunctioning
                // - App launched too early in boot sequence
                //
                // This is not a critical failure - the app remains functional, and users
                // will see permission prompts when starting a session. However, logging here
                // helps diagnose cold-start issues and device-specific problems.
                NSLog("ServiceContainer: Failed to prewarm flashlight: \(error)")
                
                #if DEBUG
                // In debug builds, set a flag that can be observed by diagnostic tools or tests
                // This allows developers to detect prewarm failures without requiring Xcode console
                UserDefaults.standard.set(true, forKey: "lastFlashlightPrewarmFailed")
                UserDefaults.standard.set(error.localizedDescription, forKey: "lastFlashlightPrewarmError")
                UserDefaults.standard.set(Date(), forKey: "lastFlashlightPrewarmErrorTime")
                #endif
            }
        }
    }
}
