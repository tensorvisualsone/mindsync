# Quickstart: MindSync Core App

**Feature**: 001-audio-strobe-sync  
**Date**: 2025-12-23  
**Plan**: [plan.md](./plan.md)

## Voraussetzungen

### Hardware
- Mac mit Apple Silicon (M1/M2/M3) oder Intel
- iPhone (für echte Taschenlampen-/Mikrofon-Tests)
- Kabel für Device-Deployment

### Software
- **macOS**: Sonoma 14.0+
- **Xcode**: 15.0+ (für Swift 5.9, iOS 17 SDK)
- **iOS Simulator**: iPhone 15 Pro (für 120Hz ProMotion Tests)
- **Git**: 2.x

### Xcode-Einstellungen
```
Xcode → Preferences → Accounts → Apple ID (für Device-Deployment)
Xcode → Preferences → Components → iOS 17 Simulator Runtime
```

---

## Projekt-Setup

### 1. Repository klonen

```bash
git clone <repository-url>
cd mindsync
```

### 2. Xcode-Projekt erstellen (einmalig)

Da dies ein neues Projekt ist, muss das Xcode-Projekt initial erstellt werden:

```bash
# Option A: Manuell in Xcode
# File → New → Project → iOS → App
# Product Name: MindSync
# Team: [Dein Team]
# Organization Identifier: com.yourdomain
# Interface: SwiftUI
# Language: Swift
# Storage: None
# Include Tests: ✓

# Option B: Falls ein Projekt-Template existiert
open MindSync.xcodeproj
```

### 3. Projekt-Konfiguration

**Target Settings** (MindSync → General):
- Minimum Deployments: iOS 17.0
- Device: iPhone, iPad
- Orientations: Portrait only (für Session-Stabilität)

**Capabilities** (MindSync → Signing & Capabilities):
- ❌ Keine speziellen Capabilities nötig (Taschenlampe/Mikrofon sind Permission-basiert)

**Info.plist** (erforderliche Privacy-Einträge):
```xml
<key>NSMicrophoneUsageDescription</key>
<string>MindSync verwendet das Mikrofon, um Musik von externen Quellen zu analysieren und das Stroboskop zu synchronisieren.</string>

<key>NSAppleMusicUsageDescription</key>
<string>MindSync benötigt Zugriff auf Ihre Musikbibliothek, um Songs für die Stroboskop-Synchronisation auszuwählen.</string>
```

---

## Build & Run

### Simulator

```bash
# Oder in Xcode: Product → Run (⌘R)
# Wähle iPhone 15 Pro Simulator
```

**Simulator-Einschränkungen**:
- ❌ Keine Taschenlampe (nur Bildschirm-Modus testbar)
- ❌ Keine echte Musikbibliothek (nur Mock-Daten)
- ✅ Bildschirm-Stroboskop funktioniert
- ✅ UI/UX testbar

### Echtes Gerät

```bash
# 1. iPhone verbinden
# 2. In Xcode: Gerät auswählen
# 3. Product → Run (⌘R)
# 4. Auf iPhone: Einstellungen → Allgemein → Geräteverwaltung → Trust
```

**Gerät-Vorteile**:
- ✅ Echte Taschenlampe
- ✅ Echte Musikbibliothek
- ✅ Echtes Mikrofon
- ✅ Thermisches Verhalten testbar

---

## Ordnerstruktur erstellen

Führe folgendes Script aus, um die Projektstruktur gemäß `plan.md` zu erstellen:

