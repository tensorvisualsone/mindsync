# MindSync Architecture Documentation

## Übersicht

MindSync ist eine iOS-App, die stroboskopisches Licht (Taschenlampe/Bildschirm) mit der persönlichen Musik des Nutzers synchronisiert, um veränderte Bewusstseinszustände durch Neural Entrainment zu induzieren.

## High-Level Data Flow

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Audio Source   │────▶│  AudioAnalyzer   │────▶│   LightScript   │
│ (File/Mic)      │     │ (BeatDetector,   │     │ (Timed events)  │
│                 │     │  TempoEstimator) │     │                 │
└─────────────────┘     └──────────────────┘     └────────┬────────┘
                                                         │
                                                         ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  User Mode      │────▶│ EntrainmentEngine│────▶│ LightController │
│ (Alpha/Theta/   │     │ (BPM→Hz Mapping) │     │ (Flash/Screen)  │
│  Gamma)         │     │                  │     │                 │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

## Architektur-Komponenten

### Core Audio

#### AudioAnalyzer
**Datei**: `MindSync/Core/Audio/AudioAnalyzer.swift`

Orchestriert die vollständige Audio-Analyse-Pipeline:
1. Lädt Audio-Datei via `AudioFileReader`
2. Extrahiert PCM-Daten
3. Führt Beat-Erkennung via `BeatDetector` durch
4. Schätzt BPM via `TempoEstimator`
5. Erstellt `AudioTrack` mit Metadaten und Beat-Timestamps

**Publisher**: `progressPublisher` für UI-Fortschrittsanzeige

#### AudioFileReader
**Datei**: `MindSync/Core/Audio/AudioFileReader.swift`

Liest PCM-Daten aus Audio-Dateien:
- Nutzt `AVURLAsset` und `AVAssetReader` für DRM-freie Dateien
- Konvertiert zu Mono, 44.1kHz, Float32
- Validierung: Max. 30 Minuten, DRM-Check via async `load(.isReadable)`
- **Code-Qualität**: Ungenutzte Variablen entfernt, moderne async APIs

#### BeatDetector
**Datei**: `MindSync/Core/Audio/BeatDetector.swift`

FFT-basierte Beat-Erkennung:
- **Algorithmus**: Spectral Flux + adaptiver Threshold
- **FFT**: 2048 Samples, Hop Size 512
- **Window**: Hann Window für Frequenz-Auflösung
- **Threshold**: Mean + 0.5 × StdDev (adaptiv)

#### TempoEstimator
**Datei**: `MindSync/Core/Audio/TempoEstimator.swift`

BPM-Schätzung aus Beat-Timestamps:
- Berechnet Inter-Onset-Intervals
- IQR-basierte Outlier-Filterung
- Tempo-Folding (60-200 BPM Range)
- Histogram-basierte Dominanz-Erkennung

### Core Entrainment

#### EntrainmentEngine
**Datei**: `MindSync/Core/Entrainment/EntrainmentEngine.swift`

Generiert `LightScript` aus `AudioTrack` und `EntrainmentMode`:
- Nutzt `FrequencyMapper` für BPM → Hz Mapping
- Erstellt `LightEvent` für jeden Beat
- Wählt Waveform basierend auf Modus (Alpha/Theta/Cinematic: Sine, Gamma: Square)
- Passt Intensität an Modus an (Alpha: 0.4, Theta: 0.3, Gamma: 0.7, Cinematic: 0.5 Basis)

**Cinematic Mode**:
- `calculateCinematicIntensity()`: Statische Methode für dynamische Intensitäts-Berechnung
- **Frequency Drift**: Langsame Oszillation zwischen 5.5-7.5 Hz (sinusoidal, 0.2 Hz Rate)
- **Audio Reactivity**: Base-Intensität 0.3-1.0 basierend auf Audio-Energie
- **Lens Flare**: Gamma-Korrektur für helle Bereiche (>0.8 → pow(0.5))
- Runtime-Modulation: Intensität wird zur Laufzeit dynamisch angepasst (nicht in LightScript gespeichert)

#### FrequencyMapper
**Datei**: `MindSync/Core/Entrainment/FrequencyMapper.swift`

BPM-zu-Hz Mapping-Logik:
- Berechnet Multiplier N: `f_target = (BPM / 60) × N`
- Validiert gegen `SafetyLimits` (PSE-Gefahrenzone, min/max)
- Berücksichtigt Light-Source-Limits (Flashlight: 30 Hz, Screen: 60 Hz)

