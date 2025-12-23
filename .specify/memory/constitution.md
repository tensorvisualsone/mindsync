# MindSync Constitution

<!--
Sync Impact Report
- Version change: 0.0.0 → 1.0.0 (initial ratified version for the MindSync iOS App project)
- Modified principles: (template placeholders replaced with concrete principles)
  - [PRINCIPLE_1_NAME] → Mobile-First User Value
  - [PRINCIPLE_2_NAME] → iOS-Native Architecture & Quality
  - [PRINCIPLE_3_NAME] → Test-First & Continuous Quality
  - [PRINCIPLE_4_NAME] → Privacy, Security & Data Minimization
  - [PRINCIPLE_5_NAME] → Simplicity, Focus & Maintainability
- Added sections:
  - Platform & Technical Constraints (Section 2)
  - Development Workflow & Quality Gates (Section 3)
- Removed sections:
  - None (all template sections instantiated, none deleted)
- Templates requiring updates:
  - .specify/templates/plan-template.md        → ✅ aligned (uses Constitution Check but no hard-coded rules)
  - .specify/templates/spec-template.md        → ✅ aligned (neutral to principles)
  - .specify/templates/tasks-template.md       → ✅ aligned (supports test-first and independent stories)
  - .specify/templates/agent-file-template.md  → ✅ aligned (generic guidance)
  - .specify/templates/checklist-template.md   → ✅ aligned (generic checklist scaffold)
  - .specify/templates/commands/*.md           → ⚠ pending (no command templates present in repo to verify)
- Deferred TODOs:
  - TODO(RATIFICATION_DATE): Set original ratification date once agreed by maintainer
-->

## Core Principles

### I. Mobile-First User Value

MindSync exists primär als iOS-App; **jede Entscheidung MUSS nachweisbar den Nutzen
für Endnutzer*innen auf dem iPhone verbessern**. Features werden in klaren,
inkrementell auslieferbaren User Journeys geschnitten, die jeweils alleine
wertstiftend sind und sich unabhängig testen und ausliefern lassen.

**Rationale**: Die App soll sich nativer als "Spielerei" anfühlen: schnell,
verlässlich, klar fokussiert auf wenige Kern-Flows statt auf viele halbgare
Funktionen.

### II. iOS-Native Architecture & Quality

Die App **MUSS** mit einem modernen, nativen Technologie-Stack für iOS
umgesetzt werden (z. B. Swift + SwiftUI + Combine/Swift Concurrency) und auf
aktuellen iOS-Versionen (mindestens iOS 17+) stabil laufen. UI- und
Architektur-Entscheidungen **MÜSSEN** die Apple Human Interface Guidelines,
Barrierefreiheit und 60fps-Interaktionen als Ziel berücksichtigen.

**Rationale**: Ein nativer Stack nutzt die Stärken des iPhone (Performance,
Gesten, Systemintegration) voll aus und reduziert langfristig technischen
Ballast.

### III. Test-First & Continuous Quality

Neue Funktionalität **MUSS** testgetrieben (TDD-ähnlich) entstehen: Zuerst
werden Akzeptanz- und/oder Komponententests definiert, dann wird die
Implementierung umgesetzt, bis die Tests grün sind. Ein automatisierter
Build-/Test-Workflow (z. B. Xcode Tests + CI) **MUSS** für jede relevante
Komponente vorhanden sein, bevor sie für Releases genutzt wird.

**Rationale**: Die App soll sich stabil anfühlen; gerade auf Mobilgeräten
fallen Abstürze und UI-Fehler besonders stark auf und frustrieren Nutzer sehr
schnell.

### IV. Privacy, Security & Data Minimization

MindSync **MUSS** nach dem Prinzip der Datensparsamkeit arbeiten: Es werden nur
die Daten erfasst und verarbeitet, die für die Kernfunktionen zwingend
notwendig sind. Sensible oder personenbezogene Daten **MÜSSEN** lokal sicher
(z. B. Keychain, geschützte Container) gespeichert und bei Übertragung Ende-
zu-Ende geschützt werden. Tracking- und Analysedaten **DÜRFEN** nur erhoben
werden, wenn sie begründet sind und sich klar in der App-Kommunikation
widerspiegeln.

**Rationale**: Nutzer*innen vertrauen der App persönliche Informationen an; das
Projekt darf dieses Vertrauen weder technisch noch kommunikativ verletzen.

### V. Simplicity, Focus & Maintainability

Der Funktionsumfang der App **MUSS** bewusst fokussiert bleiben: Jede neue
Funktion **MUSS** klaren Mehrwert nachweisen, einen eindeutigen Besitzer haben
und in die bestehenden Kern-Journeys passen. Architektur- und
Abstraktionsentscheidungen **DÜRFEN** nur getroffen werden, wenn sie konkrete,
aktuelle Probleme lösen und die Komplexität insgesamt senken.

**Rationale**: Ein kleiner, gut wartbarer Code- und Feature-Umfang ist für eine
Einzelperson oder ein kleines Team entscheidend, um langfristig Releases
schnell und sicher liefern zu können.

## Platform & Technical Constraints

Diese Sektion konkretisiert die technischen Leitplanken für MindSync.

- **Zielplattform**: Primär iOS (iPhone), sekundär iPadOS, mit einem gemeinsam
  wartbaren Code-Basis.
- **Minimal unterstützte iOS-Version**: iOS 17 (kann angepasst werden, muss
  dann in Release-Notizen und Dokumentation nachvollziehbar begründet sein).
- **Programmiersprache & UI-Framework**: Swift (aktuelles Stable Release) mit
  SwiftUI für neue Oberflächen; UIKit darf in klar abgegrenzten Bereichen
  verwendet werden, wenn SwiftUI nicht ausreicht.
- **Leistungsziele**:
  - App-Start bis zur ersten nutzbaren Ansicht SHOULD < 2 Sekunden auf
    Zielgeräten liegen.
  - Interaktionen in Kern-Views MUST flüssig bei ~60fps ablaufen.
  - Teure Hintergrundarbeit MUSS in Neben-Tasks mit sauberem
    Lade-/Fortschrittsfeedback ausgelagert werden.
- **Offline-Fähigkeit**: Kernfunktionen, bei denen es sinnvoll ist, SOLLTEN
  offline funktionieren; bei zwingend online-pflichtigen Flows MUSS die App
  klar und frühzeitig kommunizieren, dass eine Verbindung benötigt wird.
- **Fehler- und Zustandsmanagement**: Fehlerzustände **MÜSSEN** klar im UI
  dargestellt werden (keine stillen Fehlschläge) und, wo möglich, eine
  Wiederholaktion anbieten.

## Development Workflow & Quality Gates

Diese Sektion beschreibt den erwarteten Arbeitsablauf und die
Qualitätssicherung für neue Features.

- **Spezifikation vor Implementierung**:
  - Für neue Features wird eine leichtgewichtige Spezifikation erstellt
    (z. B. über speckit `spec.md`), die mindestens Kern-User-Stories,
    Akzeptanzkriterien und Erfolgskriterien beschreibt.
  - User-Stories MÜSSEN priorisiert sein (P1, P2, P3) und jeweils als
    eigenständige, testbare Inkremente formuliert werden.
- **Planung & Architektur**:
  - Vor Beginn der Implementierung MUSS ein knapper Plan (`plan.md`) die
    geplante iOS-Architektur (z. B. View/Feature-Module, Datenfluss,
    Persistenzstrategie) festhalten.
  - Abhängigkeiten zu bestehenden Features MÜSSEN explizit gemacht und, wo
    möglich, minimiert werden.
- **Tasks & Umsetzung**:
  - Aufgaben (`tasks.md`) MÜSSEN nach User-Story und Phase gruppiert werden
    (Setup/Foundation/User Stories/Polish), sodass jede Story unabhängig
    fertiggestellt und getestet werden kann.
  - Tests (Unit/UI/Integration) SOLLTEN für P1- und P2-Stories explizit
    aufgeführt sein; wenn Tests bewusst weggelassen werden, MUSS dies
    dokumentiert und begründet werden.
- **Reviews & Merges**:
  - Jeder Merge in den Haupt-Branch MUSS einen erfolgreichen automatisierten
    Build/Test-Lauf durchlaufen.
  - Größere Architektur- oder UX-Änderungen SOLLTEN in einer kurzen Notiz
    dokumentiert werden (z. B. im Changelog oder in Projekt-Dokumentation).
- **Releases**:
  - Releases der App SOLLTEN in klaren, benannten Inkrementen erfolgen
    (z. B. v1.0, v1.1), mit Release Notes, die aus den Spezifikationen und
    Tasks abgeleitet werden können.

## Governance

- **Vorrang der Verfassung**:
  - Diese MindSync Constitution **hat Vorrang** vor inoffiziellen Praktiken,
    Ad-hoc-Entscheidungen oder historischen Gewohnheiten.
  - Wenn bestehender Code oder Prozesse gegen diese Verfassung verstoßen,
    MUSS dies im Rahmen regulärer Wartungs- oder Feature-Arbeit adressiert
    werden (Refactoring, Prozessanpassung) oder in der Governance
    explizit begründet werden.
- **Änderungsverfahren**:
  - Jede inhaltliche Änderung an Prinzipien, technischen Leitplanken oder dem
    Workflow MUSS in dieser Datei festgehalten werden.
  - Änderungen MÜSSEN eine kurze Begründung im Sync Impact Report (Kommentar
    am Anfang der Datei) enthalten.
  - Backward-incompatible Änderungen an Prinzipien oder Pflichten gelten als
    **MAJOR**-Versionserhöhung, neue oder deutlich erweiterte Prinzipien als
    **MINOR**, reine Klarstellungen/Umformulierungen ohne
    Verhaltensänderung als **PATCH**.
- **Versionierung & Reviews**:
  - Vor dem Beginn größerer Features SOLLTE kurz geprüft werden, ob die
    aktuelle Verfassungsversion noch passend ist; bei erkennbaren
    Diskrepanzen MUSS entweder die Verfassung oder der geplante Ansatz
    angepasst werden.
  - Mindestens einmal pro Quartal SOLLTE ein kurzer Review der Prinzipien und
    Governance-Regeln erfolgen, um sicherzustellen, dass sie zum
    tatsächlichen Arbeitsmodus passen.
- **Compliance im Alltag**:
  - Feature-Spezifikationen, Pläne und Task-Listen SOLLTEN explizit einen
    "Constitution Check"-Abschnitt pflegen, in dem Abweichungen und
    bewusste Regelbrüche dokumentiert werden.
  - Dauerhafte, unbegründete Abweichungen von dieser Verfassung sind nicht
    zulässig; kurzfristige Ausnahmen MÜSSEN klar begrenzt und später
    aufgeräumt werden.

**Version**: 1.0.0 | **Ratified**: 2025-12-23 | **Last Amended**: 2025-12-23