```bash
#!/bin/bash
# setup-structure.sh

mkdir -p MindSync/{App,Features/{Onboarding,Home,Session,Settings},Core/{Audio,Light,Entrainment,Safety},Models,Services,Shared/{Extensions,Components},Resources}
mkdir -p MindSyncTests/{Unit,Integration}
mkdir -p MindSyncUITests

# Placeholder-Dateien erstellen
touch MindSync/App/{MindSyncApp,AppState}.swift
touch MindSync/Features/Onboarding/{OnboardingView,EpilepsyWarningView,OnboardingViewModel}.swift
touch MindSync/Features/Home/{HomeView,ModeSelectionView,SourceSelectionView}.swift
touch MindSync/Features/Session/{SessionView,SessionViewModel,SessionControlsView,AnalysisProgressView}.swift
touch MindSync/Features/Settings/{SettingsView,LightSourcePicker}.swift
touch MindSync/Core/Audio/{AudioAnalyzer,BeatDetector,TempoEstimator,AudioFileReader,MicrophoneAnalyzer}.swift
touch MindSync/Core/Light/{LightController,FlashlightController,ScreenController,ThermalManager}.swift
touch MindSync/Core/Entrainment/{EntrainmentEngine,LightScript,FrequencyMapper,WaveformGenerator}.swift
touch MindSync/Core/Safety/{FallDetector,SafetyLimits}.swift
touch MindSync/Models/{Session,AudioTrack,EntrainmentMode,UserPreferences}.swift
touch MindSync/Services/{MediaLibraryService,AudioPlaybackService,SessionHistoryService,PermissionsService}.swift
touch MindSync/Shared/Extensions/{Color+MindSync,View+Gestures}.swift
touch MindSync/Shared/Components/{LargeButton,ProgressRing,SafetyBanner}.swift
touch MindSync/Shared/Constants.swift

echo "✅ Projektstruktur erstellt!"
```

---

## Erste Schritte (Entwicklung)

### 1. Models definieren

Kopiere die Structs aus `data-model.md` in die entsprechenden Dateien:

```swift
// MindSync/Models/EntrainmentMode.swift
enum EntrainmentMode: String, Codable, CaseIterable, Identifiable {
    case alpha, theta, gamma
    // ... (siehe data-model.md)
}
```

### 2. Einstiegspunkt einrichten

```swift
// MindSync/App/MindSyncApp.swift
import SwiftUI

@main
struct MindSyncApp: App {
    @AppStorage("epilepsyDisclaimerAccepted") private var disclaimerAccepted = false
    
    var body: some Scene {
        WindowGroup {
            if disclaimerAccepted {
                HomeView()
            } else {
                OnboardingView()
            }
        }
    }
}
```

### 3. Minimale OnboardingView

```swift
// MindSync/Features/Onboarding/OnboardingView.swift
import SwiftUI

struct OnboardingView: View {
    @AppStorage("epilepsyDisclaimerAccepted") private var disclaimerAccepted = false
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.yellow)
            
            Text("Wichtige Sicherheitshinweise")
                .font(.title.bold())
            
            Text("Diese App verwendet stroboskopisches Licht, das bei Menschen mit photosensitiver Epilepsie Anfälle auslösen kann.")
                .multilineTextAlignment(.center)
                .padding()
            
            Button("Ich verstehe und akzeptiere") {
                disclaimerAccepted = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .preferredColorScheme(.dark)
    }
}
```

---

## Tests ausführen

### Unit Tests

```bash
# In Xcode: Product → Test (⌘U)
# Oder:
xcodebuild test -scheme MindSync -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

### UI Tests

```bash
xcodebuild test -scheme MindSyncUITests -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

---

## Häufige Probleme

### "Cannot find 'MPMediaPickerController' in scope"

```swift
// Lösung: MediaPlayer importieren
import MediaPlayer
```

### "This app has crashed because it attempted to access privacy-sensitive data without a usage description"

```
// Lösung: Info.plist Einträge prüfen (siehe oben)
```

### Taschenlampe funktioniert nicht im Simulator

```
// Erwartet! Taschenlampe nur auf echtem Gerät verfügbar.
// Für Simulator: Bildschirm-Modus verwenden
```

### AVAssetReader gibt nil zurück

```swift
// Ursache: DRM-geschützter Song
// Lösung: Nur DRM-freie lokale Dateien verwenden
// Test: item.assetURL != nil prüfen
```

---

## Nächste Schritte

1. **Spec lesen**: `specs/001-audio-strobe-sync/spec.md`
2. **Plan verstehen**: `specs/001-audio-strobe-sync/plan.md`
3. **Research nachschlagen**: `specs/001-audio-strobe-sync/research.md`
4. **Data Model implementieren**: `specs/001-audio-strobe-sync/data-model.md`
5. **Tasks generieren**: `/speckit.tasks` ausführen

---

**Quickstart Version**: 1.0.0 | **Status**: Ready for Development

