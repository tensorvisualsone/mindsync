# Swift Workflow Build Failure Fix - December 29, 2025

## Problem

Die GitHub Actions Workflows `swift.yml` und `codeql.yml` sind fehlgeschlagen, weil:

1. **swift.yml** versuchte `swift build` und `swift test` auszuführen
   - Diese Befehle sind für Swift Package Manager (SPM) Projekte
   - MindSync ist eine iOS-App, die ein Xcode-Projekt benötigt

2. **codeql.yml** erwartete ein Xcode-Projekt unter `MindSync/MindSync.xcodeproj`
   - Diese Datei existiert noch nicht im Repository

## Root Cause

Das Projekt befindet sich in einer frühen Entwicklungsphase:
- Swift-Quelldateien sind vorhanden (`MindSync/` Verzeichnis)
- **Kein** Xcode-Projekt (.xcodeproj) wurde noch erstellt
- **Kein** Package.swift für Swift Package Manager vorhanden

Laut `specs/001-audio-strobe-sync/quickstart.md` ist dies ein iOS-Projekt, das:
- Xcode 15.0+ benötigt
- iOS 17.0+ als Minimalversion verwendet
- SwiftUI als UI-Framework nutzt
- AVFoundation, Accelerate und andere iOS-spezifische Frameworks verwendet

Ein Swift Package Manager Ansatz ist **nicht geeignet** für diese Art von iOS-Projekt.

## Lösung

Beide Workflows wurden vorübergehend deaktiviert durch Änderung des Triggers:

### Vorher:
```yaml
on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]
```

### Nachher:
```yaml
on:
  workflow_dispatch: # Only run manually
```

Dies verhindert automatische Ausführungen bei Push/PR, ermöglicht aber manuelle Ausführung wenn gewünscht.

## Dokumentation

Beide Workflow-Dateien enthalten jetzt klare Kommentare:
- Erklärung warum sie deaktiviert sind
- Verweis auf `specs/001-audio-strobe-sync/quickstart.md` für Setup-Anweisungen
- Hinweis, dass sie nach Erstellung des Xcode-Projekts reaktiviert werden können

## Nächste Schritte

Um die Workflows zu aktivieren, muss das Xcode-Projekt erstellt werden:

### Option 1: Manuell in Xcode (empfohlen)
1. Xcode öffnen
2. File → New → Project → iOS → App
3. Product Name: MindSync
4. Interface: SwiftUI
5. Language: Swift
6. Minimum Deployments: iOS 17.0
7. Projekt im Root-Verzeichnis speichern

### Option 2: Workflows anpassen
Nach Erstellung des Xcode-Projekts:

**Für swift.yml:**
```yaml
on:
  push:
    branches: [ "main" ]
  pull_request:
    branches: [ "main" ]

jobs:
  build:
    runs-on: macos-latest
    steps:
    - uses: actions/checkout@v4
    - name: Setup Xcode
      uses: maxim-lobanov/setup-xcode@v1
      with:
        xcode-version: latest-stable
    - name: Build
      run: |
        xcodebuild clean build \
          -project MindSync.xcodeproj \
          -scheme MindSync \
          -sdk iphonesimulator \
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
    - name: Run tests
      run: |
        xcodebuild test \
          -project MindSync.xcodeproj \
          -scheme MindSync \
          -sdk iphonesimulator \
          -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

**Für codeql.yml:**
- Trigger wieder auf push/pull_request/schedule setzen
- Der Build-Schritt ist bereits korrekt konfiguriert

## Änderungen

- `.github/workflows/swift.yml` - Trigger auf `workflow_dispatch` geändert
- `.github/workflows/codeql.yml` - Trigger auf `workflow_dispatch` geändert
- Beide Dateien mit Dokumentation erweitert

## Testen

Nach diesem Fix:
- ✅ Keine automatischen Workflow-Fehler mehr bei Push/PR
- ✅ Workflows können manuell getestet werden über GitHub Actions UI
- ✅ Andere Workflows (falls vorhanden) nicht betroffen

## Referenzen

- [quickstart.md](../specs/001-audio-strobe-sync/quickstart.md) - Projekt-Setup Anleitung
- [plan.md](../specs/001-audio-strobe-sync/plan.md) - Technische Architektur
- [GitHub Actions: Building and testing Swift](https://docs.github.com/en/actions/automating-builds-and-tests/building-and-testing-swift)
