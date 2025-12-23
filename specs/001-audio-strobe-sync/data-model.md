# Data Model: MindSync Core App

**Feature**: 001-audio-strobe-sync  
**Date**: 2025-12-23  
**Plan**: [plan.md](./plan.md)

## Overview

Dieses Dokument definiert die Datenstrukturen für MindSync in Swift. Alle Models sind als `struct` mit `Codable`-Konformität implementiert für einfache Persistenz.

---

## Core Entities

### 1. EntrainmentMode

Definiert die verfügbaren Gehirnwellen-Zielzustände.

```swift
/// Verfügbare Entrainment-Modi für die Gehirnwellen-Synchronisation
enum EntrainmentMode: String, Codable, CaseIterable, Identifiable {
    case alpha   // Entspannung
    case theta   // Trip / Deep Dive
    case gamma   // Fokus
    
    var id: String { rawValue }
    
    /// Menschenlesbarer Name
    var displayName: String {
        switch self {
        case .alpha: return "Entspannung"
        case .theta: return "Trip"
        case .gamma: return "Fokus"
        }
    }
    
    /// Beschreibung für den Nutzer
    var description: String {
        switch self {
        case .alpha: return "Entspannte Wachheit, leichte Meditation, Stressabbau"
        case .theta: return "Tiefe Meditation, Kreativität, Traum-ähnliche Zustände"
        case .gamma: return "Hohe Konzentration, kognitive Klarheit, Einsicht"
        }
    }
    
    /// Ziel-Frequenzband in Hz
    var frequencyRange: ClosedRange<Double> {
        switch self {
        case .alpha: return 8.0...12.0
        case .theta: return 4.0...8.0
        case .gamma: return 30.0...40.0
        }
    }
    
    /// Mittlere Zielfrequenz in Hz
    var targetFrequency: Double {
        let range = frequencyRange
        return (range.lowerBound + range.upperBound) / 2.0
    }
    
    /// SF Symbol Icon
    var iconName: String {
        switch self {
        case .alpha: return "leaf.fill"
        case .theta: return "sparkles"
        case .gamma: return "bolt.fill"
        }
    }
}
```

### 2. LightSource

Definiert die verfügbaren Lichtquellen.

```swift
/// Verfügbare Lichtquellen für das Stroboskop
enum LightSource: String, Codable, CaseIterable, Identifiable {
    case flashlight  // Taschenlampe (LED Flash)
    case screen      // Bildschirm (OLED)
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .flashlight: return "Taschenlampe"
        case .screen: return "Bildschirm"
        }
    }
    
    var description: String {
        switch self {
        case .flashlight: return "Heller, für geschlossene Augen. Max. 15 Min empfohlen."
        case .screen: return "Präziser, mit Farben. Für längere Sitzungen geeignet."
        }
    }
    
    /// Maximale zuverlässige Frequenz in Hz
    var maxFrequency: Double {
        switch self {
        case .flashlight: return 30.0
        case .screen: return 60.0  // Kann bis 120 Hz bei ProMotion
        }
    }
}
```

### 3. AudioSource

Definiert die Audio-Eingabequellen.

```swift
/// Verfügbare Audio-Eingabequellen
enum AudioSource: String, Codable {
    case localFile   // Lokale Musikbibliothek
    case microphone  // Echtzeit-Mikrofon
}
```

### 4. AudioTrack

Repräsentiert einen analysierten Song mit Beat-Map.

