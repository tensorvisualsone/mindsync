#!/bin/bash

echo "🔧 iPhone Verbindung - Erweiterte Reparatur"
echo "=========================================="
echo ""

# Prüfen auf root oder sudo
if [ "$EUID" -ne 0 ]; then
    echo "ℹ️  Prüfe sudo-Berechtigungen..."
    if ! sudo -v; then
        echo "❌ Fehler: Root-Rechte erforderlich. Bitte führen Sie 'sudo -v' aus oder starten Sie das Skript mit sudo."
        exit 1
    fi
fi

echo "⚠️  ACHTUNG: Dies beendet Xcode und alle iOS-Dienste!"
echo "Drücken Sie Ctrl+C zum Abbrechen oder warten Sie 5 Sekunden..."
sleep 5
echo ""

echo "1️⃣ Beende Xcode und alle iOS-Dienste..."
killall Xcode 2>/dev/null

# Funktion zum sicheren Beenden
safe_kill() {
    local proc="$1"
    # Prüfen ob Prozess läuft (pgrep ist auf macOS und Linux verfügbar)
    if sudo pgrep -x "$proc" >/dev/null 2>&1; then
        # Versuche SIGTERM
        sudo killall "$proc" 2>/dev/null
        sleep 1
        # Prüfen ob immer noch läuft, dann SIGKILL
        if sudo pgrep -x "$proc" >/dev/null 2>&1; then
            sudo killall -9 "$proc" 2>/dev/null
        fi
    fi
}

# Liste der zu beendenden Dienste
SERVICES=(
    "usbmuxd"
    "lockdownd"
    "com.apple.CoreDevice.coredeviced"
    "AMPDevicesAgent"
    "AMPDeviceDiscoveryAgent"
)

for service in "${SERVICES[@]}"; do
    safe_kill "$service"
done

echo "✓ Dienste beendet"
echo ""

echo "2️⃣ Lösche Xcode Cache..."
rm -rf "$HOME/Library/Developer/Xcode/iOS DeviceSupport"/* 2>/dev/null
rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/* 2>/dev/null
echo "✓ Cache gelöscht"
echo ""

echo "3️⃣ Lösche Device Support Dateien..."
rm -rf "$HOME/Library/Developer/Xcode/iOS Device Logs"/* 2>/dev/null
echo "✓ Logs gelöscht"
echo ""

echo "4️⃣ Setze Lockdown zurück..."
if [ -d "$HOME/Library/Lockdown" ]; then
    find "$HOME/Library/Lockdown" -name "*.plist" -type f -delete 2>/dev/null
fi
echo "✓ Lockdown zurückgesetzt"
echo ""

echo "5️⃣ Warte 5 Sekunden..."
sleep 5
echo ""

echo "✅ Fertig! Jetzt BITTE:"
echo ""
echo "   1. Stecken Sie das iPhone AB"
echo "   2. Warten Sie 5 Sekunden"
echo "   3. Stecken Sie das iPhone wieder AN"
echo "   4. ENTSPERREN Sie das iPhone"
echo "   5. Öffnen Sie Xcode: open -a Xcode"
echo "   6. Öffnen Sie Ihr Projekt"
echo "   7. Wählen Sie das iPhone 15 Pro als Target"
echo "   8. Klicken Sie auf Build & Run"
echo ""
