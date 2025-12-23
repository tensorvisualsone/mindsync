import Foundation

/// Manager for thermal monitoring
/// Will be fully implemented in Phase 6 (US6)
final class ThermalManager {
    /// Current thermal state
    var currentState: ProcessInfo.ThermalState {
        ProcessInfo.processInfo.thermalState
    }
    
    /// Maximum allowed flashlight intensity based on thermal state
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
    
    /// Should switch to screen mode?
    var shouldSwitchToScreen: Bool {
        currentState == .serious || currentState == .critical
    }
}

