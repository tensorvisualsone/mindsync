---
name: MindSync Konsolidierter Masterplan
overview: "Vollständiger konsolidierter Plan für alle MindSync-Features, Fehlerbehebungen, Tests und Verbesserungen. Kombiniert alle bisherigen Pläne zu einem einzigen, priorisierten Masterplan."
todos:
  # PHASE 0: KRITISCHE FEHLERBEHEBUNGEN (HÖCHSTE PRIORITÄT)
  - id: fix-threading-source-selection
    content: "Threading-Fix in SourceSelectionView: ServiceContainer-Zugriff auf Main Actor verschieben"
    status: completed
    priority: critical
  - id: add-mode-selection-home
    content: "Modus-Auswahl auf HomeView hinzufügen: Modus-Card tappbar machen und ModeSelectionView als Sheet öffnen"
    status: completed
    priority: critical
  - id: add-settings-navigation
    content: "Settings-Navigation in HomeView Toolbar hinzufügen (Pflicht, damit alle Modi erreichbar sind)"
    status: completed
    priority: critical
    dependencies:
      - add-mode-selection-home
  - id: verify-all-modes-visible
    content: "Verifizieren, dass alle Modi (inkl. Cinematic) in ModeSelectionView und SettingsView angezeigt werden"
    status: completed
    priority: critical
    dependencies:
      - add-mode-selection-home
      - add-settings-navigation
  - id: verify-service-container-threading
    content: "ServiceContainer Thread-Safety prüfen und ggf. verbessern"
    status: completed
    priority: high
    dependencies:
      - fix-threading-source-selection
  
  # PHASE 1: TESTS FÜR FEHLERBEHEBUNGEN
  - id: add-threading-tests
    content: "Unit-Tests für Threading-Szenarien hinzufügen (SourceSelectionView, ServiceContainer)"
    status: completed
    priority: high
    dependencies:
      - fix-threading-source-selection
  - id: add-navigation-tests
    content: "UI-Tests für Modus-Auswahl und Navigation hinzufügen"
    status: completed
    priority: high
    dependencies:
      - add-mode-selection-home
      - add-settings-navigation
  
  # PHASE 2: VERIFIZIERUNG BEREITS IMPLEMENTIERTER FEATURES
  - id: verify-cinematic-mode-working
    content: "Verifizieren, dass Cinematic Mode vollständig funktioniert (laut konsolidiertem Plan bereits implementiert)"
    status: completed
    priority: medium
  - id: verify-microphone-mode-working
    content: "Verifizieren, dass Mikrofon-Modus vollständig funktioniert (laut Plan bereits implementiert)"
    status: completed
    priority: medium
  - id: verify-fall-detection-working
    content: "Verifizieren, dass Fall-Erkennung vollständig funktioniert (laut Plan bereits implementiert)"
    status: completed
    priority: medium
  
  # PHASE 3: FEHLENDE TESTS (falls noch nicht vollständig)
  - id: test-source-selection-view
    content: "SourceSelectionViewTests: Unit Tests für Threading-Szenarien"
    status: completed
    priority: medium
    dependencies:
      - fix-threading-source-selection
  - id: test-home-view
    content: "HomeViewTests: Navigation-Tests"
    status: completed
    priority: medium
    dependencies:
      - add-mode-selection-home
  - id: test-home-view-ui
    content: "HomeViewUITests: UI-Tests für Modus-Auswahl"
    status: completed
    priority: medium
    dependencies:
      - add-mode-selection-home
      - add-settings-navigation
  
  # PHASE 4: LOKALISIERUNG & POLISH
  - id: verify-localization-complete
    content: "Lokalisierung vervollständigen: Alle User-facing Strings in DE/EN prüfen und fehlende hinzufügen"
    status: pending
    priority: low
  - id: ui-polish-consistency
    content: "UI-Polish: Konsistente Farbpalette, Typografie, Spacing, Accessibility, Dark Mode Optimierungen"
    status: pending
    priority: low
  - id: documentation-update
    content: "Dokumentation: architecture.md aktualisieren mit aktueller Architektur, Fehlerbehebungen, Testing-Strategie"
    status: pending
    priority: low
