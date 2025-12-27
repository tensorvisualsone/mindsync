---
name: Cinematic Mode Implementation
overview: Implementierung eines Cinematic Mode für die MindSync App mit dynamischer Audio-Reaktivität, Frequenz-Drift und Lens-Flare-Effekten für einen Flow-State-Zustand (5.5-7.5 Hz Theta/Low Alpha Bereich).
todos:
  - id: "1"
    content: "EntrainmentMode erweitern: .cinematic Case hinzufügen mit frequencyRange 5.5...7.5 Hz, displayName, description und iconName"
    status: pending
  - id: "2"
    content: "AudioEnergyTracker Service implementieren: RMS-Berechnung, Moving Average, Publisher für Echtzeit-Energie-Werte"
    status: pending
  - id: "3"
    content: "AudioPlaybackService zu AVAudioEngine migrieren: AudioPlayer durch AVAudioEngine + AVAudioPlayerNode ersetzen, Tap-Installation vorbereiten"
    status: pending
  - id: "4"
    content: "EntrainmentEngine: calculateCinematicIntensity Methode implementieren mit Frequency Drift, Audio Reactivity und Lens Flare Logik"
    status: pending
    dependencies:
      - "1"
  - id: "5"
    content: "EntrainmentEngine: generateLightEvents anpassen für Cinematic Mode (Hybrid-Ansatz mit Basis-Intensität 0.5)"
    status: pending
    dependencies:
      - "4"
  - id: "6"
    content: "FlashlightController: updateLight erweitern für Cinematic Mode mit dynamischer Intensitäts-Modulation basierend auf Audio-Energie"
    status: pending
    dependencies:
      - "2"
      - "4"
  - id: "7"
    content: "ScreenController: Analog zu FlashlightController anpassen für Cinematic Mode"
    status: pending
    dependencies:
      - "6"
  - id: "8"
    content: "ServiceContainer: AudioEnergyTracker registrieren"
    status: pending
    dependencies:
      - "2"
  - id: "9"
    content: "SessionViewModel: AudioEnergyTracker Integration - Start/Stop Tracking bei Cinematic Mode Sessions"
    status: pending
    dependencies:
      - "2"
      - "3"
      - "8"
  - id: "10"
    content: "Testing: Unit Tests für calculateCinematicIntensity, Integration Tests für AudioEnergyTracker, Manual Testing mit verschiedenen Audio-Dateien"
    status: pending
    dependencies:
      - "1"
      - "2"
      - "3"
      - "4"
      - "6"
      - "7"
      - "9"
---

# Cinematic Mode Implementation

## Übersicht

Der Cinematic Mode erweitert MindSync um einen dynamischen Entrainment-Modus, der:

- Echtzeit-Audio-Energie-Tracking nutzt (AVAudioEngine mit Tap)
- Dynamische Frequenz-Anpassung im Theta/Low Alpha Bereich (5.5-7.5 Hz) mit Drift-Effekt
- Audio-reaktive Intensitäts-Modulation (Lens Flare bei hoher Audio-Energie)
- Gamma-korrigierte Lichtausgabe (bereits implementiert in FlashlightController)

## Architektur-Änderungen

### 1. EntrainmentMode erweitern

**Datei**: `MindSync/Models/EntrainmentMode.swift`

- `.cinematic` Case hinzufügen
- `frequencyRange`: `5.5...7.5` (Theta/Low Alpha Flow State)
- `targetFrequency`: `6.5` Hz (Mitte des Bereichs)
- `displayName`: "Cinematic"
- `description`: "Flow State Sync - Dynamisch & Reaktiv"
- `iconName`: "film.fill" (SF Symbol)

### 2. AudioPlaybackService umbauen (AVAudioEngine)

**Datei**: `MindSync/Services/AudioPlaybackService.swift`**Änderungen**:

- Von `AVAudioPlayer` zu `AVAudioEngine` migrieren
- Audio-Tap für Echtzeit-Analyse vorbereiten
- Backward-Kompatibilität: `audioPlayer` Property bleibt (als `AVAudioPlayerNode` Wrapper oder deprecated)
- Neue Properties: `audioEngine: AVAudioEngine?`, `playerNode: AVAudioPlayerNode?`
- `installTap(on:bufferSize:format:block:)` Methode für spätere Nutzung durch AudioEnergyTracker

**Hinweis**: Diese Änderung betrifft die gesamte Playback-Pipeline, daher sollte sie sorgfältig getestet werden.

### 3. AudioEnergyTracker Service (NEU)

**Neue Datei**: `MindSync/Services/AudioEnergyTracker.swift`**Funktionalität**:

- Installiert Tap auf `mainMixerNode` der AVAudioEngine
- Berechnet RMS (Root Mean Square) Energie pro Buffer
- Moving Average für Smoothing (5 Sekunden Window)
- Publisher für Echtzeit-Energie-Werte (`energyPublisher: PassthroughSubject<Float, Never>`)
- Normierte Werte (0.0 - 1.0)

**Methoden**:

