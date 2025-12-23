import Foundation
import MediaPlayer
import AVFoundation

/// Service for accessing the music library
final class MediaLibraryService {
    var authorizationStatus: MPMediaLibraryAuthorizationStatus {
        MPMediaLibrary.authorizationStatus()
    }

    /// Requests permission for music library
    func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus {
        await MPMediaLibrary.requestAuthorization()
    }

    /// Checks if an item can be analyzed (not DRM-protected)
    func canAnalyze(item: MPMediaItem) -> Bool {
        guard let url = item.assetURL else { return false }
        let asset = AVAsset(url: url)
        
        // DRM-protected content cannot be analyzed
        if asset.hasProtectedContent {
            return false
        }
        
        // For unprotected content, check if the asset is readable
        return asset.isReadable
    }

    /// Gets the asset URL for an item
    func getAssetURL(for item: MPMediaItem) -> URL? {
        item.assetURL
    }
}
