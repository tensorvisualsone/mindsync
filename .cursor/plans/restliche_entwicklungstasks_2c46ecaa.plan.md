---
name: Restliche Entwicklungstasks
overview: Umfassender Plan für alle noch fehlenden oder unvollständigen Tasks der MindSync-App, organisiert nach Priorität und Abhängigkeiten
todos:
  - id: session-controls-view
    content: Implementiere SessionControlsView oder entferne ungenutzte Datei
    status: completed
  - id: missing-ui-components
    content: Identifiziere und implementiere fehlende UI-Komponenten
    status: completed
  - id: audio-edge-cases
    content: Verbessere Error Handling für Audio-Analyse Edge Cases (fehlende Beats, Timeouts, DRM)
    status: completed
  - id: light-edge-cases
    content: Handle Edge Cases für Licht-Steuerung (iOS-Zwangsabschaltung, Thermostatus, iPad)
    status: completed
  - id: session-lifecycle-edge-cases
    content: Implementiere Edge Case Handling für Session-Lifecycle (Anrufe, Kopfhörer, Background)
    status: completed
  - id: microphone-edge-cases
    content: Verbessere Edge Case Handling für Mikrofon-Modus
    status: completed
  - id: design-system
    content: Optimiere Design-System (Farben, Typografie, Dark Mode, Accessibility)
    status: completed
  - id: session-view-ui
    content: Verbessere SessionView UI (Track-Info, Fortschritt, Button-Layout)
    status: completed
  - id: home-view-ui
    content: Verbessere HomeView UI und Flow
    status: completed
  - id: settings-view-extensions
    content: Erweitere SettingsView (Affirmationen, Session-Historie, etc.)
    status: completed
  - id: english-localization
    content: Erstelle englische Lokalisierung (en.lproj/Localizable.strings)
    status: completed
  - id: localization-review
    content: Review und vervollständige Lokalisierung
    status: completed
    dependencies:
      - english-localization
  - id: affirmations-ui
    content: Implementiere UI zur Affirmationen-Verwaltung
    status: completed
    dependencies:
      - settings-view-extensions
  - id: session-history-view
    content: Implementiere Session-Historie-View (optional Feature)
    status: completed
  - id: unit-tests
    content: Vervollständige Unit Tests für kritische Komponenten
    status: in_progress
  - id: integration-tests
    content: Implementiere Integration Tests
    status: pending
  - id: ui-tests
    content: Erweitere UI Tests für alle Haupt-Flows
    status: pending
  - id: audio-optimization
    content: Optimiere Audio-Analyse Performance
    status: pending
  - id: ui-performance
    content: Optimiere UI-Performance
    status: pending
  - id: code-documentation
    content: Füge Code-Dokumentation hinzu
    status: pending
  - id: manual-testing
    content: Führe vollständige manuelle Tests durch und dokumentiere
    status: pending
  - id: app-store-prep
    content: Bereite App für App Store vor (Info.plist, Icons, Screenshots)
    status: pending
    dependencies:
      - manual-testing
---

# Plan: Restliche Entwicklungstasks für MindSync

## Überblick

Die MindSync-App hat bereits eine solide Grundstruktur mit Services, Core-Komponenten, Models und grundlegenden Views. Dieser Plan deckt alle noch fehlenden oder unvollständigen Tasks ab, um die App funktionsfähig und produktionsreif zu machen.

## Aktueller Stand

**Vorhanden:**

- ✅ App-Struktur und Services (ServiceContainer)
- ✅ Core-Komponenten (AudioAnalyzer, LightController, EntrainmentEngine, etc.)
- ✅ Models (AudioTrack, Session, UserPreferences, EntrainmentMode)
- ✅ Basis-Views (HomeView, SessionView, SettingsView, OnboardingView, etc.)
- ✅ SessionViewModel (umfangreich implementiert)
- ✅ Deutsche Lokalisierung
- ✅ Grundlegende Funktionalität

**Fehlt/Unvollständig:**

- ❌ `SessionControlsView.swift` ist leer
- ❌ UI-Polish und Design-Verbesserungen
- ❌ Englische Lokalisierung
- ❌ Session-Historie-View (optional)
- ❌ Affirmationen-UI Integration
- ❌ Vollständige Error-Handling-Edge-Cases
- ❌ UI-Tests und Integration-Tests
- ❌ Dokumentation

---

## Phase 1: Kritische Fehlende Komponenten

### 1.1 SessionControlsView implementieren

