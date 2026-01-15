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
            self.audioFileURL = Bundle.main.url(forResource: backgroundAudioFile.replacingOccurrences(of: ".mp3", with: ""), withExtension: "mp3")
        }
    }
}

/// Catalog of available fixed entrainment sessions
enum SessionCatalog {
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
    private static let alphaSession = EntrainmentSession(
        title: "Alpha Relaxation",
        description: "Deep relaxation and calm focus",
        duration: 900, // 15 minutes
        targetState: .alpha,
        frequencyMap: [
            // Phase 1: Entry (2 Min) - 15 Hz → 10 Hz Ramp
            (0, 15.0, 0.3),
            (120, 10.0, 0.4),
            // Phase 2: Deep Alpha (10 Min) - 10 Hz konstant
            (120, 10.0, 0.4),
            (720, 10.0, 0.4),
            // Phase 3: Exit (3 Min) - 10 Hz → 12 Hz Ramp
            (720, 10.0, 0.4),
            (900, 12.0, 0.3)
        ],
        backgroundAudioFile: "alpha_audio.mp3"
    )
    
    /// Theta (Deep Dive) session: 20 minutes, 4-8 Hz Theta band with peak at 6 Hz
    private static let thetaSession = EntrainmentSession(
        title: "Theta Deep Dive",
        description: "Deep meditation and inner exploration",
        duration: 1200, // 20 minutes
        targetState: .theta,
        frequencyMap: [
            // Phase 1: Entry (3 Min) - 12 Hz → 6 Hz Ramp
            (0, 12.0, 0.3),
            (180, 6.0, 0.5),
            // Phase 2: Deep Theta (14 Min) - 6 Hz konstant (peak experience)
            (180, 6.0, 0.5),
            (1020, 6.0, 0.5),
            // Phase 3: Exit (3 Min) - 6 Hz → 8 Hz Ramp
            (1020, 6.0, 0.5),
            (1200, 8.0, 0.3)
        ],
        backgroundAudioFile: "theta_audio.mp3"
    )
    
    /// Gamma (Focus) session: 11 minutes, 30-40 Hz Gamma band
    private static let gammaSession = EntrainmentSession(
        title: "Gamma Focus",
        description: "Enhanced focus and cognitive performance",
        duration: 660, // 11 minutes (matches generateGammaScript)
        targetState: .gamma,
        frequencyMap: [
            // Phase 1: Entry (0-1 Min = 0-60s) - 20 Hz → 35 Hz Ramp
            (0, 20.0, 0.5),
            (60, 35.0, 0.7),
            // Transition: (1-2 Min = 60-120s) - 35 Hz → 40 Hz Ramp to peak
            (60, 35.0, 0.7),
            (120, 40.0, 0.8),
            // Phase 2: Peak Gamma (2-10 Min = 120-600s) - 40 Hz konstant
            (120, 40.0, 0.8),
            (600, 40.0, 0.8),
            // Phase 3: Exit (10-11 Min = 600-660s) - 40 Hz → 30 Hz Ramp
            (600, 40.0, 0.8),
            (660, 30.0, 0.5)
        ],
        backgroundAudioFile: "gamma_audio.mp3"
    )
    
    /// DMN-Shutdown session: Uses existing script from EntrainmentEngine
    private static let dmnShutdownSession = EntrainmentSession(
        title: "DMN Shutdown",
        description: "Ego-dissolution and transcendent states",
        duration: 1800, // 30 minutes (matches generateDMNShutdownScript)
        targetState: .dmnShutdown,
        frequencyMap: [
            // Frequency map matches generateDMNShutdownScript phases (chronologically ordered)
            // Phase 1: ENTRY (0-3 Min = 0-180s) - 10 Hz Alpha, soft sine waves
            (0, 10.0, 0.4),
            (180, 10.0, 0.4),    // Phase 1 end
            
            // Phase 2: THE ABYSS / VACUUM (3-12 Min = 180-720s) - 4.5 Hz Theta, alternating intensity
            (180, 4.5, 0.35),    // Phase 2 start (alternating 0.35/0.1, using 0.35 as representative)
            (720, 4.5, 0.35),    // Phase 2 end
            
            // Phase 3: DISSOLUTION (12-20 Min = 720-1200s) - Randomized Theta (3.5-6.0 Hz)
            (720, 5.0, 0.3),     // Phase 3 start (representative of randomized 3.5-6.0 Hz range)
            (1200, 5.0, 0.3),    // Phase 3 end
            
            // Transition: (20-20.5 Min = 1200-1230s) - Smooth ramp from 4.5 Hz to 40 Hz
            (1200, 4.5, 0.5),    // Transition start
            (1230, 40.0, 0.5),   // Transition end
            
            // Phase 4: THE VOID / UNIVERSE (20.5-29 Min = 1230-1740s) - 40 Hz Gamma burst
            (1230, 40.0, 0.9),   // Phase 4 start
            (1740, 40.0, 0.9),   // Phase 4 end
            
            // Phase 5: REINTEGRATION COOLDOWN (29-30 Min = 1740-1800s) - Ramp from 40 Hz to 10 Hz
            (1740, 40.0, 0.9),   // Phase 5 start (intensity fades from 0.9 to 0.3)
            (1800, 10.0, 0.3)    // Phase 5 end
        ],
        backgroundAudioFile: "void_master.mp3"
    )
    
    /// Belief-Rewiring session: Uses existing script from EntrainmentEngine
    private static let beliefRewiringSession = EntrainmentSession(
        title: "Belief Rewiring",
        description: "Subconscious reprogramming and neural pathway rewiring",
        duration: 1800, // 30 minutes (matches generateBeliefRewiringScript)
        targetState: .beliefRewiring,
        frequencyMap: [
            // Frequency map matches generateBeliefRewiringScript phases
            (0, 12.0, 0.4),      // Phase 1: The Soft-Open (4 Min) - 12 Hz → 8 Hz
            (240, 8.0, 0.4),
            (240, 5.0, 0.35),     // Phase 2: Root-Identification (10 Min) - 5 Hz Theta
            (840, 5.0, 0.35),
            (840, 40.0, 0.7),     // Phase 3: The Rewire-Burst (8 Min) - 40 Hz Gamma
            (1320, 40.0, 0.7),
            (1320, 7.83, 0.4),    // Phase 4: Integration (8 Min) - 7.83 Hz Schumann
            (1800, 7.83, 0.4)
        ],
        backgroundAudioFile: "belief_rewiring_audio.mp3"
    )
}