---

# MindSync Konsolidierter Masterplan

## Übersicht

Dieser Plan konsolidiert alle bisherigen Pläne zu einem einzigen, priorisierten Masterplan. Er deckt ab:
- **Kritische Fehlerbehebungen** (App-Abstürze, fehlende Navigation)
- **Verifizierung bereits implementierter Features** (Cinematic Mode, Mikrofon-Modus, Fall-Erkennung)
- **Fehlende Tests**
- **Lokalisierung & Polish**

## Bestandsaufnahme

### Bereits implementiert (laut konsolidiertem Plan)

- ✅ **Cinematic Mode** - Vollständig implementiert (AudioEnergyTracker, EntrainmentEngine, LightController)
- ✅ **AudioPlaybackService Migration** - Zu AVAudioEngine migriert
- ✅ **MicrophoneAnalyzer** - Vollständig mit FFT, Beat Detection, Moving Average
- ✅ **FallDetector** - Vollständig implementiert mit CMMotionManager
- ✅ **FrequencyMapper** - Vollständig implementiert mit Safety-Validierung
- ✅ **WaveformGenerator** - Bereits vorhanden
- ✅ **ModeSelectionView** - UI bereits implementiert
- ✅ **AffirmationService** - Nutzt AVAudioEngine für Affirmationen
- ✅ **Tests** - Viele Unit- und Integration-Tests bereits vorhanden
- ✅ **Lokalisierung** - Teilweise vorhanden

### Kritische Probleme (müssen zuerst behoben werden)

1. **App stürzt ab bei Auswahl** - Threading-Konflikt in SourceSelectionView
2. **Modus nicht auswählbar** - Fehlende Navigation zu ModeSelectionView/SettingsView
3. **Cinematic Mode nicht erreichbar** - Obwohl implementiert, fehlt Navigation

---

## Phase 0: Kritische Fehlerbehebungen (HÖCHSTE PRIORITÄT)

### Problem 1: App stürzt ab bei Auswahl

**Ursache**: Threading-Konflikt durch direkten Zugriff auf `ServiceContainer.shared` in `SourceSelectionView`. `ServiceContainer` ist mit `@MainActor` markiert, aber `SourceSelectionView` greift von einem nicht-Main-Thread darauf zu.

**Lösung**:
- **Datei**: `MindSync/Features/Home/SourceSelectionView.swift`
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
        authorizationStatus = mediaLibraryService?.authorizationStatus ?? .notDetermined
        microphoneStatus = permissionsService?.microphoneStatus ?? .undetermined
    }
}
```

### Problem 2: Modus nicht auswählbar auf Startbildschirm

**Ursache**: In `HomeView.swift` wird der aktuelle Modus nur angezeigt, aber es gibt keine Navigation oder Button zur `ModeSelectionView` oder `SettingsView`.

**Lösung**:
- **Datei**: `MindSync/Features/Home/HomeView.swift`
- Mache die Modus-Anzeige tappbar (Button)
- Füge Navigation zu `ModeSelectionView` als Sheet hinzu
- Füge Navigation zu `SettingsView` in der Toolbar hinzu
- State-Variablen: `showingModeSelection`, `showingSettings`
- Nach Modus-Änderung Preferences in `HomeView` aktualisieren

**Implementierung**:
```swift
@State private var showingModeSelection = false
@State private var showingSettings = false

// Modus-Card als Button
Button(action: { showingModeSelection = true }) {
    // ... bestehende Modus-Card UI
}

// Toolbar
.toolbar {
    ToolbarItem(placement: .navigationBarTrailing) {
        Button(action: { showingSettings = true }) {
            Image(systemName: "gearshape.fill")
        }
    }
}

// Sheets
.sheet(isPresented: $showingModeSelection) {
    ModeSelectionView(
        selectedMode: Binding(
            get: { preferences.preferredMode },
            set: { newMode in
                preferences.preferredMode = newMode
                preferences.save()
            }
        )
    )
}

