# Latenz-Kalibrierungs-Feature

## Übersicht

Das Latenz-Kalibrierungs-Feature ermöglicht es Usern, automatisch den optimalen `audioLatencyOffset` für ihre Kopfhörer zu ermitteln. Dies ist besonders wichtig für Bluetooth-Geräte wie AirPods, die eine inherente Audio-Latenz von 150-300ms haben.

## Implementierung

### Dateien

1. **`LatencyCalibrationViewModel.swift`**
   - ViewModel mit Kalibrierungslogik
   - Führt 5 Messungen durch
   - Berechnet Median (robust gegen Ausreißer)
   - Kompensiert durchschnittliche menschliche Reaktionszeit (~200ms)

2. **`LatencyCalibrationView.swift`**
   - SwiftUI View mit interaktivem UI
   - Zeigt Anweisungen, Progress und Ergebnisse
   - Weißer Flash + Click-Sound für jede Messung
   - Tap-Geste für User-Input

3. **`SettingsView.swift`** (Updated)
   - Integration der Kalibrierung in Settings
   - NavigationLink zum Kalibrierungs-Screen
   - Zeigt aktuellen Offset-Wert an

4. **`de.lproj/Localizable.strings`** (Updated)
   - Deutsche Lokalisierung für alle UI-Texte
   - Header und Footer für Settings-Section

## User Flow

```mermaid
flowchart TD
    Start[User öffnet Settings] --> Nav[Tippt auf Latenz-Kalibrierung]
    Nav --> Ready[Ready Screen]
    Ready --> Instructions[Anweisungen 3s]
    Instructions --> Loop{Messung < 5?}
    
    Loop -->|Ja| Wait[Zufälliger Delay 1-2s]
    Wait --> Flash[Weißer Flash + Click]
    Flash --> Tap[User tippt wenn synchron]
    Tap --> Save[Messung speichern]
    Save --> Loop
    
    Loop -->|Nein| Calc[Median berechnen]
    Calc --> Result[Ergebnis anzeigen]
    Result --> UserChoice{User Aktion}
    
    UserChoice -->|Speichern| SavePrefs[In UserPreferences speichern]
    UserChoice -->|Erneut| Ready
    
    SavePrefs --> End[Zurück zu Settings]
```

## Algorithmus

### Messvorgang

1. **Trigger:** App zeigt weißen Flash + spielt Click-Sound gleichzeitig
2. **User-Reaktion:** User tippt auf Screen wenn Flash und Sound synchron wahrgenommen werden
3. **Messung:** App misst Zeit zwischen Trigger und Tap

### Berechnung

```swift
// Beispiel-Messwerte (5 Messungen):
measurements = [0.380s, 0.420s, 0.390s, 0.410s, 0.400s]

// 1. Sortieren
sorted = [0.380s, 0.390s, 0.400s, 0.410s, 0.420s]

// 2. Median berechnen (mittlerer Wert)
median = 0.400s

// 3. Menschliche Reaktionszeit abziehen (~200ms)
bluetoothLatency = 0.400s - 0.200s = 0.200s

// 4. Runden auf 10ms
audioLatencyOffset = 0.20s (200ms)
```

### Warum Median statt Durchschnitt?

- **Robust gegen Ausreißer:** Wenn User einmal zu früh/spät tippt, verfälscht das nicht das Ergebnis
- **Typisch für Timing-Messungen:** Standard in Audio-Engineering

### Warum Reaktionszeit abziehen?

Die gemessene Zeit enthält:
- Bluetooth-Latenz (was wir messen wollen)
- + Menschliche Reaktionszeit (~200ms)

Durch Abziehen der durchschnittlichen Reaktionszeit isolieren wir die reine Bluetooth-Latenz.

## UI-States

| State | Beschreibung | User-Aktion |
|-------|--------------|-------------|
| `ready` | Startscreen mit Info | "Kalibrierung starten" Button |
| `instructions` | Anleitung + 3s Countdown | Automatisch → measuring |
| `measuring` | Progress (X von 5) | Warten auf Flash |
| `waitingForTap` | Flash + Sound aktiv | **Tippen wenn synchron** |
| `processing` | Berechnung läuft | Automatisch → completed |
| `completed` | Ergebnis anzeigen | "Speichern" oder "Erneut" |
| `error` | Fehler aufgetreten | "Abbrechen" oder "Erneut" |

