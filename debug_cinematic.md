# Cinematic Mode Debug - Flashlight bleibt dunkel

## Problem
Im Cinematic Mode bleibt das Flashlight durchgehend dunkel, obwohl Audio läuft.

## Mögliche Ursachen

### 1. AudioEnergyTracker nicht initialisiert
**Check**: Ist `audioEnergyTracker` korrekt an `lightController` attached?
- FlashlightController.swift:355-359 prüft `audioEnergyTracker`
- SessionViewModel.swift:244-246 sollte tracker setzen

**Wahrscheinlichkeit**: HOCH

### 2. Spectral Flux Detection zu konservativ
**Parameter**:
- `absoluteMinimumThreshold = 0.1` (FlashlightController:37)
- `peakRiseThreshold = 0.08` (FlashlightController:34)  
- `adaptiveThresholdMultiplier = 0.3` (FlashlightController:39)
- `fixedThreshold = 0.2` (FlashlightController:38)

**Check**: Werden überhaupt Peaks detektiert?

**Wahrscheinlichkeit**: MITTEL

### 3. Cinematic Mode Script hat keine Events
**Check**: Generiert EntrainmentEngine überhaupt Events für Cinematic Mode?

**Wahrscheinlichkeit**: NIEDRIG

### 4. Tap auf Mixer Node schlägt fehl
**Check**: `audioPlayback.getMainMixerNode()` gibt `nil` zurück?

**Wahrscheinlichkeit**: MITTEL

## Diagnose-Plan

1. **Prüfe audioEnergyTracker Attachment**
   - Log in `enableSpectralFluxForCinematicMode()` hinzufügen
   - Verify `lightController?.audioEnergyTracker` ist nicht nil

2. **Prüfe Spectral Flux Werte**
   - Log `audioEnergy` in FlashlightController.updateLight()
   - Log `isPeakDetected` Status

3. **Prüfe Peak Detection Logic**
   - Log alle Intermediate-Werte (fluxRise, adaptiveThreshold, etc.)

4. **Prüfe Mixer Node**
   - Verify `mixerNode` ist nicht nil in enableSpectralFluxForCinematicMode

## Schnelle Fixes zum Testen

### Fix 1: Reduziertere Thresholds
```swift
private let absoluteMinimumThreshold: Float = 0.05  // Von 0.1 -> 0.05
private let peakRiseThreshold: Float = 0.04  // Von 0.08 -> 0.04
private let fixedThreshold: Float = 0.1  // Von 0.2 -> 0.1
```

### Fix 2: Fallback für fehlenden Tracker
```swift
if script.mode == .cinematic {
    let audioEnergy: Float
    if let tracker = audioEnergyTracker, tracker.useSpectralFlux {
        audioEnergy = tracker.currentSpectralFlux
    } else {
        // FALLBACK: Use constant low intensity for testing
        audioEnergy = 0.3
        logger.warning("[CINEMATIC] NO TRACKER - using fallback energy")
    }
    // ...
}
```

### Fix 3: Vereinfachte Peak Detection (für Testing)
```swift
// Temporär ersetzen mit simpler Threshold
let isPeakDetected = audioEnergy > 0.15 && cooldownExpired
```

## Nächste Schritte
1. Logging hinzufügen
2. Build & Test mit echtem Song
3. Console Logs analysieren
4. Basierend auf Logs, gezielten Fix implementieren
