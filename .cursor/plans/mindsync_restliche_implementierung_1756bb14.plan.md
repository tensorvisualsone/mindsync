---
name: MindSync Restliche Implementierung
overview: "Vollständiger Implementierungsplan für die verbleibenden Features: Mikrofon-Modus, Fall-Erkennung, Tests, UI-Verbesserungen, Lokalisierung und Dokumentation."
todos: []
---

# Plan: Restliche Implemen

Implementierung für MindSync

## Übersicht

Dieser Plan deckt alle verbleibenden Aufgaben ab, die noch nicht implementiert sind. Das MVP (US1 + US2) ist funktionsfähig, aber es fehlen noch:

1. **Mikrofon-Modus** (US4, P3) - Vollständige Implementierung
2. **Fall-Erkennung** - Vollständige Implementierung  
3. **ModeSelectionView** - UI für Modus-Auswahl
4. **Tests** - Fehlende Unit- und UI-Tests
5. **Lokalisierung** - DE/EN vollständig
6. **Polish** - Design-Verbesserungen, Logging, Dokumentation

## Phase 1: Fehlende Core-Komponenten

### 1.1 MicrophoneAnalyzer vollständig implementieren

**Datei**: `MindSync/Core/Audio/MicrophoneAnalyzer.swift`**Aktueller Stand**: Nur Platzhalter-Klasse vorhanden**Implementierung**:

- `AVAudioEngine` Setup mit Input-Node
- `installTap(on:bufferSize:format:)` für Live-Audio-Aufnahme
- Echtzeit-FFT-Analyse (ähnlich wie `BeatDetector`, aber streaming)
- Beat-Erkennung mit adaptivem Threshold
- BPM-Schätzung aus Live-Beats
- Publisher für Beat-Events (`PassthroughSubject<TimeInterval, Never>`)
- Fehlerbehandlung für Mikrofon-Berechtigungen
- Graceful Shutdown bei fehlendem Signal

**Abhängigkeiten**:

- Nutzt `BeatDetector`-Logik für FFT
- Nutzt `TempoEstimator` für BPM
- Nutzt `PermissionsService` für Berechtigungen

### 1.2 FallDetector vollständig implementieren

**Datei**: `MindSync/Core/Safety/FallDetector.swift`**Aktueller Stand**: Nur Platzhalter-Klasse vorhanden**Implementierung**:

- `CMMotionManager` Setup
- Accelerometer-Monitoring mit Update-Intervall (10-20 Hz)
- Fall-Erkennung basierend auf `SafetyLimits.fallAccelerationThreshold` (2.0g)
- Freefall-Erkennung bei <0.3g (optional)
- Publisher für Fall-Events (`PassthroughSubject<Void, Never>`)
- Integration in `SessionViewModel` zum automatischen Stoppen der Session
- Energieeffizienz: Nur aktiv während laufender Sessions

**Abhängigkeiten**:

- Nutzt `SafetyLimits` für Thresholds
- Wird von `SessionViewModel` beobachtet

### 1.3 WaveformGenerator implementieren

**Datei**: `MindSync/Core/Entrainment/WaveformGenerator.swift`**Aktueller Stand**: Datei existiert, aber leer**Implementierung**:

- Funktionen zur Berechnung von Wellenformen (Square, Sine, Triangle)
- Zeitbasierte Intensitäts-Berechnung für gegebene Frequenz
- Unterstützung für sanfte Pausierung bei ausbleibendem Signal (für Mikrofon-Modus)
- Integration in `ScreenController` für Waveform-Rendering

**Abhängigkeiten**:

- Wird von `EntrainmentEngine` und `ScreenController` genutzt

### 1.4 FrequencyMapper implementieren

**Datei**: `MindSync/Core/Entrainment/FrequencyMapper.swift`**Aktueller Stand**: Datei existiert, aber leer**Implementierung**:

- Mapping-Logik für BPM → Hz basierend auf `EntrainmentMode`
- Validierung gegen `SafetyLimits` (PSE-Gefahrenzone, min/max Frequenzen)
- Helper-Funktionen für Frequenz-Berechnungen
- Integration in `EntrainmentEngine` (kann Code aus `EntrainmentEngine.calculateMultiplier` refactoren)

