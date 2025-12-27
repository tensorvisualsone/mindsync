# Tasks: MindSync Core App

**Input**: Design documents from `/specs/001-audio-strobe-sync/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Tests werden für P1- und P2-User-Stories explizit angelegt (TDD-Ansatz für kritische Teile).

**Organization**: Tasks sind nach Phasen und User Stories gruppiert, sodass jede Story unabhängig implementierbar und testbar ist.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Kann parallel laufen (andere Dateien, keine direkten Abhängigkeiten)
- **[Story]**: US1–US6 entsprechend der Spezifikation
- Alle Tasks enthalten exakte Dateipfade

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Repository vorbereiten, Xcode-Projekt und Grundstruktur anlegen.

- [ ] T001 Erstelle Xcode-Projekt `MindSync` als iOS-App (SwiftUI, iOS 17) in `MindSync/`
- [ ] T002 Konfiguriere Target-Einstellungen (iOS 17.0+, Portrait-Only) im Xcode-Target `MindSync`
- [ ] T003 Konfiguriere `Info.plist` von `MindSync` mit `NSMicrophoneUsageDescription` und `NSAppleMusicUsageDescription`
- [ ] T004 [P] Lege Basis-Ordnerstruktur für App an gemäß `MindSync/` Struktur in `MindSync/` (App, Features, Core, Models, Services, Shared, Resources)
- [ ] T005 [P] Lege Test-Targets `MindSyncTests` und `MindSyncUITests` in Xcode an und verknüpfe mit Projektdateien
- [ ] T006 Richte gemeinsames SwiftLint- oder Formatierungs-Setup (optional) in `MindSync/` ein (z.B. `.swiftlint.yml`)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Kern-Infrastruktur, die für alle User Stories benötigt wird.

- [ ] T007 Implementiere zentrale App-Einstiegsklasse in `MindSync/App/MindSyncApp.swift` (Switch zwischen `OnboardingView` und `HomeView` über `@AppStorage`)
- [ ] T008 Implementiere globale App-Statusverwaltung in `MindSync/App/AppState.swift` (z.B. aktueller Modus, aktive Session-Referenz)
- [ ] T009 [P] Implementiere Datenmodelle aus `data-model.md` in `MindSync/Models/EntrainmentMode.swift`, `AudioTrack.swift`, `LightScript.swift`, `Session.swift`, `UserPreferences.swift`
- [ ] T010 [P] Implementiere Sicherheitskonstanten `SafetyLimits` und Hilfstypen (`ThermalState`, `AnalysisProgress`) in `MindSync/Core/Safety/SafetyLimits.swift`
- [ ] T011 [P] Implementiere zentrale Service-Container-Klasse `ServiceContainer` in `MindSync/Services/ServiceContainer.swift` basierend auf den Contracts
- [ ] T012 Richte Basis-Navigation und Tab/Stack-Struktur in `MindSync/Features/Home/HomeView.swift` ein (Zugriff auf Session, Settings)

**Checkpoint**: Foundation steht – App startet, zeigt Onboarding oder leeren Home-Screen, Models und Service-Container sind vorhanden.

---

## Phase 3: User Story 2 - Sicherheits-Onboarding und Epilepsie-Warnung (Priority: P1)

**Goal**: Sicherstellen, dass jeder Nutzer beim ersten Start eine Epilepsie-Warnung sieht und bestätigen muss.

**Independent Test**: Auf frischer Installation erscheint der Disclaimer verpflichtend; nach Bestätigung startet die App direkt in den Home-Screen.

### Tests für User Story 2

- [ ] T013 [P] [US2] Erstelle Unit Tests für `UserPreferences.epilepsyDisclaimerAccepted` in `MindSyncTests/Unit/UserPreferencesTests.swift`
- [ ] T014 [P] [US2] Erstelle UI-Test, der das vollständige Onboarding durchläuft in `MindSyncUITests/OnboardingUITests.swift`

### Implementation für User Story 2

- [ ] T015 [P] [US2] Implementiere `OnboardingView` mit Epilepsie-Warntext und Bestätigungs-Button in `MindSync/Features/Onboarding/OnboardingView.swift`
- [ ] T016 [US2] Implementiere `EpilepsyWarningView` mit ausführlicher Warnung und Scrollbereich in `MindSync/Features/Onboarding/EpilepsyWarningView.swift`
- [ ] T017 [US2] Implementiere `OnboardingViewModel` zur Steuerung des Flows und Setzen von `epilepsyDisclaimerAccepted` in `MindSync/Features/Onboarding/OnboardingViewModel.swift`
- [ ] T018 [US2] Verbinde `MindSyncApp` mit `OnboardingView` über `@AppStorage("epilepsyDisclaimerAccepted")` in `MindSync/App/MindSyncApp.swift`
- [ ] T019 [US2] Erweitere `UserPreferences` um `epilepsyDisclaimerAcceptedAt` und persistiere in `MindSync/Models/UserPreferences.swift`
- [ ] T020 [US2] Implementiere Info-Screen oder Link zu weiteren Sicherheitsinformationen (z.B. Modal) in `MindSync/Features/Onboarding/OnboardingView.swift`

**Checkpoint**: User Story 2 ist vollständig – kein Zugriff auf Home/Session ohne bestätigten Disclaimer.

---

## Phase 4: User Story 1 - Lokale Musik mit Stroboskop-Synchronisation (Priority: P1) 🎯 MVP

**Goal**: Nutzer kann lokalen Song wählen und eine synchronisierte Taschenlampen-Sitzung starten und stoppen.

**Independent Test**: Ausgehend vom Home-Screen kann ein DRM-freier Song gewählt werden, eine Session starten und das Licht im Takt des Beats blinken.

### Tests für User Story 1

- [ ] T021 [P] [US1] Erstelle Unit Tests für Beat-Detection in `MindSyncTests/Unit/BeatDetectorTests.swift` (synthetische Audio-Daten)
- [ ] T022 [P] [US1] Erstelle Integrationstest für `AudioAnalyzer` mit Testdatei in `MindSyncTests/Integration/AudioAnalyzerIntegrationTests.swift`
- [ ] T023 [P] [US1] Erstelle UI-Test für Flow "Song wählen → Session starten → Session stoppen" in `MindSyncUITests/SessionUITests.swift`

### Implementation für User Story 1

- [ ] T024 [P] [US1] Implementiere `MediaLibraryService` für Song-Auswahl und DRM-Check in `MindSync/Services/MediaLibraryService.swift`
- [ ] T025 [P] [US1] Implementiere `AudioFileReader` zur PCM-Extraktion via `AVAssetReader` in `MindSync/Core/Audio/AudioFileReader.swift`
- [ ] T026 [P] [US1] Implementiere `BeatDetector` (FFT + Spectral Flux) in `MindSync/Core/Audio/BeatDetector.swift`
- [ ] T027 [P] [US1] Implementiere `TempoEstimator` zur BPM-Bestimmung in `MindSync/Core/Audio/TempoEstimator.swift`
- [ ] T028 [US1] Implementiere `AudioAnalyzer` als Orchestrator (Reader + BeatDetector + TempoEstimator + LightScript-Erstellung) in `MindSync/Core/Audio/AudioAnalyzer.swift`
- [ ] T029 [P] [US1] Implementiere `AudioPlaybackService` mit `AVAudioPlayer` oder `AVAudioEngine` in `MindSync/Services/AudioPlaybackService.swift`
- [ ] T030 [P] [US1] Implementiere `FlashlightController` für Torch-Steuerung (lockForConfiguration + setTorchModeOn) in `MindSync/Core/Light/FlashlightController.swift`
- [ ] T031 [US1] Implementiere generisches `LightController`-Protokoll und Default-Implementierung in `MindSync/Core/Light/LightController.swift`
- [ ] T032 [US1] Implementiere `EntrainmentEngine` zur Erzeugung von `LightScript` aus `AudioTrack` und `EntrainmentMode` in `MindSync/Core/Entrainment/EntrainmentEngine.swift`
- [ ] T033 [US1] Implementiere `LightScript`-Handling (Sequenz-Abspiel-Logik) in `MindSync/Core/Entrainment/LightScript.swift`
- [ ] T034 [US1] Implementiere `SessionViewModel` zur Steuerung von Analyse, Playback und Licht in `MindSync/Features/Session/SessionViewModel.swift`
- [ ] T035 [US1] Implementiere `SessionView` mit Start/Stop-Steuerung und Statusanzeigen in `MindSync/Features/Session/SessionView.swift`
- [ ] T036 [US1] Implementiere `AnalysisProgressView` zur Anzeige der Analysephasen in `MindSync/Features/Session/AnalysisProgressView.swift`
- [ ] T037 [US1] Implementiere `SourceSelectionView` für Musikquellen (lokale Bibliothek) in `MindSync/Features/Home/SourceSelectionView.swift`
- [ ] T038 [US1] Verbinde `HomeView` mit Session-Flow (Song wählen → Analyse → Session) in `MindSync/Features/Home/HomeView.swift`
- [ ] T039 [US1] Implementiere Fehlerbehandlung für DRM-geschützte Songs (Dialog mit Hinweis und Mikrofon-Empfehlung) in `MindSync/Services/MediaLibraryService.swift`

**Checkpoint**: User Story 1 ist funktionsfähig und testbar – MVP erreichbar.

---

## Phase 5: User Story 3 - Stimmungsbasierte Entrainment-Modi (Priority: P2)

**Goal**: Nutzer kann zwischen Entspannung (Alpha), Trip (Theta) und Fokus (Gamma) wählen.

**Independent Test**: Moduswechsel ändert messbar die Blinkfrequenz und das subjektive Erlebnis.

### Tests für User Story 3

- [ ] T040 [P] [US3] Erstelle Unit Tests für `EntrainmentMode.frequencyRange` und `targetFrequency` in `MindSyncTests/Unit/FrequencyMapperTests.swift`
- [ ] T041 [P] [US3] Erstelle Unit Tests für Multiplikator-Berechnung (`calculateMultiplier`) in `MindSyncTests/Unit/EntrainmentEngineTests.swift`

### Implementation für User Story 3

- [ ] T042 [P] [US3] Implementiere `ModeSelectionView` mit Auswahl Alpha/Theta/Gamma in `MindSync/Features/Home/ModeSelectionView.swift`
- [ ] T043 [US3] Erweitere `UserPreferences` um `preferredMode` und initialisiere mit `.alpha` in `MindSync/Models/UserPreferences.swift`
- [ ] T044 [US3] Verbinde `ModeSelectionView` mit `UserPreferences` und `SessionViewModel` in `MindSync/Features/Home/ModeSelectionView.swift`
- [ ] T045 [US3] Implementiere Frequenz-Mapping-Logik im `EntrainmentEngine` (BPM → Hz → LightScript) in `MindSync/Core/Entrainment/EntrainmentEngine.swift`
- [ ] T046 [US3] Zeige aktuellen Modus und Ziel-Frequenz im UI der `SessionView` in `MindSync/Features/Session/SessionView.swift`

**Checkpoint**: User Story 3 ist unabhängig funktionsfähig – Modi beeinflussen die generierten LightScripts.

---

## Phase 6: User Story 6 - Thermisches Management und Überhitzungsschutz (Priority: P2)

**Goal**: App reagiert auf thermische Zustände und schützt Gerät sowie Nutzererlebnis.

**Independent Test**: Lange Sessions mit hoher Intensität führen zu sanfter Reduktion oder Modus-Wechsel statt abruptem Abbruch.

### Tests für User Story 6

- [ ] T047 [P] [US6] Erstelle Unit Tests für `ThermalState.maxFlashlightIntensity` und `shouldSwitchToScreen` in `MindSyncTests/Unit/ThermalManagerTests.swift`

### Implementation für User Story 6

- [ ] T048 [P] [US6] Implementiere `ThermalManager` zur Beobachtung von `ProcessInfo.processInfo.thermalState` in `MindSync/Core/Light/ThermalManager.swift`
- [ ] T049 [US6] Integriere `ThermalManager` in `ServiceContainer` in `MindSync/Services/ServiceContainer.swift`
- [ ] T050 [US6] Implementiere Logik in `FlashlightController`, die Intensität basierend auf `ThermalState.maxFlashlightIntensity` begrenzt in `MindSync/Core/Light/FlashlightController.swift`
- [ ] T051 [US6] Implementiere automatischen Fallback auf Bildschirm-Modus bei `.serious`/`.critical` ThermalState in `MindSync/Core/Light/LightController.swift`
- [ ] T052 [US6] Zeige dezente UI-Warnung (z.B. `SafetyBanner`) bei thermischer Reduktion in `MindSync/Shared/Components/SafetyBanner.swift`

**Checkpoint**: User Story 6 ist funktionsfähig – App verhält sich vorhersehbar bei Hitze.

---

## Phase 7: User Story 5 - Bildschirm-Modus als Alternative zur Taschenlampe (Priority: P3)

**Goal**: Nutzer kann den Bildschirm als primäre Lichtquelle nutzen (inkl. Farbwahl).

**Independent Test**: Mit deaktivierter Taschenlampe erzeugt der Bildschirm im Dunkeln ein eigenständiges Erlebnis.

### Tests für User Story 5

- [ ] T053 [P] [US5] Erstelle UI-Test für Wechsel zwischen Taschenlampen- und Bildschirm-Modus in `MindSyncUITests/SettingsUITests.swift`

### Implementation für User Story 5

- [ ] T054 [P] [US5] Implementiere `ScreenController` zur Vollbild-Farbflackern-Steuerung via `CADisplayLink` in `MindSync/Core/Light/ScreenController.swift`
- [ ] T055 [US5] Implementiere `LightSourcePicker` in `MindSync/Features/Settings/LightSourcePicker.swift`
- [ ] T056 [US5] Erweitere `SettingsView` um Auswahl der Lichtquelle und Farbe in `MindSync/Features/Settings/SettingsView.swift`
- [ ] T057 [US5] Verbinde `SessionViewModel` mit gewählter Lichtquelle und leite an `LightController` weiter in `MindSync/Features/Session/SessionViewModel.swift`
- [ ] T058 [US5] Deaktiviere Taschenlampen-Nutzung vollständig, wenn `LightSource.screen` aktiv ist, in `MindSync/Core/Light/FlashlightController.swift`

**Checkpoint**: User Story 5 ist funktionsfähig – Sitzungen können vollständig über den Bildschirm laufen.

---

## Phase 8: User Story 4 - Mikrofon-Modus für Streaming-Musik (Priority: P3)

**Goal**: Nutzer kann Streaming-Musik über das Mikrofon analysieren lassen.

**Independent Test**: Bei externer Musikquelle synchronisiert die App das Licht wahrnehmbar zum Beat.

### User Story 4: Mikrofon-Modus

**Status: Entfernt** - Der Mikrofon-Modus wurde aus dem Projekt entfernt, um den Fokus auf die Kernfunktionalität zu legen.

**Checkpoint**: User Story 4 ist funktionsfähig – Sessions funktionieren mit externer Streaming-Musik.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Verbesserungen, die mehrere User Stories betreffen.

- [ ] T066 [P] Überarbeite visuelles Design (Farben, Typografie, Layout) für alle Kern-Views in `MindSync/Features/*/*.swift`
- [ ] T067 Implementiere Haptic Feedback für zentrale Aktionen (Start/Stop, Moduswechsel) in `MindSync/Shared/Constants.swift` und nutzen in `SessionView`, `ModeSelectionView`
- [ ] T068 [P] Erweitere Lokalisierung (DE/EN) in `MindSync/Resources/Localizable.strings`
- [ ] T069 Füge Logging für wichtige Ereignisse (Session-Start/-Ende, Fehler) in `MindSync/Services/SessionHistoryService.swift` hinzu
- [ ] T070 [P] Schreibe Entwickler-Dokumentation zu Architektur und Entrainment-Algorithmus in `docs/architecture.md` (neuen Ordner anlegen)
- [ ] T071 Führe manuelle Tests gemäß `quickstart.md` auf realem Gerät durch und dokumentiere Ergebnisse in `specs/001-audio-strobe-sync/checklists/requirements.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Keine Abhängigkeiten – kann sofort gestartet werden
- **Foundational (Phase 2)**: Hängt von Setup ab – BLOCKIERT alle User Stories
- **User Stories (Phase 3–8)**: Alle hängen von Phase 2 ab
  - US2 & US1 (P1) zuerst implementieren (MVP)
  - Danach US3 & US6 (P2)
  - Anschließend US5 & US4 (P3)
- **Polish (Phase 9)**: Hängt von allen gewünschten User Stories ab

### User Story Dependencies

- **US2 (Onboarding, P1)**: Keine Abhängigkeit von anderen Stories – kann früh implementiert werden
- **US1 (Lokale Musik, P1)**: Benötigt Foundation und grundlegende Modelle/Services
- **US3 (Modi, P2)**: Baut auf US1 (Audio/Light) auf, aber UI/Logik ist separat testbar
- **US6 (Thermal, P2)**: Nutzt LightController, kann nach US1 implementiert werden
- **US5 (Screen-Modus, P3)**: Benötigt LightController-Grundlogik aus US1/US6
- **US4 (Mikrofon, P3)**: Benötigt Audio-Infrastruktur, aber eigenen Flow

### Within Each User Story

- Tests (falls vorhanden) definieren die gewünschte Funktionalität
- Models/Services implementieren Domänenlogik
- Views und ViewModels verbinden Flow und UI
- Jede Story ist unabhängig testbar und lieferbar

### Parallel Opportunities

- In **Phase 1–2**: Alle Tasks mit [P] können parallel bearbeitet werden (Struktur, Modelle, Linting)
- In **User Story Phasen**: 
  - Tests ([P]) können parallel zu Implementierung in anderen Dateien entstehen
  - Audio-, Light- und UI-Komponenten (unterschiedliche Ordner) können parallel entwickelt werden
  - Unterschiedliche User Stories (z.B. US3 vs. US6) können nach Abschluss von Phase 2 parallel laufen

---

## Implementation Strategy

### MVP First (User Story 2 + User Story 1)

1. Phase 1: Setup abschließen
2. Phase 2: Foundational aufsetzen (Models, App-Struktur, Services)
3. Phase 3: US2 (Onboarding & Sicherheit) implementieren und testen
4. Phase 4: US1 (Lokale Musik + Taschenlampen-Stroboskop) implementieren und testen
5. **STOP & VALIDATE**: Manuelle Tests auf Gerät, Feedback einsammeln

### Incremental Delivery

1. Nach MVP: US3 (Modi) + US6 (Thermal Management)
2. Danach: US5 (Screen-Modus) für sanfteres Erlebnis
3. Zuletzt: US4 (Mikrofon-Modus) für Streaming-Support
4. Polish-Phase für UX, Lokalisierung und Dokumentation

---

**Tasks Version**: 1.0.0 | **Status**: Ready for Implementation
