---
name: UI Überarbeitung für bessere User Experience
overview: Überarbeitung der MindSync-UI für eine modernere, visuell ansprechendere und benutzerfreundlichere Oberfläche. Fokus auf visuelle Hierarchie, verbesserte Navigation, Illustrationen und verbesserte Onboarding-Erfahrung.
todos:
  - id: home-view-improvement
    content: "HomeView überarbeiten: Hero-Section verbessern, Status-Grid visueller gestalten, bessere Spacing und Card-Designs"
    status: completed
  - id: onboarding-improvement
    content: "OnboardingView verbessern: Visuelleres Layout, bessere Typografie-Hierarchie, weniger textlastig"
    status: completed
  - id: source-selection-improvement
    content: "SourceSelectionView überarbeiten: Card-basiertes Layout, bessere Icons, weniger technische Sprache"
    status: completed
  - id: settings-improvement
    content: "SettingsView verbessern: Card-basiertes Layout statt Form, bessere Gruppierung, visuellere Sections"
    status: completed
  - id: mode-selection-improvement
    content: "ModeSelectionView verbessern: Größere Cards, bessere Icon-Darstellung, subtile Animationen"
    status: completed
  - id: session-view-refinement
    content: "SessionView feinabstimmen: Track-Info Card verbessern, visuellere Controls"
    status: completed
  - id: new-components
    content: "Neue wiederverwendbare Komponenten erstellen: SettingsCard, InfoCard (optional)"
    status: completed
  - id: design-system-polish
    content: "Design-System verfeinern: Card-Styles, Spacing, Typografie-Konsistenz verbessern"
    status: completed
---

# UI-Überarbeitung für bessere User Experience

## Problemstellung

Die aktuelle UI ist funktional, aber sehr entwicklerorientiert mit folgenden Hauptproblemen:

1. **Fehlende visuelle Hierarchie**: Screens sind textlastig und wirken überladen
2. **Minimalistische Home-Screen**: Einfacher Titel und Button, wenig einladend
3. **Onboarding zu textlastig**: Warnung dominiert, wenig visuelle Anleitung
4. **Settings-View zu funktional**: Standard iOS Form, nicht visuell ansprechend
5. **Source-Selection zu technisch**: Zwei große Buttons ohne visuelle Unterscheidung
6. **Fehlende Illustrationen/Graphics**: Nur System-Icons, keine visuellen Elemente
7. **Statisches UI**: Keine subtilen Animationen oder Übergänge

## Verbesserungsansatz

Die Überarbeitung fokussiert auf:
- **Visuelle Hierarchie**: Klarere Struktur, bessere Spacing, Fokus auf Hauptaktionen
- **Moderne UI-Patterns**: Card-basierte Layouts, verbesserte Buttons, bessere Typografie
- **Onboarding-Erfahrung**: Visueller, weniger bedrohlich, mehr Führung
- **Home-Screen**: Attraktiverer Einstiegspunkt mit besserer Information Architektur
- **Settings**: Visueller organisierter, weniger überladen
- **Micro-Interactions**: Subtile Animationen für besseres Feedback

## Implementierungsplan

### 1. HomeView-Verbesserung ([MindSync/Features/Home/HomeView.swift](MindSync/Features/Home/HomeView.swift))

**Aktuelle Probleme:**
- Sehr minimalistisch: Nur Titel, ein Button, Grid mit Status
- Fehlende visuelle Elemente
- Status-Grid könnte klarer strukturiert sein

**Verbesserungen:**
- **Hero-Section**: Größerer, visuellerer Titel-Bereich mit subtilen Grafikelementen
- **Verbessertes Status-Grid**: Cards mit Icons und klarerer Hierarchie
- **Quick-Actions**: Visuellere Darstellung häufig genutzter Aktionen
- **Spacing-Verbesserungen**: Mehr Atemraum zwischen Elementen
- **Card-Design**: Einheitlichere Card-Styles mit besserer visueller Hierarchie

**Dateien:**
- `MindSync/Features/Home/HomeView.swift` - Haupt-View überarbeiten
- Optional: Neue Komponente `HomeStatusCard.swift` für bessere Status-Darstellung

### 2. OnboardingView-Verbesserung ([MindSync/Features/Onboarding/OnboardingView.swift](MindSync/Features/Onboarding/OnboardingView.swift))

**Aktuelle Probleme:**
- Sehr textlastig, Warnung dominiert
- Fehlende visuelle Elemente außer Warn-Icon
- Wirkt zu technisch/medizinisch

**Verbesserungen:**
- **Visuelleres Layout**: Größeres Icon, bessere Typografie-Hierarchie
- **Bessere Textstrukturierung**: Klarere Abschnitte, bessere Lesbarkeit
- **Visuelle Elemente**: Subtile Hintergrund-Elemente oder Patterns
- **Verbesserte Buttons**: Klarere Call-to-Actions
- **Progress-Indicator**: Wenn mehrstufiges Onboarding (optional)

**Dateien:**
- `MindSync/Features/Onboarding/OnboardingView.swift` - Layout überarbeiten
- `MindSync/Features/Onboarding/EpilepsyWarningView.swift` - Prüfen und ggf. verbessern

### 3. SourceSelectionView-Verbesserung ([MindSync/Features/Home/SourceSelectionView.swift](MindSync/Features/Home/SourceSelectionView.swift))

**Aktuelle Probleme:**
- Zwei große Buttons, wenig visuell unterscheidbar
- Technische Sprache (DRM-Warnung)
- Fehlende visuelle Führung

