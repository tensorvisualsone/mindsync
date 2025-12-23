# Research: MindSync Core App

**Feature**: 001-audio-strobe-sync  
**Date**: 2025-12-23  
**Source**: `/research/iOS App Concept_ MindSync Development de.pdf`

## Executive Summary

Dieses Dokument fasst die technische Recherche für MindSync zusammen, basierend auf dem ausführlichen Konzeptdokument. Es fokussiert auf **konkrete iOS-APIs**, **bekannte Einschränkungen** und **validierte Ansätze**.

---

## 1. Audio-Analyse auf iOS

### 1.1 DRM-Einschränkungen (kritisch)

**Problem**: Apple Music und Spotify schützen ihre Streams mit DRM. Apps können diese nicht für DSP analysieren.

| Quelle | API-Zugriff | PCM-Zugriff für DSP | Empfehlung |
|--------|-------------|---------------------|------------|
| Lokale Dateien (gekauft/importiert) | `MPMediaPickerController` | ✅ Ja via `AVAssetReader` | **Primäre Quelle** |
| Apple Music (Streaming) | `MPMusicPlayerController` | ❌ Nein (nil Asset) | Nicht unterstützen |
| Spotify | Spotify iOS SDK | ❌ Nein (kein PCM) | Nicht unterstützen |
| Mikrofon | `AVAudioEngine` | ✅ Ja via `installTap()` | **Sekundäre Quelle** |

**Strategische Entscheidung**: MindSync unterstützt nur:
1. DRM-freie lokale Dateien (hochpräzise Analyse)
2. Mikrofon-Modus (universell, aber weniger präzise)

### 1.2 Audio-Analyse-Pipeline

```swift
// Empfohlene Pipeline für lokale Dateien

1. Datei-Auswahl
   → MPMediaPickerController.show()
   → MPMediaItem.assetURL (nur für DRM-freie Items nicht-nil)

2. PCM-Extraktion
   → AVAsset(url: assetURL)
   → AVAssetReader(asset: asset)
   → AVAssetReaderTrackOutput(track: audioTrack, settings: [
       AVFormatIDKey: kAudioFormatLinearPCM,
       AVLinearPCMIsFloatKey: true,
       AVLinearPCMBitDepthKey: 32
     ])
   → reader.copyNextSampleBuffer() in Loop

3. FFT-Analyse (pro Frame-Fenster)
   → vDSP_hann_window() für Fensterfunktion
   → vDSP_ctoz() für Complex-Konvertierung
   → vDSP_fft_zrip() für FFT
   → vDSP_zvabs() für Magnitude-Spektrum

4. Beat-Erkennung
   → Spectral Flux = Σ(max(0, magnitude[i] - magnitude[i-1]))
   → Peak Detection mit Threshold (adaptive oder fixed)
   → Onset-Zeiten sammeln

5. Tempo-Schätzung
   → Inter-Onset-Intervalle berechnen
   → Histogram/Clustering für dominantes Intervall
   → BPM = 60 / dominant_interval
```

### 1.3 Relevante Apple-APIs

| Framework | Klasse/Funktion | Verwendung |
|-----------|-----------------|------------|
| MediaPlayer | `MPMediaPickerController` | Song-Auswahl aus Bibliothek |
| MediaPlayer | `MPMediaItem.assetURL` | URL für lokale Dateien |
| AVFoundation | `AVAssetReader` | PCM-Daten aus Datei lesen |
| AVFoundation | `AVAudioEngine` | Echtzeit-Audio (Mikrofon) |
| AVFoundation | `installTap(onBus:bufferSize:format:block:)` | Audio-Buffer abgreifen |
| Accelerate | `vDSP_fft_zrip()` | Fast Fourier Transform |
| Accelerate | `vDSP_hann_window()` | Fenster-Funktion |
| Accelerate | `vDSP_zvabs()` | Complex → Magnitude |

### 1.4 Mikrofon-Modus

```swift
// Echtzeit-Analyse via Mikrofon
let audioEngine = AVAudioEngine()
let inputNode = audioEngine.inputNode
let format = inputNode.outputFormat(forBus: 0)

inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
    // buffer.floatChannelData enthält PCM-Samples
    // Gleiche FFT-Pipeline wie bei Dateien, aber in Echtzeit
}

try audioEngine.start()
```

**Latenz-Hinweis**: Mikrofon → Analyse → Licht ≈ 50-150ms Gesamtlatenz. Weniger präzise als Pre-Processing, aber funktional.

---

## 2. Licht-Steuerung auf iOS

### 2.1 Taschenlampe (Rear LED Flash)

**API**: `AVCaptureDevice` (nicht `AVCaptureSession` - Taschenlampe braucht keine Kamera)

