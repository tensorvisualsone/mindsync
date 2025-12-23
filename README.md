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

### Phase 1: MVP (aktuell)
- [ ] Lokale Musik + Taschenlampen-Stroboskop
- [ ] Beat-Detection (FFT-basiert)
- [ ] Epilepsie-Onboarding
- [ ] Thermisches Management

### Phase 2: Neural Update
- [ ] Entrainment-Modi (Alpha/Theta/Gamma)
- [ ] Bildschirm-Modus mit Farben
- [ ] Mikrofon-Modus für Streaming

### Phase 3: Generative Zukunft
- [ ] Timbre-zu-Luminanz Mapping
- [ ] HomeKit Integration (Philips Hue, Nanoleaf)
- [ ] Community LightScript Sharing

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

- Inspiriert von [Lumenate](https://www.lumenate.com/) und der Forschung zu Photic Driving
- Neurowissenschaftliche Grundlagen basierend auf Studien des Netherlands Institute for Neuroscience
- Apple Developer Documentation für AVFoundation und Accelerate

---

**Version**: 0.1.0-dev | **Status**: In Entwicklung

