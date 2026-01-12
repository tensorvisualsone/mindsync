import Foundation

/// A single vibration event in the sequence
struct VibrationEvent: Codable {
    let timestamp: TimeInterval    // Seconds since session start
    let intensity: Float           // 0.0 - 1.0
    let duration: TimeInterval     // How long the vibration is active
    let waveform: Waveform         // Form of the vibration signal
    
    /// Validation error for invalid VibrationEvent parameters
    enum ValidationError: Error {
        case invalidTimestamp(TimeInterval)
        case invalidIntensity(Float)
        case invalidDuration(TimeInterval)
        
        var localizedDescription: String {
            switch self {
            case .invalidTimestamp(let value):
                return "Invalid timestamp: \(value). Timestamp must be finite and >= 0.0 (seconds since session start)."
            case .invalidIntensity(let value):
                return "Invalid intensity: \(value). Intensity must be finite and in range [0.0, 1.0]."
            case .invalidDuration(let value):
                return "Invalid duration: \(value). Duration must be finite and >= 0.0 (seconds)."
            }
        }
    }
    
    /// Initializes a vibration event with input value validation.
    /// - Parameters:
    ///   - timestamp: Seconds since session start (must be finite and >= 0.0)
    ///   - intensity: Intensity between 0.0 and 1.0 (must be finite and in this range)
    ///   - duration: Duration of vibration in seconds (must be finite and >= 0.0)
    ///   - waveform: Waveform of the vibration signal
    /// - Throws: `ValidationError` when values are outside expected bounds
    /// 
    /// **Validation behavior:**
    /// - `timestamp`: Must be finite and >= 0.0 (negative values, infinity, and NaN are invalid)
    /// - `intensity`: Must be finite and in range [0.0, 1.0] (infinity and NaN are invalid)
    /// - `duration`: Must be finite and >= 0.0 (negative duration, infinity, and NaN are physically meaningless)
    nonisolated init(timestamp: TimeInterval, intensity: Float, duration: TimeInterval, waveform: Waveform) throws {
        // Validate timestamp: must be finite and non-negative
        guard timestamp.isFinite && timestamp >= 0.0 else {
            throw ValidationError.invalidTimestamp(timestamp)
        }
        
        // Validate intensity: must be finite and in range [0.0, 1.0]
        guard intensity.isFinite && intensity >= 0.0 && intensity <= 1.0 else {
            throw ValidationError.invalidIntensity(intensity)
        }
        
        // Validate duration: must be finite and non-negative
        guard duration.isFinite && duration >= 0.0 else {
            throw ValidationError.invalidDuration(duration)
        }
        
        // All values are valid, assign directly
        self.timestamp = timestamp
        self.intensity = intensity
        self.duration = duration
        self.waveform = waveform
    }
    
    // MARK: - Codable
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Decode raw values
        let rawTimestamp = try container.decode(TimeInterval.self, forKey: .timestamp)
        let rawIntensity = try container.decode(Float.self, forKey: .intensity)
        let rawDuration = try container.decode(TimeInterval.self, forKey: .duration)
        let waveform = try container.decode(Waveform.self, forKey: .waveform)
        
        // Use the throwing initializer for validation, converting ValidationError to DecodingError
        do {
            try self.init(
                timestamp: rawTimestamp,
                intensity: rawIntensity,
                duration: rawDuration,
                waveform: waveform
            )
        } catch let validationError as ValidationError {
            // Map ValidationError to DecodingError with appropriate coding path
            let fieldKey: CodingKeys
            let debugDescription: String
            
            switch validationError {
            case .invalidTimestamp:
                fieldKey = .timestamp
                debugDescription = validationError.localizedDescription
            case .invalidIntensity:
                fieldKey = .intensity
                debugDescription = validationError.localizedDescription
            case .invalidDuration:
                fieldKey = .duration
                debugDescription = validationError.localizedDescription
            }
            
            let context = DecodingError.Context(
                codingPath: decoder.codingPath + [fieldKey],
                debugDescription: debugDescription,
                underlyingError: validationError
            )
            throw DecodingError.dataCorrupted(context)
        }
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

    /// Available waveforms
    enum Waveform: String, Codable {
        case square     // Hard on/off (rectangle)
        case sine       // Soft pulsing (sine)
        case triangle   // Linear fade in/out
    }
}

