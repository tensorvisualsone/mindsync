---
name: "Fehlerbehebung: Abstürze und Modus-Auswahl"
overview: "Behebung von drei kritischen Problemen: 1) App stürzt ab bei Auswahl einer Audioquelle, 2) Modus ist auf dem Startbildschirm nicht auswählbar, 3) Cinematic Mode und Modus-Wechsel funktionieren nicht. Der Plan umfasst Threading-Fixes, UI-Verbesserungen (Navigation zu Settings/Modus-Auswahl) und Tests."
todos:
  - id: fix-threading-source-selection
    content: "Threading-Fix in SourceSelectionView: ServiceContainer-Zugriff auf Main Actor verschieben"
    status: pending
  - id: add-mode-selection-home
    content: "Modus-Auswahl auf HomeView hinzufügen: Modus-Card tappbar machen und ModeSelectionView als Sheet öffnen"
    status: pending
  - id: verify-service-container-threading
    content: ServiceContainer Thread-Safety prüfen und ggf. verbessern
    status: pending
    dependencies:
      - fix-threading-source-selection
  - id: add-threading-tests
    content: Unit-Tests für Threading-Szenarien hinzufügen (SourceSelectionView, ServiceContainer)
    status: pending
    dependencies:
      - fix-threading-source-selection
  - id: add-navigation-tests
    content: UI-Tests für Modus-Auswahl und Navigation hinzufügen
    status: pending
    dependencies:
      - add-mode-selection-home
  - id: add-settings-navigation
    content: "Settings-Navigation in HomeView Toolbar hinzufügen (Pflicht, damit alle Modi erreichbar sind)"
    status: pending
    dependencies:
      - add-mode-selection-home
  - id: verify-all-modes-visible
    content: "Verifizieren, dass alle Modi (inkl. Cinematic) in ModeSelectionView und SettingsView angezeigt werden"
    status: pending
    dependencies:
      - add-mode-selection-home
      - add-settings-navigation
---

# Fehlerbehebung: Abstürze und Modus-Auswahl

## Problem-Analyse

### Problem 1: App stürzt ab bei Auswahl

**Ursache**: Threading-Konflikt durch direkten Zugriff auf `ServiceContainer.shared` in `SourceSelectionView`. `ServiceContainer` ist mit `@MainActor` markiert, aber `SourceSelectionView` greift von einem nicht-Main-Thread darauf zu.**Betroffene Dateien**:

- `MindSync/Features/Home/SourceSelectionView.swift` (Zeilen 6-7): Direkter Zugriff auf `ServiceContainer.shared`
- `MindSync/Services/ServiceContainer.swift`: `@MainActor`-Annotation

### Problem 2: Modus nicht auswählbar auf Startbildschirm

**Ursache**: In `HomeView.swift` wird der aktuelle Modus nur angezeigt, aber es gibt keine Navigation oder Button zur `ModeSelectionView` oder `SettingsView`.

**Betroffene Dateien**:
- `MindSync/Features/Home/HomeView.swift`: Fehlende Navigation zu Modus-Auswahl

### Problem 3: Cinematic Mode nicht verfügbar / Modus-Wechsel funktioniert nicht

**Ursache**: 
- `SettingsView` ist nicht von `HomeView` aus erreichbar (keine Navigation)
- `ModeSelectionView` existiert, wird aber nirgendwo verwendet
- Cinematic Mode ist in der Enum definiert und sollte in `allCases` enthalten sein, ist aber nicht erreichbar

**Betroffene Dateien**:
- `MindSync/Features/Home/HomeView.swift`: Fehlende Navigation zu Settings
- `MindSync/Features/Settings/SettingsView.swift`: Picker sollte alle Modi anzeigen (inkl. Cinematic)
- `MindSync/Features/Home/ModeSelectionView.swift`: Wird nicht verwendet

## Lösung

### 1. Threading-Fix für ServiceContainer-Zugriff

**Datei**: `MindSync/Features/Home/SourceSelectionView.swift`

- Entferne direkten Zugriff auf `ServiceContainer.shared` in Property-Initializern
- Verschiebe Service-Zugriff in `@MainActor`-Methoden oder verwende `Task { @MainActor in ... }`
- Alternativ: Services als `@State`-Variablen mit `@MainActor`-Annotation laden

