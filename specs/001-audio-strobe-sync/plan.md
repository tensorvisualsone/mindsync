# Implementation Plan: MindSync Core App

**Branch**: `001-audio-strobe-sync` | **Date**: 2025-12-23 | **Spec**: [spec.md](./spec.md)  
**Input**: Feature specification from `/specs/001-audio-strobe-sync/spec.md`

## Summary

MindSync ist eine iOS-App, die stroboskopisches Licht (Taschenlampe/Bildschirm) mit der persönlichen Musik des Nutzers synchronisiert, um veränderte Bewusstseinszustände durch Neural Entrainment zu induzieren. Der technische Ansatz basiert auf:

1. **Audio-Vorverarbeitung**: Vollständige Analyse des Songs vor der Wiedergabe mittels AVFoundation/AVAssetReader und Accelerate/vDSP für FFT-basierte Beat-Erkennung
2. **LightScript-Generierung**: Umwandlung der Audio-Analyse in eine zeitgesteuerte Sequenz von Licht-Ereignissen mit BPM-zu-Hz-Frequenzmapping
3. **Präzise Licht-Steuerung**: Synchrone Wiedergabe mit CADisplayLink (Bildschirm) oder High-Priority DispatchQueue (Taschenlampe)
4. **Sicherheits-First-Design**: Obligatorisches Epilepsie-Onboarding, thermisches Management, Fall-Erkennung

## Technical Context

**Language/Version**: Swift 5.9+ (Swift Concurrency, async/await)  
**Primary Dependencies**: SwiftUI, AVFoundation, Accelerate (vDSP), MediaPlayer, CoreMotion  
**Storage**: UserDefaults (Einstellungen), FileManager (LightScript-Cache), @AppStorage  
**Testing**: XCTest (Unit), XCUITest (UI), Swift Testing (neue Test-Makros)  
**Target Platform**: iOS 17.0+ (iPhone primär, iPad sekundär)  
**Project Type**: Mobile (single iOS app, kein Backend)  
**Performance Goals**: 
- App-Start < 2 Sekunden
- Audio-Analyse < 10 Sekunden für 5-Minuten-Track
- Licht-Synchronisation ±20ms Genauigkeit
- 60fps UI-Interaktionen  
**Constraints**: 
- Taschenlampe max. ~30-40 Hz zuverlässig
- Thermische Drosselung bei intensiver Taschenlampennutzung (>10 Min bei hoher Intensität)
- Nur DRM-freie lokale Dateien für präzise Analyse
- Mikrofon-Modus weniger präzise (~100ms Latenz)  
**Scale/Scope**: 
- ~10-15 Screens
- ~20 Views/Components
- Single-Developer-Wartbarkeit priorisiert

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Requirement | Status | Notes |
|-----------|-------------|--------|-------|
| **I. Mobile-First User Value** | Features als unabhängige, testbare User Journeys | ✅ Pass | 6 User Stories mit P1-P3 Priorisierung, jeweils unabhängig lieferbar |
| **II. iOS-Native Architecture** | Swift + SwiftUI, iOS 17+, HIG-konform, 60fps | ✅ Pass | Nativer Stack geplant, keine Cross-Platform |
| **III. Test-First Quality** | TDD, automatisierte Tests vor Release | ✅ Pass | XCTest/XCUITest geplant für alle P1/P2-Stories |
| **IV. Privacy & Data Minimization** | Nur notwendige Daten, lokal speichern | ✅ Pass | Keine Cloud, keine Accounts, nur lokale Präferenzen |
| **V. Simplicity & Maintainability** | Fokussierter Umfang, minimale Abstraktion | ✅ Pass | MVP-First, keine Over-Engineering |
| **Platform Constraints** | iOS 17+, Swift/SwiftUI, <2s Start, 60fps | ✅ Pass | Alle Constraints eingehalten |
| **Workflow Gates** | Spec vor Impl, Plan vor Code, Tasks nach Stories | ✅ Pass | Speckit-Workflow befolgt |

**Violations**: Keine - alle Prinzipien erfüllt.

## Project Structure

### Documentation (this feature)

