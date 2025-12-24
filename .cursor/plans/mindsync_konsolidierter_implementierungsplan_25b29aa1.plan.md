---
name: MindSync Konsolidierter Implementierungsplan
overview: "Konsolidierter Plan für alle verbleibenden MindSync-Features: Cinematic Mode, Tests, Lokalisierung und UI-Verbesserungen. Bereits implementierte Features (MicrophoneAnalyzer, FallDetector, FrequencyMapper, WaveformGenerator, ModeSelectionView) sind ausgeschlossen."
todos:
  - id: audio_migration
    content: "AudioPlaybackService zu AVAudioEngine migrieren: AudioPlayer durch AVAudioEngine + AVAudioPlayerNode ersetzen, MixerNode-Zugriff bereitstellen, Backward-Kompatibilität sicherstellen"
    status: completed
  - id: cinematic_mode_enum
    content: "EntrainmentMode erweitern: .cinematic Case hinzufügen mit frequencyRange 5.5...7.5 Hz, displayName, description und iconName"
    status: completed
  - id: audio_energy_tracker
    content: "AudioEnergyTracker Service implementieren: RMS-Berechnung, Moving Average, Publisher für Echtzeit-Energie-Werte, Thread-Safety"
    status: completed
    dependencies:
      - audio_migration
  - id: cinematic_intensity_calc
    content: "EntrainmentEngine: calculateCinematicIntensity Methode implementieren mit Frequency Drift, Audio Reactivity und Lens Flare Logik"
    status: completed
    dependencies:
      - cinematic_mode_enum
  - id: cinematic_light_events
    content: "EntrainmentEngine: generateLightEvents anpassen für Cinematic Mode (Hybrid-Ansatz mit Basis-Intensität 0.5)"
    status: completed
    dependencies:
      - cinematic_intensity_calc
  - id: cinematic_flashlight
    content: "FlashlightController: updateLight erweitern für Cinematic Mode mit dynamischer Intensitäts-Modulation basierend auf Audio-Energie"
    status: completed
    dependencies:
      - audio_energy_tracker
      - cinematic_intensity_calc
  - id: cinematic_screen
    content: "ScreenController: Analog zu FlashlightController anpassen für Cinematic Mode"
    status: completed
    dependencies:
      - cinematic_flashlight
  - id: cinematic_service_container
    content: "ServiceContainer: AudioEnergyTracker registrieren"
    status: completed
    dependencies:
      - audio_energy_tracker
  - id: cinematic_session_integration
    content: "SessionViewModel: AudioEnergyTracker Integration - Start/Stop Tracking bei Cinematic Mode Sessions"
    status: completed
    dependencies:
      - audio_energy_tracker
      - audio_migration
      - cinematic_service_container
  - id: test_frequency_mapper
    content: "FrequencyMapperTests: Unit Tests für calculateMultiplier, mapBPMToFrequency, validateFrequency, recommendedFrequencyRange"
    status: completed
  - id: test_entrainment_engine
    content: "EntrainmentEngineTests: Unit Tests für calculateMultiplier, LightScript-Generierung, calculateCinematicIntensity, Edge Cases"
    status: completed
    dependencies:
      - cinematic_intensity_calc
  - id: test_audio_energy_tracker
    content: "AudioEnergyTrackerTests: Unit Tests für RMS-Berechnung, Moving Average, Publisher-Verhalten, Thread-Safety"
    status: completed
    dependencies:
      - audio_energy_tracker
  - id: test_audio_playback_service
    content: "AudioPlaybackServiceTests: Unit Tests für AVAudioEngine-Setup, Play/Pause/Resume/Stop, MixerNode-Verfügbarkeit"
    status: completed
    dependencies:
      - audio_migration
  - id: test_thermal_manager
    content: "ThermalManagerTests erweitern: maxFlashlightIntensity, shouldSwitchToScreen, Warning-Level-Berechnung"
    status: completed
  - id: test_audio_analyzer_integration
    content: "AudioAnalyzerIntegrationTests: Integrationstest mit echten Audio-Dateien, vollständiger Analyse-Flow, Fehlerbehandlung"
    status: completed
  - id: test_cinematic_integration
    content: "CinematicModeIntegrationTests: Integrationstest für vollständigen Cinematic Mode Flow, AudioEnergyTracker Integration, dynamische Modulation"
    status: completed
    dependencies:
      - cinematic_session_integration
  - id: test_session_ui
    content: "SessionUITests: UI Tests für Session-Flow, Pause/Resume, Fehlerbehandlung, Cinematic Mode"
    status: completed
    dependencies:
      - cinematic_session_integration
  - id: test_settings_ui
    content: "SettingsUITests: UI Tests für Light-Source-Wechsel, Modus-Auswahl, Einstellungen-Persistierung"
    status: completed
  - id: localization_complete
    content: "Lokalisierung vervollständigen: Alle User-facing Strings in DE/EN lokalisieren, neue Cinematic Mode Strings hinzufügen"
    status: completed
    dependencies:
      - cinematic_mode_enum
  - id: ui_polish
    content: "UI-Polish: Konsistente Farbpalette, Typografie, Spacing, Accessibility, Dark Mode Optimierungen"
    status: completed
  - id: logging_extend
    content: "Logging erweitern: Logger für AudioEnergyTracker, AudioPlaybackService (nach Migration), bestehende Logger erweitern"
    status: completed
    dependencies:
      - audio_energy_tracker
      - audio_migration
  - id: documentation
    content: "Dokumentation: architecture.md erstellen/erweitern mit Architektur-Übersicht, Cinematic Mode, Testing-Strategie"
    status: completed
    dependencies:
      - cinematic_session_integration
