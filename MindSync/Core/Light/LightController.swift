import Foundation

/// Protocol für Licht-Steuerung
protocol LightControlling {
    /// Aktuelle Lichtquelle
    var source: LightSource { get }

    /// Startet die Licht-Ausgabe
    func start() throws

    /// Stoppt die Licht-Ausgabe
    func stop()

    /// Setzt die Intensität (0.0 - 1.0)
    func setIntensity(_ intensity: Float)

    /// Setzt die Farbe (nur für Bildschirm-Modus)
    func setColor(_ color: LightEvent.LightColor)

    /// Führt ein LightScript aus
    /// - Parameter script: Das auszuführende LightScript
    /// - Parameter startTime: Referenz-Zeitpunkt für Synchronisation
    func execute(script: LightScript, syncedTo startTime: Date)

    /// Bricht die aktuelle Ausführung ab
    func cancelExecution()
}

enum LightControlError: Error {
    case torchUnavailable
    case configurationFailed
    case thermalShutdown
}
