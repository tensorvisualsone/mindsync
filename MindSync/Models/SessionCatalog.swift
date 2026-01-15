import Foundation

/// Represents a fixed entrainment session with predefined frequency map and audio file
struct EntrainmentSession: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let duration: TimeInterval
    let targetState: EntrainmentMode
    /// Frequency map: array of (time, frequency, intensity) tuples
    /// Time is relative to session start in seconds
    let frequencyMap: [(time: TimeInterval, freq: Double, intensity: Float)]
    /// Name of the background audio file (e.g., "alpha_audio.mp3")
    let backgroundAudioFile: String
    /// Optional URL to the audio file (loaded from bundle)
    let audioFileURL: URL?
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String,
        duration: TimeInterval,
        targetState: EntrainmentMode,
        frequencyMap: [(time: TimeInterval, freq: Double, intensity: Float)],
        backgroundAudioFile: String,
        audioFileURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.duration = duration
        self.targetState = targetState
        self.frequencyMap = frequencyMap
        self.backgroundAudioFile = backgroundAudioFile
        
        // If URL not provided, try to load from bundle
        if let url = audioFileURL {
            self.audioFileURL = url
        } else {
            self.audioFileURL = Bundle.main.url(forResource: backgroundAudioFile.withoutMP3Extension, withExtension: "mp3")
        }
    }
}

/// Catalog of available fixed entrainment sessions
enum SessionCatalog {
    // MARK: - Helper Functions for Script Generation
    
    /// Advances the PRNG seed without using the generated value.
    /// Used to keep light and vibration scripts synchronized when one script
    /// needs to advance the seed but doesn't use the random value.
    /// - Parameter seed: The current PRNG seed (passed as inout to update in place)
    private static func advanceRandomSeed(_ seed: inout UInt64) {
        seed = seed &* 1103515245 &+ 12345
    }
    
    /// Pre-generates a shared sequence of random (frequency, intensity) pairs for Phase 3.
    /// This ensures light and vibration scripts stay synchronized by using the same random
    /// values at the same time points, regardless of their different iteration rates.
    /// - Parameters:
    ///   - seed: Initial PRNG seed (must match between light and vibration scripts)
    ///   - duration: Total duration of Phase 3 in seconds
    ///   - interval: Fixed time interval between random value samples (e.g., 0.1 seconds)
    /// - Returns: Array of (frequency: Double, intensity: Float) pairs indexed by time step
    private static func generatePhase3RandomValues(
        seed: UInt64,
        duration: TimeInterval,
        interval: TimeInterval
    ) -> [(frequency: Double, intensity: Float)] {
        let stepCount = Int(ceil(duration / interval))
        var values: [(frequency: Double, intensity: Float)] = []
        var currentSeed = seed
        
        for _ in 0..<stepCount {
            // Generate frequency (3.5-6.0 Hz)
            advanceRandomSeed(&currentSeed)
            let randomValue = Double(currentSeed & 0x7FFFFFFF) / Double(0x7FFFFFFF)
            let frequency = 3.5 + (randomValue * 2.5) // 3.5-6.0 Hz
            
            // Generate intensity (0.15-0.4 for vibration, 0.2-0.5 for light)
            // We'll use the wider range and let each script clamp as needed
            advanceRandomSeed(&currentSeed)
            let randomValue2 = Double(currentSeed & 0x7FFFFFFF) / Double(0x7FFFFFFF)
            let intensity = Float(0.15 + (randomValue2 * 0.35)) // 0.15-0.5 (covers both ranges)
            
            values.append((frequency: frequency, intensity: intensity))
        }
        
        return values
    }
    
    /// Calculates a deterministic duration value for Phase 3 light events.
    /// Uses a separate PRNG seed sequence (offset from main seed) to generate duration
    /// independently from frequency/intensity, ensuring reproducibility.
    /// - Parameters:
    ///   - seed: Initial PRNG seed (same as used for frequency/intensity)
    ///   - index: Time step index for deterministic generation
    /// - Returns: Duration value in range 1.5-3.0 seconds
    private static func generatePhase3Duration(seed: UInt64, index: Int) -> TimeInterval {
        // Use a separate seed offset to generate duration independently
        // This ensures duration is deterministic but doesn't interfere with frequency/intensity sync
        var durationSeed = seed &+ 99999 // Offset seed for duration generation
        // Advance seed by index to get deterministic value for this time step
        for _ in 0..<index {
            advanceRandomSeed(&durationSeed)
        }
        advanceRandomSeed(&durationSeed)
        let randomValue = Double(durationSeed & 0x7FFFFFFF) / Double(0x7FFFFFFF)
        return 1.5 + (randomValue * 1.5) // 1.5-3.0 seconds
    }
    
