import Foundation

/// Verfügbare Entrainment-Modi für die Gehirnwellen-Synchronisation
enum EntrainmentMode: String, Codable, CaseIterable, Identifiable {
    case alpha   // Entspannung
    case theta   // Trip / Deep Dive
    case gamma   // Fokus
    case cinematic  // Flow State Sync - Dynamisch & Reaktiv
    case dmnShutdown  // Ego-Dissolution: DMN-Deaktivierung für transzendente Zustände
    case beliefRewiring  // Belief-Rewiring: Glaubenssätze umprogrammieren durch Theta-Open und Gamma-Sync

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
        case .dmnShutdown: return 4.5...40.0  // Spans alle Phasen (Theta bis Gamma)
        case .beliefRewiring: return 5.0...40.0  // Spans alle Phasen (Theta bis Gamma)
        }
    }

    /// Mittlere Zielfrequenz in Hz
    var targetFrequency: Double {
        switch self {
        case .gamma:
            // 40 Hz ist der wissenschaftliche Goldstandard für Gamma-Entrainment
            // MIT-Studien zeigen maximale kognitive Verbesserung bei exakt 40 Hz
            return 40.0
        case .dmnShutdown:
            // 40 Hz Gamma-Peak für Phase 3 (THE VOID)
            return 40.0
        case .beliefRewiring:
            // 40 Hz Gamma-Peak für Phase 3 (THE REWIRE-BURST)
            return 40.0
        default:
            let range = frequencyRange
            return (range.lowerBound + range.upperBound) / 2.0
        }
    }

    /// Startfrequenz (welche Frequenz nehmen wir als Ausgangspunkt beim Ramping)
    /// Standardmäßig nehmen wir eine typische Beta-Range, damit der Ramp den Nutzer "abholt".
    var startFrequency: Double {
        switch self {
        case .alpha: return 15.0
        case .theta: return 16.0
        case .gamma: return 12.0
        case .cinematic: return 18.0
        case .dmnShutdown: return 10.0  // Phase 1 Start: 10Hz Alpha
        case .beliefRewiring: return 12.0  // Phase 1 Start: 12Hz Alpha
        }
    }

    /// Dauer des Ramp-Vorgangs in Sekunden. Nach Ablauf bleibt die Ziel-Frequenz erhalten.
    var rampDuration: TimeInterval {
        switch self {
        case .alpha: return 180.0   // 3 Minuten
        case .theta: return 180.0   // 3 Minuten
        case .gamma: return 120.0   // 2 Minuten (schneller Hochfahren)
        case .cinematic: return 180.0
        case .dmnShutdown: return 240.0  // 4 Minuten (Phase 1: DISCONNECT)
        case .beliefRewiring: return 240.0  // 4 Minuten (Phase 1: THE SOFT-OPEN)
        }
    }

    /// SF Symbol Icon
    var iconName: String {
        switch self {
        case .alpha: return "leaf.fill"
        case .theta: return "sparkles"
        case .gamma: return "bolt.fill"
        case .cinematic: return "film.fill"
        case .dmnShutdown: return "moon.stars.fill"  // Spiritueller/transzendenter Zustand
        case .beliefRewiring: return "brain.head.profile"  // Belief-Rewiring / Mind-Programming
        }
    }
    
    /// Indicates whether this mode uses a fixed script with frequencyOverride.
    /// Fixed-script modes don't need audio reactivity (spectral flux tracking).
    var usesFixedScript: Bool {
        switch self {
        case .alpha, .theta, .gamma, .dmnShutdown, .beliefRewiring:
            return true
        case .cinematic:
            return false
        }
    }
    
    /// Returns the default audio file name for fixed-script modes.
    /// Returns nil for modes that require user-selected audio (e.g., cinematic).
    var defaultAudioFileName: String? {
        switch self {
        case .alpha:
            return "alpha_audio.mp3"
        case .theta:
            return "theta_audio.mp3"
        case .gamma:
            return "gamma_audio.mp3"
        case .dmnShutdown:
            return "void_master.mp3"
        case .beliefRewiring:
            return "belief_rewiring_audio.mp3"
        case .cinematic:
            return nil // Requires user-selected audio
        }
    }
}