**Problem:** [SessionControlsView.swift](MindSync/Features/Session/SessionControlsView.swift) ist leer, wird aber möglicherweise referenziert.**Tasks:**

- Prüfe ob `SessionControlsView` verwendet wird oder entfernt werden kann
- Falls verwendet: Implementiere Controls für Pause/Resume/Stop in `SessionControlsView.swift`
- Integriere in `SessionView` falls gewünscht (oder entferne Referenz)

**Dateien:**

- `MindSync/Features/Session/SessionControlsView.swift`
- `MindSync/Features/Session/SessionView.swift`

### 1.2 Fehlende UI-Komponenten identifizieren und implementieren

**Tasks:**

- Überprüfe alle View-Referenzen auf fehlende Komponenten
- Implementiere fehlende UI-Komponenten falls nötig
- Stelle sicher, dass alle verwendeten Komponenten existieren

**Dateien:**

- `MindSync/Features/**/*.swift`
- `MindSync/Shared/Components/**/*.swift`

---

## Phase 2: Error Handling & Edge Cases verbessern

### 2.1 Audio-Analyse Edge Cases

**Tasks:**

- Verbessere Fehlerbehandlung für fehlende Beats in Ambient-Musik (Fallback auf RMS-Energie)
- Implementiere Timeout-Handling für sehr lange Audio-Dateien
- Füge Validierung für korrupte Audio-Dateien hinzu
- Verbessere DRM-Erkennung mit klaren Fehlermeldungen

**Dateien:**

- `MindSync/Core/Audio/AudioAnalyzer.swift`
- `MindSync/Services/MediaLibraryService.swift`
- `MindSync/Features/Session/SessionViewModel.swift`

### 2.2 Licht-Steuerung Edge Cases

**Tasks:**

- Handle iOS-Zwangsabschaltung der Taschenlampe (Graceful Fallback)
- Verbessere Reaktion auf Thermostatus-Änderungen
- Implementiere Retry-Logik für fehlgeschlagene Licht-Initialisierung
- Handle Geräte ohne Taschenlampe (iPad)

**Dateien:**

- `MindSync/Core/Light/FlashlightController.swift`
- `MindSync/Core/Safety/ThermalManager.swift`
- `MindSync/Features/Session/SessionViewModel.swift`

### 2.3 Session-Lifecycle Edge Cases

**Tasks:**

- Handle Anrufe während Session (Pause & Resume)
- Handle Kopfhörer-Anschließen/Trennen (Audio-Route-Wechsel)
- Verbessere Behandlung von App-Wechsel (Background/Foreground)
- Implementiere Session-Recovery nach App-Crash

**Dateien:**

- `MindSync/Features/Session/SessionViewModel.swift`
- `MindSync/Services/AudioPlaybackService.swift`
- `MindSync/App/MindSyncApp.swift`

### 2.4 Mikrofon-Modus Edge Cases

**Tasks:**

- Handle sehr leises Audio-Signal (sanfte Pausierung)
- Verbessere Beat-Erkennung bei Hintergrundgeräuschen
- Implementiere Timeout für fehlendes Audio-Signal
- Handle Mikrofon-Zugriff-Verweigerung während Session

**Dateien:**

- `MindSync/Core/Audio/MicrophoneAnalyzer.swift`
- `MindSync/Features/Session/SessionViewModel.swift`
- `MindSync/Services/PermissionsService.swift`

---

## Phase 3: UI-Verbesserungen & Polish

### 3.1 Design-System optimieren

**Tasks:**

- Überprüfe und standardisiere Farben, Typografie und Spacing
- Stelle sicher, dass Dark Mode konsistent ist
- Verbessere Accessibility (VoiceOver, Dynamic Type)
- Optimiere für verschiedene Bildschirmgrößen (iPhone SE bis iPhone Pro Max)

**Dateien:**

- `MindSync/Shared/Constants.swift`
- `MindSync/Shared/Extensions/Color+MindSync.swift`
- Alle View-Dateien in `MindSync/Features/**/*.swift`

### 3.2 SessionView UI-Verbesserungen

**Tasks:**

- Verbessere Track-Info-Anzeige während Session
- Füge Fortschrittsanzeige für Audio-Playback hinzu
- Optimiere Button-Layout für einfache Bedienung
- Verbessere Visual Feedback für Pause/Resume/Stop

**Dateien:**

- `MindSync/Features/Session/SessionView.swift`
- `MindSync/Features/Session/SessionViewModel.swift`

### 3.3 HomeView UI-Verbesserungen

**Tasks:**