    // MARK: - Frequency Map Extraction
    
    /// Threshold for detecting significant frequency changes when extracting frequency maps (in Hz)
    private static let frequencyChangeThreshold: Double = 0.5
    
    /// Threshold for detecting significant intensity changes when extracting frequency maps (0.0-1.0)
    private static let intensityChangeThreshold: Float = 0.05
    
    /// Checks if a new point should be added to the frequency map based on significant changes
    private static func shouldAddMapPoint(
        freq: Double,
        intensity: Float,
        lastFreq: Double,
        lastIntensity: Float,
        isEmpty: Bool
    ) -> Bool {
        return isEmpty ||
               abs(freq - lastFreq) > frequencyChangeThreshold ||
               abs(intensity - lastIntensity) > intensityChangeThreshold
    }
    
    /// Extracts a simplified frequency map from a LightScript
    /// Samples the script at key transition points to create a representative frequency map
    /// - Parameter script: The LightScript to extract from
    /// - Returns: Array of (time, frequency, intensity) tuples
    private static func extractFrequencyMap(from script: LightScript) -> [(time: TimeInterval, freq: Double, intensity: Float)] {
        var frequencyMap: [(time: TimeInterval, freq: Double, intensity: Float)] = []
        
        // Sample key events from the script to build frequency map
        // We want to capture phase transitions and boundaries
        var lastFreq: Double = 0
        var lastIntensity: Float = 0
        
        for event in script.events {
            let freq = event.frequencyOverride ?? script.targetFrequency
            let intensity = event.intensity
            
            // Add entry if this is a new phase (frequency or intensity changed significantly)
            if shouldAddMapPoint(freq: freq, intensity: intensity, lastFreq: lastFreq, lastIntensity: lastIntensity, isEmpty: frequencyMap.isEmpty) {
                frequencyMap.append((time: event.timestamp, freq: freq, intensity: intensity))
                lastFreq = freq
                lastIntensity = intensity
            }
        }
        
        // Add final event if script has events
        if let lastEvent = script.events.last {
            let freq = lastEvent.frequencyOverride ?? script.targetFrequency
            let endTime = lastEvent.timestamp + lastEvent.duration
            // Only add if not already at the end (check cached last element to avoid duplicate entries)
            if let lastMapEntry = frequencyMap.last, lastMapEntry.time != endTime {
                frequencyMap.append((time: endTime, freq: freq, intensity: lastEvent.intensity))
            } else if frequencyMap.isEmpty {
                frequencyMap.append((time: endTime, freq: freq, intensity: lastEvent.intensity))
            }
        }
        
        return frequencyMap
    }
    
    /// Get the fixed session for a given mode
    /// - Parameter mode: The entrainment mode
    /// - Returns: The fixed session, or nil if mode doesn't use fixed sessions
    static func session(for mode: EntrainmentMode) -> EntrainmentSession? {
        switch mode {
        case .alpha:
            return alphaSession
        case .theta:
            return thetaSession
        case .gamma:
            return gammaSession
        case .dmnShutdown:
            return dmnShutdownSession
        case .beliefRewiring:
            return beliefRewiringSession
        case .cinematic:
            return nil // Cinematic mode uses user-selected audio
        }
    }
    
    /// Alpha (Relax) session: 15 minutes, 8-12 Hz Alpha band
    private static let alphaSession: EntrainmentSession = {
        return EntrainmentSession(
            title: "Alpha Relaxation",
            description: "Deep relaxation and calm focus",
            duration: 900, // 15 minutes
            targetState: .alpha,
            frequencyMap: extractFrequencyMap(from: EntrainmentEngine.generateAlphaScript()),
            backgroundAudioFile: "alpha_audio.mp3"
        )
    }()
    
