import Foundation

/// Ein einzelnes Vibrations-Ereignis in der Sequenz
struct VibrationEvent: Codable {
    let timestamp: TimeInterval    // Sekunden seit Session-Start
    let intensity: Float           // 0.0 - 1.0
    let duration: TimeInterval     // Wie lange die Vibration aktiv ist
    let waveform: Waveform         // Form des Vibrationssignals
    
    init(timestamp: TimeInterval, intensity: Float, duration: TimeInterval, waveform: Waveform) {
        self.timestamp = timestamp
        self.intensity = max(0.0, min(1.0, intensity)) // Clamp intensity to valid range
        self.duration = duration
        self.waveform = waveform
    }

    /// Verfügbare Wellenformen
    enum Waveform: String, Codable {
        case square     // Hartes Ein/Aus (Rechteck)
        case sine       // Sanftes Pulsieren (Sinus)
        case triangle   // Lineares Ein-/Ausblenden
    }
}

