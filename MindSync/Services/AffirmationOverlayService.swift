import Foundation
import AVFoundation

/// Service für Audio-Affirmationen während der Theta-Phase
/// Spielt Sprachmemos genau in der stabilen Theta-Phase ab mit Reverb-Effekt
class AffirmationOverlayService {
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    private var reverbNode: AVAudioUnitReverb?
    private var musicPlayer: AVAudioPlayer? // Referenz zum Haupt-Audio-Player für Ducking
    
    // Konfiguration
    private let duckingVolume: Float = 0.3 // Leiser für mehr Dramatik
    private let standardVolume: Float = 1.0
    
    /// Spielt eine Affirmation ab, wenn die Theta-Phase stabil ist
    /// - Parameters:
    ///   - url: Die URL zum Sprachmemo des Users
    ///   - musicPlayer: Die aktuelle AudioPlayback-Instanz für das Ducking
    func playAffirmation(url: URL, musicPlayer: AVAudioPlayer) {
        self.musicPlayer = musicPlayer
        
        // 1. Eigene AudioEngine für Affirmationen erstellen
        let engine = AVAudioEngine()
        self.audioEngine = engine
        
        // 2. Nodes erstellen
        let playerNode = AVAudioPlayerNode()
        let reverb = AVAudioUnitReverb()
        
        self.audioPlayerNode = playerNode
        self.reverbNode = reverb
        
        // 3. Reverb "Dreamy" einstellen
        reverb.loadFactoryPreset(.cathedral) // Großer, weiter Raum
        reverb.wetDryMix = 50 // 50% Original, 50% Hall (Sphärisch)
        
        // 4. Nodes an die Engine hängen
        engine.attach(playerNode)
        engine.attach(reverb)
        
        // 5. Verbinden: Player -> Reverb -> MainMixer
        do {
            let file = try AVAudioFile(forReading: url)
            let mixer = engine.mainMixerNode
            
            engine.connect(playerNode, to: reverb, format: file.processingFormat)
            engine.connect(reverb, to: mixer, format: file.processingFormat)
            
            // 6. Ducking starten (Musik leiser machen)
            fadeMusicVolume(to: duckingVolume)
            
            // 7. Engine starten
            try engine.start()
            
            // 8. Abspielen
            playerNode.scheduleFile(file, at: nil) {
                // Callback wenn fertig
                DispatchQueue.main.async {
                    self.fadeMusicVolume(to: self.standardVolume)
                    // Cleanup Nodes (wichtig um Ressourcen zu sparen)
                    self.cleanupNodes()
                }
            }
            
            playerNode.play()
            print("--- 🌌 MindSync: Affirmation aus dem Äther gestartet ---")
            
        } catch {
            print("Mandatory Truth: Audio-File ist korrupt oder nicht lesbar: \(error)")
            cleanupNodes()
        }
    }
    
    private func fadeMusicVolume(to volume: Float) {
        // Ducking: Musik leiser machen während Affirmation spielt
        // AVAudioPlayer hat keine direkte Volume-Kontrolle während Playback,
        // daher nutzen wir einen Workaround mit einem Timer
        let currentVolume = musicPlayer?.volume ?? 1.0
        let targetVolume = volume
        let steps = 10
        let stepSize = (targetVolume - currentVolume) / Float(steps)
        
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.1) { [weak self] in
                self?.musicPlayer?.volume = currentVolume + (stepSize * Float(i))
            }
        }
    }
    
    private func cleanupNodes() {
        audioPlayerNode?.stop()
        
        if let engine = audioEngine,
           let player = audioPlayerNode,
           let reverb = reverbNode {
            engine.disconnectNodeInput(player)
            engine.disconnectNodeInput(reverb)
            engine.detach(player)
            engine.detach(reverb)
            engine.stop()
        }
        
        audioEngine = nil
        audioPlayerNode = nil
        reverbNode = nil
    }
    
    /// Stoppt die aktuelle Affirmation
    func stop() {
        cleanupNodes()
        // Musik wieder auf normale Lautstärke
        musicPlayer?.volume = standardVolume
    }
}
