import Foundation
import AVFoundation

/// Service für Audio-Wiedergabe
final class AudioPlaybackService: NSObject {
    private var audioPlayer: AVAudioPlayer?
    
    /// Callback when playback completes
    var onPlaybackComplete: (() -> Void)?

    /// Spielt eine Audio-Datei ab
    /// - Parameter url: URL der Audio-Datei
    /// - Throws: Fehler wenn Wiedergabe nicht möglich
    func play(url: URL) throws {
        stop()
        
        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        audioPlayer = player
        audioPlayer?.prepareToPlay()
        audioPlayer?.play()
    }

    /// Stoppt die Wiedergabe
    func stop() {
        audioPlayer?.stop()
        audioPlayer = nil
    }

    /// Pausiert die Wiedergabe
    func pause() {
        audioPlayer?.pause()
    }

    /// Setzt die Wiedergabe fort
    func resume() {
        audioPlayer?.play()
    }

    /// Aktuelle Wiedergabezeit in Sekunden
    var currentTime: TimeInterval {
        audioPlayer?.currentTime ?? 0
    }

    /// Ist die Wiedergabe aktiv?
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