```swift
guard let device = AVCaptureDevice.default(for: .video),
      device.hasTorch else { return }

// WICHTIG: Nur einmal pro Session locken!
try device.lockForConfiguration()

// Variable Intensität (0.0 - 1.0)
try device.setTorchModeOn(level: 0.5)

// Ausschalten
device.torchMode = .off

// Am Ende der Session
device.unlockForConfiguration()
```

**Einschränkungen**:

| Aspekt | Limit | Workaround |
|--------|-------|------------|
| Max. Frequenz | ~30-40 Hz stabil | Für Gamma (40 Hz) Bildschirm verwenden |
| Thermische Drosselung | Nach ~10 Min bei 1.0 | Intensität auf 0.3-0.5 begrenzen |
| API-Latenz | ~5-10ms pro Aufruf | Nicht bei jedem Beat locken |
| Batterieverbrauch | Hoch bei hoher Intensität | User warnen bei niedrigem Akku |

### 2.2 Bildschirm (OLED-Displays)

**Vorteile**:
- Präzises Timing via `CADisplayLink` (60/120 Hz)
- Farbmodulation (Weiß, Rot, RGB-Zyklen)
- Keine thermischen Probleme
- Echtes Schwarz auf OLED

```swift
// SwiftUI Fullscreen Color Strobing
struct StrobeView: View {
    @State private var isOn = false
    
    var body: some View {
        Rectangle()
            .fill(isOn ? Color.white : Color.black)
            .ignoresSafeArea()
            .onAppear { startDisplayLink() }
    }
    
    func startDisplayLink() {
        let link = CADisplayLink(target: self, selector: #selector(tick))
        link.preferredFrameRateRange = CAFrameRateRange(
            minimum: 60, maximum: 120, preferred: 120
        )
        link.add(to: .main, forMode: .common)
    }
}
```

### 2.3 Empfehlung: Hybrid-Strategie

| Modus | Lichtquelle | Frequenzbereich | Use Case |
|-------|-------------|-----------------|----------|
| Standard | Bildschirm | 4-40 Hz | Sicher, präzise, lange Sitzungen |
| Intensiv | Taschenlampe | 4-30 Hz | Heller, aber max. 15 Min |
| Fallback | Bildschirm | - | Automatisch bei Überhitzung |

---

## 3. Thermisches Management

### 3.1 ProcessInfo.ThermalState

iOS bietet native Thermal-Überwachung:

```swift
// Observer für Thermal State
NotificationCenter.default.addObserver(
    forName: ProcessInfo.thermalStateDidChangeNotification,
    object: nil,
    queue: .main
) { _ in
    switch ProcessInfo.processInfo.thermalState {
    case .nominal:
        // Alles OK
    case .fair:
        // Leicht warm, optional Intensität reduzieren
    case .serious:
        // Zu heiß! Intensität stark reduzieren oder auf Bildschirm wechseln
    case .critical:
        // Sofort stoppen!
    @unknown default:
        break
    }
}
```

### 3.2 Thermische Strategie

| ThermalState | Aktion |
|--------------|--------|
| `.nominal` | Volle Intensität erlaubt (0.0-1.0) |
| `.fair` | Max. Intensität auf 0.7 begrenzen |
| `.serious` | Auf Bildschirm-Modus wechseln, User benachrichtigen |
| `.critical` | Session sofort beenden |

---

## 4. Sicherheit & Fall-Erkennung

### 4.1 CoreMotion für Fall-Erkennung

```swift
import CoreMotion

let motionManager = CMMotionManager()

if motionManager.isAccelerometerAvailable {
    motionManager.accelerometerUpdateInterval = 0.1 // 10 Hz
    motionManager.startAccelerometerUpdates(to: .main) { data, error in
        guard let acceleration = data?.acceleration else { return }
        
        // Berechne Gesamtbeschleunigung
        let magnitude = sqrt(
            acceleration.x * acceleration.x +
            acceleration.y * acceleration.y +
            acceleration.z * acceleration.z
        )
        
        // Freier Fall: magnitude ≈ 0 (keine Schwerkraft)
        // Aufprall: magnitude > 2.0g
        if magnitude < 0.3 || magnitude > 2.0 {
            // Potentieller Fall erkannt → Session stoppen
            stopSession()
        }
    }
}
```

### 4.2 Epilepsie-Sicherheitsgrenzen

| Parameter | Grenzwert | Begründung |
|-----------|-----------|------------|
| PSE-Gefahrenzone | 3-30 Hz | Internationale Epilepsie-Richtlinien |
| Empfohlener Bereich | 8-12 Hz (Alpha) | Außerhalb der kritischsten Zone (15-25 Hz) |
| Harte Obergrenze | 40 Hz | Hardware-Limit Taschenlampe |
| Harte Untergrenze | 3 Hz | Unter PSE-Gefahrenzone |