```text
specs/001-audio-strobe-sync/
├── plan.md              # This file
├── spec.md              # Feature specification (created)
├── research.md          # Phase 0 output (to be created)
├── data-model.md        # Phase 1 output (to be created)
├── quickstart.md        # Phase 1 output (to be created)
├── contracts/           # Phase 1 output (internal APIs)
├── checklists/
│   └── requirements.md  # Spec quality checklist (created)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
MindSync/
├── App/
│   ├── MindSyncApp.swift           # App entry point, @main
│   └── AppState.swift              # Global app state, onboarding status
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift         # Safety disclaimer flow
│   │   ├── EpilepsyWarningView.swift    # Mandatory epilepsy confirmation
│   │   └── OnboardingViewModel.swift    # Onboarding state management
│   │
│   ├── Home/
│   │   ├── HomeView.swift               # Main navigation hub
│   │   ├── ModeSelectionView.swift      # Alpha/Theta/Gamma mode picker
│   │   └── SourceSelectionView.swift    # Library vs Microphone picker
│   │
│   ├── Session/
│   │   ├── SessionView.swift            # Active stroboscope session UI
│   │   ├── SessionViewModel.swift       # Session orchestration
│   │   ├── SessionControlsView.swift    # Gesture-based controls (swipe/tap)
│   │   └── AnalysisProgressView.swift   # "Extracting beats..." loading
│   │
│   └── Settings/
│       ├── SettingsView.swift           # User preferences
│       └── LightSourcePicker.swift      # Flashlight vs Screen toggle
│
├── Core/
│   ├── Audio/
│   │   ├── AudioAnalyzer.swift          # Main analysis coordinator
│   │   ├── BeatDetector.swift           # FFT-based onset detection
│   │   ├── TempoEstimator.swift         # BPM calculation
│   │   ├── AudioFileReader.swift        # AVAssetReader wrapper
│   │   └── MicrophoneAnalyzer.swift     # Real-time mic input analysis
│   │
│   ├── Light/
│   │   ├── LightController.swift        # Protocol for light sources
│   │   ├── FlashlightController.swift   # AVCaptureDevice torch control
│   │   ├── ScreenController.swift       # SwiftUI fullscreen color flashing
│   │   └── ThermalManager.swift         # ProcessInfo thermal monitoring
│   │
│   ├── Entrainment/
│   │   ├── EntrainmentEngine.swift      # BPM-to-Hz mapping algorithm
│   │   ├── LightScript.swift            # Timed light event sequence
│   │   ├── FrequencyMapper.swift        # Target brainwave bands
│   │   └── WaveformGenerator.swift      # Sine/square wave patterns
│   │
│   └── Safety/
│       ├── FallDetector.swift           # CoreMotion accelerometer
│       └── SafetyLimits.swift           # Frequency bounds, thermal limits
│
├── Models/
│   ├── Session.swift                    # Session entity
│   ├── AudioTrack.swift                 # Track metadata + beat map
│   ├── EntrainmentMode.swift            # Alpha/Theta/Gamma definitions
│   └── UserPreferences.swift            # Persisted settings
│
├── Services/
│   ├── MediaLibraryService.swift        # MPMediaPickerController wrapper
│   ├── AudioPlaybackService.swift       # AVAudioPlayer management
│   ├── SessionHistoryService.swift      # Session logging
│   └── PermissionsService.swift         # Microphone/Media Library auth
│
├── Shared/
│   ├── Extensions/
│   │   ├── Color+MindSync.swift         # App color palette
│   │   └── View+Gestures.swift          # Swipe/tap gesture modifiers
│   ├── Components/
│   │   ├── LargeButton.swift            # Accessible large buttons
│   │   ├── ProgressRing.swift           # Circular progress indicator
│   │   └── SafetyBanner.swift           # Warning banners
│   └── Constants.swift                  # App-wide constants
│
└── Resources/
    ├── Assets.xcassets/                 # App icons, colors
    ├── Localizable.strings              # German/English localization
    └── Info.plist                       # Permissions descriptions

MindSyncTests/
├── Unit/
│   ├── BeatDetectorTests.swift
│   ├── TempoEstimatorTests.swift
│   ├── FrequencyMapperTests.swift
│   └── ThermalManagerTests.swift
└── Integration/
    ├── AudioAnalyzerIntegrationTests.swift
    └── SessionFlowTests.swift

MindSyncUITests/
├── OnboardingUITests.swift
├── SessionUITests.swift
└── SettingsUITests.swift
```

**Structure Decision**: Single iOS App ohne Backend. Feature-basierte Ordnerstruktur für klare Verantwortlichkeiten. `Core/` enthält die geschäftskritische Logik (Audio, Light, Entrainment), `Features/` die UI-Screens, `Services/` die System-Integrationen. Diese Struktur ermöglicht parallele Entwicklung der User Stories und klare Test-Abgrenzung.

## Architecture Overview

### High-Level Data Flow

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

### Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Audio Analysis Timing | Pre-processing (nicht Echtzeit) | Präzisere Synchronisation, keine Wiedergabe-Latenz |
| FFT Window Size | 1024-2048 Samples | Balance zwischen Frequenz- und Zeit-Auflösung |
| Beat Detection | Spectral Flux + Onset Detection | Robuster als reine Amplitude, erkennt auch leise Beats |
| Flashlight API | Single `lockForConfiguration()` pro Session | Vermeidet Lock-Overhead bei jedem Beat |
| Screen Strobing | `CADisplayLink` + SwiftUI Color | Präzises Frame-Timing, nutzt ProMotion (120Hz) |
| Thermal Management | `ProcessInfo.thermalState` Observer | Native iOS API, reagiert auf System-Events |
| State Management | `@Observable` (iOS 17+) | Moderner Swift, weniger Boilerplate als Combine |

