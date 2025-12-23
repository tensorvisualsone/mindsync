import Foundation

/// Ein einzelnes Licht-Ereignis in der Sequenz
struct LightEvent: Codable {
    let timestamp: TimeInterval    // Sekunden seit Session-Start
    let intensity: Float           // 0.0 - 1.0
    let duration: TimeInterval     // Wie lange das Licht an bleibt
    let waveform: Waveform         // Form des Lichtsignals
    let color: LightColor?         // Nur für Bildschirm-Modus
    
    init(timestamp: TimeInterval, intensity: Float, duration: TimeInterval, waveform: Waveform, color: LightColor?) {
        self.timestamp = timestamp
        self.intensity = max(0.0, min(1.0, intensity)) // Clamp intensity to valid range
        self.duration = duration
        self.waveform = waveform
        self.color = color
    }

    /// Verfügbare Wellenformen
    enum Waveform: String, Codable {
        case square     // Hartes Ein/Aus (Rechteck)
        case sine       // Sanftes Pulsieren (Sinus)
        case triangle   // Lineares Ein-/Ausblenden
    }

    /// Verfügbare Farben für Bildschirm-Modus
    enum LightColor: String, Codable {
        case white
        case red
        case blue
        case green
        case custom  // Für zukünftige RGB-Zyklen
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