```swift
/// Ein analysierter Audio-Track mit extrahierten Features
struct AudioTrack: Codable, Identifiable {
    let id: UUID
    
    // Metadaten (aus MPMediaItem)
    let title: String
    let artist: String?
    let albumTitle: String?
    let duration: TimeInterval  // Sekunden
    let assetURL: URL?          // Nur für lokale Dateien
    
    // Analyse-Ergebnisse
    let bpm: Double
    let beatTimestamps: [TimeInterval]  // Sekunden seit Start
    let rmsEnvelope: [Float]?           // Optional: Lautstärke-Kurve
    let spectralCentroid: [Float]?      // Optional: Helligkeit/Timbre
    
    // Analyse-Status
    let analyzedAt: Date
    let analysisVersion: String  // Für Cache-Invalidierung
    
    init(
        id: UUID = UUID(),
        title: String,
        artist: String? = nil,
        albumTitle: String? = nil,
        duration: TimeInterval,
        assetURL: URL? = nil,
        bpm: Double,
        beatTimestamps: [TimeInterval],
        rmsEnvelope: [Float]? = nil,
        spectralCentroid: [Float]? = nil,
        analyzedAt: Date = Date(),
        analysisVersion: String = "1.0"
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.duration = duration
        self.assetURL = assetURL
        self.bpm = bpm
        self.beatTimestamps = beatTimestamps
        self.rmsEnvelope = rmsEnvelope
        self.spectralCentroid = spectralCentroid
        self.analyzedAt = analyzedAt
        self.analysisVersion = analysisVersion
    }
    
    /// Formatierte Dauer (z.B. "3:45")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Anzahl der erkannten Beats
    var beatCount: Int { beatTimestamps.count }
}
```

### 5. LightEvent

Ein einzelnes Licht-Ereignis im LightScript.

```swift
/// Ein einzelnes Licht-Ereignis in der Sequenz
struct LightEvent: Codable {
    let timestamp: TimeInterval    // Sekunden seit Session-Start
    let intensity: Float           // 0.0 - 1.0
    let duration: TimeInterval     // Wie lange das Licht an bleibt
    let waveform: Waveform         // Form des Lichtsignals
    let color: LightColor?         // Nur für Bildschirm-Modus
    
    /// Verfügbare Wellenformen
    enum Waveform: String, Codable {
        case square     // Hartes Ein/Aus (Rechteck)
        case sine       // Sanftes Pulsieren (Sinus)
        case triangle   // Lineares Ein-/Ausblenden
    }
    
    /// Verfügbare Farben für Bildschirm-Modus
    enum LightColor: String, Codable {
        case white
        case red
        case blue
        case green
        case custom  // Für zukünftige RGB-Zyklen
    }
}
```

### 6. LightScript

Die vollständige Sequenz von Licht-Ereignissen für einen Track.

```swift
/// Vollständige Licht-Sequenz für einen analysierten Track
struct LightScript: Codable, Identifiable {
    let id: UUID
    let trackId: UUID              // Referenz auf AudioTrack
    let mode: EntrainmentMode
    let targetFrequency: Double    // Berechnete Frequenz in Hz
    let multiplier: Int            // BPM-zu-Hz Multiplikator (N)
    let events: [LightEvent]
    let createdAt: Date
    
    init(
        id: UUID = UUID(),
        trackId: UUID,
        mode: EntrainmentMode,
        targetFrequency: Double,
        multiplier: Int,
        events: [LightEvent],
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
```

### 7. Session

Eine abgeschlossene oder laufende Stroboskop-Sitzung.

```swift
/// Eine Stroboskop-Sitzung (laufend oder abgeschlossen)
struct Session: Codable, Identifiable {
    let id: UUID
    let startedAt: Date
    var endedAt: Date?
    
    // Konfiguration
    let mode: EntrainmentMode
    let lightSource: LightSource
    let audioSource: AudioSource
    
    // Track-Info (optional für Mikrofon-Modus)
    let trackTitle: String?
    let trackArtist: String?
    let trackBPM: Double?
    
    // Laufzeit-Statistiken
    var actualDuration: TimeInterval?
    var averageIntensity: Float?
    var thermalWarningOccurred: Bool
    var manuallyPaused: Bool
    var endReason: EndReason?
    
    enum EndReason: String, Codable {
        case userStopped        // Nutzer hat gestoppt
        case trackEnded         // Song zu Ende
        case thermalShutdown    // Überhitzung
        case fallDetected       // Gerät gefallen
        case phoneCall          // Anruf eingegangen
        case appBackgrounded    // App in Hintergrund
    }
    
    init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        mode: EntrainmentMode,
        lightSource: LightSource,
        audioSource: AudioSource,
        trackTitle: String? = nil,
        trackArtist: String? = nil,
        trackBPM: Double? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = nil
        self.mode = mode
        self.lightSource = lightSource
        self.audioSource = audioSource
        self.trackTitle = trackTitle
        self.trackArtist = trackArtist
        self.trackBPM = trackBPM
        self.actualDuration = nil
        self.averageIntensity = nil
        self.thermalWarningOccurred = false
        self.manuallyPaused = false
        self.endReason = nil
    }
    
    /// Berechnet Dauer basierend auf Start/Ende
    var duration: TimeInterval {
        actualDuration ?? (endedAt ?? Date()).timeIntervalSince(startedAt)
    }
    
    /// Formatierte Dauer
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    /// Ist die Session noch aktiv?
    var isActive: Bool { endedAt == nil }
}
```