### Entrainment Algorithm (Frequenzzuordnung)

```
f_target = (BPM / 60) × N

Wobei N (Multiplikator) so gewählt wird, dass f_target im Zielband liegt:
- Alpha (Entspannung): 8-12 Hz
- Theta (Trip):        4-8 Hz
- Gamma (Fokus):       30-40 Hz

Beispiel: Song mit 120 BPM
- Grundfrequenz: 2 Hz
- Alpha-Modus: N=5 → 10 Hz ✓
- Theta-Modus: N=3 → 6 Hz ✓
- Gamma-Modus: N=18 → 36 Hz ✓
```

### Safety Constraints (hardcodiert)

| Constraint | Wert | Grund |
|------------|------|-------|
| Min. Frequenz (mit Warnung) | 3 Hz | PSE-Gefahrenzone beginnt |
| Max. Frequenz (Flashlight) | 40 Hz | Hardware-Limit für zuverlässiges Schalten |
| Max. Flashlight Intensity (sustained) | 0.5 | Thermische Schonung |
| Thermal Warning Threshold | `.serious` | iOS ProcessInfo.ThermalState |
| Fall Detection Threshold | 2.0g Acceleration | CoreMotion Beschleunigung |

## Phase 0: Research Summary

Die ausführliche Recherche liegt bereits vor in `/research/iOS App Concept_ MindSync Development de.pdf`. Kernerkenntnisse:

### Audio-Analyse (iOS)
- **DRM-Barriere**: Apple Music/Spotify-Streams sind für DSP nicht zugänglich. Nur lokale DRM-freie Dateien (MP3, AAC via iTunes-Kauf oder Import) können analysiert werden.
- **Empfohlene Pipeline**: `AVAssetReader` → PCM → `vDSP` FFT → Spectral Flux → Onset Detection → BPM
- **Mikrofon-Workaround**: `AVAudioEngine.installTap()` für Echtzeit-Analyse, aber ~100ms Latenz

### Licht-Steuerung (iOS)
- **Taschenlampe**: `AVCaptureDevice.setTorchModeOn(level:)` - variable Intensität 0.0-1.0, aber max. ~30-40 Hz stabil
- **Bildschirm**: `CADisplayLink` für 60/120 Hz präzises Timing, OLED ermöglicht echtes Schwarz und Farbmodulation
- **Thermik**: Taschenlampe bei Dauerbetrieb problematisch, iOS deaktiviert sie bei Überhitzung

### Neurowissenschaft
- **Photic Driving**: Gehirnwellen synchronisieren sich mit Lichtfrequenz (3-40 Hz)
- **Frequenzbänder**: Alpha (8-12 Hz) = Entspannung, Theta (4-8 Hz) = Trip, Gamma (30-40 Hz) = Fokus
- **PSE-Risiko**: 3-30 Hz ist der gefährliche Bereich für photosensitive Epilepsie

### Regulatorik
- **App Store**: Keine medizinischen Claims ("heilt", "behandelt"), nur Wellness ("fördert", "unterstützt")
- **Epilepsie-Warnung**: Obligatorisch, deutlich sichtbar, Bestätigung erforderlich

## Complexity Tracking

> **Keine Verstöße gegen die Constitution festgestellt.**

| Bereich | Komplexität | Begründung |
|---------|-------------|------------|
| Audio-Analyse | Mittel | FFT/vDSP ist komplex, aber gut dokumentiert (Apple Sample Code) |
| Licht-Steuerung | Niedrig | Klare iOS APIs, gut verstanden |
| Entrainment-Algorithmus | Mittel | Mathematisch einfach, aber erfordert Feintuning |
| UI/UX | Niedrig | Standard SwiftUI, keine komplexen Animationen |
| Sicherheit | Niedrig | Klare Regeln, einfache Implementierung |

**Gesamtbewertung**: Das Projekt ist für einen einzelnen iOS-Entwickler machbar. Die größte Herausforderung ist die Audio-Analyse, aber Apple stellt gute Dokumentation und Sample Code bereit.

## Next Steps

1. **Phase 0 abschließen**: `research.md` mit konkreten API-Referenzen erstellen
2. **Phase 1 Design**: `data-model.md` mit Swift-Structs, `contracts/` mit Service-Protokollen
3. **Phase 1 Quickstart**: `quickstart.md` für lokale Entwicklungsumgebung
4. **Phase 2 Tasks**: `/speckit.tasks` für detaillierte Implementierungsaufgaben

---

**Plan Version**: 1.0.0 | **Author**: AI Assistant | **Review Status**: Draft