---

# MindSync

Konsolidierter Implementierungsplan

## Bestandsaufnahme

### Bereits implementiert (nicht Teil dieses Plans)

- ✅ **MicrophoneAnalyzer** - Vollständig mit FFT, Beat Detection, Moving Average
- ✅ **FallDetector** - Vollständig implementiert mit CMMotionManager
- ✅ **FrequencyMapper** - Vollständig implementiert mit Safety-Validierung
- ✅ **WaveformGenerator** - Bereits vorhanden
- ✅ **ModeSelectionView** - UI bereits implementiert
- ✅ **AffirmationService** - Nutzt AVAudioEngine für Affirmationen (separate Engine)

### Noch offene Features

1. **Cinematic Mode** (neues Feature)
2. **AudioPlaybackService Migration** (Voraussetzung für Cinematic Mode)
3. **Tests** (Unit & UI Tests)
4. **Lokalisierung** (Vervollständigung)
5. **UI-Polish** (Design-Verbesserungen, Dokumentation)

---

## Phase 1: AudioPlaybackService Migration (KRITISCH)

**Zweck**: Migration von AVAudioPlayer zu AVAudioEngine, um Audio-Taps für Echtzeit-Analyse zu ermöglichen (Voraussetzung für Cinematic Mode).**Datei**: `MindSync/Services/AudioPlaybackService.swift`**Änderungen**:

- Ersetze `AVAudioPlayer` durch `AVAudioEngine` + `AVAudioPlayerNode`
- Behalte Backward-Kompatibilität: `audioPlayer` Property als deprecated Wrapper oder entfernen
- Neue Properties: `audioEngine: AVAudioEngine?`, `playerNode: AVAudioPlayerNode?`
- Methode `getMainMixerNode()` für AudioEnergyTracker-Zugriff
- Alle bestehenden Methoden (`play`, `pause`, `resume`, `stop`) müssen weiterhin funktionieren
- `onPlaybackComplete` Callback beibehalten

**Besondere Herausforderungen**:

- AffirmationService nutzt aktuell `AVAudioPlayer` als Parameter - muss angepasst werden
- SessionViewModel nutzt `audioPlayer` Property - muss migriert werden
- AudioSession-Konfiguration muss kompatibel bleiben

**Abhängigkeiten**: Keine (ist Voraussetzung für Cinematic Mode)---

## Phase 2: Cinematic Mode Implementation

### 2.1 EntrainmentMode erweitern

**Datei**: `MindSync/Models/EntrainmentMode.swift`

