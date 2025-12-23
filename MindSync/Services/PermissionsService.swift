import Foundation
import AVFoundation
import MediaPlayer

/// Service for permission checking
final class PermissionsService {
    /// Microphone permission status
    var microphoneStatus: AVAudioApplication.RecordPermission {
        AVAudioApplication.shared.recordPermission
    }
    
    /// Whether microphone access is granted
    var hasMicrophoneAccess: Bool {
        microphoneStatus == .granted
    }

    /// Music library permission
    var mediaLibraryStatus: MPMediaLibraryAuthorizationStatus {
        MPMediaLibrary.authorizationStatus()
    }

    /// Requests microphone permission
    func requestMicrophoneAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Requests music library permission
    func requestMediaLibraryAccess() async -> MPMediaLibraryAuthorizationStatus {
        await MPMediaLibrary.requestAuthorization()
    }
}
