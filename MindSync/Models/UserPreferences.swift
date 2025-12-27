import Foundation

/// RGB color values for custom color (0.0 - 1.0)
struct CustomColorRGB: Codable {
    let red: Double
    let green: Double
    let blue: Double
    
    init(red: Double, green: Double, blue: Double) {
        self.red = max(0.0, min(1.0, red))
        self.green = max(0.0, min(1.0, green))
        self.blue = max(0.0, min(1.0, blue))
    }
    
    /// Converts to tuple for easier use
    var tuple: (red: Double, green: Double, blue: Double) {
        (red: red, green: green, blue: blue)
    }
}

/// Persistierte Nutzereinstellungen
struct UserPreferences: Codable {
    // Onboarding
    var epilepsyDisclaimerAccepted: Bool
    var epilepsyDisclaimerAcceptedAt: Date?

    // Präferenzen
    var preferredMode: EntrainmentMode
    var preferredLightSource: LightSource
    var defaultIntensity: Float  // 0.0 - 1.0
    var screenColor: LightEvent.LightColor
    var customColorRGB: CustomColorRGB?  // RGB-Werte für Custom Color (0.0 - 1.0)

    // Sicherheit
    var fallDetectionEnabled: Bool
    var thermalProtectionEnabled: Bool
    var maxSessionDuration: TimeInterval?  // nil = unbegrenzt

    // UI
    var hapticFeedbackEnabled: Bool
    
    // Vibration
    var vibrationEnabled: Bool
    private var _vibrationIntensity: Float  // Backing property
    var vibrationIntensity: Float {  // 0.1 - 1.0
        get {
            _vibrationIntensity
        }
        set {
            _vibrationIntensity = max(0.1, min(1.0, newValue))
        }
    }
    
    // Affirmationen
    var selectedAffirmationURL: URL? // URL zum Sprachmemo des Users
    
    // Audio Analysis
    var quickAnalysisEnabled: Bool // Schnellanalyse mit reduzierter Genauigkeit

    // MARK: - Initializers
    
    init(
        epilepsyDisclaimerAccepted: Bool,
        epilepsyDisclaimerAcceptedAt: Date?,
        preferredMode: EntrainmentMode,
        preferredLightSource: LightSource,
        defaultIntensity: Float,
        screenColor: LightEvent.LightColor,
        customColorRGB: CustomColorRGB?,
        fallDetectionEnabled: Bool,
        thermalProtectionEnabled: Bool,
        maxSessionDuration: TimeInterval?,
        hapticFeedbackEnabled: Bool,
        vibrationEnabled: Bool,
        vibrationIntensity: Float,
        selectedAffirmationURL: URL?,
        quickAnalysisEnabled: Bool
    ) {
        self.epilepsyDisclaimerAccepted = epilepsyDisclaimerAccepted
        self.epilepsyDisclaimerAcceptedAt = epilepsyDisclaimerAcceptedAt
        self.preferredMode = preferredMode
        self.preferredLightSource = preferredLightSource
        self.defaultIntensity = defaultIntensity
        self.screenColor = screenColor
        self.customColorRGB = customColorRGB
        self.fallDetectionEnabled = fallDetectionEnabled
        self.thermalProtectionEnabled = thermalProtectionEnabled
        self.maxSessionDuration = maxSessionDuration
        self.hapticFeedbackEnabled = hapticFeedbackEnabled
        self.vibrationEnabled = vibrationEnabled
        self._vibrationIntensity = max(0.1, min(1.0, vibrationIntensity))
        self.selectedAffirmationURL = selectedAffirmationURL
        self.quickAnalysisEnabled = quickAnalysisEnabled
    }

