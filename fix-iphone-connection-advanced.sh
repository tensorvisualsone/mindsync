#!/bin/bash

echo "🔧 iPhone Verbindung - Erweiterte Reparatur"
echo "=========================================="
echo ""

echo "⚠️  ACHTUNG: Dies beendet Xcode und alle iOS-Dienste!"
echo "Drücken Sie Ctrl+C zum Abbrechen oder warten Sie 5 Sekunden..."
sleep 5
echo ""

# Helper Funktion: Sicheres Beenden von Prozessen mit Warnungen
safe_killall() {
    local output
    output=$("$@" 2>&1)
    local status=$?
    
    # Prüfe auf Fehler (Ignoriere "Keine passenden Prozesse")
    if [ $status -ne 0 ]; then
        if ! echo "$output" | grep -qE "No matching processes|no process found|Keine passenden Prozesse"; then
            echo "⚠️  Warnung: Fehler beim Befehl '$*': $output"
        fi
    fi
}

# Helper Funktion: Sicheres Löschen mit Existenzprüfung
safe_rm() {
    for target in "$@"; do
        if [ -e "$target" ]; then
            if ! rm -rf "$target" 2>&1; then
                 echo "⚠️  Fehler beim Löschen von: $target"
            fi
        fi
    done
}

echo "1️⃣ Beende Xcode und alle iOS-Dienste..."
safe_killall killall Xcode
safe_killall sudo killall -9 usbmuxd
safe_killall sudo killall -9 lockdownd  
safe_killall sudo killall -9 com.apple.CoreDevice.coredeviced
safe_killall sudo killall -9 AMPDevicesAgent
safe_killall sudo killall -9 AMPDeviceDiscoveryAgent
echo "✓ Dienste beendet"
echo ""

echo "2️⃣ Lösche Xcode Cache..."
safe_rm ~/Library/Developer/Xcode/iOS\ DeviceSupport/*
safe_rm ~/Library/Developer/Xcode/DerivedData/*
echo "✓ Cache gelöscht"
echo ""

echo "3️⃣ Lösche Device Support Dateien..."
safe_rm ~/Library/Developer/Xcode/iOS\ Device\ Logs/*
echo "✓ Logs gelöscht"
echo ""

echo "4️⃣ Setze Lockdown zurück..."
safe_rm ~/Library/Lockdown/*.plist
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