**Abhängigkeiten**:

- Nutzt `EntrainmentMode` und `SafetyLimits`
- Wird von `EntrainmentEngine` genutzt

## Phase 2: UI-Komponenten

### 2.1 ModeSelectionView implementieren

**Datei**: `MindSync/Features/Home/ModeSelectionView.swift`**Aktueller Stand**: Datei existiert, aber leer**Implementierung**:

- Grid oder Liste mit drei Modi (Alpha, Theta, Gamma)
- Jeder Modus zeigt: Icon, Name, Beschreibung, Ziel-Frequenz-Band
- Auswahl speichert in `UserPreferences.preferredMode`
- Haptic Feedback bei Moduswechsel (wenn aktiviert)
- Integration in `HomeView` als Sheet oder Navigation

**Abhängigkeiten**:

- Nutzt `EntrainmentMode` und `UserPreferences`
- Verbindet mit `SessionViewModel` für aktive Sessions

### 2.2 SourceSelectionView erweitern

**Datei**: `MindSync/Features/Home/SourceSelectionView.swift`**Aktueller Stand**: Mikrofon-Button ist deaktiviert**Implementierung**:

- Mikrofon-Button aktivieren
- Berechtigungsabfrage über `PermissionsService`
- Flow für Mikrofon-Modus: Direkt zu `SessionView` ohne Song-Auswahl
- Info-Hinweis: "Mikrofon-Modus ist weniger präzise als lokale Analyse (~100ms Latenz)"

**Abhängigkeiten**:

- Nutzt `PermissionsService` und `MicrophoneAnalyzer`

## Phase 3: SessionViewModel Erweiterungen

### 3.1 Mikrofon-Modus Flow

**Datei**: `MindSync/Features/Session/SessionViewModel.swift`**Erweiterungen**:

- Neue Methode `startMicrophoneSession()` 
- Live-Beat-Events von `MicrophoneAnalyzer` empfangen
- Dynamische `LightScript`-Generierung basierend auf Live-BPM
- Fallback bei ausbleibendem Signal (sanfte Pausierung)
- Integration mit `WaveformGenerator` für Signal-Pausierung

**Abhängigkeiten**:

- Nutzt `MicrophoneAnalyzer`, `EntrainmentEngine`, `WaveformGenerator`

### 3.2 Fall-Erkennung Integration

**Datei**: `MindSync/Features/Session/SessionViewModel.swift`**Erweiterungen**:

- Observer für `FallDetector` Fall-Events
- Automatisches Stoppen der Session bei erkanntem Fall
- Session-End-Reason `.fallDetected` setzen
- UI-Feedback (Alert oder Toast)

**Abhängigkeiten**:

- Nutzt `FallDetector` aus `ServiceContainer`

## Phase 4: Tests

### 4.1 Unit Tests

**Fehlende Tests** (laut `tasks.md`):

1. **`MindSyncTests/Unit/FrequencyMapperTests.swift`** (neu)

- Test `EntrainmentMode.frequencyRange`
- Test `targetFrequency` Berechnung
- Test Frequenz-Mapping für verschiedene BPMs

2. **`MindSyncTests/Unit/EntrainmentEngineTests.swift`** (neu)

- Test `calculateMultiplier` für verschiedene Modi
- Test LightScript-Generierung
- Test Edge Cases (sehr langsame/schnelle BPMs)

3. **`MindSyncTests/Unit/MicrophoneAnalyzerTests.swift`** (neu)

- Test Live-Beat-Erkennung mit synthetischen Audio-Daten
- Test BPM-Schätzung
- Test Fehlerbehandlung (keine Berechtigung, kein Signal)

4. **`MindSyncTests/Unit/ThermalManagerTests.swift`** (erweitern)

- Test `maxFlashlightIntensity` für verschiedene Thermal States
- Test `shouldSwitchToScreen` Logik
- Test Warning-Level-Berechnung

5. **`MindSyncTests/Integration/AudioAnalyzerIntegrationTests.swift`** (neu)

- Integrationstest mit echten Audio-Dateien
- Test vollständiger Analyse-Flow
- Test Fehlerbehandlung (DRM, unsupported format)

### 4.2 UI Tests

**Fehlende Tests**:

1. **`MindSyncUITests/SessionUITests.swift`** (neu)

