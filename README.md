# MindSync

**Neural Entrainment für veränderte Bewusstseinszustände durch audio-synchronisierte Lichtstimulation**

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

---

## 🌟 Kurzüberblick

MindSync ist eine iOS-App für **Neural Entrainment**: Audio-analysierte, stroboskopische Lichtmuster werden mit deiner Musik synchronisiert, um gezielt bestimmte Gehirnwellen-Bereiche anzuregen (z.B. Entspannung, Fokus, tiefe Meditation).

- Personalisierte Erfahrung: Analyse deiner Musik in Echtzeit  
- Mehrere Entrainment-Modi: Alpha, Theta, Gamma & Cinematic  
- Dual-Lichtquellen: Taschenlampe oder farbiger Bildschirm  
- Sicherheit first: Epilepsie-Onboarding, Frequenz-Limits, Thermal-Management  

Für Vision, Wissenschaft & Roadmap siehe `docs/CONCEPT_AND_ROADMAP.md`.

---

## 🧠 Neural Entrainment (Kurz erklärt)

**Neural Entrainment** ist die Anpassung der Gehirnaktivität an externe Rhythmen (z.B. Lichtblitze). MindSync nutzt dieses Prinzip, indem es Lichtimpulse in definierter Frequenz mit der Energie und den Beats der Musik kombiniert.

Die ausführliche neurowissenschaftliche Herleitung findest du in `docs/CONCEPT_AND_ROADMAP.md`.

---

## 🎯 Was macht MindSync einzigartig?

Im Gegensatz zu Apps wie Lumenate, die vorgefertigte, statische Inhalte verwenden:

✨ **Personalisierte Erfahrung**: MindSync analysiert DEINE Musik in Echtzeit
🎵 **Dynamische Synchronisation**: Lichtmuster passen sich an Beats, Tempo und Energie deiner Tracks an
🎨 **Cinematic Mode**: Beat-synchronisierte Pulse - die Lampe blitzt kurz auf Beats auf und geht zwischen Beats aus, für eine klare, musik-synchronisierte Erfahrung
🔬 **Wissenschaftlich fundiert**: Basiert auf etablierten Prinzipien des Neural Entrainment
💡 **Dual-Lichtquellen**: Wähle zwischen intensiver Taschenlampe oder farbigem Bildschirm
🎤 **Mikrofon-Modus**: Funktioniert auch mit Streaming-Diensten wie Spotify

---

## 🧘 Entrainment-Modi (Überblick)

- **Alpha (8–13 Hz)**: Entspannung & Stressabbau  
- **Theta (4–8 Hz)**: Tiefe Meditation & Trips  
- **Gamma (30–100 Hz)**: Fokus & High-Performance  
- **Cinematic**: Beat-synchronisierte Pulse - kurze Lichtblitze auf Beats, aus zwischen Beats  

Details zu den Parametern der einzelnen Modi stehen in `docs/CONCEPT_AND_ROADMAP.md`.

---

## 🛡️ Sicherheit steht an erster Stelle

### ⚠️ KRITISCHE WARNUNG

> **Diese App verwendet stroboskopisches Licht, das bei Menschen mit photosensitiver Epilepsie Anfälle auslösen kann.**
>
> **Verwenden Sie MindSync NICHT, wenn Sie:**
> - Eine Vorgeschichte mit Krampfanfällen haben
> - Photosensitive Epilepsie haben
> - Familienmitglieder mit Epilepsie haben
> - Sich unsicher über Ihre Eignung fühlen

### Eingebaute Sicherheitsfeatures

✅ **Verpflichtendes Epilepsie-Onboarding**: Jeder Benutzer muss die Risiken bestätigen
✅ **Thermisches Management**: Automatische Intensitätsreduzierung bei Überhitzung
✅ **Fall-Erkennung**: Session stoppt automatisch bei erkanntem Fall
✅ **Frequenz-Limits**: Alle Modi bleiben in sicheren Frequenzbereichen (< 25 Hz Strobe-Rate)
✅ **Emergency Stop**: Jederzeit per Bildschirmtipp beendbar

**Rechtlicher Hinweis**: MindSync ist ein Wellness-Produkt, kein medizinisches Gerät. Es macht keine therapeutischen oder medizinischen Versprechen. Konsultieren Sie einen Arzt vor der Verwendung.

---

## ✨ Kernfeatures

### 🎵 Audio-Analyse & Synchronisation
- **Beat-Detection**: FFT-basierte Erkennung von Beats und Tempo
- **Tempo-Estimation**: Automatische BPM-Analyse
- **Audio-Energie-Tracking**: Echtzeit-Messung der Audio-Intensität mit Spectral Flux für präzise Beat-Erkennung (Cinematic Mode)
- **Unterstützte Quellen**: 
  - Lokale Musikbibliothek (Apple Music/iTunes)
  - Mikrofon-Modus (für Streaming-Dienste)

