# MindSync - Umfassende Fehleranalyse und Korrektur

**Datum**: 27. Dezember 2025  
**Status**: Abgeschlossen ✅

## Zusammenfassung

Die App hatte zwei kritische Probleme:
1. **Frequenzanzeige fehlt** - `currentFrequency` wurde nicht aktualisiert
2. **Flashlight blinkt nicht kontinuierlich** - Lücken zwischen den Events

## Durchgeführte Korrekturen

### 1. Event-Duration-Logik (KRITISCH)

**Problem**: Events wurden nur bei Beat-Timestamps generiert, mit fester Duration basierend auf der Period. Bei weit auseinander liegenden Beats (z.B. alle 3 Sekunden bei 20 BPM) entstanden Lücken, in denen das Licht aus war.

**Lösung**: 
- Events erstrecken sich jetzt bis zum **nächsten Beat-Timestamp**
- Für Sine/Triangle Waveforms: `duration = max(period, nextBeatTimestamp - currentBeatTimestamp)`
- Für Square Waveform: `duration = period / 2.0` (bleibt unverändert für harte On/Off-Effekte)
- Letztes Event: Erstreckt sich bis zum Ende des Tracks

**Betroffene Dateien**:
- `MindSync/Core/Entrainment/EntrainmentEngine.swift`
  - `generateLightEvents()`: Lines 254-351
  - `generateVibrationEvents()`: Lines 447-523

**Code-Beispiel**:
```swift
// Vorher: Feste Duration
let eventDuration = period * 1.5  // Funktioniert nicht bei weit auseinander liegenden Beats

// Nachher: Duration bis zum nächsten Beat
let nextTimestamp: TimeInterval
if index + 1 < beatTimestamps.count {
    nextTimestamp = beatTimestamps[index + 1]
} else {
    nextTimestamp = trackDuration
}
let eventDuration = max(period, nextTimestamp - timestamp)
```

### 2. Timer-Konfiguration

**Problem**: Timer wurden mit `Timer.scheduledTimer()` erstellt, was sie nur im `.default` RunLoop-Mode ausführt. Bei UI-Interaktionen oder Scroll-Vorgängen pausieren diese Timer.

**Lösung**:
- Timer explizit mit `RunLoop.main.add(timer, forMode: .common)` hinzufügen
- Dies stellt sicher, dass Timer auch während UI-Interaktionen feuern

**Betroffene Dateien**:
- `MindSync/Features/Session/SessionViewModel.swift`
  - `startPlaybackProgressUpdates()`: Lines 420-442
  - `startFrequencyUpdates()`: Lines 453-470

**Code-Beispiel**:
```swift
// Vorher:
let timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { ... }

// Nachher:
let timer = Timer(timeInterval: 0.5, repeats: true) { ... }
RunLoop.main.add(timer, forMode: .common)  // WICHTIG!
```

### 3. Test-Crash behoben

**Problem**: `MicrophoneAnalyzerTests.testInitialization_WithValidFFTSetup_Succeeds()` erstellte eine zweite Analyzer-Instanz, was zu Konflikten mit AVAudioEngine und Memory-Management-Problemen führte.

**Lösung**: Test verwendet jetzt die bereits in `setUp()` erstellte Instanz.

**Betroffene Dateien**:
- `MindSyncTests/Unit/MicrophoneAnalyzerTests.swift`: Line 25-31

## Architektur-Verständnis

### Wie Entrainment funktioniert

1. **Audio-Analyse**: Beat-Timestamps werden aus dem Audio extrahiert
2. **BPM-Berechnung**: Tempo wird geschätzt (z.B. 120 BPM)
3. **Frequenz-Mapping**: BPM wird auf Ziel-Frequenz gemappt
   - Beispiel Theta-Mode: `targetFrequency = (120 / 60) × 3 = 6 Hz`
4. **Event-Generierung**: 
   - Bei jedem Beat wird ein `LightEvent` erstellt
   - Event enthält: `timestamp`, `intensity`, `duration`, `waveform`
   - **NEU**: Duration erstreckt sich bis zum nächsten Beat