- Verbessere Start-Session-Flow
- Füge Quick-Access zu häufig verwendeten Songs hinzu (optional)
- Optimiere Modus-Auswahl-Visualisierung
- Füge Session-Historie-Zugriff hinzu (optional)

**Dateien:**

- `MindSync/Features/Home/HomeView.swift`
- `MindSync/Features/Home/ModeSelectionView.swift`

### 3.4 SettingsView Erweiterungen

**Tasks:**

- Füge Affirmationen-Verwaltung hinzu (URL-Auswahl für Sprachmemo)
- Erweitere Intensitäts-Slider mit visueller Feedback
- Füge Session-Historie-View hinzu (optional)
- Verbessere Lichtquelle-Auswahl-UI

**Dateien:**

- `MindSync/Features/Settings/SettingsView.swift`
- `MindSync/Features/Settings/LightSourcePicker.swift`

### 3.5 Onboarding UI-Verbesserungen

**Tasks:**

- Verbessere Epilepsie-Warnung Visualisierung
- Füge Animationen für besseres Onboarding-Erlebnis hinzu
- Optimiere Text-Layout für bessere Lesbarkeit

**Dateien:**

- `MindSync/Features/Onboarding/OnboardingView.swift`
- `MindSync/Features/Onboarding/EpilepsyWarningView.swift`

---

## Phase 4: Lokalisierung

### 4.1 Englische Lokalisierung

**Tasks:**

- Erstelle `en.lproj/Localizable.strings` mit allen Strings
- Übersetze alle vorhandenen deutschen Strings ins Englische
- Stelle sicher, dass alle NSLocalizedString-Aufrufe korrekt sind
- Teste Sprachwechsel in den iOS-Einstellungen

**Dateien:**

- `MindSync/Resources/en.lproj/Localizable.strings` (neu)
- `MindSync/Resources/Localizable.strings` (Basis - Deutsch)

### 4.2 Lokalisierung-Review

**Tasks:**

- Überprüfe alle Strings auf Vollständigkeit
- Stelle sicher, dass Format-Strings korrekt sind (z.B. String(format:...))
- Teste Lokalisierung auf verschiedenen Geräten

**Dateien:**

- Alle `.strings` Dateien
- Alle Swift-Dateien mit NSLocalizedString-Aufrufen

---

## Phase 5: Affirmationen-Feature UI

### 5.1 Affirmationen-Verwaltung

**Problem:** `AffirmationOverlayService` existiert und wird in `SessionViewModel` verwendet, aber UI zur Auswahl/Verwaltung fehlt.**Tasks:**

- Implementiere UI zur Auswahl von Sprachmemo-URLs für Affirmationen
- Füge Affirmationen-Verwaltung in SettingsView hinzu
- Implementiere Audio-Recorder-Integration (optional) oder Link zu Sprachmemos-App
- Teste Affirmationen-Abspielung während Theta-Session

**Dateien:**

- `MindSync/Features/Settings/SettingsView.swift` (erweitern)
- Neue Datei: `MindSync/Features/Settings/AffirmationPicker.swift` (optional)

---

## Phase 6: Session-Historie (Optional Feature)

### 6.1 Session-Historie-View

**Tasks:**

- Implementiere View zur Anzeige vergangener Sessions
- Füge Filter/Sortierung nach Datum, Modus, Dauer hinzu
- Implementiere Detail-View für einzelne Sessions
- Füge Export-Funktion hinzu (optional)

**Dateien:**

- Neue Datei: `MindSync/Features/History/SessionHistoryView.swift`
- Neue Datei: `MindSync/Features/History/SessionHistoryViewModel.swift`
- Neue Datei: `MindSync/Features/History/SessionDetailView.swift`
- `MindSync/Features/Home/HomeView.swift` (Navigation hinzufügen)

---

## Phase 7: Testing

### 7.1 Unit Tests vervollständigen

**Tasks:**

- Überprüfe vorhandene Tests auf Vollständigkeit
- Füge fehlende Unit Tests hinzu für kritische Komponenten
- Stelle sicher, dass alle Services getestet sind
- Teste Edge Cases in Unit Tests

**Dateien:**

- `MindSyncTests/Unit/**/*.swift`
- Alle Service- und Core-Dateien

### 7.2 Integration Tests

**Tasks:**

- Implementiere Integration Tests für Audio-Analyse-Pipeline
- Teste Session-Lifecycle komplett
- Teste Licht-Synchronisation mit Audio
- Teste Mikrofon-Modus Integration

**Dateien:**

- `MindSyncTests/Integration/**/*.swift`

