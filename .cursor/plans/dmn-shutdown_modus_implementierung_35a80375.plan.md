---
name: DMN-Shutdown Modus Implementierung
overview: Implementierung des neuen "DMN-Shutdown" Entrainment-Modus, der gezielt auf die Deaktivierung des Default Mode Network (DMN) abzielt und einen Ego-Dissolution-Zustand induziert, basierend auf dem wissenschaftlichen Konzept aus dem Gemini-Chat.
todos:
  - id: add-dmn-shutdown-mode
    content: EntrainmentMode Enum um .dmnShutdown Case erweitern mit allen Properties (frequencyRange, targetFrequency, startFrequency, rampDuration, iconName)
    status: completed
  - id: implement-script-generator
    content: generateDMNShutdownScript() Funktion in EntrainmentEngine Extension implementieren mit 4 Phasen (DISCONNECT, THE ABYSS, THE VOID, REINTEGRATION)
    status: completed
    dependencies:
      - add-dmn-shutdown-mode
  - id: update-engine-logic
    content: EntrainmentEngine.generateLightScript() und generateLightEvents() um DMN-Shutdown Special Case erweitern
    status: completed
    dependencies:
      - implement-script-generator
  - id: add-localization
    content: Lokalisierungsstrings für DMN-Shutdown Modus in Localizable.strings hinzufügen (displayName und description)
    status: completed
    dependencies:
      - add-dmn-shutdown-mode
  - id: update-selectors
    content: Waveform- und Intensity-Selektoren in EntrainmentEngine um DMN-Shutdown Case erweitern
    status: completed
    dependencies:
      - add-dmn-shutdown-mode
  - id: verify-ui-integration
    content: "UI-Integration testen: Modus sollte automatisch in ModeSelectionView erscheinen"
    status: completed
    dependencies:
      - add-dmn-shutdown-mode
      - add-localization
---

# DMN-Shutdown Modus Implementierung

## Übersicht

Der "DMN-Shutdown" Modus ist ein spezieller Entrainment-Flow, der ohne Audio-Analyse funktioniert und eine feste 30-minütige Sequenz erzeugt. Er zielt darauf ab, das Default Mode Network (DMN) zu deaktivieren und einen Zustand der Ego-Dissolution (Ich-Auflösung) zu erreichen, wie im Gemini-Chat beschrieben.

## Architektur

Der neue Modus folgt dem bestehenden Pattern von `generateAwakeningScript()` in [EntrainmentEngine.swift](MindSync/Core/Entrainment/EntrainmentEngine.swift), verwendet jedoch feste Frequenzen mit `frequencyOverride` statt Audio-basierter Beat-Erkennung.

### Frequenz-Phasen

1. **Phase 1: DISCONNECT (4 Min)** - 10Hz → 5Hz Ramp (Alpha zu Theta)
2. **Phase 2: THE ABYSS (12 Min)** - 4.5Hz Theta mit variierender Intensität
3. **Phase 3: THE VOID / PEAK (8 Min)** - 40Hz Gamma-Burst
4. **Phase 4: REINTEGRATION (6 Min)** - 7.83Hz Schumann-Resonanz

## Implementierungsschritte

### 1. EntrainmentMode Enum erweitern

**Datei**: [EntrainmentMode.swift](MindSync/Models/EntrainmentMode.swift)

- `.dmnShutdown` Case hinzufügen
- `frequencyRange`: 4.5...40.0 Hz (spans alle Phasen)
- `targetFrequency`: 40.0 Hz (Gamma-Peak)
- `startFrequency`: 10.0 Hz (Start der Phase 1)
- `rampDuration`: 240.0 Sekunden (Phase 1 Dauer)
- `iconName`: `"moon.stars.fill"` (SF Symbol für spirituellen/transzendenten Zustand)

### 2. DMN-Shutdown Script Generator

**Datei**: [EntrainmentEngine.swift](MindSync/Core/Entrainment/EntrainmentEngine.swift)

- Neue statische Funktion `generateDMNShutdownScript()` in der Extension hinzufügen
- Implementierung der 4 Phasen:
- **Phase 1**: 1-Sekunden-Events mit smoothstep-Interpolation von 10Hz → 5Hz, **square wave**, Intensität 0.4, blau
- **Phase 2**: 2-Sekunden-Events bei 4.5Hz mit alternierender Intensität (0.35/0.25), **sine wave**, lila
- **Phase 3**: Ein einzelnes Event bei 40Hz für 8 Minuten, **square wave**, Intensität 0.75, weiß
- **Phase 4**: Ein Event bei 7.83Hz für 6 Minuten, **sine wave**, Intensität 0.4, grün

**KRITISCH - Event-Dauer Regel (aus Chat-Verlauf gelernt):**