**Verbesserungen:**
- **Card-basiertes Layout**: Visuellere Cards mit besseren Icons
- **Bessere Beschreibungen**: Weniger technisch, mehr nutzerorientiert
- **Visuelle Hierarchie**: Eine Option visuell hervorheben (z.B. File-Picker)
- **Verbesserte Icons**: Größere, aussagekräftigere Icons
- **Bessere Warnings**: Weniger technisch, mehr nutzerfreundlich

**Dateien:**
- `MindSync/Features/Home/SourceSelectionView.swift` - Card-Layout implementieren

### 4. SettingsView-Verbesserung ([MindSync/Features/Settings/SettingsView.swift](MindSync/Features/Settings/SettingsView.swift))

**Aktuelle Probleme:**
- Standard iOS Form-Layout
- Viele Sections, wirkt überladen
- Fehlende visuelle Gruppierung

**Verbesserungen:**
- **Card-basierte Sections**: Statt Standard Form-Sections
- **Bessere Gruppierung**: Visuell klarere Kategorien
- **Icons in Sections**: Visuellere Headers
- **Verbesserte Slider-Darstellung**: Visuellere Controls
- **Spacing**: Mehr Atemraum zwischen Sections

**Dateien:**
- `MindSync/Features/Settings/SettingsView.swift` - Form zu Card-Layout ändern
- Optional: Neue Komponenten für Settings-Cards

### 5. SessionView-Verbesserung ([MindSync/Features/Session/SessionView.swift](MindSync/Features/Session/SessionView.swift))

**Aktuelle Probleme:**
- Relativ gut, aber könnte visueller sein
- Track-Info könnte prominenter sein
- Controls könnten visueller sein

**Verbesserungen:**
- **Track-Info Card**: Größere, visuellere Card für Track-Informationen
- **Verbesserte Controls**: Visuellere Darstellung der Session-Controls
- **Bessere Progress-Anzeige**: Visuellere Progress-Indikatoren
- **Status-Banner**: Verbesserte Darstellung

**Dateien:**
- `MindSync/Features/Session/SessionView.swift` - Track-Info und Controls verbessern

### 6. ModeSelectionView-Verbesserung ([MindSync/Features/Home/ModeSelectionView.swift](MindSync/Features/Home/ModeSelectionView.swift))

**Aktuelle Probleme:**
- Relativ gut, aber Cards könnten visueller sein
- Fehlende visuelle Elemente

**Verbesserungen:**
- **Größere Cards**: Mehr Platz für Informationen
- **Bessere Icon-Darstellung**: Größere, visuellere Icons
- **Subtile Animationen**: Bei Selektion
- **Bessere Beschreibungen**: Visuellere Typografie

**Dateien:**
- `MindSync/Features/Home/ModeSelectionView.swift` - Card-Design verbessern

### 7. Neue wiederverwendbare Komponenten

**Zu erstellende Komponenten:**
- **SettingsCard**: Card-Komponente für Settings-Sections
- **InfoCard**: Standardisierte Info-Card für verschiedene Use-Cases
- **SectionHeader**: Verbesserter Section-Header mit Icons

**Dateien:**
- `MindSync/Shared/Components/SettingsCard.swift` - Neue Komponente
- `MindSync/Shared/Components/InfoCard.swift` - Neue Komponente (optional)

### 8. Design-System-Verbesserungen

**Zu verbessern:**
- **Card-Styles**: Einheitlichere Card-Definitionen
- **Spacing**: Konsistentere Spacing-Verwendung
- **Typography**: Verbesserte Typografie-Hierarchie
- **Colors**: Ggf. feinere Abstufungen für bessere Kontraste

**Dateien:**
- `MindSync/Shared/Extensions/View+Gestures.swift` - Card-Style-Modifier verbessern
- `MindSync/Shared/Constants.swift` - Ggf. zusätzliche Spacing-Werte

## Technische Details

### Design-Prinzipien

1. **Card-basiertes Design**: Konsistente Card-Komponenten für bessere visuelle Hierarchie
2. **Spacing**: Mehr Atemraum zwischen Elementen (aktuell zu kompakt)
3. **Typografie**: Klarere Hierarchie mit besseren Font-Größen
4. **Icons**: Größere, aussagekräftigere Icons
5. **Subtile Animationen**: Spring-Animationen für Interaktionen

### Kompatibilität

- Alle Änderungen bleiben kompatibel mit bestehender Funktionalität
- Keine Breaking Changes für ViewModels oder Services
- Nur visuelle/UX-Verbesserungen, keine Funktionalitätsänderungen

### Testing

- UI-Tests bleiben gültig (Accessibility-Identifier bleiben)
- Manuelle Testing der verbesserten Screens
- Dark Mode Kompatibilität sicherstellen

## Priorisierung

**Phase 1 (Höchste Priorität):**
1. HomeView-Verbesserung
2. OnboardingView-Verbesserung
3. SourceSelectionView-Verbesserung

**Phase 2:**
4. SettingsView-Verbesserung
5. ModeSelectionView-Verbesserung

**Phase 3:**
6. SessionView-Feinabstimmungen
7. Neue wiederverwendbare Komponenten

## Erwartete Ergebnisse

- **Moderne UI**: Visuell ansprechendere, zeitgemäße Oberfläche
- **Bessere UX**: Klarere Navigation, bessere Führung
- **Professionelleres Erscheinungsbild**: Weniger "Developer-UI", mehr Produkt-UI
- **Konsistentes Design**: Einheitlicheres Design-System