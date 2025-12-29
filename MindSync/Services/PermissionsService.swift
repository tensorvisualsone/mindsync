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
    /// Uses AVAudioApplication API on iOS 17+ for better type safety
    var microphoneStatus: AVAudioSession.RecordPermission {
        if #available(iOS 17.0, *) {
            // Convert AVAudioApplication.recordPermission to AVAudioSession.RecordPermission
            let appPermission = AVAudioApplication.shared.recordPermission
            switch appPermission {
            case .granted:
                return .granted
            case .denied:
                return .denied
            @unknown default:
                return .undetermined
            }
        } else {
            return AVAudioSession.sharedInstance().recordPermission
        }
    }

    /// Requests music library permission
    func requestMediaLibraryAccess() async -> MPMediaLibraryAuthorizationStatus {
        await MPMediaLibrary.requestAuthorization()
    }

    /// Requests microphone permission
    /// Uses AVAudioApplication API on iOS 17+ for better type safety
    func requestMicrophoneAccess() async -> AVAudioSession.RecordPermission {
        if #available(iOS 17.0, *) {
            return await withCheckedContinuation { continuation in
                AVAudioApplication.requestRecordPermission { granted in
                    // Map the callback parameter directly
                    let permission: AVAudioSession.RecordPermission = granted ? .granted : .denied
                    continuation.resume(returning: permission)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    // Map the callback parameter directly instead of re-querying
                    let permission: AVAudioSession.RecordPermission = granted ? .granted : .denied
                    continuation.resume(returning: permission)
                }
            }
        }
    }
}