- **NICHT** `period / 2.0` für Square-Wellen-Events verwenden (verursacht zu kurze Events und Lücken)
- **ALLE Events müssen vollständige Dauern haben** (1.0s, 2.0s, 480s, 360s)
- Die Square-Wellen-Form wird **innerhalb der Event-Dauer über den Duty Cycle** im `FlashlightController` gesteuert
- Die Waveform-Eigenschaft im Event definiert nur die Form, nicht die Dauer
- Phase 1: `duration: 1.0` für jedes Event (vollständige Sekunde)
- Phase 2: `duration: 2.0` für jedes Event (vollständige 2 Sekunden)
- Phase 3 & 4: Lange Events mit vollständiger Dauer (480s bzw. 360s)

- `frequencyOverride` für alle Events nutzen (wie bei `generateAwakeningScript()`)
- `mode: .dmnShutdown` im LightScript verwenden (nicht `.cinematic`)

### 3. EntrainmentEngine Logik anpassen

**Datei**: [EntrainmentEngine.swift](MindSync/Core/Entrainment/EntrainmentEngine.swift)

- In `generateLightScript()`: Special Case für `.dmnShutdown` (ähnlich wie `.cinematic`)
- `generateDMNShutdownScript()` aufrufen statt Audio-basierte Generierung
- In `generateLightEvents()`: Special Case für `.dmnShutdown` hinzufügen
- In `generateVibrationEvents()`: DMN-Shutdown Modus unterstützen (optional, da Vibration möglicherweise nicht benötigt wird)

### 4. SessionViewModel Integration

**Datei**: [SessionViewModel.swift](MindSync/Features/Session/SessionViewModel.swift)

- Prüfen, ob DMN-Shutdown Modus als spezieller Flow behandelt werden soll (ohne Audio-Analyse)
- Falls ja: Ähnliche Logik wie Awakening Flow implementieren
- Falls nein: Normale Audio-Analyse-Pipeline nutzen (aber der Script-Generator ignoriert Audio sowieso)

### 5. Lokalisierung

**Datei**: [Localizable.strings](MindSync/Resources/Localizable.strings)

- `mode.dmnShutdown.displayName`: "DMN-Shutdown (4,5-40 Hz)"
- `mode.dmnShutdown.description`: "Ego-Dissolution: Tiefe Theta-Entspannung gefolgt von Gamma-Synchronisation für transzendente Zustände"

### 6. UI-Integration

**Datei**: [ModeSelectionView.swift](MindSync/Features/Home/ModeSelectionView.swift)

- Automatisch in UI integriert über `EntrainmentMode.allCases` (keine expliziten Änderungen nötig)
- Card wird automatisch angezeigt mit Icon, Name und Beschreibung

### 7. Waveform/Intensity Selektoren

**Datei**: [EntrainmentEngine.swift](MindSync/Core/Entrainment/EntrainmentEngine.swift)

- In `generateLightEvents()`: `.dmnShutdown` Case zu `waveformSelector` und `intensitySelector` hinzufügen
- Für DMN-Shutdown: Standardwerte (werden aber durch Script-Override überschrieben)

## Technische Details

### Frequenz-Override Mechanismus

Der `frequencyOverride` Parameter in `LightEvent` wird genutzt, um feste Frequenzen zu erzwingen, unabhängig von Audio-BPM. Dies ermöglicht präzise neuronale Programmierung ohne Beat-Erkennung.

### Square vs Sine Waves

- **Square Waves** (Phase 1 & 3): Maximale kortikale Erregung, höhere SSVEP-Erfolgsrate (90.8% vs 75%)
- Wichtig: Square-Wellen-Events haben die **gleiche Dauer** wie Sine-Wellen-Events
- Die Square-Wellen-Form wird durch den **Duty Cycle** im `FlashlightController` gesteuert (nicht durch kürzere Event-Dauern)
- Verwendung von `period / 2.0` für Event-Dauer führt zu Lücken und "Between events" Problemen
- **Sine Waves** (Phase 2 & 4): Sanftere Übergänge für Entspannung und Erdung

### Event-Dauer Best Practices (aus Chat-Verlauf gelernt)

**FEHLER VERMEIDEN:**

- ❌ FALSCH: Square-Wellen-Events mit `duration = period / 2.0` (zu kurz, verursacht Lücken)
- ✅ RICHTIG: Alle Events mit vollständiger Dauer (`duration: 1.0`, `duration: 2.0`, etc.)

**Warum?**

- `findCurrentEvent()` findet keine Events mehr, wenn Lücken zwischen Events existieren
- Die Flashlight-Controller zeigt "Between events or no active event" und bleibt dunkel
- Die Square-Wellen-Form wird durch `WaveformGenerator` und `DutyCycleConfig` gesteuert, nicht durch Event-Dauer

### Intensitäts-Variation (Phase 2)

Alternierende Intensität verhindert Habituation (Gewöhnung) und hält das Gehirn "wachsam" für den Theta-Zustand.

## Teststrategie

- Unit Tests für `generateDMNShutdownScript()` Validierung
- Verifikation der Event-Sequenz (Timestamps, Frequenzen, Intensitäten)
- Integration Tests mit FlashlightController zur Verifikation der tatsächlichen Ausgabe