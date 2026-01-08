import Foundation

/// Verfügbare Audio-Eingabequellen
enum AudioSource: String, Codable {
    case localFile   // Lokale Musikbibliothek
    case microphone  // Echtzeit-Mikrofon
}

/// Verfügbare Lichtquellen für das Stroboskop
enum LightSource: String, Codable, CaseIterable, Identifiable {
    case flashlight  // Taschenlampe (LED Flash)

    var id: String { rawValue }

    var displayName: String {
        return "Taschenlampe"
    }

    var description: String {
        return "Intensiver Impuls. Unterstützt bis zu 100 Hz (Lambda)."
    }

    /// Maximale zuverlässige Frequenz in Hz
    var maxFrequency: Double {
        return 100.0
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
    
    // Custom decoder to handle migration from older versions that had .screen case
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(UUID.self, forKey: .id)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        mode = try container.decode(EntrainmentMode.self, forKey: .mode)
        audioSource = try container.decode(AudioSource.self, forKey: .audioSource)
        trackTitle = try container.decodeIfPresent(String.self, forKey: .trackTitle)
        trackArtist = try container.decodeIfPresent(String.self, forKey: .trackArtist)
        trackBPM = try container.decodeIfPresent(Double.self, forKey: .trackBPM)
        actualDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .actualDuration)
        averageIntensity = try container.decodeIfPresent(Float.self, forKey: .averageIntensity)
        thermalWarningOccurred = try container.decode(Bool.self, forKey: .thermalWarningOccurred)
        manuallyPaused = try container.decode(Bool.self, forKey: .manuallyPaused)
        endReason = try container.decodeIfPresent(EndReason.self, forKey: .endReason)
        
        // Migrate old .screen values to .flashlight for backward compatibility
        if let lightSourceString = try? container.decode(String.self, forKey: .lightSource) {
            if lightSourceString == "screen" {
                // Legacy .screen case - migrate to .flashlight
                lightSource = .flashlight
            } else if let decoded = LightSource(rawValue: lightSourceString) {
                lightSource = decoded
            } else {
                // Unknown value - default to flashlight
                lightSource = .flashlight
            }
        } else {
            // Fallback if decoding fails
            lightSource = .flashlight
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, startedAt, endedAt, mode, lightSource, audioSource
        case trackTitle, trackArtist, trackBPM
        case actualDuration, averageIntensity, thermalWarningOccurred, manuallyPaused, endReason
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
