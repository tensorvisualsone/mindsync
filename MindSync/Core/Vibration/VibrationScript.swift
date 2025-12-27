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