### 💡 Licht-Steuerung
- **Taschenlampe**: Maximale Intensität für geschlossene Augen
- **Bildschirm**: Präzise Farbsteuerung und sanftere Übergänge
- **Präzisions-Timing**: CADisplayLink für frame-genaue Synchronisation
- **Dynamische Anpassung**: Thermal Management passt Intensität automatisch an

### 🎨 Visuelle Anpassung
- **Waveforms**: Sinus, Dreieck, Rechteck - je nach Modus
- **Farbpalette**: 
  - Weiß (maximale Intensität)
  - Blau (beruhigend)
  - Grün (harmonisierend)
  - Violett (spirituell)
  - Custom RGB
- **Intensitätskontrolle**: Pro Modus optimiert

### 📊 Session-Tracking
- **Vollständige Historie**: Alle Sessions werden gespeichert
- **Statistiken**: 
  - Gesamtdauer aller Sessions
  - Anzahl Sessions
  - Verwendete Modi
- **Filterung**: Nach Entrainment-Modus filtern
- **Persistenz**: Automatisches Speichern via UserDefaults (max. 100 Sessions)

---

## 🛠️ Technologie-Stack

### Kern-Technologien

| Bereich | Technologie | Verwendung |
|---------|-------------|------------|
| **Sprache** | Swift 5.9+ | async/await, @MainActor, modern concurrency |
| **UI-Framework** | SwiftUI | Deklarative UI, @Observable pattern |
| **Audio-Playback** | AVAudioEngine | Echtzeit-Audio mit Mixer-Node-Zugriff |
| **Audio-Analyse** | AVFoundation + Accelerate | FFT, vDSP, Beat Detection |
| **Licht-Steuerung** | AVCaptureDevice + CADisplayLink | Torch API + 120Hz Display Sync |
| **Bewegungs-Sensor** | CoreMotion | Fall-Erkennung |
| **Persistenz** | UserDefaults + Codable | Session History Storage |
| **Thermal Management** | ProcessInfo | Geräte-Temperatur-Monitoring |
| **Minimum iOS** | 17.0 | Nutzt neueste SwiftUI Features |

### Architektur-Prinzipien

🏗️ **Feature-Based Structure**: Jedes Feature ist eigenständig organisiert
🔌 **Protocol-Oriented**: Alle Services implementieren testbare Protokolle
🧪 **Test-Driven**: Unit Tests + UI Tests + Integration Tests
🔒 **Thread-Safety**: @MainActor für UI, Background Queues für Audio
📦 **Service Container**: Zentrale Dependency Injection
⚡ **Performance**: Optimiert für Echtzeit-Audio-Verarbeitung

---

## 📁 Projektstruktur