- `.cinematic` Case hinzufügen
- `frequencyRange`: `5.5...7.5` (Theta/Low Alpha Flow State)
- `targetFrequency`: `6.5` Hz (Mitte des Bereichs)
- `displayName`: "Cinematic"
- `description`: "Flow State Sync - Dynamisch & Reaktiv"
- `iconName`: "film.fill" (SF Symbol)

### 2.2 AudioEnergyTracker Service (NEU)

**Neue Datei**: `MindSync/Services/AudioEnergyTracker.swift`**Funktionalität**:

- Installiert Tap auf `mainMixerNode` der AVAudioEngine (aus AudioPlaybackService)
- Berechnet RMS (Root Mean Square) Energie pro Buffer
- Moving Average für Smoothing (`smoothingFactor = 0.95`, 5 Sekunden Window)
- Publisher für Echtzeit-Energie-Werte (`energyPublisher: PassthroughSubject<Float, Never>`)
- Normierte Werte (0.0 - 1.0)

**Methoden**:

- `startTracking(mixerNode: AVAudioMixerNode)` - Tap installieren
- `stopTracking()` - Tap entfernen
- `currentEnergy: Float` - Letzter berechneter Energie-Wert
- Private `calculateRMS(buffer: AVAudioPCMBuffer) -> Float`
- Private Moving Average State Management

**Threading**: Callbacks laufen auf Audio-Thread → Werte müssen auf Main-Thread publiziert werden

### 2.3 EntrainmentEngine: Cinematic Mode Logik

**Datei**: `MindSync/Core/Entrainment/EntrainmentEngine.swift`**Neue Methode**:

```swift
static func calculateCinematicIntensity(
    baseFrequency: Double,
    currentTime: TimeInterval,
    audioEnergy: Float
) -> Float
```

**Logik**:

1. **Frequency Drift**: `drift = sin(currentTime * 0.2) * 1.0` → `currentFreq = 6.5 + drift` (5.5-7.5 Hz Oszillation über 5-10 Sek)
2. **Base Wave**: Cosine-Welle für weichere Übergänge (nutze `cos()` statt `sin()` mit Phase-Offset)
3. **Audio Reactivity**: `baseIntensity = 0.3 + (audioEnergy * 0.7)` (Minimum 30%, bei hoher Energie bis 100%)
4. **Lens Flare**: Gamma-Korrektur für helle Bereiche (`pow(output, 0.5)` wenn > 0.8)

**Anpassungen in `generateLightEvents`**:

- Für `.cinematic` Mode: Generiere Basis-Events mit statischer Intensität 0.5 (wird zur Laufzeit dynamisch moduliert)
- Waveform: `.sine` (weich)

### 2.4 LightController: Dynamische Intensitäts-Modulation

**Dateien**:

- `MindSync/Core/Light/FlashlightController.swift`
- `MindSync/Core/Light/ScreenController.swift`

**Anpassungen in `updateLight()` (BaseLightController oder Subclasses)**:

- Prüfe ob `currentScript?.mode == .cinematic`
- Falls ja: Hole aktuelle Audio-Energie vom `AudioEnergyTracker`
- Berechne dynamische Intensität via `EntrainmentEngine.calculateCinematicIntensity`
- Multipliziere Event-Intensität mit dynamischem Faktor

**Alternative**: Neue Methode `calculateDynamicIntensity(event: LightEvent, energy: Float, currentTime: TimeInterval) -> Float` in BaseLightController**Hinweis**: Gamma-Korrektur ist bereits in FlashlightController implementiert

### 2.5 ServiceContainer & SessionViewModel Integration

**Datei**: `MindSync/Services/ServiceContainer.swift`

- `AudioEnergyTracker` als Service registrieren
- Lazy initialization

**Datei**: `MindSync/Features/Session/SessionViewModel.swift`

- `audioEnergyTracker: AudioEnergyTracker` Property hinzufügen (aus ServiceContainer)
- In `startSession`: Wenn Mode == `.cinematic`, starte Energy Tracking auf AudioPlaybackService's MixerNode
- In `stopSession`: Stop Energy Tracking
- Optional: Subscribe zu `energyPublisher` für zukünftige UI-Visualisierungen