#### WaveformGenerator
**Datei**: `MindSync/Core/Entrainment/WaveformGenerator.swift`

Berechnet Wellenformen für Licht-Intensität:
- **Square**: Hartes Ein/Aus (50% Duty Cycle)
- **Sine**: Sanftes Pulsieren (0-1 Intensität)
- **Triangle**: Lineares Rampen
- Unterstützt Fade-Out für Signal-Pausierung (Mikrofon-Modus)

#### LightScript
**Datei**: `MindSync/Core/Entrainment/LightScript.swift`

Zeitgesteuerte Sequenz von Licht-Ereignissen:
- Enthält `LightEvent` Array mit Timestamps
- Jedes Event: timestamp, intensity, duration, waveform, color
- Wird von `LightController` abgespielt

### Core Light

#### BaseLightController
**Datei**: `MindSync/Core/Light/BaseLightController.swift`

Basisklasse für Light-Controller:
- Verwaltet `CADisplayLink` für präzises Timing
- Script-Execution-State (start, pause, resume)
- Event-Finding-Logik basierend auf elapsed time
- Pause-Duration-Tracking
- **AudioEnergyTracker-Referenz**: Optionale weak-Referenz für Cinematic Mode (gesetzt via `SessionViewModel`)

#### FlashlightController
**Datei**: `MindSync/Core/Light/FlashlightController.swift`

Taschenlampen-Steuerung:
- Nutzt `AVCaptureDevice.setTorchModeOn(level:)`
- Lock-For-Configuration für Session-Dauer
- Thermisches Management via `ThermalManager`
- Max. ~30-40 Hz zuverlässig
- **Gamma-Korrektur**: `pow(intensity, 2.2)` für natürliche Wahrnehmung (logarithmisches Auge)
- **Cinematic Mode**: Dynamische Intensitäts-Modulation in `updateLight()` via `EntrainmentEngine.calculateCinematicIntensity()`

#### ScreenController
**Datei**: `MindSync/Core/Light/ScreenController.swift`

Bildschirm-Stroboskop:
- Vollbild-Farbflackern via SwiftUI `Color`
- `CADisplayLink` für 60/120 Hz Timing
- Waveform-Rendering via `WaveformGenerator`
- Unterstützt Farben (White, Red, Blue, Green)
- **Cinematic Mode**: Dynamische Opacity-Modulation in `updateScreen()` via `EntrainmentEngine.calculateCinematicIntensity()`

#### LightController (Protocol)
**Datei**: `MindSync/Core/Light/LightController.swift`

Protokoll für Light-Quellen:
- `start()`, `stop()`, `setIntensity()`, `setColor()`
- `execute(script:syncedTo:)` für LightScript-Abspiel
- `pauseExecution()`, `resumeExecution()`

### Core Safety

#### ThermalManager
**Datei**: `MindSync/Core/Safety/ThermalManager.swift`

Thermisches Management:
- Beobachtet `ProcessInfo.thermalState`
- Berechnet `maxFlashlightIntensity` basierend auf State
- Empfiehlt Screen-Fallback bei serious/critical
- Publisher für UI-Warnungen

#### FallDetector
**Datei**: `MindSync/Core/Safety/FallDetector.swift`

Sturz-Erkennung:
- `CMMotionManager` Accelerometer (20 Hz)
- Filterung via Moving Average (5 Samples)
- Threshold: 2.0g für Impact-Erkennung
- Publisher für Fall-Events

#### SafetyLimits
**Datei**: `MindSync/Core/Safety/SafetyLimits.swift`

Sicherheitskonstanten:
- PSE-Gefahrenzone: 3-30 Hz
- Absolute Limits: 1-60 Hz
- Flashlight: Max 30 Hz, Max Intensity 0.5 (sustained)
- Fall Detection: 2.0g threshold

### Services

#### ServiceContainer
**Datei**: `MindSync/Services/ServiceContainer.swift`

Zentraler Service-Container (Singleton):
- Initialisiert alle Services einmalig
- `@MainActor` für Thread-Safety
- Vermeidet zirkuläre Abhängigkeiten (ThermalManager vor FlashlightController)