**Implementierung**:

```swift
@State private var mediaLibraryService: MediaLibraryService?
@State private var permissionsService: PermissionsService?

.onAppear {
    Task { @MainActor in
        mediaLibraryService = ServiceContainer.shared.mediaLibraryService
        permissionsService = ServiceContainer.shared.permissionsService
        // ... rest of initialization
    }
}
```



### 2. Modus-Auswahl auf HomeView hinzufügen

**Datei**: `MindSync/Features/Home/HomeView.swift`

- Mache die Modus-Anzeige tappbar (Button/NavigationLink)
- Füge Navigation zu `ModeSelectionView` hinzu
- Füge Navigation zu `SettingsView` in der Toolbar hinzu (Pflicht, nicht optional)

**Implementierung**:
- Modus-Card als Button umwandeln, der `ModeSelectionView` als Sheet öffnet
- State-Variable für `showingModeSelection` hinzufügen
- State-Variable für `showingSettings` hinzufügen
- Toolbar-Button für Settings hinzufügen
- Nach Modus-Änderung in `ModeSelectionView` Preferences in `HomeView` aktualisieren

### 2b. Sicherstellen, dass alle Modi angezeigt werden

**Dateien**: 
- `MindSync/Features/Home/ModeSelectionView.swift`: Verwendet bereits `EntrainmentMode.allCases` ✓
- `MindSync/Features/Settings/SettingsView.swift`: Verwendet bereits `EntrainmentMode.allCases` ✓

**Prüfung**:
- Verifizieren, dass `EntrainmentMode.allCases` alle 4 Modi enthält (Alpha, Theta, Gamma, Cinematic)
- Lokalisierungsstrings für Cinematic Mode sind vorhanden ✓
- Icon und Theme-Color für Cinematic Mode sind definiert ✓

### 3. ServiceContainer Thread-Safety verbessern

**Datei**: `MindSync/Services/ServiceContainer.swift`

- Prüfen, ob `ServiceContainer.shared` thread-safe initialisiert wird
- Sicherstellen, dass alle Zugriffe auf `@MainActor` erfolgen
- Optional: Nonisolated(unsafe) für `shared` Property, wenn nötig

### 4. Tests hinzufügen

**Neue Test-Dateien**:

- `MindSyncTests/Unit/SourceSelectionViewTests.swift`: Threading-Tests
- `MindSyncTests/Unit/HomeViewTests.swift`: Navigation-Tests
- `MindSyncUITests/HomeViewUITests.swift`: UI-Tests für Modus-Auswahl

**Bestehende Tests erweitern**:

- `SessionViewModelTests.swift`: Threading-Szenarien testen

## Implementierungsreihenfolge

1. **Threading-Fix** (höchste Priorität - verhindert Abstürze)

- `SourceSelectionView.swift` anpassen
- Service-Zugriff thread-safe machen

2. **Modus-Auswahl UI** (mittlere Priorität - UX-Verbesserung)
   - `HomeView.swift` erweitern
   - `ModeSelectionView` integrieren
   - Settings-Navigation hinzufügen (Pflicht)

3. **Modus-Verfügbarkeit prüfen** (wichtig - alle Modi müssen erreichbar sein)
   - Verifizieren, dass alle Modi (inkl. Cinematic) angezeigt werden
   - Testen, dass Modus-Wechsel funktioniert

4. **Tests** (wichtig für Stabilität)
   - Unit-Tests für Threading
   - UI-Tests für Navigation
   - Tests für Modus-Auswahl (inkl. Cinematic)

## Erwartete Ergebnisse

- ✅ App stürzt nicht mehr ab bei Auswahl einer Audioquelle
- ✅ Modus kann direkt vom Home-Screen aus geändert werden (via tappbare Modus-Card)
- ✅ Settings sind von HomeView aus erreichbar (Toolbar-Button)
- ✅ Alle Modi (Alpha, Theta, Gamma, Cinematic) sind auswählbar und funktionieren
- ✅ Modus-Wechsel funktioniert sowohl in ModeSelectionView als auch in SettingsView
- ✅ Alle Service-Zugriffe erfolgen thread-safe
- ✅ Tests decken Threading-Szenarien und Modus-Auswahl ab