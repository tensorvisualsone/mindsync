---
name: DMN-Shutdown Modus Implementierung
overview: Implementierung des neuen "DMN-Shutdown" Entrainment-Modus mit festem Master-Audio-File, der gezielt auf die Deaktivierung des Default Mode Network (DMN) abzielt und einen Ego-Dissolution-Zustand induziert.
todos:
  - id: add-dmn-shutdown-mode
    content: EntrainmentMode Enum um .dmnShutdown Case erweitern mit allen Properties (frequencyRange, targetFrequency, startFrequency, rampDuration, iconName)
    status: completed
  - id: implement-script-generator
    content: generateDMNShutdownScript() Funktion in EntrainmentEngine Extension implementieren mit 4 Phasen (DISCONNECT, THE ABYSS, THE VOID, REINTEGRATION). WICHTIG: Alle Events müssen vollständige Dauern haben (nicht period/2.0 für Square-Wellen). Square-Wellen-Form wird über Duty Cycle gesteuert, nicht über Event-Dauer.
    status: completed
    dependencies:
      - add-dmn-shutdown-mode
  - id: update-engine-logic
    content: EntrainmentEngine.generateLightScript() und generateLightEvents() um DMN-Shutdown Special Case erweitern
    status: completed
    dependencies:
      - implement-script-generator
  - id: add-master-audio-support
    content: SessionViewModel um startDMNShutdownFlow() Methode erweitern, die automatisch Master-Audio-File lädt (void_master.mp3 aus Bundle) statt User-Auswahl. Ähnlich wie startAwakeningFlow().
    status: completed
    dependencies:
      - add-dmn-shutdown-mode
  - id: add-audio-resource
    content: Master-Audio-File void_master.mp3 (30 Minuten, Brown Noise mit isochronen Tönen) zum App-Bundle hinzufügen (MindSync/Resources/)
    status: completed
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
    content: "UI-Integration testen: Modus sollte automatisch in ModeSelectionView erscheinen. Session startet automatisch mit Master-Audio ohne User-Auswahl."
    status: completed
    dependencies:
      - add-dmn-shutdown-mode
      - add-localization
      - add-master-audio-support
---

# DMN-Shutdown Modus Implementierung

## Übersicht

Der "DMN-Shutdown" Modus ist ein spezieller Entrainment-Flow, der **ohne Audio-Analyse** funktioniert und eine feste 30-minütige Sequenz erzeugt. Er zielt darauf ab, das Default Mode Network (DMN) zu deaktivieren und einen Zustand der Ego-Dissolution (Ich-Auflösung) zu erreichen, wie im Gemini-Chat beschrieben.

**Wichtig:** Dieser Modus verwendet ein **festes Master-Audio-File** aus dem App-Bundle statt einer User-Auswahl, um synästhetische Kohärenz zu gewährleisten.

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

### 4. Master-Audio-File Support

**Datei**: [SessionViewModel.swift](MindSync/Features/Session/SessionViewModel.swift)

- Neue Methode `startDMNShutdownFlow()` implementieren (ähnlich wie `startAwakeningFlow()`)
- **Automatisches Laden** des Master-Audio-Files `void_master.mp3` aus dem App-Bundle
- **Keine User-Auswahl** - Audio wird automatisch geladen wenn Modus `.dmnShutdown` gewählt wird
- Audio-Datei aus `Bundle.main.url(forResource: "void_master", withExtension: "mp3")` laden
- Audio-Playback starten synchron mit LightScript (wie bei normalen Sessions)
- Session-Objekt erstellen mit `.dmnShutdown` Modus und `.localFile` als AudioSource