    /// Theta (Deep Dive) session: 20 minutes, 4-8 Hz Theta band with peak at 6 Hz
    private static let thetaSession: EntrainmentSession = {
        return EntrainmentSession(
            title: "Theta Deep Dive",
            description: "Deep meditation and inner exploration",
            duration: 1200, // 20 minutes
            targetState: .theta,
            frequencyMap: extractFrequencyMap(from: EntrainmentEngine.generateThetaScript()),
            backgroundAudioFile: "theta_audio.mp3"
        )
    }()
    
    /// Gamma (Focus) session: 11 minutes, 30-40 Hz Gamma band
    private static let gammaSession: EntrainmentSession = {
        return EntrainmentSession(
            title: "Gamma Focus",
            description: "Enhanced focus and cognitive performance",
            duration: 660, // 11 minutes (matches generateGammaScript)
            targetState: .gamma,
            frequencyMap: extractFrequencyMap(from: EntrainmentEngine.generateGammaScript()),
            backgroundAudioFile: "gamma_audio.mp3"
        )
    }()
    
    /// DMN-Shutdown session: Uses existing script from SessionCatalog
    private static let dmnShutdownSession: EntrainmentSession = {
        return EntrainmentSession(
            title: "DMN Shutdown",
            description: "Ego-dissolution and transcendent states",
            duration: 1800, // 30 minutes (matches generateDMNShutdownScript)
            targetState: .dmnShutdown,
            frequencyMap: extractFrequencyMap(from: generateDMNShutdownScript()),
            backgroundAudioFile: "void_master.mp3"
        )
    }()
    
    /// Belief-Rewiring session: Uses existing script from SessionCatalog
    private static let beliefRewiringSession: EntrainmentSession = {
        return EntrainmentSession(
            title: "Belief Rewiring",
            description: "Subconscious reprogramming and neural pathway rewiring",
            duration: 1800, // 30 minutes (matches generateBeliefRewiringScript)
            targetState: .beliefRewiring,
            frequencyMap: extractFrequencyMap(from: generateBeliefRewiringScript()),
            backgroundAudioFile: "belief_rewiring_audio.mp3"
        )
    }()
    
    // MARK: - Session Script Generators
    