#### AudioPlaybackService
**Datei**: `MindSync/Services/AudioPlaybackService.swift`

Audio-Wiedergabe:
- `AVAudioEngine` + `AVAudioPlayerNode` für lokale Dateien (migriert von AVAudioPlayer)
- Callback für Playback-Completion
- Pause/Resume/Stop-Funktionalität
- `getMainMixerNode()` für Audio-Taps (z.B. AudioEnergyTracker)

#### AudioEnergyTracker
**Datei**: `MindSync/Services/AudioEnergyTracker.swift`

Echtzeit-Audio-Energie-Tracking (für Cinematic Mode):
- Installiert Tap auf `mainMixerNode` der AVAudioEngine
- RMS-Berechnung (Root Mean Square) pro Buffer
- Moving Average für Smoothing (95% old, 5% new)
- Publisher für Echtzeit-Energie-Werte (0.0 - 1.0)
- Thread-Safe: Audio-Callbacks → Main-Thread-Publikation

#### MediaLibraryService
**Datei**: `MindSync/Services/MediaLibraryService.swift`

Musikbibliothek-Zugriff:
- `MPMediaPickerController` Integration
- DRM-Check via `AVURLAsset` und async `load(.hasProtectedContent)` / `load(.isReadable)`
- Berechtigungs-Management
- **API-Migration**: Verwendet moderne iOS APIs (AVURLAsset statt AVAsset, async Property Loading)

#### PermissionsService
**Datei**: `MindSync/Services/PermissionsService.swift`

Berechtigungen:
- Mikrofon-Berechtigung (AVAudioSession)
- Musikbibliothek-Berechtigung (MPMediaLibrary)

#### SessionHistoryService
**Datei**: `MindSync/Services/SessionHistoryService.swift`

Session-Historie:
- Speichert Sessions in UserDefaults (max. 100)
- JSON-Encoding/Decoding
- Logging via os.log

### Features

#### SessionViewModel
**Datei**: `MindSync/Features/Session/SessionViewModel.swift`

Session-Orchestrierung:
- Startet Audio-Analyse und Playback
- Generiert LightScript via EntrainmentEngine
- Steuert LightController
- Beobachtet ThermalManager und FallDetector
- Unterstützt lokale Dateien und Mikrofon-Modus
- **Cinematic Mode Integration**:
  - Startet `AudioEnergyTracker` auf MixerNode bei `.cinematic` Mode
  - Setzt `audioEnergyTracker` auf `LightController` für dynamische Modulation
  - Stoppt Tracking bei Session-Ende
- **Concurrency**: 
  - `@MainActor` für Thread-Safety
  - Timer für Affirmation-Observer nutzt `Task { @MainActor in }` für Main Actor Isolation
  - `SessionState` explizit als `Equatable` markiert
- **MediaLibraryService Integration**: Verwendet async `canAnalyze(item:)` Methode

#### SessionView
**Datei**: `MindSync/Features/Session/SessionView.swift`

Session-UI:
- Zeigt Analyse-Fortschritt
- Pause/Resume/Stop-Buttons
- Thermal-Warnungen via SafetyBanner
- Screen-Controller Color-Binding

## Entrainment-Algorithmus

### BPM → Hz Mapping

```
f_target = (BPM / 60) × N

Wobei N (Multiplikator) so gewählt wird, dass f_target im Zielband liegt:
- Alpha (Entspannung): 8-12 Hz
- Theta (Trip):        4-8 Hz
- Gamma (Fokus):       30-40 Hz
- Cinematic (Flow State): 5.5-7.5 Hz (Theta/Low Alpha)
```

**Beispiel**: Song mit 120 BPM
- Grundfrequenz: 2 Hz
- Alpha-Modus: N=5 → 10 Hz ✓
- Theta-Modus: N=3 → 6 Hz ✓
- Gamma-Modus: N=18 → 36 Hz ✓
- Cinematic-Modus: N=3 → 6 Hz (dynamisch moduliert 5.5-7.5 Hz) ✓

### LightScript-Generierung

1. **Beat-Timestamps** aus Audio-Analyse
2. **Target-Frequenz** via FrequencyMapper
3. **LightEvent** für jeden Beat:
   - **Waveform**: Modus-abhängig (Alpha/Theta/Cinematic: Sine, Gamma: Square)
   - **Intensity**: Modus-abhängig (Alpha: 0.4, Theta: 0.3, Gamma: 0.7, Cinematic: 0.5 Basis)
   - **Duration**: Period / 2 (Square) oder Period (Sine)
   - **Color**: Nur für Screen-Modus