- `startTracking(engine: AVAudioEngine)` - Tap installieren
- `stopTracking()` - Tap entfernen
- Private `calculateRMS(buffer: AVAudioPCMBuffer) -> Float`
- Private Moving Average State Management

### 4. EntrainmentEngine: Cinematic Mode Logik

**Datei**: `MindSync/Core/Entrainment/EntrainmentEngine.swift`**Neue Methode**: `calculateCinematicIntensity`

```swift
private func calculateCinematicIntensity(
    baseFrequency: Double,
    currentTime: TimeInterval,
    audioEnergy: Float
) -> Float
```

**Logik**:

1. **Frequency Drift**: `baseFrequency + sin(time * 0.2) * 1.0` (5.5-7.5 Hz Oszillation über 5-10 Sek)
2. **Base Wave**: Cosine-Welle für weichere Übergänge
3. **Audio Reactivity**: `baseIntensity = 0.3 + (audioEnergy * 0.7)` (Minimum 30%, bei hoher Energie bis 100%)
4. **Lens Flare**: Gamma-Korrektur für helle Bereiche (`pow(output, 0.5)` wenn > 0.8)

**Anpassungen in `generateLightEvents`**:

- Für `.cinematic` Mode: Generiere Events mit reduzierter statischer Intensität (wird zur Laufzeit dynamisch angepasst)
- Oder: Generiere keine statischen Events, sondern nutze vollständig dynamische Berechnung zur Laufzeit

**Entscheidung**: Hybrid-Ansatz - Generiere Basis-Events mit 0.5 Intensität, die zur Laufzeit moduliert werden.

### 5. LightController: Dynamische Intensitäts-Modulation

**Datei**: `MindSync/Core/Light/FlashlightController.swift`**Anpassungen in `updateLight()`**:

- Prüfe ob `currentScript.mode == .cinematic`
- Falls ja: Hole aktuelle Audio-Energie vom `AudioEnergyTracker`
- Berechne dynamische Intensität via `calculateCinematicIntensity`
- Wende auf gefundenes Event an (multipliziere Event-Intensität mit dynamischem Faktor)

**Alternative**: Neue Methode `updateCinematicLight(energy: Float, event: LightEvent) -> Float`**Hinweis**: ScreenController muss analog angepasst werden.

### 6. SessionViewModel Integration

**Datei**: `MindSync/Features/Session/SessionViewModel.swift`**Änderungen**:

- `audioEnergyTracker: AudioEnergyTracker` Property hinzufügen
- In `startSession`: Wenn Mode == `.cinematic`, starte Energy Tracking
- Subscribe zu `energyPublisher` für UI-Updates (optional)
- In `stopSession`: Stop Energy Tracking

**ServiceContainer Integration**:

- `AudioEnergyTracker` im `ServiceContainer` registrieren
- Lazy initialization

### 7. WaveformGenerator: Cosine Support

**Datei**: `MindSync/Core/Entrainment/WaveformGenerator.swift` (optional)Falls Cosine-Welle benötigt wird (weicher als Sine):

- Neuer Case `.cosine` in `LightEvent.Waveform` (oder direkt in WaveformGenerator nutzen)

**Oder**: Nutze bestehende `.sine` und verschiebe Phase um π/2 in der Berechnung.

## Abhängigkeiten und Reihenfolge

1. **Phase 1: Foundation** (kann parallel gemacht werden)

- EntrainmentMode erweitern
- AudioEnergyTracker implementieren

2. **Phase 2: Audio Pipeline** (kritisch - muss zuerst)

- AudioPlaybackService zu AVAudioEngine migrieren
- AudioEnergyTracker Integration testen

3. **Phase 3: Entrainment Logic**

- EntrainmentEngine: calculateCinematicIntensity
- LightController: Dynamische Modulation

4. **Phase 4: Integration**

- SessionViewModel Integration
- ServiceContainer Updates

## Technische Details

### Frequency Drift Formel

```javascript
drift = sin(time * 0.2) * 1.0  // Langsame Oszillation
currentFreq = 6.5 + drift       // 5.5 - 7.5 Hz
```



### Audio Reactivity Formel

```javascript
baseIntensity = 0.3 + (audioEnergy * 0.7)
output = cosineWave(time, currentFreq) * baseIntensity
if output > 0.8:
    output = pow(output, 0.5)  // Lens Flare Crispness
```



### Moving Average für Audio-Energie

```javascript
smoothingFactor = 0.95
averageEnergy = (averageEnergy * smoothingFactor) + (currentEnergy * (1.0 - smoothingFactor))
```



## Testing Strategie

1. Unit Tests für `calculateCinematicIntensity`
2. Integration Tests für AudioEnergyTracker mit Mock-Engine
3. Manual Testing mit verschiedenen Audio-Dateien (ruhig vs. energiegeladen)
4. Performance-Tests für Echtzeit-Processing

## Bekannte Herausforderungen

1. **AVAudioEngine Migration**: Grosse Änderung, benötigt sorgfältiges Testing aller Playback-Funktionen
2. **Threading**: AudioEnergyTracker Callbacks laufen auf Audio-Thread, müssen auf Main-Thread für UI-Updates