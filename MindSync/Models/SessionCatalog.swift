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
    /// Threshold for detecting significant frequency changes when extracting frequency maps (in Hz)
    private static let frequencyChangeThreshold: Double = 0.5
    
    /// Threshold for detecting significant intensity changes when extracting frequency maps (0.0-1.0)
    private static let intensityChangeThreshold: Float = 0.05
    
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
            if frequencyMap.isEmpty ||
               abs(freq - lastFreq) > Self.frequencyChangeThreshold ||
               abs(intensity - lastIntensity) > Self.intensityChangeThreshold {
                frequencyMap.append((time: event.timestamp, freq: freq, intensity: intensity))
                lastFreq = freq
                lastIntensity = intensity
            }
        }
        
        // Add final event if script has events
        if let lastEvent = script.events.last {
            let freq = lastEvent.frequencyOverride ?? script.targetFrequency
            let endTime = lastEvent.timestamp + lastEvent.duration
            // Only add if not already at the end
            if frequencyMap.last?.time != endTime {
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
        let script = EntrainmentEngine.generateAlphaScript()
        return EntrainmentSession(
            title: "Alpha Relaxation",
            description: "Deep relaxation and calm focus",
            duration: 900, // 15 minutes
            targetState: .alpha,
            frequencyMap: extractFrequencyMap(from: script),
            backgroundAudioFile: "alpha_audio.mp3"
        )
    }()
    
    /// Theta (Deep Dive) session: 20 minutes, 4-8 Hz Theta band with peak at 6 Hz
    private static let thetaSession: EntrainmentSession = {
        let script = EntrainmentEngine.generateThetaScript()
        return EntrainmentSession(
            title: "Theta Deep Dive",
            description: "Deep meditation and inner exploration",
            duration: 1200, // 20 minutes
            targetState: .theta,
            frequencyMap: extractFrequencyMap(from: script),
            backgroundAudioFile: "theta_audio.mp3"
        )
    }()
    
    /// Gamma (Focus) session: 11 minutes, 30-40 Hz Gamma band
    private static let gammaSession: EntrainmentSession = {
        let script = EntrainmentEngine.generateGammaScript()
        return EntrainmentSession(
            title: "Gamma Focus",
            description: "Enhanced focus and cognitive performance",
            duration: 660, // 11 minutes (matches generateGammaScript)
            targetState: .gamma,
            frequencyMap: extractFrequencyMap(from: script),
            backgroundAudioFile: "gamma_audio.mp3"
        )
    }()
    
    /// DMN-Shutdown session: Uses existing script from EntrainmentEngine
    private static let dmnShutdownSession: EntrainmentSession = {
        let script = EntrainmentEngine.generateDMNShutdownScript()
        return EntrainmentSession(
            title: "DMN Shutdown",
            description: "Ego-dissolution and transcendent states",
            duration: 1800, // 30 minutes (matches generateDMNShutdownScript)
            targetState: .dmnShutdown,
            frequencyMap: extractFrequencyMap(from: script),
            backgroundAudioFile: "void_master.mp3"
        )
    }()
    
    /// Belief-Rewiring session: Uses existing script from EntrainmentEngine
    private static let beliefRewiringSession: EntrainmentSession = {
        let script = EntrainmentEngine.generateBeliefRewiringScript()
        return EntrainmentSession(
            title: "Belief Rewiring",
            description: "Subconscious reprogramming and neural pathway rewiring",
            duration: 1800, // 30 minutes (matches generateBeliefRewiringScript)
            targetState: .beliefRewiring,
            frequencyMap: extractFrequencyMap(from: script),
            backgroundAudioFile: "belief_rewiring_audio.mp3"
        )
    }()
}
