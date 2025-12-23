import Foundation

/// Thermischer Zustand des Geräts
enum ThermalState: Int, Comparable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3

    static func < (lhs: ThermalState, rhs: ThermalState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// Empfohlene maximale Taschenlampen-Intensität
    var maxFlashlightIntensity: Float {
        switch self {
        case .nominal: return 1.0
        case .fair: return 0.7
        case .serious: return 0.3
        case .critical: return 0.0
        }
    }

    /// Sollte auf Bildschirm gewechselt werden?
    var shouldSwitchToScreen: Bool {
        self >= .serious
    }
}

/// Sicherheitskonstanten (nicht veränderbar)
enum SafetyLimits {
    /// PSE-Gefahrenzone (Hz).
    /// Literatur nennt typischerweise einen Haupt-Risikobereich von ca. 15–25 Hz
    /// (mit besonderer Sensitivität um 20 Hz). Wir verwenden hier bewusst einen
    /// konservativen Bereich von 3–30 Hz, um die Gefahrenspanne eher zu über‑
    /// approximieren als zu unterschätzen und die Logik der Sicherheitsprüfungen
    /// zu vereinfachen. Bei neuen klinischen Leitlinien sollten diese Werte
    /// entsprechend überprüft werden.
    static let pseMinFrequency: Double = 3.0
    static let pseMaxFrequency: Double = 30.0

    /// Harte Frequenzgrenzen (Hz)
    static let absoluteMinFrequency: Double = 1.0
    static let absoluteMaxFrequency: Double = 60.0

    /// Taschenlampen-Grenzen
    static let flashlightMaxFrequency: Double = 30.0
    static let flashlightMaxSustainedIntensity: Float = 0.5

    /// Fall-Erkennung
    static let fallAccelerationThreshold: Double = 2.0  // g
    static let freefallThreshold: Double = 0.3  // g

    /// Session-Grenzen
    static let flashlightMaxDuration: TimeInterval = 15 * 60  // 15 Min
}
