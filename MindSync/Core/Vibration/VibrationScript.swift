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

    nonisolated init(
        id: UUID = UUID(),
        trackId: UUID,
        mode: EntrainmentMode,
        targetFrequency: Double,
        multiplier: Int,
        events: [VibrationEvent],
        createdAt: Date = Date()
    ) throws {
        // Validate targetFrequency: must be finite and positive
        guard targetFrequency.isFinite && targetFrequency > 0 else {
            throw VibrationScriptError.invalidTargetFrequency(targetFrequency)
        }
        
        // Validate multiplier: must be positive
        guard multiplier > 0 else {
            throw VibrationScriptError.invalidMultiplier(multiplier)
        }
        
        self.id = id
        self.trackId = trackId
        self.mode = mode
        self.targetFrequency = targetFrequency
        self.multiplier = multiplier
        self.events = events
        self.createdAt = createdAt
    }
    
    // MARK: - Codable
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode all properties
        let id = try container.decode(UUID.self, forKey: .id)
        let trackId = try container.decode(UUID.self, forKey: .trackId)
        let mode = try container.decode(EntrainmentMode.self, forKey: .mode)
        let targetFrequency = try container.decode(Double.self, forKey: .targetFrequency)
        let multiplier = try container.decode(Int.self, forKey: .multiplier)
        let events = try container.decode([VibrationEvent].self, forKey: .events)
        let createdAt = try container.decode(Date.self, forKey: .createdAt)
        
        // Call the throwing initializer to run validation
        try self.init(
            id: id,
            trackId: trackId,
            mode: mode,
            targetFrequency: targetFrequency,
            multiplier: multiplier,
            events: events,
            createdAt: createdAt
        )
    }
    
    // Encodable synthesis is used (default implementation)
    
    private enum CodingKeys: String, CodingKey {
        case id
        case trackId
        case mode
        case targetFrequency
        case multiplier
        case events
        case createdAt
    }

    /// Gesamtdauer in Sekunden (berechnet aus dem Maximum von timestamp + duration über alle Events)
    var duration: TimeInterval {
        events.map { $0.timestamp + $0.duration }.max() ?? 0
    }

    /// Anzahl der Events
    var eventCount: Int { events.count }
}

// MARK: - VibrationScript Errors

enum VibrationScriptError: Error {
    case invalidTargetFrequency(Double)
    case invalidMultiplier(Int)
}

extension VibrationScriptError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .invalidTargetFrequency(let frequency):
            return String(format: NSLocalizedString("error.vibrationScript.invalidTargetFrequency", comment: ""), frequency)
        case .invalidMultiplier(let multiplier):
            return String(format: NSLocalizedString("error.vibrationScript.invalidMultiplier", comment: ""), multiplier)
        }
    }
}