5. **Ausführung**: 
   - `FlashlightController` nutzt `CADisplayLink` (120 Hz)
   - `findCurrentEvent()` findet das aktive Event basierend auf elapsed time
   - `calculateIntensity()` berechnet Intensität basierend auf Waveform:
     - **Square**: Konstante Intensität während Event-Duration
     - **Sine**: `sin(elapsed * 2π * targetFrequency)` - pulsiert kontinuierlich
     - **Triangle**: Lineares Rampen basierend auf Phase

### Frequenz-Ramping

- Start bei `mode.startFrequency` (z.B. 16 Hz für Theta)
- Rampe über `mode.rampDuration` (z.B. 180 Sekunden)
- Ziel: `targetFrequency` (z.B. 6 Hz für Theta)
- Interpolation: Smoothstep für natürliche Übergänge
- `updateCurrentFrequency()` berechnet aktuelle Frequenz basierend auf Elapsed Time

## Synchronisation (Audio + Light + Vibration)

Alle drei Komponenten verwenden **dieselbe** `startTime`:

```swift
let startTime = Date()
sessionStartTime = startTime
try await startPlaybackAndLight(url: assetURL, script: script, startTime: startTime)
vibrationController.execute(script: vibrationScript, syncedTo: startTime)
```

- **Audio**: `AVAudioEngine` startet zur `startTime`
- **Light**: `CADisplayLink` berechnet `elapsed = Date().timeIntervalSince(startTime)`
- **Vibration**: Gleiche Logik wie Light

## Modi im Detail

### Alpha (Entspannung)
- Frequenz: 8-12 Hz (Ziel: 10 Hz)
- Waveform: Sine (sanft)
- Intensity: 0.4 (gedämpft)
- Ramp: 180 Sekunden

### Theta (Trip)
- Frequenz: 4-8 Hz (Ziel: 6 Hz)
- Waveform: Sine (sanft)
- Intensity: 0.3 (sehr sanft)
- Ramp: 180 Sekunden

### Gamma (Fokus)
- Frequenz: 30-40 Hz (Ziel: 35 Hz)
- Waveform: Square (hart)
- Intensity: 0.7 (intensiv)
- Ramp: 120 Sekunden

### Cinematic (Flow State)
- Frequenz: 5.5-7.5 Hz mit Drift
- Waveform: Sine + Audio-Reaktivität
- Intensity: 0.3-1.0 basierend auf Audio-Energie
- Dynamische Modulation zur Laufzeit

## Was NICHT geändert wurde

Um sicherzustellen, dass die ursprüngliche Architektur erhalten bleibt:

✅ **Beat-Detection bleibt unverändert**: `BeatDetector`, `TempoEstimator`  
✅ **Frequency-Mapping bleibt unverändert**: `FrequencyMapper`  
✅ **Light-Controller-Logik bleibt unverändert**: `FlashlightController`, `ScreenController`  
✅ **Waveform-Berechnungen bleiben unverändert**: Sine/Square/Triangle-Formeln  
✅ **Cinematic-Mode bleibt unverändert**: Audio-Energie-Tracking  
✅ **Safety-Features bleiben unverändert**: Thermal Management, Fall Detection  

## Validierung

### Build Status
✅ **Build erfolgreich** (Xcode 16.0, iOS Simulator iPhone 17 Pro)

### Linter Status
✅ **Keine Linter-Fehler**

### Erwartetes Verhalten nach Korrektur

1. **Frequenz-Anzeige**:
   - Zeigt initial `startFrequency` (z.B. 16 Hz für Theta)
   - Rampt über 3 Minuten auf `targetFrequency` (z.B. 6 Hz)
   - Aktualisiert alle 0.5 Sekunden via Timer

2. **Flashlight**:
   - Pulsiert **kontinuierlich** mit der Target-Frequenz
   - Keine Lücken mehr (Events überlappen)
   - Sine-Waveform: Sanftes Pulsieren
   - Square-Waveform: Hartes On/Off

3. **Vibration**:
   - Synchron mit Light
   - Gleiche Frequenz und Ramping
   - Minimale Intensität: 0.15 (spürbar)

