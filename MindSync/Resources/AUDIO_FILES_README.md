# Audio Files für feste Sessions

Diese Datei dokumentiert die benötigten Audiodateien für die festen Entrainment-Sessions.

## Benötigte Audiodateien

Die folgenden Audiodateien müssen im `MindSync/Resources/` Verzeichnis abgelegt werden:

1. **alpha_audio.mp3** - Alpha Relaxation Session (15 Minuten)
   - Drone/Atmosphere Sound für Entspannung
   - Optional: Subtile 10 Hz Impulse für Frequenz-Sync
   - Format: MP3, 44.1kHz, Mono/Stereo

2. **theta_audio.mp3** - Theta Deep Dive Session (20 Minuten)
   - Deep Atmosphere für Meditation
   - Optional: Subtile 6 Hz Impulse für Frequenz-Sync
   - Format: MP3, 44.1kHz, Mono/Stereo

3. **gamma_audio.mp3** - Gamma Focus Session (10 Minuten)
   - Energetischer Drone für Fokus
   - Optional: Subtile 40 Hz Impulse für Frequenz-Sync
   - Format: MP3, 44.1kHz, Mono/Stereo

4. **void_master.mp3** - DMN-Shutdown Session (30 Minuten)
   - **Kanonischer Dateiname**: `void_master.mp3` (bereits im Projekt vorhanden)
   - Brown/Pink Noise mit isochronen Tönen
   - **Hinweis**: Der Code referenziert `void_master.mp3` direkt. Keine Alias- oder Umbenennung erforderlich.

5. **belief_rewiring_audio.mp3** - Belief-Rewiring Session (30 Minuten)
   - Drone/Atmosphere für Unterbewusstseins-Zugang
   - Optional: Frequenz-Sync mit Script-Phasen
   - Format: MP3, 44.1kHz, Mono/Stereo

## Hinweise zur Audio-Produktion

- **Drone-Sounds**: Pink Noise, OM-Chants, Isochrone Töne
- **Frequenz-Sync**: Audio sollte subtile Impulse bei der Lichtfrequenz haben
- **Dauer**: Entspricht Session-Dauer (10-30 Minuten)
- **Lautstärke**: Moderate Lautstärke, nicht zu laut (kann Entrainment stören)

## Xcode-Projekt Integration

Die Audiodateien müssen im Xcode-Projekt registriert werden:
1. Dateien zu `MindSync/Resources/` hinzufügen
2. Im Xcode-Projekt unter "Copy Bundle Resources" registrieren
3. Sicherstellen, dass sie im App-Bundle enthalten sind

## Fallback-Verhalten

Wenn eine Audiodatei fehlt, startet die Session ohne Audio (nur Licht).
Dies ist ein gültiger Fallback und beeinträchtigt die Entrainment-Wirkung nicht.
