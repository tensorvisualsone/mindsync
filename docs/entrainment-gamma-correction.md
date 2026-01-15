# Entrainment Gamma Correction

## Overview

This document explains the scientific rationale behind mode-specific gamma correction in MindSync's flashlight controller for optimal neural entrainment effectiveness.

## Mode-Specific Gamma Values

| Mode | Gamma Value | Rationale |
|------|-------------|-----------|
| Gamma | 1.0 (raw) | Maximum LED power for hardcore entrainment |
| Theta | 1.0 (raw) | Maximum LED power for deep meditation |
| Alpha | 1.2 | Slight correction for gentler relaxation transitions |
| DMN-Shutdown | 1.0 (raw) | Maximum power for intense ego-dissolution |
| Belief-Rewiring | 1.0 (raw) | Maximum power for subconscious access |
| Cinematic | 1.0 (raw) | Maximum power for beat-synchronized flashes |

## Scientific Rationale for Raw Mode (Gamma 1.0)

### Neural Entrainment Requirements

For true neural entrainment (Brainwave Entrainment), we need the "shock effect" for the optic nerve. The key principles:

1. **Maximum Contrast Ratio**: Raw intensity (gamma 1.0) ensures maximum contrast ratio between on/off states, which is crucial for optimal cortical evoked potentials.

2. **Sharp Transitions**: Square waves with hard on/off transitions maximize transient steepness (dI/dt), which is what the brain's visual cortex responds to most strongly.

3. **SSVEP Effectiveness**: Steady-State Visual Evoked Potentials (SSVEP) require machine-precise, constant frequency stimulation. Raw mode preserves the "hard edges" needed for effective entrainment.

4. **Power Loss with Gamma Correction**: Standard gamma correction (e.g., 1.8) significantly reduces LED power in the mid-range:
   - Input 0.5 → Output ~0.28 with gamma 1.8 (44% power loss)
   - This weakens the entrainment effect by reducing stimulus intensity

### Why Alpha Mode Uses Gamma 1.2

Alpha mode targets relaxation states, which benefit from:
- Gentler transitions to avoid startling the user
- Slightly softer stimulus intensity while maintaining effectiveness
- Still much higher power than traditional gamma 1.8 (only ~15% reduction at 0.5 intensity vs 44%)

## Safety Considerations

Despite using raw intensity, all safety mechanisms remain fully active:

1. **Thermal Management**: `ThermalManager` applies `maxFlashlightIntensity` limits (0.6-0.9) based on device temperature
2. **Duty Cycle Control**: Standard 30% duty cycle prevents sustained maximum brightness
3. **Emergency Stop**: User-accessible emergency stop remains available
4. **Fall Detection**: Motion-based safety features remain active
5. **Epilepsy Warnings**: Comprehensive warnings shown before first use

## References

- **SSVEP Research**: [Steady-State Visual Evoked Potentials](https://en.wikipedia.org/wiki/Steady_state_visually_evoked_potential)
- **Gamma Entrainment**: MIT studies on 40 Hz light stimulation for cognitive enhancement
- **Visual Cortex Response**: Square wave stimulation produces stronger evoked potentials than sinusoidal

## Implementation

See `MindSync/Core/Light/FlashlightController.swift` (lines ~365-407) for the implementation of mode-specific gamma correction.

---

**Last Updated**: January 2026  
**Related Docs**: `GAMMA_OPTIMIZATION.md` (frequency optimization), `USER_GUIDE.md` (safety)