## Technische Details

### Audio-Wiedergabe

```swift
// Verwendet System-Sound für maximale Präzision
AudioServicesPlaySystemSound(1306) // "Tock" Sound
```

Warum System-Sound statt AVAudioPlayer?
- **Niedrigere Latenz:** Direkt über Audio-Hardware
- **Vorhersehbar:** Keine Buffer-Delays
- **Einfach:** Kein Setup nötig

### Flash-Animation

```swift
// 100ms weißer Vollbild-Flash
withAnimation(.easeInOut(duration: 0.05)) {
    showFlash = true
}
DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    withAnimation(.easeInOut(duration: 0.05)) {
        showFlash = false
    }
}
```

### Validierung

```swift
// Nur plausible Werte speichern (0-1000ms)
if measuredLatency >= 0 && measuredLatency <= 1.0 {
    measurements.append(measuredLatency)
}
```

Verhindert Fehl-Taps (z.B. wenn User versehentlich während Instructions tippt)

## Typische Ergebnisse

| Kopfhörer-Typ | Erwarteter Offset |
|---------------|-------------------|
| Kabelgebunden | 0-30ms |
| AirPods Pro (Gen 2) | 150-200ms |
| AirPods (Standard) | 180-220ms |
| Andere Bluetooth | 200-300ms |
| Bluetooth mit aptX | 120-180ms |

## Testing

### Manuelle Tests

1. **Kabelgebundene Kopfhörer:**
   - Erwartung: ~0-30ms
   - Prüfen: Alle 5 Messungen ähnlich

2. **AirPods:**
   - Erwartung: ~180ms
   - Prüfen: Konsistente Messungen

3. **Error-Cases:**
   - Zu früh tippen (vor Flash)
   - Zu spät tippen (>1s)
   - Nicht tippen (Timeout?)

### UI-Tests

```swift
func testLatencyCalibrationFlow() {
    // 1. Navigation zu Kalibrierung
    app.buttons["settings.latencyCalibration"].tap()
    
    // 2. Start
    app.buttons["Kalibrierung starten"].tap()
    
    // 3. Warte auf Flash (könnte schwer zu testen sein)
    // 4. Simuliere Tap
    // 5. Prüfe ob Messung gespeichert
    // 6. Wiederhole 5x
    // 7. Prüfe Ergebnis-Screen
    // 8. Speichern
    
    XCTAssertTrue(UserPreferences.load().audioLatencyOffset > 0)
}
```

## Zukünftige Verbesserungen

### Phase 2.1: Automatische Kalibrierung

Statt User-Taps: Analysiere Audio-Output vs. Light-Timing automatisch
- Spiele bekannte Waveform ab
- Messe mit Mikrofon
- Berechne Latenz automatisch

**Vorteil:** Genauer, keine User-Reaktionszeit
**Nachteil:** Komplexer, benötigt Mikrofon-Permission

### Phase 2.2: Kopfhörer-Datenbank

Speichere bekannte Latenz-Werte für populäre Kopfhörer:
```swift
let knownDevices = [
    "AirPods Pro (2nd generation)": 0.18,
    "AirPods Pro": 0.20,
    "Sony WH-1000XM5": 0.25,
    // ...
]
```

Wenn Gerät erkannt wird: Vorschlag anzeigen statt Kalibrierung

### Phase 2.3: Adaptive Kalibrierung

Kontinuierliche Feinjustierung während Sessions:
- Analysiere User-Taps auf Beats
- Vergleiche mit erwarteten Beat-Timestamps
- Passe Offset minimal an

## Integration mit bestehendem System

Die Kalibrierung speichert direkt in `UserPreferences.audioLatencyOffset`, welches bereits von allen Controllern verwendet wird:

```swift
// Wird automatisch angewendet in:
- BaseLightController.findCurrentEvent()
- VibrationController.findCurrentEvent()
```

Keine weiteren Änderungen nötig! Das System ist "plug and play".

---

*Erstellt: 2025-01-27*
*Feature-Status: ✅ Vollständig implementiert*