**Cinematic Mode (Runtime-Modulation)**:
- Basis-Intensität im LightScript: 0.5 (wird zur Laufzeit moduliert)
- Dynamische Intensität in `LightController.updateLight()`:
  - Audio-Energie vom `AudioEnergyTracker` (0.0-1.0)
  - `EntrainmentEngine.calculateCinematicIntensity()` berechnet:
    - Frequency Drift: `6.5 + sin(time * 0.2) * 1.0` Hz
    - Audio Reactivity: `0.3 + (energy * 0.7)` Basis-Intensität
    - Lens Flare: Gamma-Korrektur für >0.8
  - Finale Intensität = Event-Intensität × Cinematic-Intensität

## Audio-Analyse Pipeline

### Lokale Dateien

1. **AudioFileReader**: PCM-Extraktion (AVAssetReader)
2. **BeatDetector**: FFT → Spectral Flux → Beat-Timestamps
3. **TempoEstimator**: BPM-Schätzung aus Intervals
4. **EntrainmentEngine**: LightScript-Generierung

### Mikrofon-Modus

1. **MicrophoneAnalyzer**: Live-Audio-Streaming
2. **Streaming FFT**: Frame-by-Frame Analyse
3. **Live Beat-Detection**: Adaptive Threshold
4. **Dynamische LightScript**: Regeneriert bei neuen Beats/BPM

## Light-Steuerung

### Flashlight (Taschenlampe)

- **API**: `AVCaptureDevice.setTorchModeOn(level:)`
- **Timing**: `CADisplayLink` (60/120 Hz)
- **Limits**: Max 30-40 Hz zuverlässig
- **Thermal**: Automatische Intensitäts-Reduktion
- **Gamma-Korrektur**: `pow(intensity, 2.2)` für natürliche Wahrnehmung
- **Cinematic Mode**: Dynamische Intensitäts-Modulation zur Laufzeit via `AudioEnergyTracker`

### Screen (Bildschirm)

- **API**: SwiftUI `Color` + `CADisplayLink`
- **Timing**: 60/120 Hz (ProMotion)
- **Limits**: Bis 60 Hz (theoretisch 120 Hz)
- **Features**: Farben, Waveform-Rendering
- **Cinematic Mode**: Dynamische Opacity-Modulation zur Laufzeit via `AudioEnergyTracker`

## Sicherheits-Features

### Epilepsie-Warnung

- **Obligatorisch**: Onboarding beim ersten Start
- **Persistenz**: `@AppStorage("epilepsyDisclaimerAccepted")`
- **UI**: Dark Mode, hoher Kontrast

### Thermisches Management

- **Monitoring**: `ProcessInfo.thermalState`
- **Reaktionen**:
  - Serious: Intensität → 0.5
  - Critical: Flashlight deaktiviert, Fallback zu Screen
- **UI**: SafetyBanner mit Warnung

### Fall-Erkennung

- **Sensor**: Accelerometer (20 Hz)
- **Threshold**: 2.0g Impact
- **Reaktion**: Session stoppt automatisch
- **Filterung**: Moving Average reduziert False Positives

### PSE-Gefahrenzone

- **Bereich**: 3-30 Hz
- **Validierung**: FrequencyMapper prüft gegen SafetyLimits
- **Warnung**: UI-Hinweis bei Frequenzen in diesem Bereich

## Service-Container Pattern

Alle Services werden zentral in `ServiceContainer` verwaltet:

```swift
@MainActor
final class ServiceContainer: ObservableObject {
    static let shared = ServiceContainer()
    
    let audioAnalyzer: AudioAnalyzer
    let flashlightController: FlashlightController
    // ... weitere Services
}
```

**Vorteile**:
- Einfache Dependency Injection
- Thread-Safety via `@MainActor`
- Vermeidet zirkuläre Abhängigkeiten
- Testbarkeit (kann gemockt werden)

## Testing-Strategie

### Unit Tests

- **Audio-Analyse**: BeatDetector, TempoEstimator mit synthetischen Daten
- **Entrainment**: FrequencyMapper, EntrainmentEngine mit verschiedenen BPMs
- **Safety**: ThermalManager, FallDetector mit simulierten States

