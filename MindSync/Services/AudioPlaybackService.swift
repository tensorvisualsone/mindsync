import Foundation
import AVFoundation

/// Service for audio playback
final class AudioPlaybackService: NSObject {
    private var audioPlayer: AVAudioPlayer?
    
    /// Callback when playback completes
    var onPlaybackComplete: (() -> Void)?

    /// Plays an audio file
    /// - Parameter url: URL of the audio file
    /// - Throws: Error if playback is not possible
    func play(url: URL) throws {
        stop()
        
        // Configure audio session to ensure audio plays even in silent mode
        // and handles interruptions appropriately for a safety-critical app
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default, options: [])
        try audioSession.setActive(true)
        
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        audioPlayer = player
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }

    /// Stops playback
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    /// Pauses playback
    func pause() {
        audioPlayer?.pause()
    }

    /// Resumes playback
    func resume() {
        audioPlayer?.play()
    }

    /// Current playback time in seconds
    var currentTime: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }

    /// Is playback active?
    var isPlaying: Bool {
        audioPlayer?.isPlaying ?? false
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackService: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onPlaybackComplete?()
    }
}