```
mindsync/
├── MindSync/                         # Haupt-App-Target
│   ├── App/                          # App-Lifecycle & State
│   │   ├── MindSyncApp.swift         # App Entry Point (SwiftUI)
│   │   └── AppState.swift            # Zentraler App-Status
│   │
│   ├── Features/                     # Feature-Module (SwiftUI-Screens)
│   │   ├── Onboarding/               # Epilepsie-Warnung & Erste Schritte
│   │   ├── Home/                     # Hauptbildschirm & Navigation
│   │   ├── Session/                  # Aktive Entrainment-Session
│   │   ├── Settings/                 # App-Einstellungen & Präferenzen
│   │   └── History/                  # Session-Historie & Statistiken
│   │
│   ├── Core/                         # Kern-Komponenten (Framework-agnostisch)
│   │   ├── Audio/                    # Audio-Analyse
│   │   │   ├── AudioAnalyzer.swift
│   │   │   ├── AudioFileReader.swift
│   │   │   ├── BeatDetector.swift
│   │   │   ├── SpectralFluxDetector.swift
│   │   │   └── TempoEstimator.swift
│   │   │
│   │   ├── Entrainment/              # Entrainment-Logik
│   │   │   ├── EntrainmentEngine.swift
│   │   │   ├── FrequencyMapper.swift
│   │   │   ├── LightScript.swift
│   │   │   └── WaveformGenerator.swift
│   │   │
│   │   ├── Light/                    # Licht-Steuerung
│   │   │   ├── BaseLightController.swift
│   │   │   ├── FlashlightController.swift
│   │   │   ├── LightController.swift
│   │   │   └── ScreenController.swift
│   │   │
│   │   ├── Safety/                   # Sicherheits-Features
│   │   │   ├── ThermalManager.swift
│   │   │   ├── SafetyLimits.swift
│   │   │   └── FallDetector.swift
│   │   │
│   │   ├── Sync/                     # Latenz & Synchronisation
│   │   │   └── BluetoothLatencyMonitor.swift
│   │   │
│   │   └── Vibration/                # Haptische Entrainment-Komponenten
│   │       ├── VibrationController.swift
│   │       ├── VibrationEvent.swift
│   │       └── VibrationScript.swift
│   │
│   ├── Models/                       # Datenmodelle
│   │   ├── AudioTrack.swift          # Repräsentation eines Audiotracks
│   │   ├── EntrainmentMode.swift     # Alpha/Theta/Gamma/Cinematic
│   │   ├── Session.swift             # Session-Daten
│   │   └── UserPreferences.swift     # Nutzerpräferenzen
│   │
│   ├── Services/                     # Business Logic & System-Services
│   │   ├── ServiceContainer.swift    # DI Container
│   │   ├── AudioPlaybackService.swift
│   │   ├── AudioEnergyTracker.swift
│   │   ├── MediaLibraryService.swift
│   │   ├── PermissionsService.swift
│   │   ├── SessionHistoryService.swift
│   │   └── AffirmationOverlayService.swift
│   │
│   └── Shared/                       # Wiederverwendbare Bausteine
│       ├── Components/               # UI-Komponenten
│       ├── Extensions/               # Swift-Extensions
│       ├── Theme/                    # Farben & Typografie
│       ├── MathHelpers.swift         # Mathematische Hilfsfunktionen
│       ├── Constants.swift           # App-weite Konstanten
│       └── Resources/                # Lokalisierungen & Strings
│
├── MindSyncTests/                    # Unit & Integration Tests
│   ├── Unit/                         # Isolierte Unit Tests
│   └── Integration/                  # Integrations-Tests
│
├── MindSyncUITests/                  # UI Tests (XCTest)
│
├── docs/                             # High-Level Dokumentation
│
├── specs/                            # Detaillierte Spezifikationen
│   └── 001-audio-strobe-sync/        # Haupt-Spezifikation für Audio-Licht-Sync
│
└── README.md                         # Diese Datei
```

---

## 🚀 Schnellstart für Entwickler

### Voraussetzungen

- macOS Sonoma 14.0+
- Xcode 15.0+
- iPhone (für echte Taschenlampen-Tests)
- Apple Developer Account (für Device Testing)

### Installation

```bash
# Repository klonen
git clone <repository-url>
cd mindsync

# Xcode öffnen
open MindSync/MindSync.xcodeproj

# Auf echtem Gerät testen (empfohlen)
# 1. iPhone anschließen
# 2. In Xcode: Scheme "MindSync" wählen
# 3. Zielgerät auswählen
# 4. ⌘R drücken
```

### Erste Schritte

1. **Musik vorbereiten**: Lokale Musik in Apple Music/iTunes
2. **Epilepsie-Warning**: Beim ersten Start bestätigen
3. **Modus wählen**: Alpha für erste Erfahrung empfohlen
4. **Augen schließen**: Beste Erfahrung mit geschlossenen Augen
5. **Genießen**: 5-15 Minuten pro Session

---

## 🧪 Testing

### Unit Tests ausführen

```bash
# Alle Unit Tests
xcodebuild test \
  -project MindSync/MindSync.xcodeproj \
  -scheme MindSync \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MindSyncTests

# Spezifische Test Suite
xcodebuild test \
  -project MindSync/MindSync.xcodeproj \
  -scheme MindSync \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MindSyncTests/AudioAnalyzerTests
```

### UI Tests ausführen

```bash
xcodebuild test \
  -project MindSync/MindSync.xcodeproj \
  -scheme MindSync \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -only-testing:MindSyncUITests
```

### Test Coverage

Die Test-Suite umfasst unter anderem:
- ✅ Audio-Analyse-Algorithmen
- ✅ Beat-Detection-Logik
- ✅ Entrainment-Engine-Berechnungen
- ✅ Licht-Controller-Synchronisation
- ✅ Safety-Feature-Validierung
- ✅ Session-History-Management
- ✅ UI-Interaktions-Flows

---

## 🎯 Roadmap (Kurzfassung)

Der aktuelle Status inkl. abgeschlossener Phasen und geplanter Features ist in `docs/CONCEPT_AND_ROADMAP.md` dokumentiert.

---

## 🏗️ Architektur (Kurzüberblick)

- Audio-Pipeline: `AVAudioEngine` → FFT (Accelerate) → Beat-/Tempo-Detection → `EntrainmentEngine` → Licht-/Vibrations-Controller  
- Architekturprinzipien: Feature-basiert, protocollastig, testgetrieben, Service-Container für DI  
- Details: Siehe `docs/architecture.md`, `docs/SYNC_IMPLEMENTATION.md` und `docs/CONCEPT_AND_ROADMAP.md`.