.sheet(isPresented: $showingSettings) {
    SettingsView()
}
```

### Problem 3: ServiceContainer Thread-Safety

**Prüfung**:
- **Datei**: `MindSync/Services/ServiceContainer.swift`
- Prüfen, ob `ServiceContainer.shared` thread-safe initialisiert wird
- Sicherstellen, dass alle Zugriffe auf `@MainActor` erfolgen
- Optional: `nonisolated(unsafe)` für `shared` Property, wenn nötig

---

## Phase 1: Tests für Fehlerbehebungen

### Unit Tests

**Neue Test-Dateien**:
- `MindSyncTests/Unit/SourceSelectionViewTests.swift`: Threading-Tests
- `MindSyncTests/Unit/HomeViewTests.swift`: Navigation-Tests

**Bestehende Tests erweitern**:
- `SessionViewModelTests.swift`: Threading-Szenarien testen

### UI Tests

**Neue Test-Dateien**:
- `MindSyncUITests/HomeViewUITests.swift`: UI-Tests für Modus-Auswahl und Navigation

---

## Phase 2: Verifizierung bereits implementierter Features

### Cinematic Mode Verifizierung

Laut konsolidiertem Plan ist Cinematic Mode bereits vollständig implementiert:
- ✅ EntrainmentMode.cinematic
- ✅ AudioEnergyTracker
- ✅ EntrainmentEngine.calculateCinematicIntensity
- ✅ FlashlightController & ScreenController Support
- ✅ SessionViewModel Integration

**Verifizierung**:
- Testen, dass Cinematic Mode in ModeSelectionView und SettingsView angezeigt wird
- Testen, dass Cinematic Mode Sessions funktionieren
- Testen, dass Audio-Energie-Tracking aktiviert wird

### Mikrofon-Modus Verifizierung

Laut Plan bereits implementiert:
- ✅ MicrophoneAnalyzer vollständig
- ✅ SessionViewModel.startMicrophoneSession()

**Verifizierung**:
- Testen, dass Mikrofon-Modus funktioniert
- Testen, dass Berechtigungen korrekt abgefragt werden

### Fall-Erkennung Verifizierung

Laut Plan bereits implementiert:
- ✅ FallDetector vollständig
- ✅ SessionViewModel Integration

**Verifizierung**:
- Testen, dass Fall-Erkennung funktioniert
- Testen, dass Session bei erkanntem Fall gestoppt wird

---

## Phase 3: Fehlende Tests

### Unit Tests

Falls noch nicht vollständig vorhanden:
- `SourceSelectionViewTests` - Threading-Szenarien
- `HomeViewTests` - Navigation-Logik

### UI Tests

Falls noch nicht vollständig vorhanden:
- `HomeViewUITests` - Modus-Auswahl, Settings-Navigation

---

## Phase 4: Lokalisierung & Polish

### Lokalisierung

**Status**: Teilweise vorhanden, muss vervollständigt werden

**Dateien**:
- `MindSync/Resources/Localizable.strings` (DE)
- `MindSync/Resources/en.lproj/Localizable.strings` (EN)

**Prüfung**:
- Alle User-facing Strings extrahieren und lokalisieren
- Fehlende Strings hinzufügen (insbesondere für neue Features)

### UI-Polish

**Verbesserungen**:
- Konsistente Farbpalette (nutze `Color+MindSync.swift`)
- Verbesserte Typografie (Font-System konsistent)
- Spacing und Padding standardisieren
- Accessibility-Verbesserungen (VoiceOver Labels, Dynamic Type)
- Dark Mode Optimierungen

### Dokumentation

**Datei**: `docs/architecture.md`

**Inhalt**:
- Architektur-Übersicht (High-Level Data Flow)
- Entrainment-Algorithmus Erklärung
- Audio-Analyse Pipeline
- Light-Steuerung (Flashlight vs Screen)
- Cinematic Mode Architektur
- Sicherheits-Features
- Service-Container Pattern
- Testing-Strategie
- Fehlerbehebungen (Threading-Fixes)

---

## Implementierungsreihenfolge

### Sofort (Kritisch)

1. **Threading-Fix** - `SourceSelectionView.swift` anpassen
2. **Modus-Auswahl UI** - `HomeView.swift` erweitern
3. **Settings-Navigation** - Toolbar-Button hinzufügen
4. **Modus-Verfügbarkeit prüfen** - Verifizieren, dass alle Modi angezeigt werden

### Kurzfristig (Hoch)

5. **ServiceContainer Thread-Safety** - Prüfen und verbessern
6. **Threading-Tests** - Unit-Tests hinzufügen
7. **Navigation-Tests** - UI-Tests hinzufügen

### Mittelfristig (Medium)

8. **Feature-Verifizierung** - Cinematic Mode, Mikrofon-Modus, Fall-Erkennung testen
9. **Fehlende Tests** - Ergänzen falls nötig

### Langfristig (Niedrig)

10. **Lokalisierung** - Vervollständigen
11. **UI-Polish** - Design-Verbesserungen
12. **Dokumentation** - Aktualisieren

---

## Erwartete Ergebnisse

### Phase 0 (Kritisch)

- ✅ App stürzt nicht mehr ab bei Auswahl einer Audioquelle
- ✅ Modus kann direkt vom Home-Screen aus geändert werden (via tappbare Modus-Card)
- ✅ Settings sind von HomeView aus erreichbar (Toolbar-Button)
- ✅ Alle Modi (Alpha, Theta, Gamma, Cinematic) sind auswählbar und funktionieren
- ✅ Modus-Wechsel funktioniert sowohl in ModeSelectionView als auch in SettingsView
- ✅ Alle Service-Zugriffe erfolgen thread-safe

### Phase 1-4 (Weiterführend)

- ✅ Tests decken Threading-Szenarien und Modus-Auswahl ab
- ✅ Alle implementierten Features sind verifiziert und funktionieren
- ✅ Lokalisierung ist vollständig
- ✅ UI ist konsistent und poliert
- ✅ Dokumentation ist aktuell

---

## Technische Details

### Threading-Fix Details

**Problem**: `ServiceContainer` ist `@MainActor`, aber wird von nicht-Main-Threads aufgerufen.

**Lösung**: Alle Zugriffe auf `ServiceContainer.shared` müssen auf `@MainActor` erfolgen.

**Pattern**:
```swift
// ❌ Falsch (Property-Initializer)
private let service = ServiceContainer.shared.service

