import Foundation

/// Vollständige Vibrations-Sequenz für einen analysierten Track
struct VibrationScript: Codable, Identifiable {
    let id: UUID
    let trackId: UUID              // Referenz auf AudioTrack
    let mode: EntrainmentMode
    let targetFrequency: Double    // Berechnete Frequenz in Hz
    let multiplier: Int            // BPM-zu-Hz Multiplikator (N)
    let events: [VibrationEvent]
    let createdAt: Date

    init(
        id: UUID = UUID(),
        trackId: UUID,
        mode: EntrainmentMode,
        targetFrequency: Double,
        multiplier: Int,
        events: [VibrationEvent],
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

