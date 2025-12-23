import Foundation

/// Manager für thermisches Monitoring
/// Wird in Phase 6 (US6) vollständig implementiert
final class ThermalManager {
    /// Aktueller thermischer Zustand
    var currentState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }
    
    /// Maximale erlaubte Taschenlampen-Intensität basierend auf thermischem Zustand
    var maxFlashlightIntensity: Float {
        switch currentState {
        case .nominal, .fair:
            return 1.0
        case .serious:
            return 0.5
        case .critical:
            return 0.0
        @unknown default:
            return 0.5
        }
    }
    
    /// Sollte auf Bildschirm-Modus gewechselt werden?
    var shouldSwitchToScreen: Bool {
        currentState == .serious || currentState == .critical
    }
}

