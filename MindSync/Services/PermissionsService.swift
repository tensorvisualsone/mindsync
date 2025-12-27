import Foundation
import MediaPlayer

/// Service for permission checking
final class PermissionsService {
    /// Music library permission
    var mediaLibraryStatus: MPMediaLibraryAuthorizationStatus {
        MPMediaLibrary.authorizationStatus()
    }

    /// Requests music library permission
    func requestMediaLibraryAccess() async -> MPMediaLibraryAuthorizationStatus {
        await MPMediaLibrary.requestAuthorization()
    }
}
