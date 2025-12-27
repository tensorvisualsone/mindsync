#!/bin/bash

echo "🔧 iPhone Verbindung - Erweiterte Reparatur"
echo "=========================================="
echo ""

echo "⚠️  ACHTUNG: Dies beendet Xcode und alle iOS-Dienste!"
echo "Drücken Sie Ctrl+C zum Abbrechen oder warten Sie 5 Sekunden..."
sleep 5
echo ""

echo "1️⃣ Beende Xcode und alle iOS-Dienste..."
killall Xcode 2>/dev/null
sudo killall -9 usbmuxd 2>/dev/null
sudo killall -9 lockdownd 2>/dev/null  
sudo killall -9 com.apple.CoreDevice.coredeviced 2>/dev/null
sudo killall -9 AMPDevicesAgent 2>/dev/null
sudo killall -9 AMPDeviceDiscoveryAgent 2>/dev/null
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
rm ~/Library/Lockdown/*.plist 2>/dev/null
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

