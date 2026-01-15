# Audio Files for Fixed Sessions

This file documents the required audio files for the fixed entrainment sessions.

## Required Audio Files

The following audio files must be placed in the `MindSync/Resources/` directory:

1. **alpha_audio.mp3** – Alpha Relaxation Session (15 minutes)
   - Drone/atmosphere sound for relaxation
   - Optional: Subtle 10 Hz pulses for frequency sync
   - Format: MP3, 44.1 kHz, mono/stereo

2. **theta_audio.mp3** – Theta Deep Dive Session (20 minutes)
   - Deep atmosphere for meditation
   - Optional: Subtle 6 Hz pulses for frequency sync
   - Format: MP3, 44.1 kHz, mono/stereo

3. **gamma_audio.mp3** – Gamma Focus Session (10 minutes)
   - Energetic drone for focus
   - Optional: Subtle 40 Hz pulses for frequency sync
   - Format: MP3, 44.1 kHz, mono/stereo

4. **void_master.mp3** – DMN shutdown session (30 minutes)
   - **Canonical file name**: `void_master.mp3` (already present in the project)
   - Brown/pink noise with isochronic tones
   - **Note**: The code references `void_master.mp3` directly. No aliasing or renaming is required.

5. **belief_rewiring_audio.mp3** – Belief rewiring session (30 minutes)
   - Drone/atmosphere sound for subconscious access
   - Optional: Frequency sync aligned with script phases
   - Format: MP3, 44.1 kHz, mono/stereo

## Notes on Audio Production

- **Drone sounds**: Pink noise, OM chants, isochronic tones
- **Frequency sync**: Audio should contain subtle pulses at the light frequency
- **Duration**: Must match session duration (10–30 minutes)
- **Volume**: Moderate volume, not too loud (excessive loudness can disrupt entrainment)

## Xcode Project Integration

The audio files must be registered in the Xcode project:
1. Add the files to `MindSync/Resources/`
2. Register them under "Copy Bundle Resources" in the Xcode target settings
3. Ensure they are included in the app bundle

## Fallback Behavior

If an audio file is missing, the session starts without audio (light only).
This is a valid fallback and does not impair the effectiveness of the entrainment.