### 8. UserPreferences

Persistierte Nutzereinstellungen.

```swift
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
```

---

## Supporting Types

### AnalysisProgress

Für die Fortschrittsanzeige während der Audio-Analyse.

```swift
/// Fortschritt der Audio-Analyse
struct AnalysisProgress {
    let phase: Phase
    let progress: Double  // 0.0 - 1.0
    let message: String
    
    enum Phase: String {
        case loading = "Lade Audio..."
        case extracting = "Extrahiere PCM-Daten..."
        case analyzing = "Analysiere Frequenzen..."
        case detecting = "Erkenne Beats..."
        case mapping = "Erstelle LightScript..."
        case complete = "Fertig!"
    }
}
```

### ThermalState

Wrapper für ProcessInfo.ThermalState mit eigener Logik.

```swift
/// Thermischer Zustand des Geräts
enum ThermalState: Int, Comparable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3
    
    static func < (lhs: ThermalState, rhs: ThermalState) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// Empfohlene maximale Taschenlampen-Intensität
    var maxFlashlightIntensity: Float {
        switch self {
        case .nominal: return 1.0
        case .fair: return 0.7
        case .serious: return 0.3
        case .critical: return 0.0
        }
    }
    
    /// Sollte auf Bildschirm gewechselt werden?
    var shouldSwitchToScreen: Bool {
        self >= .serious
    }
}
```

### SafetyLimits

Konstanten für Sicherheitsgrenzen.

```swift
/// Sicherheitskonstanten (nicht veränderbar)
enum SafetyLimits {
    /// PSE-Gefahrenzone (Hz)
    static let pseMinFrequency: Double = 3.0
    static let pseMaxFrequency: Double = 30.0
    
    /// Harte Frequenzgrenzen (Hz)
    static let absoluteMinFrequency: Double = 1.0
    static let absoluteMaxFrequency: Double = 60.0
    
    /// Taschenlampen-Grenzen
    static let flashlightMaxFrequency: Double = 30.0
    static let flashlightMaxSustainedIntensity: Float = 0.5
    
    /// Fall-Erkennung
    static let fallAccelerationThreshold: Double = 2.0  // g
    static let freefallThreshold: Double = 0.3  // g
    
    /// Session-Grenzen
    static let flashlightMaxDuration: TimeInterval = 15 * 60  // 15 Min
}
```

---

## Persistence Strategy

### UserDefaults (via @AppStorage)

Für einfache Einstellungen:

```swift
@AppStorage("epilepsyDisclaimerAccepted") var disclaimerAccepted = false
@AppStorage("preferredMode") var preferredMode = EntrainmentMode.alpha
@AppStorage("preferredLightSource") var preferredLightSource = LightSource.screen
```

### FileManager (JSON)

Für komplexere Daten:

```swift
// LightScript-Cache: Documents/lightscripts/{trackId}.json
// Session-Historie: Documents/sessions/{sessionId}.json
// Analysierte Tracks: Documents/tracks/{trackId}.json
```

### Kein CloudKit/iCloud

Gemäß Constitution (Privacy & Data Minimization) bleiben alle Daten lokal.

---

## Entity Relationships

```
UserPreferences (1)
       │
       ├──▶ EntrainmentMode (enum)
       └──▶ LightSource (enum)

AudioTrack (N)
       │
       └──▶ LightScript (1:N, pro Mode)
                  │
                  └──▶ LightEvent (1:N)

Session (N)
       │
       ├──▶ EntrainmentMode (enum)
       ├──▶ LightSource (enum)
       ├──▶ AudioSource (enum)
       └──▶ AudioTrack (optional, 0:1)
```

---

**Data Model Version**: 1.0.0 | **Status**: Draft

