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
    
    // Affirmationen
    var selectedAffirmationURL: URL? // URL zum Sprachmemo des Users

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
            selectedAffirmationURL: nil
        )
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