### Integration Tests

- **AudioAnalyzer**: Vollständiger Flow mit echten Audio-Dateien
- **SessionViewModel**: Komplette Session-Orchestrierung

### UI Tests

- **Onboarding**: Epilepsie-Warnung Flow
- **Session**: Start/Stop/Pause/Resume
- **Settings**: Präferenzen-Persistierung

### Manuelle Tests

- **Mikrofon-Modus**: Echtzeit-Analyse auf realem Gerät
- **Thermisches Management**: Lange Sessions mit hoher Intensität
- **Fall-Erkennung**: Beschleunigungstests

## Performance-Überlegungen

### Audio-Analyse

- **Memory**: PCM-Daten für 30-Minuten-Track ~500MB
- **CPU**: FFT ist rechenintensiv, läuft im Background
- **Optimierung**: Streaming für Mikrofon-Modus

### Light-Steuerung

- **Timing**: `CADisplayLink` für präzise Synchronisation
- **Battery**: Flashlight ist energieintensiv (max. 15 Min empfohlen)
- **Thermal**: Automatische Drosselung verhindert Überhitzung

## Bekannte Einschränkungen

1. **DRM-geschützte Dateien**: Können nicht analysiert werden (nur lokale, DRM-freie Dateien)
2. **Mikrofon-Latenz**: ~100ms Hardware-Latenz führt zu leichter Desynchronisation
3. **Flashlight-Frequenz**: Max. 30-40 Hz zuverlässig (Hardware-Limit)
4. **Fall-Erkennung**: False Positives möglich bei normaler Bewegung

## Cinematic Mode Architektur

### Übersicht

Der Cinematic Mode ist ein spezieller Entrainment-Modus, der dynamische, audio-reaktive Lichtsynchronisation bietet. Er erzeugt einen "Flow State" ähnlich hochwertiger Video-Produktionen durch:

1. **Frequency Drift**: Langsame Oszillation der Frequenz (5.5-7.5 Hz) verhindert Habituation
2. **Audio Reactivity**: Intensität reagiert auf Audio-Energie (Beats/Drops)
3. **Lens Flare**: Gamma-Korrektur für helle Bereiche erzeugt "Blitz"-Effekte

### Technische Implementierung

#### Audio-Energie-Tracking

```
AudioPlaybackService (AVAudioEngine)
    └── mainMixerNode
        └── AudioEnergyTracker (Tap installiert)
            ├── RMS-Berechnung pro Buffer
            ├── Moving Average (95% smoothing)
            └── Publisher → Main Thread
```

#### Dynamische Intensitäts-Modulation

```
SessionViewModel.startSession()
    ├── Mode == .cinematic?
    │   ├── AudioEnergyTracker.startTracking(mixerNode)
    │   └── LightController.audioEnergyTracker = tracker
    └── LightController.execute(script)
        └── CADisplayLink.updateLight()
            ├── currentScript.mode == .cinematic?
            │   ├── audioEnergy = audioEnergyTracker.currentEnergy
            │   ├── cinematicIntensity = EntrainmentEngine.calculateCinematicIntensity(...)
            │   └── intensity = event.intensity * cinematicIntensity
            └── setIntensity(intensity)
```

### Formeln

**Frequency Drift**:
```
drift = sin(currentTime * 0.2) * 1.0  // Langsame Oszillation (5-10 Sek)
currentFreq = 6.5 + drift              // 5.5 - 7.5 Hz
```

**Audio Reactivity**:
```
baseIntensity = 0.3 + (audioEnergy * 0.7)  // 30%-100%
cosineWave = cos(time * currentFreq * 2π + π/2)
normalizedWave = (cosineWave + 1.0) / 2.0
output = normalizedWave * baseIntensity
```

**Lens Flare**:
```
if output > 0.8:
    output = pow(output, 0.5)  // Hellt Spitzen auf
```

### Abhängigkeiten

- **AudioPlaybackService**: Muss `AVAudioEngine` verwenden (nicht `AVAudioPlayer`)
- **AudioEnergyTracker**: Benötigt MixerNode-Zugriff
- **BaseLightController**: Speichert optionale AudioEnergyTracker-Referenz
- **SessionViewModel**: Orchestriert Start/Stop des Trackings

### Testing-Strategie

