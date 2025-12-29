import Foundation
import MediaPlayer
import AVFoundation

/// Service for permission checking
final class PermissionsService {
    /// Music library permission
    var mediaLibraryStatus: MPMediaLibraryAuthorizationStatus {
        MPMediaLibrary.authorizationStatus()
    }

    /// Microphone permission status
    var microphoneStatus: AVAudioSession.RecordPermission {
        AVAudioSession.sharedInstance().recordPermission
    }

    /// Requests music library permission
    func requestMediaLibraryAccess() async -> MPMediaLibraryAuthorizationStatus {
        await MPMediaLibrary.requestAuthorization()
    }

    /// Requests microphone permission
    func requestMicrophoneAccess() async -> AVAudioSession.RecordPermission {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                // Map the callback parameter directly instead of re-querying
                let permission: AVAudioSession.RecordPermission = granted ? .granted : .denied
                continuation.resume(returning: permission)
            }
        }
    }
}