- Test Flow: Song wählen → Session starten → Session stoppen
- Test Pause/Resume-Funktionalität
- Test Fehlerbehandlung (DRM-geschützte Songs)

2. **`MindSyncUITests/SettingsUITests.swift`** (neu)

- Test Wechsel zwischen Taschenlampen- und Bildschirm-Modus
- Test Modus-Auswahl
- Test Einstellungen-Persistierung

## Phase 5: Lokalisierung

### 5.1 Localizable.strings erstellen

**Datei**: `MindSync/Resources/Localizable.strings` (DE) und `MindSync/Resources/en.lproj/Localizable.strings` (EN)**Implementierung**:

- Alle User-facing Strings extrahieren
- Strukturierte Keys (z.B. `onboarding.title`, `session.pause`, `settings.lightSource`)
- Deutsche und englische Übersetzungen
- Integration in Views mit `NSLocalizedString` oder `LocalizedStringKey`

**Betroffene Dateien** (Strings extrahieren):

- `OnboardingView.swift`
- `EpilepsyWarningView.swift`
- `HomeView.swift`
- `SessionView.swift`
- `SourceSelectionView.swift`
- `SettingsView.swift`
- `ModeSelectionView.swift` (nach Implementierung)
- `SafetyBanner.swift`
- `AnalysisProgressView.swift`

## Phase 6: Polish & Verbesserungen

### 6.1 Logging erweitern

**Datei**: `MindSync/Services/SessionHistoryService.swift`**Erweiterungen**:

- Logging für Session-Start/-Ende bereits vorhanden (os.log)
- Erweitern um:
- Fehler-Logging in `AudioAnalyzer`
- Thermal-Warnungen in `ThermalManager`
- Fall-Erkennung in `FallDetector`
- Mikrofon-Modus Events

**Betroffene Dateien**:

- `AudioAnalyzer.swift` - Logger hinzufügen
- `ThermalManager.swift` - Logging erweitern
- `FallDetector.swift` - Logger hinzufügen
- `MicrophoneAnalyzer.swift` - Logger hinzufügen

### 6.2 Design-Verbesserungen

**Betroffene Dateien**: `MindSync/Features/*/*.swift`**Verbesserungen**:

- Konsistente Farbpalette (nutze `Color+MindSync.swift` falls vorhanden)
- Verbesserte Typografie (Font-System konsistent nutzen)
- Spacing und Padding standardisieren
- Accessibility-Verbesserungen (VoiceOver Labels, Dynamic Type)
- Dark Mode Optimierungen

**Priorität**: Niedrig, kann schrittweise erfolgen

### 6.3 Dokumentation

**Datei**: `docs/architecture.md` (neu erstellen)**Inhalt**:

- Architektur-Übersicht (High-Level Data Flow)
- Entrainment-Algorithmus Erklärung (BPM → Hz Mapping)
- Audio-Analyse Pipeline (FFT, Spectral Flux, Beat Detection)
- Light-Steuerung (Flashlight vs Screen)
- Sicherheits-Features (Thermal, Fall Detection, PSE-Warnungen)
- Service-Container Pattern
- Testing-Strategie

## Abhängigkeiten und Reihenfolge

### Kritische Abhängigkeiten

1. **Phase 1.1-1.4** (Core-Komponenten) müssen vor **Phase 2-3** (UI/Integration) implementiert werden
2. **Phase 2.1** (ModeSelectionView) kann parallel zu **Phase 1** laufen
3. **Phase 3** (SessionViewModel) hängt von **Phase 1** ab
4. **Phase 4** (Tests) kann parallel zu anderen Phasen entwickelt werden
5. **Phase 5-6** (Lokalisierung, Polish) können unabhängig implementiert werden

### Empfohlene Reihenfolge

1. **Phase 1**: Core-Komponenten (MicrophoneAnalyzer, FallDetector, WaveformGenerator, FrequencyMapper)
2. **Phase 2**: UI-Komponenten (ModeSelectionView, SourceSelectionView Erweiterungen)
3. **Phase 3**: SessionViewModel Integration
4. **Phase 4**: Tests (parallel möglich)
5. **Phase 5**: Lokalisierung
6. **Phase 6**: Polish & Dokumentation