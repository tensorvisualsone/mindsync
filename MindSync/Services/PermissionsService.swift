import Foundation
import AVFoundation
import MediaPlayer

/// Microphone permission status
enum MicrophonePermissionStatus {
    case undetermined
    case denied
    case granted
}

/// Service for permission checking
final class PermissionsService {
    /// Microphone permission status
    var microphoneStatus: MicrophonePermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .undetermined:
            return .undetermined
        case .denied:
            return .denied
        case .granted:
            return .granted
        @unknown default:
            return .denied
        }
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
        await AVAudioApplication.requestRecordPermission()
    }

    /// Requests music library permission
    func requestMediaLibraryAccess() async -> MPMediaLibraryAuthorizationStatus {
        await MPMediaLibrary.requestAuthorization()
    }
}
