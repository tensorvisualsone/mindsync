import Foundation

/// Ein einzelnes Vibrations-Ereignis in der Sequenz
struct VibrationEvent: Codable {
    let timestamp: TimeInterval    // Sekunden seit Session-Start
    let intensity: Float           // 0.0 - 1.0
    let duration: TimeInterval     // Wie lange die Vibration aktiv ist
    let waveform: Waveform         // Form des Vibrationssignals
    
    /// Initialisiert ein Vibrations-Ereignis mit Validierung der Eingabewerte.
    /// - Parameters:
    ///   - timestamp: Sekunden seit Session-Start (wird auf >= 0.0 geclammpt)
    ///   - intensity: Intensität zwischen 0.0 und 1.0 (wird auf diesen Bereich geclammpt)
    ///   - duration: Dauer der Vibration in Sekunden (wird auf >= 0.0 geclammpt)
    ///   - waveform: Wellenform des Vibrationssignals
    /// 
    /// **Validierungsverhalten:**
    /// - `intensity`: Wird auf den Bereich [0.0, 1.0] geclammpt
    /// - `duration`: Negative Werte werden auf 0.0 geclammpt (eine negative Dauer ist physikalisch nicht sinnvoll)
    /// - `timestamp`: Negative Werte werden auf 0.0 geclammpt (ein negativer Timestamp würde "vor Session-Start" bedeuten, was in diesem Kontext nicht sinnvoll ist)
    init(timestamp: TimeInterval, intensity: Float, duration: TimeInterval, waveform: Waveform) {
        self.timestamp = max(0.0, timestamp) // Clamp timestamp to non-negative (relative to session start)
        self.intensity = max(0.0, min(1.0, intensity)) // Clamp intensity to valid range [0.0, 1.0]
        self.duration = max(0.0, duration) // Clamp duration to non-negative (negative duration is physically meaningless)
        self.waveform = waveform
    }
    
    // MARK: - Codable
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawTimestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        let rawIntensity = try container.decode(Float.self, forKey: .intensity)
        let rawDuration = try container.decode(TimeInterval.self, forKey: .duration)
        let waveform = try container.decode(Waveform.self, forKey: .waveform)
        
        // Apply same validation as in regular initializer
        self.timestamp = max(0.0, rawTimestamp) // Clamp timestamp to non-negative
        self.intensity = max(0.0, min(1.0, rawIntensity)) // Clamp intensity to valid range [0.0, 1.0]
        self.duration = max(0.0, rawDuration) // Clamp duration to non-negative
        self.waveform = waveform
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(duration, forKey: .duration)
        try container.encode(waveform, forKey: .waveform)
    }
    
    private enum CodingKeys: String, CodingKey {
        case timestamp
        case intensity
        case duration
        case waveform
    }

    /// Verfügbare Wellenformen
    enum Waveform: String, Codable {
        case square     // Hartes Ein/Aus (Rechteck)
        case sine       // Sanftes Pulsieren (Sinus)
        case triangle   // Lineares Ein-/Ausblenden
    }
}

