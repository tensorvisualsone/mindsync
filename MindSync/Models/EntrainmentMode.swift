import Foundation

/// Verfügbare Entrainment-Modi für die Gehirnwellen-Synchronisation
enum EntrainmentMode: String, Codable, CaseIterable, Identifiable {
    case alpha   // Entspannung
    case theta   // Trip / Deep Dive
    case gamma   // Fokus
    case cinematic  // Flow State Sync - Dynamisch & Reaktiv

    var id: String { rawValue }

    /// Menschenlesbarer Name
    var displayName: String {
        let key = "mode.\(rawValue).displayName"
        return NSLocalizedString(key, comment: "Display name for entrainment mode \(rawValue)")
    }

    /// Beschreibung für den Nutzer
    var description: String {
        let key = "mode.\(rawValue).description"
        return NSLocalizedString(key, comment: "Description for entrainment mode \(rawValue)")
    }

    /// Ziel-Frequenzband in Hz
    var frequencyRange: ClosedRange<Double> {
        switch self {
        case .alpha: return 8.0...12.0
        case .theta: return 4.0...8.0
        case .gamma: return 30.0...40.0
        case .cinematic: return 5.5...7.5  // Theta/Low Alpha Flow State
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
        case .cinematic: return "film.fill"
        }
    }
}
