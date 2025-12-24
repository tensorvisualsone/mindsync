import Foundation
import Combine
import os.log

/// Thermal warning level for UI display
enum ThermalWarningLevel: Equatable {
    case none
    case reduced       // Intensity reduced (serious)
    case critical      // Flashlight disabled (critical)
    
    var message: String? {
        switch self {
        case .none:
            return nil
        case .reduced:
            return "Intensität reduziert wegen Gerätewärme"
        case .critical:
            return "Taschenlampe deaktiviert – zu heiß"
        }
    }
    
    var icon: String {
        switch self {
        case .none:
            return ""
        case .reduced:
            return "thermometer.medium"
        case .critical:
            return "thermometer.high"
        }
    }
}

/// Evaluates the current thermal state and derives safe flashlight intensity and screen fallback behavior.
final class ThermalManager: ObservableObject {
    /// Published thermal warning level for UI binding
    @Published private(set) var warningLevel: ThermalWarningLevel = .none
    
    /// Published thermal state for reactive updates
    @Published private(set) var thermalState: ProcessInfo.ThermalState = .nominal
    
    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.mindsync", category: "ThermalManager")
    
    init() {
        // Initial state
        updateThermalState()
        
        // Observe thermal state changes
        NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateThermalState()
            }
            .store(in: &cancellables)
        
        logger.info("ThermalManager initialized, current state: \(String(describing: self.thermalState), privacy: .public)")
    }
    
    /// Updates the thermal state and warning level
    private func updateThermalState() {
        let previousState = self.thermalState
        self.thermalState = ProcessInfo.processInfo.thermalState
        self.warningLevel = calculateWarningLevel(for: self.thermalState)
        
        // Log state changes
        if previousState != self.thermalState {
            logger.info("Thermal state changed: \(String(describing: previousState), privacy: .public) -> \(String(describing: self.thermalState), privacy: .public), warning level: \(String(describing: self.warningLevel), privacy: .public)")
            
            // Log warnings for serious/critical states
            if self.warningLevel == .reduced {
                logger.warning("Thermal state serious - reducing flashlight intensity")
            } else if self.warningLevel == .critical {
                logger.error("Thermal state critical - flashlight should be disabled")
            }
        }
    }
    
    /// Calculates warning level from thermal state
    private func calculateWarningLevel(for state: ProcessInfo.ThermalState) -> ThermalWarningLevel {
        switch state {
        case .nominal, .fair:
            return .none
        case .serious:
            return .reduced
        case .critical:
            return .critical
        @unknown default:
            return .reduced
        }
    }
    
    /// Current thermal state (computed for backwards compatibility)
    var currentState: ProcessInfo.ThermalState {
        thermalState
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

