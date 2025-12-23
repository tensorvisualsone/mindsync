import Foundation

/// Platzhalter für Bildschirm-Stroboskop-Steuerung
/// Wird in Phase 7 (US5) implementiert
final class ScreenController: LightControlling {
    var source: LightSource { .screen }
    
    func start() throws {
        // TODO: Phase 7 implementieren
    }
    
    func stop() {
        // TODO: Phase 7 implementieren
    }
    
    func setIntensity(_ intensity: Float) {
        // TODO: Phase 7 implementieren
    }
    
    func setColor(_ color: LightEvent.LightColor) {
        // TODO: Phase 7 implementieren
    }
    
    func execute(script: LightScript, syncedTo startTime: Date) {
        // TODO: Phase 7 implementieren
    }
    
    func cancelExecution() {
        // TODO: Phase 7 implementieren
    }
}