**Warnung**: Die App kann für Menschen mit PSE nicht sicher gemacht werden. Der Haftungsausschluss ist der primäre Schutz.

---

## 5. Frequenzzuordnung (Entrainment-Algorithmus)

### 5.1 BPM-zu-Hz-Mapping

```
f_target = (BPM / 60) × N

Ziel: f_target soll im gewünschten Frequenzband liegen
```

**Beispielrechnung**:

| Song BPM | Modus | Zielband | N (Multiplikator) | Ergebnis |
|----------|-------|----------|-------------------|----------|
| 120 | Alpha | 8-12 Hz | 5 | 10 Hz ✓ |
| 120 | Theta | 4-8 Hz | 3 | 6 Hz ✓ |
| 120 | Gamma | 30-40 Hz | 18 | 36 Hz ✓ |
| 60 | Alpha | 8-12 Hz | 10 | 10 Hz ✓ |
| 90 | Alpha | 8-12 Hz | 7 | 10.5 Hz ✓ |

### 5.2 Algorithmus zur Multiplikator-Wahl

```swift
func selectMultiplier(bpm: Double, targetBand: ClosedRange<Double>) -> Int {
    let baseFreq = bpm / 60.0  // Hz
    
    // Finde N so dass baseFreq * N im Zielband liegt
    let minN = Int(ceil(targetBand.lowerBound / baseFreq))
    let maxN = Int(floor(targetBand.upperBound / baseFreq))
    
    guard minN <= maxN else {
        // Kein ganzzahliger Multiplikator möglich, nächstbesten wählen
        return Int(round(targetBand.midpoint / baseFreq))
    }
    
    // Wähle Multiplikator, der Frequenz zur Bandmitte bringt
    let targetMid = (targetBand.lowerBound + targetBand.upperBound) / 2
    return Int(round(targetMid / baseFreq))
}
```

---

## 6. App Store Compliance

### 6.1 Wellness vs. Medical Device

| Kategorie | Erlaubt | Verboten |
|-----------|---------|----------|
| Formulierungen | "Fördert Entspannung" | "Behandelt Schlaflosigkeit" |
| | "Unterstützt Meditation" | "Heilt Angstzustände" |
| | "Visuelle Erkundung" | "Medizinische Synchronisation" |
| | "Fördert Konzentration" | "Therapie" |

### 6.2 Erforderliche Warnungen

1. **Epilepsie-Disclaimer** (obligatorisch, Vollbild, vor erstem Zugriff):
   > "Diese App verwendet stroboskopisches Licht, das bei Menschen mit photosensitiver Epilepsie Anfälle auslösen kann. Verwenden Sie diese App nicht, wenn Sie oder Familienmitglieder eine Vorgeschichte mit Krampfanfällen haben."

2. **Umgebungs-Hinweis** (empfohlen):
   > "Verwenden Sie MindSync an einem sicheren, dunklen Ort. Stellen Sie sicher, dass Sie bequem sitzen oder liegen."

3. **Info.plist Privacy Descriptions**:
   - `NSMicrophoneUsageDescription`: "MindSync verwendet das Mikrofon, um Musik von externen Quellen zu analysieren und das Stroboskop zu synchronisieren."
   - `NSAppleMusicUsageDescription`: "MindSync benötigt Zugriff auf Ihre Musikbibliothek, um Songs für die Stroboskop-Synchronisation zu analysieren."

---

## 7. Validierte Referenzen

### Apple Developer Documentation
- [AVFoundation Audio](https://developer.apple.com/av-foundation/)
- [Accelerate vDSP](https://developer.apple.com/documentation/accelerate/vdsp)
- [Fast Fourier Transforms](https://developer.apple.com/documentation/accelerate/fast-fourier-transforms)
- [AVCaptureDevice (Torch)](https://developer.apple.com/documentation/avfoundation/avcapturedevice)
- [ProcessInfo.ThermalState](https://developer.apple.com/documentation/foundation/processinfo/thermalstate)
- [CoreMotion](https://developer.apple.com/documentation/coremotion)

### Apple Sample Code
- [Audio Spectrum Visualizer](https://developer.apple.com/documentation/accelerate/visualizing_sound_as_an_audio_spectrogram)
- [Signal Processing with vDSP](https://developer.apple.com/documentation/accelerate/signal_extraction_from_noise)

### Stack Overflow (validierte Antworten)
- [iPhone Strobe Light Precision](https://stackoverflow.com/questions/48956549)
- [AVAssetReader for MP3 Analysis](https://stackoverflow.com/questions/4218243)
- [Beat Detection Algorithm](https://dsp.stackexchange.com/questions/9521)

---

**Research Version**: 1.0.0 | **Status**: Complete

