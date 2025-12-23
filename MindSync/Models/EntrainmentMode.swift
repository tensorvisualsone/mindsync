import Foundation

/// Verfügbare Entrainment-Modi für die Gehirnwellen-Synchronisation
enum EntrainmentMode: String, Codable, CaseIterable, Identifiable {
    case alpha   // Entspannung
    case theta   // Trip / Deep Dive
    case gamma   // Fokus

    var id: String { rawValue }

    /// Menschenlesbarer Name
    var displayName: String {
        switch self {
        case .alpha: return "Entspannung"
        case .theta: return "Trip"
        case .gamma: return "Fokus"
        }
    }

    /// Beschreibung für den Nutzer
    var description: String {
        switch self {
        case .alpha:
            return "Entspannte Wachheit, leichte Meditation, Stressabbau"
        case .theta:
            return "Tiefe Meditation, Kreativität, traumähnliche Zustände"
        case .gamma:
            return "Hohe Konzentration, kognitive Klarheit, Einsicht"
        }
    }

    /// Ziel-Frequenzband in Hz
    var frequencyRange: ClosedRange<Double> {
        switch self {
        case .alpha: return 8.0...12.0
        case .theta: return 4.0...8.0
        case .gamma: return 30.0...40.0
        }
    }

    /// Mittlere Zielfrequenz in Hz
    var targetFrequency: Double {
        let range = frequencyRange
        return (range.lowerBound + range.upperBound) / 2.0
    }

    /// SF Symbol Icon
    var iconName: String {
        switch self {
        case .alpha: return "leaf.fill"
        case .theta: return "sparkles"
        case .gamma: return "bolt.fill"
        }
    }
}
