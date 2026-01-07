import Foundation

/// Ein einzelnes Licht-Ereignis in der Sequenz
struct LightEvent: Codable {
    let timestamp: TimeInterval    // Sekunden seit Session-Start
    let intensity: Float           // 0.0 - 1.0
    let duration: TimeInterval     // Wie lange das Licht an bleibt
    let waveform: Waveform         // Form des Lichtsignals
    let color: LightColor?         // Nur für Bildschirm-Modus
    
    /// Optional: Allows specific events to override the global session frequency.
    /// Crucial for "Awakening Flows" that change frequency over time (e.g. Ramp -> Theta -> Gamma).
    let frequencyOverride: Double?
    
    init(timestamp: TimeInterval, intensity: Float, duration: TimeInterval, waveform: Waveform, color: LightColor?, frequencyOverride: Double? = nil) {
        self.timestamp = timestamp
        self.intensity = max(0.0, min(1.0, intensity)) // Clamp intensity to valid range
        self.duration = duration
        self.waveform = waveform
        self.color = color
        self.frequencyOverride = frequencyOverride
    }

    /// Verfügbare Wellenformen
    enum Waveform: String, Codable {
        case square     // Hartes Ein/Aus (Rechteck)
        case sine       // Sanftes Pulsieren (Sinus)
        case triangle   // Lineares Ein-/Ausblenden
    }

    /// Verfügbare Farben für Bildschirm-Modus
    enum LightColor: String, Codable, CaseIterable, Identifiable {
        case white
        case red
        case blue
        case green
        case purple
        case orange
        case custom  // Für zukünftige RGB-Zyklen
        
        var id: String { rawValue }
        
        /// German display name for the UI (project uses German for user-facing strings)
        var displayName: String {
            switch self {
            case .white: return "Weiß"
            case .red: return "Rot"
            case .blue: return "Blau"
            case .green: return "Grün"
            case .purple: return "Lila"
            case .orange: return "Orange"
            case .custom: return "Eigene Farbe"
            }
        }
    }
}

/// Vollständige Licht-Sequenz für einen analysierten Track
struct LightScript: Codable, Identifiable {
    let id: UUID
    let trackId: UUID              // Referenz auf AudioTrack
    let mode: EntrainmentMode
    let targetFrequency: Double    // Berechnete Frequenz in Hz
    let multiplier: Int            // BPM-zu-Hz Multiplikator (N)
    let events: [LightEvent]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        trackId: UUID,
        mode: EntrainmentMode,
        targetFrequency: Double,
        multiplier: Int,
        events: [LightEvent],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.trackId = trackId
        self.mode = mode
        self.targetFrequency = targetFrequency
        self.multiplier = multiplier
        self.events = events
        self.createdAt = createdAt
    }

    /// Gesamtdauer in Sekunden
    var duration: TimeInterval {
        events.last.map { $0.timestamp + $0.duration } ?? 0
    }

    /// Anzahl der Events
    var eventCount: Int { events.count }
}
