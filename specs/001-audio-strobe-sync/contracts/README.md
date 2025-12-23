# Contracts: MindSync Core App

**Feature**: 001-audio-strobe-sync  
**Date**: 2025-12-23

## Overview

Dieses Verzeichnis enthält die Service-Protokolle (Contracts) für MindSync. Diese definieren die Schnittstellen zwischen den Modulen und ermöglichen Testbarkeit durch Dependency Injection.

---

## Core Protocols

### AudioAnalyzing

```swift
/// Protocol für Audio-Analyse-Services
protocol AudioAnalyzing {
    /// Analysiert einen lokalen Audio-Track
    /// - Parameter url: URL der lokalen Audio-Datei
    /// - Returns: Analysierter AudioTrack mit Beat-Map
    /// - Throws: AudioAnalysisError
    func analyze(url: URL) async throws -> AudioTrack
    
    /// Fortschritts-Publisher für UI-Updates
    var progressPublisher: AnyPublisher<AnalysisProgress, Never> { get }
    
    /// Bricht die laufende Analyse ab
    func cancel()
}

enum AudioAnalysisError: Error, LocalizedError {
    case fileNotFound
    case drmProtected
    case unsupportedFormat
    case analysisFailure(underlying: Error)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "Audio-Datei nicht gefunden"
        case .drmProtected: return "DRM-geschützte Datei kann nicht analysiert werden"
        case .unsupportedFormat: return "Audio-Format wird nicht unterstützt"
        case .analysisFailure(let e): return "Analyse fehlgeschlagen: \(e.localizedDescription)"
        case .cancelled: return "Analyse abgebrochen"
        }
    }
}
```

### MicrophoneAnalyzing

```swift
/// Protocol für Echtzeit-Mikrofon-Analyse
protocol MicrophoneAnalyzing {
    /// Startet die Mikrofon-Analyse
    /// - Returns: AsyncStream von Beat-Events
    func startListening() -> AsyncStream<BeatEvent>
    
    /// Stoppt die Mikrofon-Analyse
    func stopListening()
    
    /// Aktuelles geschätztes Tempo
    var currentBPM: Double? { get }
    
    /// Aktuelle RMS-Energie (0.0 - 1.0)
    var currentEnergy: Float { get }
}

struct BeatEvent {
    let timestamp: Date
    let intensity: Float  // 0.0 - 1.0
    let isOnBeat: Bool
}
```

### LightControlling

```swift
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
```

### EntrainmentCalculating

```swift
/// Protocol für Entrainment-Berechnungen
protocol EntrainmentCalculating {
    /// Generiert ein LightScript aus einem AudioTrack
    /// - Parameters:
    ///   - track: Der analysierte Audio-Track
    ///   - mode: Der gewünschte Entrainment-Modus
    /// - Returns: Das generierte LightScript
    func generateScript(for track: AudioTrack, mode: EntrainmentMode) -> LightScript
    
    /// Berechnet den optimalen Multiplikator
    /// - Parameters:
    ///   - bpm: Das Tempo des Songs
    ///   - targetBand: Das Ziel-Frequenzband
    /// - Returns: Der ganzzahlige Multiplikator N
    func calculateMultiplier(bpm: Double, targetBand: ClosedRange<Double>) -> Int
    
    /// Berechnet die Ziel-Frequenz
    /// - Parameters:
    ///   - bpm: Das Tempo des Songs
    ///   - multiplier: Der Multiplikator N
    /// - Returns: Die Frequenz in Hz
    func calculateFrequency(bpm: Double, multiplier: Int) -> Double
}
```

### ThermalMonitoring

```swift
/// Protocol für thermische Überwachung
protocol ThermalMonitoring {
    /// Aktueller thermischer Zustand
    var currentState: ThermalState { get }
    
    /// Publisher für Zustandsänderungen
    var statePublisher: AnyPublisher<ThermalState, Never> { get }
    
    /// Empfohlene maximale Intensität für aktuelle Temperatur
    var recommendedMaxIntensity: Float { get }
    
    /// Sollte die Session beendet werden?
    var shouldStopSession: Bool { get }
}
```

### FallDetecting

