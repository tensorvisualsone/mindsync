import Foundation

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

    // Sicherheit
    var fallDetectionEnabled: Bool
    var thermalProtectionEnabled: Bool
    var maxSessionDuration: TimeInterval?  // nil = unbegrenzt

    // UI
    var hapticFeedbackEnabled: Bool

    static var `default`: UserPreferences {
        UserPreferences(
            epilepsyDisclaimerAccepted: false,
            epilepsyDisclaimerAcceptedAt: nil,
            preferredMode: .alpha,
            preferredLightSource: .screen,
            defaultIntensity: 0.5,
            screenColor: .white,
            fallDetectionEnabled: true,
            thermalProtectionEnabled: true,
            maxSessionDuration: nil,
            hapticFeedbackEnabled: true
        )
    }
}