// ✅ Richtig (onAppear mit Task)
@State private var service: SomeService?

.onAppear {
    Task { @MainActor in
        service = ServiceContainer.shared.service
    }
}
```

### Navigation-Pattern

**HomeView Navigation**:
- Modus-Card → Sheet mit `ModeSelectionView`
- Toolbar-Button → Sheet mit `SettingsView`
- Beide Sheets aktualisieren `preferences` State in `HomeView`

---

## Bekannte Herausforderungen

1. **Threading**: ServiceContainer-Zugriffe müssen konsistent auf Main Actor erfolgen
2. **State Management**: Preferences müssen nach Änderungen in Sheets aktualisiert werden
3. **Navigation**: Mehrere Sheets können zu State-Konflikten führen - sorgfältig testen

---

## Abhängigkeiten

### Kritische Abhängigkeiten

- Phase 0 muss **vor** allen anderen Phasen abgeschlossen sein (App muss funktionieren)
- Tests (Phase 1) hängen von Phase 0 ab
- Verifizierung (Phase 2) kann parallel zu Phase 1 laufen
- Lokalisierung & Polish (Phase 4) können unabhängig erfolgen

### Empfohlene Reihenfolge

1. **Phase 0**: Kritische Fehlerbehebungen (Sofort)
2. **Phase 1**: Tests für Fehlerbehebungen (Kurzfristig)
3. **Phase 2**: Feature-Verifizierung (Mittelfristig)
4. **Phase 3**: Fehlende Tests (Mittelfristig)
5. **Phase 4**: Lokalisierung & Polish (Langfristig)

