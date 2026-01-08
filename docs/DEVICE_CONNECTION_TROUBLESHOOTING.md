# Xcode Geräteverbindungs-Problembehebung

## Problem: "Connecting to iPhone" hängt endlos

Wenn Xcode beim Verbinden mit einem physischen iPhone hängt, obwohl das Gerät im Finder erkannt wird, gibt es mehrere mögliche Lösungen.

## Lösung 1: Multi-Path Networking deaktivieren

**Auf dem iPhone:**
1. Einstellungen → Entwickler (erscheint nur wenn Developer Mode aktiv ist)
2. Nach unten scrollen zu "Multi-Path Networking"
3. Deaktivieren
4. iPhone neu starten
5. Mac neu starten
6. Erneut versuchen

## Lösung 2: Developer Mode vollständig zurücksetzen

**Auf dem iPhone:**
1. Einstellungen → Datenschutz & Sicherheit → Developer Mode
2. Developer Mode deaktivieren
3. iPhone neu starten
4. Developer Mode wieder aktivieren
5. iPhone erneut neu starten
6. Gerät neu verbinden

## Lösung 3: Gerät-Vertrauen zurücksetzen

**Auf dem iPhone:**
1. Einstellungen → Allgemein → Übertragen oder iPhone zurücksetzen → Zurücksetzen
2. "Netzwerkeinstellungen zurücksetzen" wählen (nicht alle Daten löschen!)
3. iPhone neu starten
4. Gerät neu verbinden und "Diesem Computer vertrauen" bestätigen

## Lösung 4: Xcode Device Support Cache löschen

**Auf dem Mac:**
```bash
# Xcode beenden
killall Xcode

# Device Support Cache löschen
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport/*

# Provisioning Profiles löschen
rm -rf ~/Library/MobileDevice/Provisioning\ Profiles/*

# Xcode neu starten
```

## Lösung 5: USB-Verbindung prüfen

- Original-Apple-Kabel verwenden (keine Drittanbieter-Kabel)
- Anderen USB-Port am Mac probieren
- USB-Hub vermeiden (direkt am Mac anschließen)
- Kabel wechseln falls möglich

## Lösung 6: Xcode Command Line Tools neu installieren

```bash
sudo xcode-select --reset
xcode-select --install
```

## Lösung 7: Gerät in Xcode manuell hinzufügen

1. Xcode → Window → Devices and Simulators (⇧⌘2)
2. Falls das Gerät erscheint: Rechtsklick → "Unpair Device"
3. Gerät trennen und neu verbinden
4. "Use for Development" aktivieren

## Lösung 8: iOS-Version prüfen

Stelle sicher, dass:
- Das iPhone iOS 17.0+ läuft (MindSync Minimum)
- Xcode die entsprechende iOS-Version unterstützt
- Device Support für die iOS-Version in Xcode installiert ist

## Lösung 9: Code Signing prüfen

In Xcode:
1. MindSync Target → Signing & Capabilities
2. "Automatically manage signing" aktivieren
3. Team auswählen (R5J8377X89)
4. Bundle Identifier prüfen (com.tensorvisualsone.MindSync)

## Lösung 10: Alternative: Wireless Debugging

Falls USB weiterhin Probleme macht:
1. iPhone und Mac müssen im gleichen WLAN sein
2. Xcode → Window → Devices and Simulators
3. "Connect via network" aktivieren
4. Erste Verbindung muss per USB erfolgen, danach funktioniert Wireless

## Debug-Informationen sammeln

Falls nichts hilft, sammle diese Informationen:
```bash
# Geräte-Status prüfen
xcrun devicectl list devices

# Xcode Version
xcodebuild -version

# iOS Version auf dem iPhone
# (Einstellungen → Allgemein → Info)
```

## Häufigste Ursachen (nach Häufigkeit)

1. **Multi-Path Networking aktiv** (Lösung 1)
2. **Device Support Cache beschädigt** (Lösung 4)
3. **USB-Kabel/Port Problem** (Lösung 5)
4. **Developer Mode nicht vollständig aktiviert** (Lösung 2)
5. **Code Signing Konfiguration** (Lösung 9)

## Script zur automatischen Bereinigung

Führe `scripts/fix-device-connection.sh` aus für automatische Cache-Bereinigung.