    /// Generiert den speziellen "Awakening Flow" Script.
    /// Dieser ignoriert Audio-Beats und erzeugt eine feste 30-minütige Zeitreise durch die Gehirnwellen.
    static func generateAwakeningScript() -> LightScript {
        var events: [LightEvent] = []
        var currentTime: TimeInterval = 0.0
        
        // --- PHASE 1: ARRIVAL (5 Min) ---
        // Ramp von 12 Hz (Alpha) runter auf 8 Hz (Alpha/Theta Grenze)
        // Wir erstellen kleine 1-Sekunden-Schnipsel für einen super-smoothen Übergang
        let phase1Duration: TimeInterval = 300 // 5 Minuten
        let startFreq = 12.0
        let endFreq = 8.0
        
        for i in 0..<Int(phase1Duration) {
            let progress = Double(i) / phase1Duration
            // Smoothstep Interpolation für organisches Gefühl
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = startFreq + (endFreq - startFreq) * smoothProgress
            
            let event = LightEvent(
                timestamp: currentTime,
                intensity: 0.4, // Sanfter Start
                duration: 1.0,
                waveform: .sine,
                color: .blue, // Falls Screen Mode genutzt wird
                frequencyOverride: currentFreq // Dynamische Frequenz!
            )
            events.append(event)
            currentTime += 1.0
        }
        
        // --- PHASE 2: THE VOID (10 Min) ---
        // Konstante 4 Hz (Tiefes Theta) - Dissoziation
        let phase2Duration: TimeInterval = 600
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.35, // Etwas dunkler für Trance
            duration: phase2Duration,
            waveform: .sine,
            color: .purple,
            frequencyOverride: 4.0
        ))
        currentTime += phase2Duration
        
        // --- PHASE 3: ACTIVATION (5 Min) ---
        // 40 Hz Gamma - Synchronisation
        let phase3Duration: TimeInterval = 300
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.6, // Heller für Fokus
            duration: phase3Duration,
            waveform: .square, // Harte Kanten für Gamma-Sync
            color: .orange,
            frequencyOverride: 40.0
        ))
        currentTime += phase3Duration
        
        // --- PHASE 4: PEAK (5 Min) ---
        // 100 Hz Lambda - "Awakening"
        // Achtung: Das ist visuell fast Dauerlicht, aber das Nervensystem spürt den Takt.
        let phase4Duration: TimeInterval = 300
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.8, // Sehr hell
            duration: phase4Duration,
            waveform: .square,
            color: .white,
            frequencyOverride: 100.0 // Lambda!
        ))
        currentTime += phase4Duration
        
        // --- PHASE 5: GROUNDING (5 Min) ---
        // 7.83 Hz Schumann Resonanz - Erdung
        let phase5Duration: TimeInterval = 300
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.4,
            duration: phase5Duration,
            waveform: .sine,
            color: .green,
            frequencyOverride: 7.83
        ))
        
        // Dummy Audio Track ID (Da wir hier keine Musik analysieren, sondern Frequenzen vorgeben)
        return LightScript(
            trackId: UUID(),
            mode: .gamma, // Technisch gesehen ein Mix, aber Gamma passt als "High Energy" Container
            targetFrequency: 40.0,
            multiplier: 1,
            events: events
        )
    }
    
    /// Generates the special "DMN-Shutdown" script for ego-dissolution (Tepperwein Sequence).
    /// This ignores audio beats and creates a fixed 30-minute sequence
    /// to specifically deactivate the Default Mode Network (DMN).
    /// 
    /// Phases (Tepperwein Sequence):
    /// - Phase 1: ENTRY (0-3 Min) - 10 Hz Alpha, soft sine waves
    /// - Phase 2: THE ABYSS / VACUUM (3-12 Min) - 4.5 Hz Theta, dim to 0.1 (no black pauses)
    /// - Phase 3: DISSOLUTION (12-20 Min) - Randomized intervals (variability breaks expectation)
    /// - Transition: (20-20.5 Min) - Smooth ramp from Theta to 40 Hz Gamma
    /// - Phase 4: THE VOID / UNIVERSE (20.5-29 Min) - 40 Hz Gamma burst, maximum brightness
    /// - Phase 5: REINTEGRATION COOLDOWN (29-30 Min) - Gradual ramp-down to Alpha
    /// Total duration: 30 minutes (1800 seconds)
    /// 
    /// Note: Light script total is 1800s (180+540+480+30+510+60). The 30-second transition
    /// phase smooths the shift from randomized Theta to high-intensity Gamma.
    static func generateDMNShutdownScript() -> LightScript {
        var events: [LightEvent] = []
        var currentTime: TimeInterval = 0.0
        
        // --- PHASE 1: ENTRY (0-3 Min) ---
        // 10 Hz Alpha, soft sine waves for gentle entry
        // "Let everything go..." - calms the body immediately
        // **Waveform Choice**: Sine waves are intentionally used here for gentle transitions.
        // While square waves are more effective for neural entrainment (90.8% vs 75% SSVEP),
        // the entry phase requires smooth, non-jarring transitions to help users relax and
        // prepare for deeper states. Square waves would be too abrupt for this therapeutic phase.
        let phase1Duration: TimeInterval = 180 // 3 minutes
        let p1Frequency = 10.0 // 10 Hz Alpha
        
        // 1-second events with sine waves for gentle, organic feeling
        for _ in 0..<Int(phase1Duration) {
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: 0.4, // Gentle start
                duration: 1.0,
                waveform: .sine, // Soft sine waves for gentle entry (intentional, not square)
                color: .blue,
                frequencyOverride: p1Frequency
            ))
            currentTime += 1.0
        }
        
        // --- PHASE 2: THE ABYSS / VACUUM (3-12 Min) ---
        // 4.5 Hz Theta - "underwater feeling"
        // IMPORTANT: No black pauses (0.0), instead dim down to 0.1
        // This keeps the visual cortex minimally active for therapeutic effect.
        // **Waveform Choice**: Sine waves are used here to create a "breathing" effect with
        // gradual intensity changes. The smooth oscillation through lower values (0.35 to 0.1)
        // creates a therapeutic, non-jarring experience that supports dissociation. Square waves
        // would create abrupt transitions that could disrupt the meditative state.
        // Note: Sine waveform naturally oscillates through lower values, achieving a breathing effect.
        let phase2Duration: TimeInterval = 540 // 9 minutes (3-12 Min)
        let p2Frequency = 4.5 // 4.5 Hz Theta
        
        // 2-second events with alternating intensity (0.35/0.1) - no complete off
        // This keeps the visual cortex minimally active, creating a "breathing" sensory experience
        for i in 0..<Int(phase2Duration / 2) {
            // Alternate between 0.35 and 0.1 (instead of 0.0) - no complete off
            let intensity: Float = (i % 2 == 0) ? 0.35 : 0.1
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: intensity,
                duration: 2.0,
                waveform: .sine, // Soft waves for "underwater feeling"
                color: .purple,
                frequencyOverride: p2Frequency
            ))
            currentTime += 2.0
        }
        
        // --- PHASE 3: DISSOLUTION (12-20 Min) ---
        // Randomized intervals (variability) - the brain cannot predict the pattern anymore
        // This breaks expectations and leads to dissociation
        let phase3Duration: TimeInterval = 480 // 8 minutes (12-20 Min)
        
        // Pre-generate shared sequence of random (frequency, intensity) pairs for synchronization
        // with vibration script. Both scripts index into this sequence by fixed time-step.
        let phase3Interval: TimeInterval = 0.1 // Fixed 100ms interval for indexing
        let phase3RandomValues = generatePhase3RandomValues(
            seed: 12345, // Fixed seed for reproducible "randomness" across sessions
            duration: phase3Duration,
            interval: phase3Interval
        )
        
        var phase3Time: TimeInterval = 0
        
        while phase3Time < phase3Duration {
            // Index into pre-generated sequence using fixed time-step
            let index = Int(floor(phase3Time / phase3Interval))
            let clampedIndex = min(index, phase3RandomValues.count - 1)
            let randomPair = phase3RandomValues[clampedIndex]
            
            // Use frequency and intensity from shared sequence
            let variedFrequency = randomPair.frequency // 3.5-6.0 Hz
            let variedIntensity = max(0.2, min(0.5, randomPair.intensity)) // Clamp to 0.2-0.5 for light
            
            // Varying event duration (1.5-3.0 seconds) for additional unpredictability
            // Generated deterministically based on index to maintain reproducibility
            let variedDuration = generatePhase3Duration(seed: 12345, index: clampedIndex)
            
            events.append(LightEvent(
                timestamp: currentTime + phase3Time,
                intensity: variedIntensity,
                duration: variedDuration,
                waveform: .sine, // Soft waves for organic dissociation (intentional - smooth transitions support therapeutic dissociation)
                color: .purple,
                frequencyOverride: variedFrequency
            ))
            phase3Time += variedDuration
        }
        currentTime += phase3Duration
        
        // --- TRANSITION RAMP (20-20.5 Min) ---
        // Smooth transition from randomized Theta to 40 Hz Gamma
        let transitionDuration: TimeInterval = 30 // 30 seconds
        let startFreq = 4.5
        let endFreq = 40.0
        
        for i in 0..<Int(transitionDuration) {
            let progress = Double(i) / transitionDuration
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = startFreq + (endFreq - startFreq) * smoothProgress
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: 0.5, // Moderate intensity during transition
                duration: 1.0,
                waveform: .square, // Square wave for hard transition to Gamma
                color: .white,
                frequencyOverride: currentFreq
            ))
            currentTime += 1.0
        }
        
        // --- PHASE 4: THE VOID / UNIVERSE (20.5-29 Min) ---
        // 40 Hz Gamma Burst - maximum brightness (with safety limit)
        // "Body sleeps, mind is awake" - total stillness in the body, only light in the mind
        // **Waveform Choice**: Square waves are essential here for maximum gamma entrainment effectiveness.
        // Research shows 90.8% SSVEP success rate with square waves vs 75% with sine waves. The hard
        // on/off transitions maximize transient steepness (dI/dt), activating the magnocellular pathway
        // and creating optimal conditions for gamma synchronization at 40 Hz.
        let phase4Duration: TimeInterval = 510 // 8.5 minutes (starts at 20.5 min, ends at 29 min)
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.9, // Maximum brightness (with safety limit)
            duration: phase4Duration,
            waveform: .square, // Square wave is gold standard for Gamma sync (90.8% vs 75% SSVEP success rate)
            color: .white,
            frequencyOverride: 40.0
        ))
        currentTime += phase4Duration
        
        // --- PHASE 5: REINTEGRATION COOLDOWN (29-30 Min) ---
        // Gradual ramp-down from high Gamma to help users transition back safely
        // Prevents jarring abrupt ending at maximum intensity
        // **Waveform Choice**: Sine waves are used here for gentle reintegration. After intense
        // gamma stimulation, users need smooth transitions back to normal consciousness. Square waves
        // would create abrupt changes that could be disorienting or uncomfortable during this
        // critical reintegration phase.
        let cooldownDuration: TimeInterval = 60 // 1 minute cooldown
        let cooldownStartFreq = 40.0
        let cooldownEndFreq = 10.0 // Return to Alpha for gentle landing
        
        for i in 0..<Int(cooldownDuration) {
            let progress = Double(i) / cooldownDuration
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = cooldownStartFreq - (cooldownStartFreq - cooldownEndFreq) * smoothProgress
            let currentIntensity = 0.9 - (0.6 * Float(smoothProgress)) // Fade from 0.9 to 0.3
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: currentIntensity,
                duration: 1.0,
                waveform: .sine, // Sine wave for gentle reintegration (intentional - smooth transitions support safe return)
                color: .blue,
                frequencyOverride: currentFreq
            ))
            currentTime += 1.0
        }
        
        // Dummy Audio Track ID (since we don't analyze music here, but provide frequencies)
        return LightScript(
            trackId: UUID(),
            mode: .dmnShutdown, // Uses the new DMN-Shutdown mode
            targetFrequency: 40.0,
            multiplier: 1,
            events: events
        )
    }
    
    /// Generates the special "Belief-Rewiring" script for subconscious reprogramming.
    /// This ignores audio beats and creates a fixed 30-minute sequence
    /// to identify limiting beliefs and rewire them with new neural pathways.
    /// 
    /// Phases:
    /// - Phase 1: THE SOFT-OPEN (4 Min) - 12Hz → 8Hz Ramp (Alpha to Theta)
    /// - Phase 2: ROOT-IDENTIFICATION (10 Min) - 5Hz Theta for accessing subconscious
    /// - Phase 3: THE REWIRE-BURST (8 Min) - 40Hz Gamma-Burst with affirmations
    /// - Phase 4: INTEGRATION (8 Min) - 7.83Hz Schumann Resonance for grounding
    static func generateBeliefRewiringScript() -> LightScript {
        var events: [LightEvent] = []
        var currentTime: TimeInterval = 0.0
        
        // --- PHASE 1: THE SOFT-OPEN (4 Min) ---
        // We start at 12Hz (Alpha) and gently pull consciousness down to 8Hz (Alpha/Theta border).
        // This softens the critical mind and prepares for subconscious access.
        // **Waveform Choice**: Sine waves are intentionally used here for gentle, organic transitions.
        // While square waves are more effective for neural entrainment, the soft-open phase requires
        // smooth, non-jarring transitions to help users relax and prepare for subconscious access.
        let phase1Duration: TimeInterval = 240 // 4 minutes
        let p1StartFreq = 12.0
        let p1EndFreq = 8.0
        
        // IMPORTANT: Each event has duration: 1.0 (full second), not period/2.0
        // The sine wave shape is controlled by duty cycle, not by event duration
        for i in 0..<Int(phase1Duration) {
            let progress = Double(i) / phase1Duration
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = p1StartFreq + (p1EndFreq - p1StartFreq) * smoothProgress
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: 0.4, // Gentle intensity for soft opening
                duration: 1.0, // Full second - NOT period/2.0!
                waveform: .sine, // Sine waves for gentle, organic transition
                color: .blue,
                frequencyOverride: currentFreq
            ))
            currentTime += 1.0
        }
        
        // --- PHASE 2: ROOT-IDENTIFICATION (10 Min) ---
        // Deep theta oscillation at 5 Hz.
        // Here we open the gate to the subconscious to identify the limiting belief.
        // **Waveform Choice**: Square waves are used here for visual clarity and maximum contrast.
        // Research shows 90.8% SSVEP success rate with square waves vs 75% with sine waves. The hard
        // on/off transitions (complete darkness between pulses) maximize contrast and support deep
        // introspection during subconscious access.
        let phase2Duration: TimeInterval = 600 // 10 minutes
        let p2Frequency = 5.0
        
        // 2-second events with alternating intensity (0.35/0.0) for hard contrast
        // Square waves ensure the light is completely off (0.0) between pulses
        // IMPORTANT: duration: 2.0 (full 2 seconds), not period/2.0
        for i in 0..<Int(phase2Duration / 2) {
            // We alternate between 0.35 and 0.0 (complete darkness) for maximum contrast
            let intensity: Float = (i % 2 == 0) ? 0.35 : 0.0
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: intensity,
                duration: 2.0, // Full 2 seconds - NOT period/2.0!
                waveform: .square, // Square waves for visual clarity during introspection
                color: .purple,
                frequencyOverride: p2Frequency
            ))
            currentTime += 2.0
        }
        
        // --- TRANSITION RAMP (60 Sek) ---
        // We smoothly ramp the brain from 5 Hz (Theta) to 40 Hz (Gamma)
        // This prevents the abrupt frequency jump that can cause discomfort
        let transitionDuration: TimeInterval = 60 // 60 seconds
        let startFreq = 5.0
        let endFreq = 40.0
        
        for i in 0..<Int(transitionDuration) {
            let progress = Double(i) / transitionDuration
            // Smoothstep interpolation for organic transition
            let smoothProgress = MathHelpers.smoothstep(progress)
            let currentFreq = startFreq + (endFreq - startFreq) * smoothProgress
            
            events.append(LightEvent(
                timestamp: currentTime,
                intensity: 0.4, // Gentle intensity during the transition
                duration: 1.0,
                waveform: .square,
                color: .white,
                frequencyOverride: currentFreq
            ))
            currentTime += 1.0
        }
        
        // --- PHASE 3: THE REWIRE-BURST (8 Min) ---
        // 40Hz Gamma-Burst for burning in the new neural pathway.
        // This is where we imprint the new belief with maximum synchronization.
        // **Waveform Choice**: Square waves are essential here for maximum gamma entrainment effectiveness.
        // Research shows 90.8% SSVEP success rate with square waves vs 75% with sine waves. The hard
        // on/off transitions maximize transient steepness (dI/dt), activating the magnocellular pathway
        // and creating optimal conditions for gamma synchronization at 40 Hz - critical for neural
        // pathway rewiring.
        let phase3Duration: TimeInterval = 480 // 8 minutes
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.7, // High intensity (70%) for maximum effect, but not overwhelming
            duration: phase3Duration, // Full duration - NOT period/2.0!
            waveform: .square, // Square wave is gold standard for gamma sync (90.8% vs 75% SSVEP success rate)
            color: .white,
            frequencyOverride: 40.0
        ))
        currentTime += phase3Duration
        
        // --- PHASE 4: INTEGRATION (8 Min) ---
        // Schumann Resonance (7.83Hz) for peaceful grounding and integration.
        // This allows the new neural pathway to settle and integrate.
        // **Waveform Choice**: Sine waves are used here for gentle grounding and integration.
        // After intense gamma stimulation, users need smooth transitions to help the new neural
        // pathway settle. Square waves would create abrupt changes that could disrupt the
        // integration process during this critical phase.
        let phase4Duration: TimeInterval = 480 // 8 minutes
        events.append(LightEvent(
            timestamp: currentTime,
            intensity: 0.4,
            duration: phase4Duration, // Full duration - NOT period/2.0!
            waveform: .sine, // Sine for gentle grounding and integration (intentional - smooth transitions support neural pathway integration)
            color: .green,
            frequencyOverride: 7.83
        ))
        
        // Dummy Audio Track ID (since we don't analyze music here, but provide frequencies)
        return LightScript(
            trackId: UUID(),
            mode: .beliefRewiring, // Uses the new Belief-Rewiring mode
            targetFrequency: 40.0,
            multiplier: 1,
            events: events
        )
    }
}
