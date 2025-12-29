# GitHub Workflows für MindSync

Dieses Verzeichnis enthält die GitHub Actions Workflows für das MindSync-Projekt.

## Verfügbare Workflows

### Swift Workflow (`swift.yml`)

Dieser Workflow führt Build und Tests für das MindSync Xcode-Projekt aus.

**Trigger:**
- Push auf `main` Branch
- Pull Requests gegen `main` Branch

**Schritte:**
1. Repository auschecken
2. Xcode einrichten (neueste stabile Version)
3. Shared Scheme-Verzeichnis erstellen
4. Scheme als "shared" markieren (falls noch nicht geschehen)
5. Projekt bauen (Debug, iOS Simulator)
6. Unit Tests ausführen (`MindSyncTests`)
7. UI Tests ausführen (`MindSyncUITests`)

**Voraussetzungen:**
- Das Xcode-Scheme "MindSync" muss als "shared" markiert sein
- Das Scheme sollte alle Test-Targets enthalten (MindSyncTests, MindSyncUITests)

### CodeQL Workflow (`codeql.yml`)

Dieser Workflow führt statische Code-Analyse mit CodeQL durch, um Sicherheitslücken und Code-Qualitätsprobleme zu finden.

**Trigger:**
- Push auf `main` oder `master` Branch
- Pull Requests gegen `main` oder `master` Branch
- Wöchentlich (Sonntag um Mitternacht)

## Scheme als "Shared" markieren

Damit die Workflows funktionieren, muss das Xcode-Scheme als "shared" markiert sein:

### Option 1: Automatisch (empfohlen)

Führe das Script aus:
```bash
./scripts/make-scheme-shared.sh
```

### Option 2: Manuell in Xcode

1. Öffne `MindSync.xcodeproj` in Xcode
2. Gehe zu **Product → Scheme → Manage Schemes...**
3. Aktiviere das **"Shared"**-Checkbox für das "MindSync"-Scheme
4. Schließe den Dialog

Das Scheme wird dann in `MindSync.xcodeproj/xcshareddata/xcschemes/` gespeichert und kann in CI/CD verwendet werden.

## Lokales Testen der Workflows

Du kannst die Workflows lokal testen, indem du die gleichen Befehle ausführst:

```bash
# Build
xcodebuild clean build \
  -project MindSync/MindSync.xcodeproj \
  -scheme MindSync \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO

# Unit Tests
xcodebuild test \
  -project MindSync/MindSync.xcodeproj \
  -scheme MindSync \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:MindSyncTests

# UI Tests
xcodebuild test \
  -project MindSync/MindSync.xcodeproj \
  -scheme MindSync \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  -only-testing:MindSyncUITests
```

## Troubleshooting

### "Scheme not found" Fehler

- Stelle sicher, dass das Scheme als "shared" markiert ist (siehe oben)
- Prüfe, ob `MindSync.xcodeproj/xcshareddata/xcschemes/MindSync.xcscheme` existiert

### "No such file or directory" Fehler

- Stelle sicher, dass das Projekt korrekt strukturiert ist
- Prüfe, ob `MindSync/MindSync.xcodeproj` existiert

### Tests schlagen fehl

- Stelle sicher, dass alle Test-Targets korrekt konfiguriert sind
- Prüfe, ob der Simulator-Name korrekt ist (kann je nach Xcode-Version variieren)

## Weitere Informationen

- [GitHub Actions Dokumentation](https://docs.github.com/en/actions)
- [Xcode Build Settings](https://developer.apple.com/documentation/xcode/build-settings-reference)
- [xcodebuild Man Page](https://www.manpagez.com/man/1/xcodebuild/)
