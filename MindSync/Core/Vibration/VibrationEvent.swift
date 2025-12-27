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
                return "Invalid timestamp: \(value). Timestamp must be >= 0.0 (seconds since session start)."
            case .invalidIntensity(let value):
                return "Invalid intensity: \(value). Intensity must be in range [0.0, 1.0]."
            case .invalidDuration(let value):
                return "Invalid duration: \(value). Duration must be >= 0.0 (seconds)."
            }
        }
    }
    
    /// Initializes a vibration event with input value validation.
    /// - Parameters:
    ///   - timestamp: Seconds since session start (must be >= 0.0)
    ///   - intensity: Intensity between 0.0 and 1.0 (must be in this range)
    ///   - duration: Duration of vibration in seconds (must be >= 0.0)
    ///   - waveform: Waveform of the vibration signal
    /// - Throws: `ValidationError` when values are outside expected bounds
    /// 
    /// **Validation behavior:**
    /// - `timestamp`: Must be >= 0.0 (negative values are invalid)
    /// - `intensity`: Must be in range [0.0, 1.0]
    /// - `duration`: Must be >= 0.0 (negative duration is physically meaningless)
    init(timestamp: TimeInterval, intensity: Float, duration: TimeInterval, waveform: Waveform) throws {
        // Debug assertions to catch issues during development
        #if DEBUG
        assert(timestamp >= 0.0, "VibrationEvent: timestamp must be >= 0.0, got \(timestamp)")
        assert(intensity >= 0.0 && intensity <= 1.0, "VibrationEvent: intensity must be in [0.0, 1.0], got \(intensity)")
        assert(duration >= 0.0, "VibrationEvent: duration must be >= 0.0, got \(duration)")
        #endif
        
        // Validate timestamp: must be non-negative
        guard timestamp >= 0.0 else {
            throw ValidationError.invalidTimestamp(timestamp)
        }
        
        // Validate intensity: must be in range [0.0, 1.0]
        guard intensity >= 0.0 && intensity <= 1.0 else {
            throw ValidationError.invalidIntensity(intensity)
        }
        
        // Validate duration: must be non-negative
        guard duration >= 0.0 else {
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

