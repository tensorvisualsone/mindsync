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
    func canAnalyze(item: MPMediaItem) async -> Bool {
        guard let url = item.assetURL else { return false }
        let asset = AVURLAsset(url: url)
        
        do {
            // DRM-protected content cannot be analyzed
            let hasProtectedContent = try await asset.load(.hasProtectedContent)
            if hasProtectedContent {
                return false
            }
            
            // For unprotected content, check if the asset is readable
            let isReadable = try await asset.load(.isReadable)
            return isReadable
        } catch {
            // If loading properties fails, assume the item cannot be analyzed
            return false
        }
    }

    /// Gets the asset URL for an item
    func getAssetURL(for item: MPMediaItem) -> URL? {
        item.assetURL
    }
}