- **Unit Tests**: `EntrainmentEngine.calculateCinematicIntensity()` mit verschiedenen Parametern
- **Integration Tests**: Vollständiger Flow mit echten Audio-Dateien
- **UI Tests**: Session-Flow mit Cinematic Mode

## Lokalisierung

### Übersicht

MindSync unterstützt vollständige Lokalisierung für Deutsch (Standard) und Englisch. Alle user-facing Strings werden über `NSLocalizedString` bereitgestellt.

### Lokalisierungsdateien

- **Base (Deutsch)**: `MindSync/Resources/Localizable.strings`
- **Englisch**: `MindSync/Resources/en.lproj/Localizable.strings`

### String-Kategorien

1. **Onboarding**: Epilepsie-Warnung und Disclaimer
2. **Home**: Titel, Untertitel, Buttons
3. **Source Selection**: Audioquelle-Auswahl, Berechtigungen
4. **Session**: Pause/Resume/Stop, Status-Meldungen
5. **Settings**: Einstellungen, Lichtquelle, Modi
6. **Mode Selection**: Modus-Beschreibungen und Auswahl
7. **Light Source**: Taschenlampe/Bildschirm, Farben
8. **Safety**: Thermal-Warnungen, Fall-Erkennung
9. **Errors**: Fehlermeldungen für verschiedene Szenarien
10. **Common UI**: Gemeinsame UI-Elemente (OK, Abbrechen, etc.)

### Verwendung in Code

```swift
// ✅ Richtig: Lokalisierter String
Text(NSLocalizedString("home.title", comment: ""))

// ❌ Falsch: Hardcodierter String
Text("Home")
```

### Format-Strings

Für Strings mit Parametern wird `String(format:)` verwendet:

```swift
String(format: NSLocalizedString("modeSelection.currentMode", comment: ""), mode.displayName)
```

### Best Practices

1. **Keine hardcodierten Strings**: Alle user-facing Texte müssen lokalisiert sein
2. **Konsistente Keys**: Verwende kategorisierte Keys (z.B. `home.title`, `settings.mode`)
3. **Comments**: Kommentare in `NSLocalizedString` helfen Übersetzern
4. **Accessibility**: Auch Accessibility-Labels sollten lokalisiert werden

## Code-Qualität & Wartbarkeit

### Concurrency & Thread-Safety

- **Main Actor Isolation**: Alle ViewModels und Services nutzen `@MainActor` für Thread-Safety
- **Timer-Handling**: Timer-Callbacks verwenden `Task { @MainActor in }` für sicheren Zugriff auf Main Actor-isolierte Eigenschaften
- **SessionState**: Explizit als `Equatable` markiert für bessere Concurrency-Kompatibilität

### API-Migrationen

- **MediaLibraryService**: Migriert auf moderne iOS APIs:
  - `AVAsset(url:)` → `AVURLAsset(url:)`
  - `asset.hasProtectedContent` → `await asset.load(.hasProtectedContent)`
  - `asset.isReadable` → `await asset.load(.isReadable)`
  - `canAnalyze(item:)` ist jetzt async
- **AudioFileReader**: Verwendet async Property Loading für bessere Performance

### Code-Qualität

- **Ungenutzte Variablen**: Entfernt (z.B. `formatDescription` in AudioFileReader)
- **Deprecation-Warnungen**: Alle deprecated APIs wurden migriert
- **Lokalisierung**: Alle user-facing Strings sind lokalisiert, inkl. Accessibility-Labels

### UI-Konsistenz

- **AppConstants**: Zentrale Definitionen für Spacing, Typography, Colors, Corner Radius, Icons
- **Color Palette**: Adaptive Colors für Dark/Light Mode via `Color+MindSync` Extension
- **Accessibility**: Minimum Touch Targets (44pt), vollständige Accessibility-Labels

## Zukünftige Erweiterungen

- **RGB-Zyklen**: Custom-Farben für Screen-Modus
- **Predictive Beat-Extrapolation**: Reduziert Mikrofon-Latenz
- **Erweiterte Fall-Filterung**: Kontext-bewusste Erkennung
- **Session-Analytics**: Detaillierte Statistiken
- **CADisplayLink Background Issue**: Timing vom Audio-Thread ableiten (siehe BaseLightController Kommentar)
- **Weitere Sprachen**: Französisch, Spanisch, etc.