```swift
/// Protocol für Fall-Erkennung
protocol FallDetecting {
    /// Startet die Überwachung
    func startMonitoring()
    
    /// Stoppt die Überwachung
    func stopMonitoring()
    
    /// Publisher für Fall-Events
    var fallDetectedPublisher: AnyPublisher<Void, Never> { get }
    
    /// Ist die Erkennung aktiv?
    var isMonitoring: Bool { get }
}
```

### SessionManaging

```swift
/// Protocol für Session-Verwaltung
protocol SessionManaging {
    /// Startet eine neue Session
    func startSession(config: SessionConfiguration) -> Session
    
    /// Beendet die aktuelle Session
    func endSession(reason: Session.EndReason)
    
    /// Pausiert die aktuelle Session
    func pauseSession()
    
    /// Setzt die pausierte Session fort
    func resumeSession()
    
    /// Aktuelle Session (nil wenn keine aktiv)
    var currentSession: Session? { get }
    
    /// Session-Historie
    func getHistory(limit: Int) -> [Session]
}

struct SessionConfiguration {
    let mode: EntrainmentMode
    let lightSource: LightSource
    let audioSource: AudioSource
    let track: AudioTrack?  // nil für Mikrofon-Modus
    let script: LightScript?
}
```

### MediaLibraryAccessing

```swift
/// Protocol für Musikbibliothek-Zugriff
protocol MediaLibraryAccessing {
    /// Zeigt den Song-Picker an
    /// - Returns: Ausgewähltes MPMediaItem oder nil
    func pickSong() async -> MPMediaItem?
    
    /// Prüft ob ein Item analysierbar ist (nicht DRM-geschützt)
    func canAnalyze(item: MPMediaItem) -> Bool
    
    /// Holt die Asset-URL für ein Item
    func getAssetURL(for item: MPMediaItem) -> URL?
    
    /// Autorisierungsstatus
    var authorizationStatus: MPMediaLibraryAuthorizationStatus { get }
    
    /// Fordert Berechtigung an
    func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus
}
```

### PermissionsChecking

```swift
/// Protocol für Berechtigungs-Prüfung
protocol PermissionsChecking {
    /// Mikrofon-Berechtigung
    var microphoneStatus: AVAudioSession.RecordPermission { get }
    
    /// Musikbibliothek-Berechtigung
    var mediaLibraryStatus: MPMediaLibraryAuthorizationStatus { get }
    
    /// Fordert Mikrofon-Berechtigung an
    func requestMicrophoneAccess() async -> Bool
    
    /// Fordert Musikbibliothek-Berechtigung an
    func requestMediaLibraryAccess() async -> MPMediaLibraryAuthorizationStatus
}
```

---

## Dependency Injection

Alle Services werden über einen zentralen Container injiziert:

```swift
@MainActor
final class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()
    
    lazy var audioAnalyzer: AudioAnalyzing = AudioAnalyzer()
    lazy var microphoneAnalyzer: MicrophoneAnalyzing = MicrophoneAnalyzer()
    lazy var entrainmentEngine: EntrainmentCalculating = EntrainmentEngine()
    lazy var thermalMonitor: ThermalMonitoring = ThermalManager()
    lazy var fallDetector: FallDetecting = FallDetector()
    lazy var sessionManager: SessionManaging = SessionHistoryService()
    lazy var mediaLibrary: MediaLibraryAccessing = MediaLibraryService()
    lazy var permissions: PermissionsChecking = PermissionsService()
    
    // Für Tests: Erlaube Mock-Injection
    func register<T>(service: T) {
        // ...
    }
}
```

---

## Testing

Alle Protocols ermöglichen einfaches Mocking:

```swift
// Beispiel: Mock für AudioAnalyzer
class MockAudioAnalyzer: AudioAnalyzing {
    var mockResult: AudioTrack?
    var mockError: AudioAnalysisError?
    
    func analyze(url: URL) async throws -> AudioTrack {
        if let error = mockError { throw error }
        return mockResult ?? AudioTrack(...)
    }
    
    // ...
}
```

---

**Contracts Version**: 1.0.0 | **Status**: Draft