    static var `default`: UserPreferences {
        UserPreferences(
            epilepsyDisclaimerAccepted: false,
            epilepsyDisclaimerAcceptedAt: nil,
            preferredMode: .alpha,
            preferredLightSource: .screen,
            defaultIntensity: 0.5,
            screenColor: .white,
            customColorRGB: nil,
            fallDetectionEnabled: true,
            thermalProtectionEnabled: true,
            maxSessionDuration: nil,
            hapticFeedbackEnabled: true,
            vibrationEnabled: false,
            vibrationIntensity: 0.5,
            selectedAffirmationURL: nil,
            quickAnalysisEnabled: false
        )
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case epilepsyDisclaimerAccepted
        case epilepsyDisclaimerAcceptedAt
        case preferredMode
        case preferredLightSource
        case defaultIntensity
        case screenColor
        case customColorRGB
        case fallDetectionEnabled
        case thermalProtectionEnabled
        case maxSessionDuration
        case hapticFeedbackEnabled
        case vibrationEnabled
        case _vibrationIntensity = "vibrationIntensity"  // Map private property to JSON key "vibrationIntensity"
        case selectedAffirmationURL
        case quickAnalysisEnabled
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        epilepsyDisclaimerAccepted = try container.decode(Bool.self, forKey: .epilepsyDisclaimerAccepted)
        epilepsyDisclaimerAcceptedAt = try container.decodeIfPresent(Date.self, forKey: .epilepsyDisclaimerAcceptedAt)
        preferredMode = try container.decode(EntrainmentMode.self, forKey: .preferredMode)
        preferredLightSource = try container.decode(LightSource.self, forKey: .preferredLightSource)
        defaultIntensity = try container.decode(Float.self, forKey: .defaultIntensity)
        screenColor = try container.decode(LightEvent.LightColor.self, forKey: .screenColor)
        customColorRGB = try container.decodeIfPresent(CustomColorRGB.self, forKey: .customColorRGB)
        fallDetectionEnabled = try container.decode(Bool.self, forKey: .fallDetectionEnabled)
        thermalProtectionEnabled = try container.decode(Bool.self, forKey: .thermalProtectionEnabled)
        maxSessionDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .maxSessionDuration)
        hapticFeedbackEnabled = try container.decode(Bool.self, forKey: .hapticFeedbackEnabled)
        vibrationEnabled = try container.decode(Bool.self, forKey: .vibrationEnabled)
        let decodedIntensity = try container.decode(Float.self, forKey: ._vibrationIntensity)
        _vibrationIntensity = max(0.1, min(1.0, decodedIntensity))  // Clamp during decoding
        selectedAffirmationURL = try container.decodeIfPresent(URL.self, forKey: .selectedAffirmationURL)
        quickAnalysisEnabled = try container.decodeIfPresent(Bool.self, forKey: .quickAnalysisEnabled) ?? false
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(epilepsyDisclaimerAccepted, forKey: .epilepsyDisclaimerAccepted)
        try container.encodeIfPresent(epilepsyDisclaimerAcceptedAt, forKey: .epilepsyDisclaimerAcceptedAt)
        try container.encode(preferredMode, forKey: .preferredMode)
        try container.encode(preferredLightSource, forKey: .preferredLightSource)
        try container.encode(defaultIntensity, forKey: .defaultIntensity)
        try container.encode(screenColor, forKey: .screenColor)
        try container.encodeIfPresent(customColorRGB, forKey: .customColorRGB)
        try container.encode(fallDetectionEnabled, forKey: .fallDetectionEnabled)
        try container.encode(thermalProtectionEnabled, forKey: .thermalProtectionEnabled)
        try container.encodeIfPresent(maxSessionDuration, forKey: .maxSessionDuration)
        try container.encode(hapticFeedbackEnabled, forKey: .hapticFeedbackEnabled)
        try container.encode(vibrationEnabled, forKey: .vibrationEnabled)
        try container.encode(_vibrationIntensity, forKey: ._vibrationIntensity)
        try container.encodeIfPresent(selectedAffirmationURL, forKey: .selectedAffirmationURL)
        try container.encode(quickAnalysisEnabled, forKey: .quickAnalysisEnabled)
    }
    
    // MARK: - Persistence
    
    private static let userDefaultsKey = "userPreferences"
    
    /// Lädt die gespeicherten Präferenzen aus UserDefaults
    static func load() -> UserPreferences {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let preferences = try? JSONDecoder().decode(UserPreferences.self, from: data) else {
            return .default
        }
        return preferences
    }
    
    /// Speichert die aktuellen Präferenzen in UserDefaults
    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: Self.userDefaultsKey)
        }
    }
}
