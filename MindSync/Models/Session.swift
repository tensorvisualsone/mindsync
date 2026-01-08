import Foundation

/// Verfügbare Audio-Eingabequellen
enum AudioSource: String, Codable {
    case localFile   // Lokale Musikbibliothek
    case microphone  // Echtzeit-Mikrofon
}

/// Verfügbare Lichtquellen für das Stroboskop
enum LightSource: String, Codable, CaseIterable, Identifiable {
    case flashlight  // Taschenlampe (LED Flash)
    case screen      // Bildschirm (OLED)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .flashlight: return "Taschenlampe"
        case .screen: return "Bildschirm"
        }
    }

    var description: String {
        switch self {
        case .flashlight:
            return "Intensiver Impuls. Unterstützt bis zu 100 Hz (Lambda)."
        case .screen:
            return "Präziser, mit Farben. Für längere Sitzungen geeignet."
        }
    }

    /// Maximale zuverlässige Frequenz in Hz
    var maxFrequency: Double {
        switch self {
        case .flashlight: return 100.0
        case .screen: return 60.0 // Kann bis 120 Hz bei ProMotion
        }
    }
}

/// Eine Stroboskop-Sitzung (laufend oder abgeschlossen)
struct Session: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?

    // Konfiguration
    let mode: EntrainmentMode
    let lightSource: LightSource
    let audioSource: AudioSource

    // Track-Info (optional für Mikrofon-Modus)
    let trackTitle: String?
    let trackArtist: String?
    let trackBPM: Double?

    // Laufzeit-Statistiken
    var actualDuration: TimeInterval?
    var averageIntensity: Float?
    var thermalWarningOccurred: Bool
    var manuallyPaused: Bool
    var endReason: EndReason?

    enum EndReason: String, Codable {
        case userStopped        // Nutzer hat gestoppt
        case trackEnded         // Song zu Ende
        case thermalShutdown    // Überhitzung
        case fallDetected       // Gerät gefallen
        case phoneCall          // Anruf eingegangen
        case appBackgrounded    // App in Hintergrund
    }

    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        mode: EntrainmentMode,
        lightSource: LightSource,
        audioSource: AudioSource,
        trackTitle: String? = nil,
        trackArtist: String? = nil,
        trackBPM: Double? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = nil
        self.mode = mode
        self.lightSource = lightSource
        self.audioSource = audioSource
        self.trackTitle = trackTitle
        self.trackArtist = trackArtist
        self.trackBPM = trackBPM
        self.actualDuration = nil
        self.averageIntensity = nil
        self.thermalWarningOccurred = false
        self.manuallyPaused = false
        self.endReason = nil
    }

    /// Berechnet Dauer basierend auf Start/Ende
    var duration: TimeInterval {
        actualDuration ?? (endedAt ?? Date()).timeIntervalSince(startedAt)
    }

    /// Formatierte Dauer
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Ist die Session noch aktiv?
    var isActive: Bool { endedAt == nil }
}