### 7.3 UI Tests erweitern

**Tasks:**

- Vervollständige UI Tests für alle Haupt-Flows
- Teste Onboarding-Flow
- Teste Session-Start/Stop/Pause/Resume
- Teste Settings-Änderungen
- Teste Error-Handling in UI

**Dateien:**

- `MindSyncUITests/**/*.swift`

---

## Phase 8: Performance & Optimierung

### 8.1 Audio-Analyse Optimierung

**Tasks:**

- Profiliere Audio-Analyse-Performance
- Optimiere FFT-Berechnungen falls nötig
- Implementiere Caching für analysierte Tracks
- Verbessere Memory-Management bei großen Audio-Dateien

**Dateien:**

- `MindSync/Core/Audio/AudioAnalyzer.swift`
- `MindSync/Core/Audio/AudioFileReader.swift`
- `MindSync/Core/Audio/BeatDetector.swift`

### 8.2 UI-Performance

**Tasks:**

- Optimiere SwiftUI-View-Updates
- Reduziere unnötige Re-Renderings
- Verbessere Animation-Performance
- Optimiere Memory-Nutzung in Views

**Dateien:**

- Alle View-Dateien
- `MindSync/Features/Session/SessionViewModel.swift`

---

## Phase 9: Dokumentation

### 9.1 Code-Dokumentation

**Tasks:**

- Füge Swift-Doc-Comments zu allen public APIs hinzu
- Dokumentiere komplexe Algorithmen (Beat-Detection, Entrainment)
- Erstelle README für Entwickler-Onboarding
- Dokumentiere Architektur-Entscheidungen

**Dateien:**

- `docs/architecture.md` (erweitern)
- `docs/DEVELOPMENT.md` (neu)
- Alle Swift-Dateien

### 9.2 User-Dokumentation (Optional)

**Tasks:**

- Erstelle Anleitung für Endnutzer
- Dokumentiere Sicherheitshinweise
- Erkläre Entrainment-Modi
- Tipps zur optimalen Nutzung

**Dateien:**

- `docs/USER_GUIDE.md` (neu)

---

## Phase 10: Finale Validierung

### 10.1 Manuelle Tests

**Tasks:**

- Führe vollständige manuelle Tests durch
- Teste alle User Stories aus der Spec
- Teste auf verschiedenen Geräten (iPhone SE, iPhone 15 Pro, etc.)
- Teste Edge Cases manuell
- Dokumentiere gefundene Issues

**Checkliste:**

- ✅ Onboarding-Flow funktioniert
- ✅ Lokale Musik-Session funktioniert
- ✅ Mikrofon-Modus funktioniert
- ✅ Modus-Wechsel funktioniert
- ✅ Taschenlampen-Modus funktioniert
- ✅ Bildschirm-Modus funktioniert
- ✅ Thermisches Management funktioniert
- ✅ Fall-Erkennung funktioniert
- ✅ Pause/Resume funktioniert
- ✅ Error-Handling ist robust

### 10.2 App Store Vorbereitung

**Tasks:**

- Überprüfe Info.plist auf Vollständigkeit
- Stelle sicher, dass alle Berechtigungs-Beschreibungen vorhanden sind
- Erstelle App-Icon und Screenshots
- Überprüfe Privacy Policy Requirements
- Teste App auf TestFlight

**Dateien:**

- `MindSync/Info.plist`
- App-Icon-Assets
- Screenshot-Assets

---

## Priorisierung

**Kritisch (MVP):**

1. Phase 1: Kritische fehlende Komponenten
2. Phase 2: Error Handling & Edge Cases (mindestens kritische Fälle)
3. Phase 3: UI-Verbesserungen (Minimum für nutzbare App)

**Wichtig (Release-Qualität):**

4. Phase 4: Lokalisierung
5. Phase 7: Testing (mindestens kritische Tests)
6. Phase 10: Finale Validierung

**Nice-to-Have (Erweiterungen):**

7. Phase 5: Affirmationen-Feature UI
8. Phase 6: Session-Historie
9. Phase 8: Performance Optimierung
10. Phase 9: Dokumentation

---

## Abhängigkeiten

```javascript
Phase 1 → Phase 2 → Phase 3
                ↓
            Phase 4
                ↓
            Phase 5 (optional)
            Phase 6 (optional)
                ↓
            Phase 7
                ↓
            Phase 8
                ↓
            Phase 9
                ↓
            Phase 10
```

**Parallele Arbeit möglich:**

- Phase 4 (Lokalisierung) kann parallel zu Phase 3 laufen