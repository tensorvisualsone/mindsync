import Foundation
import AVFoundation
import MediaPlayer

/// Service for permission checking
final class PermissionsService {
    /// Microphone permission
    var microphoneStatus: AVAudioSession.RecordPermission {
        AVAudioSession.sharedInstance().recordPermission
    }

    /// Music library permission
    var mediaLibraryStatus: MPMediaLibraryAuthorizationStatus {
        MPMediaLibrary.authorizationStatus()
    }

    /// Requests microphone permission
    func requestMicrophoneAccess() async -> Bool {
        await AVAudioSession.sharedInstance().requestRecordPermission()
    }

    /// Requests music library permission
    func requestMediaLibraryAccess() async -> MPMediaLibraryAuthorizationStatus {
        await MPMediaLibrary.requestAuthorization()
    }
}
