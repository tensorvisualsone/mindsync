#!/bin/bash

# Prüfen, ob sudo verfügbar/autorisiert ist (mit Passwort-Prompt falls nötig)
if ! sudo -v 2>/dev/null; then
    echo "❌ Fehler: Dieses Skript benötigt sudo-Rechte."
    echo "Bitte führen Sie das Skript mit sudo aus oder stellen Sie sicher, dass Sie sudo-Rechte haben."
    exit 1
fi

echo "🔧 iPhone Verbindungsproblem beheben"
echo "===================================="
echo ""

echo "1️⃣ Beende iOS-Verbindungsdienste..."
sudo killall -9 usbmuxd 2>/dev/null
sudo killall -9 lockdownd 2>/dev/null
sudo killall -9 com.apple.CoreDevice.coredeviced 2>/dev/null
echo "✓ Dienste beendet"
echo ""

echo "2️⃣ Setze Lockdown-Dateien zurück..."
rm ~/Library/Lockdown/*.plist 2>/dev/null
echo "✓ Lockdown-Dateien entfernt"
echo ""

echo "3️⃣ Beende Xcode..."
killall Xcode 2>/dev/null
echo "✓ Xcode beendet"
echo ""

echo "4️⃣ Warte 3 Sekunden..."
sleep 3
echo ""

echo "✅ Fertig! Jetzt bitte:"
echo ""
echo "   1. Stecken Sie Ihr iPhone AB und wieder AN"
echo "   2. Entsperren Sie das iPhone"
echo "   3. Tippen Sie auf 'Vertrauen' wenn die Meldung erscheint"
echo "   4. Öffnen Sie Xcode neu: open -a Xcode"
echo ""
echo "⚠️  WICHTIG: Stellen Sie sicher, dass der Entwicklermodus"
echo "   auf dem iPhone aktiviert ist:"
echo "   Einstellungen → Datenschutz & Sicherheit → Entwicklermodus"
echo ""