---

## 📚 Weitere Dokumentation

Ausführliche Dokumentation findest du in:

| Dokument | Beschreibung |
|----------|--------------|
| [Architecture](docs/architecture.md) | Architektur-Übersicht & Komponenten |
| [Development Guide](docs/DEVELOPMENT.md) | Setup, Build, Testing & Entwickler-Workflow |
| [User Guide](docs/USER_GUIDE.md) | Benutzerführung & Session-Empfehlungen |
| [Sync Implementation](docs/SYNC_IMPLEMENTATION.md) | Details zur Audio-Licht-Synchronisation |
| [Latency Calibration](docs/LATENCY_CALIBRATION.md) | Latenz-Messung & -Korrektur |
| [Gamma Optimization](docs/GAMMA_OPTIMIZATION.md) | Optimierungen für Gamma-/High-Frequency-Modi |
| [Final Acceptance Report](docs/FINAL_ACCEPTANCE_REPORT.md) | Abnahme- & Qualitätszusammenfassung |
| Spezifikation 001 (specs/001-audio-strobe-sync/spec.md) | Formale Spezifikation der Audio-Strobe-Sync-Pipeline |

---

## 🤝 Beiträge & Entwicklung

MindSync ist derzeit ein privates Projekt. Wenn du Interesse an Zusammenarbeit hast oder Feedback geben möchtest, öffne gerne ein Issue.

### Code Style

- **Swift Style Guide**: Orientiert an [Ray Wenderlich Swift Style Guide](https://github.com/raywenderlich/swift-style-guide)
- **SwiftLint**: Projekt nutzt SwiftLint für konsistenten Code
- **Dokumentation**: Alle öffentlichen APIs sind dokumentiert
- **Tests**: Neue Features benötigen Unit Tests

---

## 📜 Lizenz & Rechtliches

**Lizenz**: Proprietary - Alle Rechte vorbehalten

**Haftungsausschluss**: 
- MindSync ist ein Wellness-Produkt, kein medizinisches Gerät
- Keine Garantie für therapeutische Wirkung
- Verwendung auf eigene Verantwortung
- Bei gesundheitlichen Bedenken konsultiere einen Arzt

**Sicherheit**:
- Die Verwendung von MindSync bei photosensitiver Epilepsie kann gefährlich sein
- Alle Sicherheitswarnungen müssen ernst genommen werden
- Der Entwickler übernimmt keine Haftung für gesundheitliche Schäden

---

## 🙏 Danksagungen & Inspiration

Eine ausführlichere Liste an wissenschaftlichen Quellen, technischer Inspiration und persönlicher Motivation findest du in `docs/CONCEPT_AND_ROADMAP.md`.

---

## 📞 Kontakt

Für Fragen, Feedback oder Zusammenarbeit:
- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)

---

## 🌍 English Overview

MindSync is an iOS app for **neural entrainment** using audio-synchronised stroboscopic light patterns. It analyses your music in real time and generates light scripts that target specific brainwave ranges (e.g. relaxation, focus, deep meditation).

- Personalised experience: Real-time analysis of your own tracks  
- Multiple entrainment modes: Alpha, Theta, Gamma & Cinematic (beat-synchronized pulses)  
- Dual light sources: Torch (eyes closed) or coloured screen  
- Safety first: Epilepsy onboarding, frequency limits, thermal management  

For more details, please refer to:  
- `docs/USER_GUIDE.md` for user-facing guidance  
- `docs/architecture.md` and `docs/SYNC_IMPLEMENTATION.md` for technical internals  
- `docs/CONCEPT_AND_ROADMAP.md` for the scientific background and roadmap  

---

**Version**: 1.0.0 | **Status**: Phase 1 & 2 abgeschlossen, Phase 3 in Planung | **Letztes Update**: Dezember 2025

---

*\"Das Gehirn ist ein Instrument der unglaublichen Macht. Mit den richtigen Werkzeugen können wir lernen, es bewusst zu nutzen, um unser volles Potenzial zu entfalten.\"*

---

## 📞 Kontakt

Für Fragen, Feedback oder Zusammenarbeit:
- **Issues**: [GitHub Issues](../../issues)
- **Discussions**: [GitHub Discussions](../../discussions)

---

**Version**: 1.0.0 | **Status**: Phase 1 & 2 abgeschlossen, Phase 3 in Planung | **Letztes Update**: Dezember 2025

---

*"Das Gehirn ist ein Instrument der unglaublichen Macht. Mit den richtigen Werkzeugen können wir lernen, es bewusst zu nutzen, um unser volles Potenzial zu entfalten."*
