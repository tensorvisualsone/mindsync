import Foundation
import AVFoundation
import MediaPlayer

/// Service für Berechtigungs-Prüfung
final class PermissionsService {
    /// Mikrofon-Berechtigung
    var microphoneStatus: AVAudioSession.RecordPermission {
        AVAudioSession.sharedInstance().recordPermission
    }

    /// Musikbibliothek-Berechtigung
    var mediaLibraryStatus: MPMediaLibraryAuthorizationStatus {
        MPMediaLibrary.authorizationStatus()
    }

    /// Fordert Mikrofon-Berechtigung an
    func requestMicrophoneAccess() async -> Bool {
        await AVAudioSession.sharedInstance().requestRecordPermission()
    }

    /// Fordert Musikbibliothek-Berechtigung an
    func requestMediaLibraryAccess() async -> MPMediaLibraryAuthorizationStatus {
        await MPMediaLibrary.requestAuthorization()
    }
}
