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
- Nutzt `AVAssetReader` für DRM-freie Dateien
- Konvertiert zu Mono, 44.1kHz, Float32
- Validierung: Max. 30 Minuten, DRM-Check

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

#### MicrophoneAnalyzer
**Datei**: `MindSync/Core/Audio/MicrophoneAnalyzer.swift`

Echtzeit-Mikrofon-Analyse:
- `AVAudioEngine` mit Input-Node
- Streaming FFT-Analyse (ähnlich BeatDetector)
- Live Beat-Events via Publisher
- BPM-Updates basierend auf letzten 20 Beats
- ~100ms Latenz (Hardware-bedingt)

### Core Entrainment

#### EntrainmentEngine
**Datei**: `MindSync/Core/Entrainment/EntrainmentEngine.swift`

Generiert `LightScript` aus `AudioTrack` und `EntrainmentMode`:
- Nutzt `FrequencyMapper` für BPM → Hz Mapping
- Erstellt `LightEvent` für jeden Beat
- Wählt Waveform basierend auf Modus (Alpha/Theta: Sine, Gamma: Square)
- Passt Intensität an Modus an

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

#### FlashlightController
**Datei**: `MindSync/Core/Light/FlashlightController.swift`

Taschenlampen-Steuerung:
- Nutzt `AVCaptureDevice.setTorchModeOn(level:)`
- Lock-For-Configuration für Session-Dauer
- Thermisches Management via `ThermalManager`
- Max. ~30-40 Hz zuverlässig

#### ScreenController
**Datei**: `MindSync/Core/Light/ScreenController.swift`

Bildschirm-Stroboskop:
- Vollbild-Farbflackern via SwiftUI `Color`
- `CADisplayLink` für 60/120 Hz Timing
- Waveform-Rendering via `WaveformGenerator`
- Unterstützt Farben (White, Red, Blue, Green)

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
- `AVAudioPlayer` für lokale Dateien
- Callback für Playback-Completion
- Pause/Resume/Stop-Funktionalität

#### MediaLibraryService
**Datei**: `MindSync/Services/MediaLibraryService.swift`

Musikbibliothek-Zugriff:
- `MPMediaPickerController` Integration
- DRM-Check via `AVAsset.hasProtectedContent`
- Berechtigungs-Management

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
```

**Beispiel**: Song mit 120 BPM
- Grundfrequenz: 2 Hz
- Alpha-Modus: N=5 → 10 Hz ✓
- Theta-Modus: N=3 → 6 Hz ✓
- Gamma-Modus: N=18 → 36 Hz ✓

### LightScript-Generierung

1. **Beat-Timestamps** aus Audio-Analyse
2. **Target-Frequenz** via FrequencyMapper
3. **LightEvent** für jeden Beat:
   - **Waveform**: Modus-abhängig (Alpha/Theta: Sine, Gamma: Square)
   - **Intensity**: Modus-abhängig (Alpha: 0.4, Theta: 0.3, Gamma: 0.7)
   - **Duration**: Period / 2 (Square) oder Period (Sine)
   - **Color**: Nur für Screen-Modus

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

### Screen (Bildschirm)

- **API**: SwiftUI `Color` + `CADisplayLink`
- **Timing**: 60/120 Hz (ProMotion)
- **Limits**: Bis 60 Hz (theoretisch 120 Hz)
- **Features**: Farben, Waveform-Rendering

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
    let microphoneAnalyzer: MicrophoneAnalyzer?
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

## Zukünftige Erweiterungen

- **RGB-Zyklen**: Custom-Farben für Screen-Modus
- **Predictive Beat-Extrapolation**: Reduziert Mikrofon-Latenz
- **Erweiterte Fall-Filterung**: Kontext-bewusste Erkennung
- **Session-Analytics**: Detaillierte Statistiken