**Audio-Requirements** (vom User bereitgestellt):
- **Dauer**: Exakt 30 Minuten (1800 Sekunden)
- **Sound-Design**: 
  - **Phase 2 (Abyss)**: Brown Noise (basslastig, sublim, "unendlich weit")
  - **Phase 4 (Reintegration)**: Pink Noise (natürlicher, wie Regen)
  - **Gesamt**: Dark Ambient Pad, keine Vocals, keine harten Beats
  - **Frequenzen**: Eingebettete Isochronic Tones bei 4.5 Hz (Phase 2) und 40 Hz (Phase 3)
- **Format**: MP3 (für App-Bundle)
- **Dateiname**: `void_master.mp3`

### 5. Audio-Ressource zum Bundle hinzufügen

**Datei**: [MindSync/Resources/void_master.mp3](MindSync/Resources/) (vom User bereitgestellt)

- Audio-File zum App-Bundle hinzufügen
- In Xcode: File → Add Files to "MindSync" → `void_master.mp3` auswählen
- **Wichtig**: "Copy items if needed" aktivieren und "MindSync" Target auswählen
- In `Info.plist` prüfen, ob Audio-File im Bundle enthalten ist (optional)

### 6. Lokalisierung

**Datei**: [Localizable.strings](MindSync/Resources/Localizable.strings)

- `mode.dmnShutdown.displayName`: "DMN-Shutdown (4,5-40 Hz)"
- `mode.dmnShutdown.description`: "Ego-Dissolution: Tiefe Theta-Entspannung gefolgt von Gamma-Synchronisation für transzendente Zustände"

### 7. UI-Integration

**Datei**: [ModeSelectionView.swift](MindSync/Features/Home/ModeSelectionView.swift)

- Automatisch in UI integriert über `EntrainmentMode.allCases` (keine expliziten Änderungen nötig)
- Card wird automatisch angezeigt mit Icon, Name und Beschreibung

**Wichtig:** Wenn User DMN-Shutdown Modus wählt, muss der Flow automatisch starten **ohne** Audio-Auswahl-Dialog (da Master-Audio automatisch geladen wird).

**Datei**: [SourceSelectionView.swift](MindSync/Features/Home/SourceSelectionView.swift)

- Prüfen: Wenn `.dmnShutdown` Modus gewählt wurde, direkt `startDMNShutdownFlow()` aufrufen
- Oder: Separate Start-Methode in HomeView, wenn DMN-Shutdown gewählt wird

### 8. Waveform/Intensity Selektoren

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

### Audio-Integration

**Warum festes Master-Audio?**
- **Synästhetische Kohärenz**: Licht und Audio müssen exakt synchronisiert sein
- **Flow-Steuerung**: Feste Phasen (4 Min, 12 Min etc.) erfordern präzise Audio-Licht-Sync
- **User Experience**: Geführte Reise ohne manuelle Audio-Auswahl

**Sound-Charakteristika** (aus Gemini-Chat):
- **Brown Noise** (Phase 2 - Abyss): Basslastig, sublim, erzeugt "Sicherheit im Nichts"
- **Pink Noise** (Phase 4 - Reintegration): Natürlicher Klang, sanfte Rückkehr
- **Isochronic Tones**: Besser als Binaural Beats (kein Kopfhörerzwang, stärkere kortikale Antwort)
  - 4.5 Hz für Phase 2 (tiefe Theta)
  - 40 Hz für Phase 3 (Gamma-Synchronisation)

**Optional (zukünftig):**
- Filter-Sweeps für dynamische Audio-Manipulation (Low-Pass Filter für "Internalization", High-Pass Filter für "Ego-Thinning")
- `VoidSoundEngine` mit `AVAudioUnitEQ` für Filter-Sweeps (später implementieren)

## Teststrategie

- Unit Tests für `generateDMNShutdownScript()` Validierung
- Verifikation der Event-Sequenz (Timestamps, Frequenzen, Intensitäten)
- Integration Tests mit FlashlightController zur Verifikation der tatsächlichen Ausgabe
- Test: Master-Audio-File wird korrekt aus Bundle geladen
- Test: Session startet automatisch ohne Audio-Auswahl-Dialog
