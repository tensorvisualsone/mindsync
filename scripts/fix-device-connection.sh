#!/bin/bash

# Script zur Behebung von Xcode-Geräteverbindungsproblemen
# Führt die häufigsten Lösungen für "Connecting to iPhone" Hänger aus

echo "🔧 MindSync - Xcode Geräteverbindungs-Fix"
echo "=========================================="
echo ""

# 1. Xcode beenden
echo "1️⃣  Beende Xcode..."
killall Xcode 2>/dev/null
sleep 2

# 2. Device Support Cache löschen
echo "2️⃣  Lösche Device Support Cache..."
DEVICE_SUPPORT_PATH="$HOME/Library/Developer/Xcode/iOS DeviceSupport"
if [ -d "$DEVICE_SUPPORT_PATH" ]; then
    rm -rf "$DEVICE_SUPPORT_PATH"/*
    echo "   ✓ Device Support Cache gelöscht"
else
    echo "   ⚠ Device Support Verzeichnis nicht gefunden"
fi

# 3. Derived Data löschen
echo "3️⃣  Lösche Derived Data..."
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
if [ -d "$DERIVED_DATA_PATH" ]; then
    rm -rf "$DERIVED_DATA_PATH"/*
    echo "   ✓ Derived Data gelöscht"
else
    echo "   ⚠ Derived Data Verzeichnis nicht gefunden"
fi

# 4. Module Cache löschen
echo "4️⃣  Lösche Module Cache..."
MODULE_CACHE_PATH="$HOME/Library/Developer/Xcode/DerivedData/ModuleCache.noindex"
if [ -d "$MODULE_CACHE_PATH" ]; then
    rm -rf "$MODULE_CACHE_PATH"/*
    echo "   ✓ Module Cache gelöscht"
fi

# 5. Provisioning Profile Cache löschen
echo "5️⃣  Lösche Provisioning Profile Cache..."
PROVISIONING_PATH="$HOME/Library/MobileDevice/Provisioning Profiles"
if [ -d "$PROVISIONING_PATH" ]; then
    rm -rf "$PROVISIONING_PATH"/*
    echo "   ✓ Provisioning Profiles gelöscht"
fi

# 6. com.apple.dt.Xcode.plist löschen (Xcode Einstellungen)
echo "6️⃣  Setze Xcode Einstellungen zurück..."
XCODE_PREFS="$HOME/Library/Preferences/com.apple.dt.Xcode.plist"
if [ -f "$XCODE_PREFS" ]; then
    rm "$XCODE_PREFS"
    echo "   ✓ Xcode Einstellungen zurückgesetzt"
fi

echo ""
echo "✅ Cache-Bereinigung abgeschlossen!"
echo ""
echo "📱 Nächste Schritte am iPhone:"
echo "   1. Trenne das iPhone vom Mac"
echo "   2. Auf dem iPhone: Einstellungen → Allgemein → VPN & Geräteverwaltung"
echo "   3. Prüfe, ob 'Developer Mode' aktiviert ist"
echo "   4. Falls nicht: Einstellungen → Datenschutz & Sicherheit → Developer Mode aktivieren"
echo "   5. iPhone neu starten (falls Developer Mode aktiviert wurde)"
echo "   6. Verbinde das iPhone erneut mit dem Mac"
echo "   7. Auf dem iPhone: 'Diesem Computer vertrauen' bestätigen"
echo "   8. Xcode öffnen und erneut versuchen"
echo ""
echo "💡 Falls das Problem weiterhin besteht:"
echo "   - Prüfe, ob das iPhone mit einem Original-Apple-Kabel verbunden ist"
echo "   - Versuche einen anderen USB-Port"
echo "   - Prüfe Xcode → Window → Devices and Simulators, ob das Gerät dort erscheint"
echo ""
