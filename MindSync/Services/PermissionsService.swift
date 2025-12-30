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
            case .undetermined:
                return .undetermined
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
                AVAudioApplication.requestRecordPermission { _ in
                    // After the system dialog completes, re-query the actual permission status
                    // to handle cases where the user dismisses without choosing
                    let appPermission = AVAudioApplication.shared.recordPermission
                    let permission: AVAudioSession.RecordPermission
                    switch appPermission {
                    case .granted:
                        permission = .granted
                    case .denied:
                        permission = .denied
                    case .undetermined:
                        permission = .undetermined
                    @unknown default:
                        permission = .undetermined
                    }
                    continuation.resume(returning: permission)
                }
            }
        } else {
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { _ in
                    // After the system dialog completes, re-query the actual permission status
                    let currentPermission = AVAudioSession.sharedInstance().recordPermission
                    continuation.resume(returning: currentPermission)
                }
            }
        }
    }
}