**Abhängigkeiten**: Phase 1 (AudioPlaybackService Migration) muss abgeschlossen sein---

## Phase 3: Tests

### 3.1 Unit Tests

**Fehlende Tests**:

1. **`MindSyncTests/Unit/FrequencyMapperTests.swift`** (neu)

- Test `calculateMultiplier` für verschiedene Modi und BPMs
- Test `mapBPMToFrequency`
- Test `validateFrequency` (PSE-Zone, Limits)
- Test `recommendedFrequencyRange`

2. **`MindSyncTests/Unit/EntrainmentEngineTests.swift`** (neu)

- Test `calculateMultiplier` für verschiedene Modi
- Test LightScript-Generierung
- Test `calculateCinematicIntensity` (Phase 2.3)
- Test Edge Cases (sehr langsame/schnelle BPMs)

3. **`MindSyncTests/Unit/AudioEnergyTrackerTests.swift`** (neu)

- Test RMS-Berechnung mit Mock-Buffers
- Test Moving Average Smoothing
- Test Publisher-Verhalten
- Test Thread-Safety

4. **`MindSyncTests/Unit/AudioPlaybackServiceTests.swift`** (neu, nach Migration)

- Test AVAudioEngine-Setup
- Test Play/Pause/Resume/Stop
- Test MixerNode-Verfügbarkeit

5. **`MindSyncTests/Unit/ThermalManagerTests.swift`** (erweitern)

- Test `maxFlashlightIntensity` für verschiedene Thermal States
- Test `shouldSwitchToScreen` Logik
- Test Warning-Level-Berechnung

### 3.2 Integration Tests

1. **`MindSyncTests/Integration/AudioAnalyzerIntegrationTests.swift`** (neu)

- Integrationstest mit echten Audio-Dateien
- Test vollständiger Analyse-Flow
- Test Fehlerbehandlung (DRM, unsupported format)

2. **`MindSyncTests/Integration/CinematicModeIntegrationTests.swift`** (neu, nach Phase 2)

- Test vollständiger Cinematic Mode Flow
- Test AudioEnergyTracker Integration
- Test dynamische Intensitäts-Modulation

### 3.3 UI Tests

1. **`MindSyncUITests/SessionUITests.swift`** (neu)

- Test Flow: Song wählen → Session starten → Session stoppen
- Test Pause/Resume-Funktionalität
- Test Fehlerbehandlung (DRM-geschützte Songs)
- Test Cinematic Mode (nach Phase 2)

2. **`MindSyncUITests/SettingsUITests.swift`** (neu)

- Test Wechsel zwischen Taschenlampen- und Bildschirm-Modus
- Test Modus-Auswahl (inkl. Cinematic Mode)
- Test Einstellungen-Persistierung

---

## Phase 4: Lokalisierung

**Zweck**: Vollständige DE/EN Lokalisierung für alle User-facing Strings**Dateien**:

- `MindSync/Resources/Localizable.strings` (DE)
- `MindSync/Resources/en.lproj/Localizable.strings` (EN)

**Betroffene Dateien** (Strings extrahieren und lokalisieren):

- `OnboardingView.swift`
- `EpilepsyWarningView.swift`
- `HomeView.swift`
- `SessionView.swift`
- `SourceSelectionView.swift`
- `SettingsView.swift`
- `ModeSelectionView.swift` (teilweise bereits lokalisiert)
- `SafetyBanner.swift`
- `AnalysisProgressView.swift`
- Neue Cinematic Mode Strings (Phase 2)

**Struktur**: Konsistente Keys (z.B. `onboarding.title`, `session.pause`, `settings.lightSource`, `mode.cinematic.description`)**Status**: Teilweise bereits vorhanden (ModeSelectionView), muss vervollständigt werden---

## Phase 5: UI-Polish & Dokumentation

### 5.1 Design-Verbesserungen

**Betroffene Dateien**: `MindSync/Features/*/*.swift`**Verbesserungen**:

- Konsistente Farbpalette (nutze `Color+MindSync.swift` falls vorhanden)
- Verbesserte Typografie (Font-System konsistent nutzen)
- Spacing und Padding standardisieren
- Accessibility-Verbesserungen (VoiceOver Labels, Dynamic Type)
- Dark Mode Optimierungen