4. **Audio**:
   - Spielt normal ab
   - Cinematic-Mode: Isochronic Tones synchronized

## Test-Empfehlungen

### Manuelle Tests auf echtem Gerät:

1. **Theta-Mode mit langsamem Song** (60-80 BPM):
   - Prüfen: Kontinuierliches Pulsieren (~6 Hz)
   - Prüfen: Frequenz-Anzeige rampt von 16 Hz → 6 Hz

2. **Alpha-Mode mit schnellem Song** (140-160 BPM):
   - Prüfen: Kontinuierliches Pulsieren (~10 Hz)
   - Prüfen: Frequenz-Anzeige rampt von 15 Hz → 10 Hz

3. **Gamma-Mode** (beliebiger Song):
   - Prüfen: Schnelles hartes Blinken (~35 Hz)
   - Prüfen: Square-Waveform deutlich spürbar

4. **Cinematic-Mode**:
   - Prüfen: Audio-reaktives Pulsieren
   - Prüfen: Sync zwischen Audio und Light

5. **Vibration (falls aktiviert)**:
   - Prüfen: Sync mit Flashlight
   - Prüfen: Spürbare Intensität

### Unit-Tests:
- ✅ `EntrainmentEngineTests`
- ✅ `FrequencyMapperTests`
- ✅ `SessionViewModelTests`
- ⚠️ `MicrophoneAnalyzerTests` (erfordert echtes Gerät)

## Nächste Schritte

1. **Auf echtem iPhone testen** (Simulator hat keine Taschenlampe)
2. **Verschiedene Songs testen** (langsam, schnell, verschiedene Genres)
3. **Alle Modi durchgehen** (Alpha, Theta, Gamma, Cinematic)
4. **Lange Session** (>15 Min) für Thermal Management
5. **User-Feedback einholen**

## Technische Details für Entwickler

### Event-Duration-Formel

```swift
for (index, timestamp) in beatTimestamps.enumerated() {
    let period = 1.0 / currentFrequency
    
    let eventDuration: TimeInterval
    if waveform == .square {
        // Square: Hart on/off, halbe Period
        eventDuration = period / 2.0
    } else {
        // Sine/Triangle: Bis zum nächsten Beat
        let nextTimestamp = (index + 1 < beatTimestamps.count) 
            ? beatTimestamps[index + 1] 
            : trackDuration
        eventDuration = max(period, nextTimestamp - timestamp)
    }
}
```

### Warum funktioniert das?

1. **Sine/Triangle Waveforms**: Die Intensität wird **kontinuierlich** berechnet basierend auf `timeWithinEvent`:
   ```swift
   let sineValue = sin(timeWithinEvent * 2.0 * .pi * targetFrequency)
   ```
   - Auch wenn das Event 3 Sekunden dauert, pulsiert die Sine-Welle mit 6 Hz
   - Das Event ist nur ein "Zeitfenster", die Waveform definiert die tatsächliche Frequenz

2. **Square Waveform**: Konstante Intensität während Event-Duration
   - Duration = period / 2 sorgt für 50% Duty Cycle
   - Hart on/off für stroboskopischen Effekt

### Debugging-Tipps

Wenn Probleme auftreten:

1. **Frequenz wird nicht angezeigt**:
   - Prüfen: `sessionStartTime` gesetzt?
   - Prüfen: `currentScript` vorhanden?
   - Prüfen: Timer läuft? (in `list_sessions` checken)

2. **Flashlight blinkt nicht**:
   - Prüfen: `lightController.start()` erfolgreich?
   - Prüfen: Events generiert? (`script.events.count > 0`)
   - Prüfen: `CADisplayLink` läuft?
   - Prüfen: Thermal Management aktiv?

3. **Lücken im Blinken**:
   - Prüfen: Event-Durations korrekt berechnet?
   - Prüfen: Waveform = .sine oder .triangle?
   - Prüfen: `findCurrentEvent()` findet aktives Event?

## Kontakt

Bei Fragen zur Implementierung: Siehe `docs/architecture.md`

