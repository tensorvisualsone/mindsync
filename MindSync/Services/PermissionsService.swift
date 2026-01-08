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
            // Use the new iOS 17+ API directly
            if appPermission == AVAudioApplication.recordPermission.granted {
                return AVAudioSession.RecordPermission.granted
            } else if appPermission == AVAudioApplication.recordPermission.denied {
                return AVAudioSession.RecordPermission.denied
            } else {
                return AVAudioSession.RecordPermission.undetermined
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
                    // Use the new iOS 17+ API directly
                    if appPermission == AVAudioApplication.recordPermission.granted {
                        permission = AVAudioSession.RecordPermission.granted
                    } else if appPermission == AVAudioApplication.recordPermission.denied {
                        permission = AVAudioSession.RecordPermission.denied
                    } else {
                        permission = AVAudioSession.RecordPermission.undetermined
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