**Priorität**: Niedrig, kann schrittweise erfolgen

### 5.2 Logging erweitern

**Betroffene Dateien**:

- `AudioAnalyzer.swift` - Logger bereits vorhanden, erweitern
- `ThermalManager.swift` - Logging erweitern
- `FallDetector.swift` - Logger bereits vorhanden
- `MicrophoneAnalyzer.swift` - Logger bereits vorhanden
- `AudioEnergyTracker.swift` (neu) - Logger hinzufügen
- `AudioPlaybackService.swift` - Logger nach Migration hinzufügen

### 5.3 Dokumentation

**Datei**: `docs/architecture.md` (erweitern falls vorhanden, sonst neu)**Inhalt**:

- Architektur-Übersicht (High-Level Data Flow)
- Entrainment-Algorithmus Erklärung (BPM → Hz Mapping)
- Audio-Analyse Pipeline (FFT, Spectral Flux, Beat Detection)
- Light-Steuerung (Flashlight vs Screen)
- Cinematic Mode Architektur (Phase 2)
- Sicherheits-Features (Thermal, Fall Detection, PSE-Warnungen)
- Service-Container Pattern
- Testing-Strategie

---

## Abhängigkeiten und Implementierungsreihenfolge

### Kritische Abhängigkeiten

1. **Phase 1 (AudioPlaybackService Migration)** muss **vor Phase 2 (Cinematic Mode)** abgeschlossen sein
2. **Phase 2.2 (AudioEnergyTracker)** hängt von **Phase 1** ab
3. **Phase 2.3-2.5** hängen von **Phase 2.1-2.2** ab
4. **Phase 3 (Tests)** kann parallel zu anderen Phasen entwickelt werden (mit Mock-Objekten)
5. **Phase 4-5** können unabhängig implementiert werden

### Empfohlene Reihenfolge

1. **Phase 1**: AudioPlaybackService Migration (KRITISCH)
2. **Phase 2**: Cinematic Mode Implementation (2.1 → 2.2 → 2.3 → 2.4 → 2.5)
3. **Phase 3**: Tests (parallel möglich, aber nach Phase 1+2 für Integration Tests)
4. **Phase 4**: Lokalisierung (unabhängig)
5. **Phase 5**: UI-Polish & Dokumentation (unabhängig, niedrige Priorität)

---

## Konflikte und Lösungen

### Konflikt: AffirmationService nutzt AVAudioPlayer

**Problem**: AffirmationService erwartet `AVAudioPlayer` als Parameter, aber nach Migration gibt es nur noch AVAudioEngine.**Lösung**:

- Option A: AffirmationService nutzt separate AVAudioEngine (wie aktuell) und duckt die Haupt-Engine über AudioSession
- Option B: AffirmationService erhält MixerNode-Referenz und nutzt Volume-Control für Ducking
- **Empfehlung**: Option A (einfacher, weniger Kopplung)

### Konflikt: AudioEnergyTracker und AffirmationService

**Problem**: Beide benötigen Zugriff auf Audio-Engine, aber AffirmationService nutzt separate Engine.**Lösung**: AudioEnergyTracker nutzt nur die Haupt-Engine (AudioPlaybackService). AffirmationService bleibt unabhängig.---

## Technische Details (Cinematic Mode)

### Frequency Drift Formel

```javascript
drift = sin(time * 0.2) * 1.0  // Langsame Oszillation
currentFreq = 6.5 + drift       // 5.5 - 7.5 Hz
```



### Audio Reactivity Formel

```javascript
baseIntensity = 0.3 + (audioEnergy * 0.7)
cosineWave = cos(time * currentFreq * 2π)
output = (cosineWave + 1.0) / 2.0 * baseIntensity  // Normalisiert auf 0-1
if output > 0.8:
    output = pow(output, 0.5)  // Lens Flare Crispness
```



### Moving Average für Audio-Energie

```javascript
smoothingFactor = 0.95
averageEnergy = (averageEnergy * smoothingFactor) + (currentEnergy * (1.0 - smoothingFactor))





```