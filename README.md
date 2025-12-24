# MindSync

**Audio-synchronisiertes Stroboskop für veränderte Bewusstseinszustände**

[![iOS 17+](https://img.shields.io/badge/iOS-17%2B-blue.svg)](https://developer.apple.com/ios/)
[![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
[![License](https://img.shields.io/badge/License-Proprietary-red.svg)]()

---

## 🧠 Was ist MindSync?

MindSync ist eine iOS-App, die **stroboskopisches Licht** (Taschenlampe oder Bildschirm) mit deiner **persönlichen Musik** synchronisiert, um veränderte Bewusstseinszustände durch **Neural Entrainment** zu induzieren.

Im Gegensatz zu bestehenden Apps wie Lumenate, die statische, proprietäre Inhalte verwenden, analysiert MindSync deine eigene Musikbibliothek in Echtzeit und erzeugt dynamische, personalisierte Lichtmuster.

### Kernfeatures

- 🎵 **Musik-Synchronisation**: Beat-Detection und Tempo-Analyse aus deiner Musikbibliothek
- 💡 **Dual-Lichtquellen**: Taschenlampe (intensiv) oder Bildschirm (präzise, farbig)
- 🧘 **Entrainment-Modi**: Alpha (Entspannung), Theta (Trip), Gamma (Fokus)
- 🎤 **Mikrofon-Modus**: Funktioniert auch mit Streaming-Diensten
- 🛡️ **Sicherheit-First**: Epilepsie-Warnungen, thermisches Management, Fall-Erkennung

---

## ⚠️ Wichtige Sicherheitshinweise

> **WARNUNG**: Diese App verwendet stroboskopisches Licht, das bei Menschen mit **photosensitiver Epilepsie** Anfälle auslösen kann.
>
> **Verwenden Sie diese App NICHT, wenn Sie oder Familienmitglieder eine Vorgeschichte mit Krampfanfällen haben.**

MindSync ist ein **Wellness-Produkt**, kein medizinisches Gerät. Es macht keine therapeutischen oder medizinischen Versprechen.

---

## 🛠️ Technologie-Stack

| Bereich | Technologie |
|---------|-------------|
| Sprache | Swift 5.9+ (async/await, @Observable) |
| UI | SwiftUI |
| Audio-Analyse | AVFoundation + Accelerate (vDSP/FFT) |
| Audio-Playback | AVAudioEngine + AVAudioPlayerNode |
| Licht-Steuerung | AVCaptureDevice (Torch) + CADisplayLink |
| Minimum iOS | 17.0 |
| Architektur | Feature-based, Protocol-oriented |

---

## 📁 Projektstruktur

```
mindsync/
├── .specify/                    # Speckit Framework
│   ├── memory/
│   │   └── constitution.md      # Projekt-Verfassung
│   ├── scripts/                 # Automatisierungs-Scripts
│   └── templates/               # Dokumentations-Templates
│
├── specs/                       # Feature-Spezifikationen
│   └── 001-audio-strobe-sync/   # Aktuelles Feature
│       ├── spec.md              # User Stories & Requirements
│       ├── plan.md              # Technischer Plan
│       ├── research.md          # API-Recherche
│       ├── data-model.md        # Swift Datenmodelle
│       ├── quickstart.md        # Entwickler-Setup
│       └── contracts/           # Service-Protokolle
│
├── research/                    # Konzept-Dokumente (PDF)
│
└── MindSync/                    # iOS App (noch zu erstellen)
    ├── App/
    ├── Features/
    ├── Core/
    ├── Models/
    ├── Services/
    └── Shared/
```

---

## 🚀 Schnellstart

### Voraussetzungen

- macOS Sonoma 14.0+
- Xcode 15.0+
- iPhone für echte Taschenlampen-Tests

### Setup

```bash
# Repository klonen
git clone <repository-url>
cd mindsync

# Dokumentation lesen
open specs/001-audio-strobe-sync/quickstart.md
```

Detaillierte Setup-Anweisungen findest du in [`specs/001-audio-strobe-sync/quickstart.md`](specs/001-audio-strobe-sync/quickstart.md).

---

## 📋 Dokumentation

| Dokument | Beschreibung |
|----------|--------------|
| [Constitution](/.specify/memory/constitution.md) | Projekt-Prinzipien und Governance |
| [Spec](specs/001-audio-strobe-sync/spec.md) | User Stories und Anforderungen |
| [Plan](specs/001-audio-strobe-sync/plan.md) | Technische Architektur |
| [Research](specs/001-audio-strobe-sync/research.md) | iOS API-Dokumentation |
| [Data Model](specs/001-audio-strobe-sync/data-model.md) | Swift Datenstrukturen |
| [Quickstart](specs/001-audio-strobe-sync/quickstart.md) | Entwickler-Onboarding |

---

## 🎯 Roadmap

### Phase 1: MVP ✅ (abgeschlossen)
- [x] Lokale Musik + Taschenlampen-Stroboskop
- [x] Beat-Detection (FFT-basiert)
- [x] Epilepsie-Onboarding
- [x] Thermisches Management
- [x] **AudioPlaybackService Migration**: AVAudioPlayer → AVAudioEngine (für zukünftige Audio-Analyse)

### Phase 2: Neural Update ✅ (abgeschlossen)
- [x] Entrainment-Modi (Alpha/Theta/Gamma)
- [x] Bildschirm-Modus mit Farben
- [x] Mikrofon-Modus für Streaming
- [x] **Cinematic Mode**: Dynamische Intensitäts-Modulation basierend auf Audio-Energie

### Phase 3: Generative Zukunft (geplant)
- [ ] Timbre-zu-Luminanz Mapping
- [ ] HomeKit Integration (Philips Hue, Nanoleaf)
- [ ] Community LightScript Sharing

---

## 🏗️ Architektur-Highlights

### Audio-Playback (Phase 1 Migration)

MindSync nutzt **AVAudioEngine** für Audio-Playback, was folgende Vorteile bietet:

- **Audio-Analyse in Echtzeit**: Zugriff auf den Main Mixer Node für Audio-Energie-Tracking
- **Erweiterbarkeit**: Einfache Integration von Audio-Effekten (Reverb, EQ, etc.)
- **Präzise Synchronisation**: Frame-genaue Timing-Kontrolle für Licht-Synchronisation
- **Multi-Streaming**: Unterstützung für gleichzeitiges Abspielen mehrerer Audio-Quellen (z.B. Affirmationen)

Die Migration von `AVAudioPlayer` zu `AVAudioEngine` wurde in Phase 1 abgeschlossen und stellt die Basis für erweiterte Features wie den Cinematic Mode dar.

### Service-Architektur

- **ServiceContainer**: Zentrale Dependency Injection für alle Services
- **Protocol-oriented**: Alle Services implementieren klare Protokolle für Testbarkeit
- **Thread-Safety**: Audio-Services nutzen Background-Queues, UI-Services sind `@MainActor`

---

## 🧪 Testing

```bash
# Unit Tests
xcodebuild test -scheme MindSync -destination 'platform=iOS Simulator,name=iPhone 15 Pro'

# UI Tests
xcodebuild test -scheme MindSyncUITests -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## 📜 Lizenz

Proprietary - Alle Rechte vorbehalten.

---

## 🙏 Danksagungen

- Inspiriert von der Forschung zu Photic Driving
- Neurowissenschaftliche Grundlagen basierend auf Studien des Netherlands Institute for Neuroscience
- Apple Developer Documentation für AVFoundation und Accelerate

---

**Version**: 0.2.0-dev | **Status**: Phase 1 & 2 abgeschlossen, Phase 3 in Planung

