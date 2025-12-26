import Foundation
import MediaPlayer
import AVFoundation
import os.log

/// Service for accessing the music library
final class MediaLibraryService {
    private let logger = Logger(subsystem: "com.mindsync", category: "MediaLibraryService")

    var authorizationStatus: MPMediaLibraryAuthorizationStatus {
        MPMediaLibrary.authorizationStatus()
    }

    /// Requests permission for music library
    func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus {
        await MPMediaLibrary.requestAuthorization()
    }

    /// Checks if an item can be analyzed (not DRM-protected)
    func canAnalyze(item: MPMediaItem) async -> Bool {
        // Accessing `MPMediaItem` properties must happen on the main thread.
        // Read the `assetURL` on the MainActor, then perform async AVAsset work off-main.
        let assetURL = await MainActor.run { item.assetURL }
        
        // If assetURL is nil, the item is likely a cloud item that hasn't been downloaded
        // or is DRM-protected. We cannot analyze items without a local asset URL.
        guard let url = assetURL else {
            return false
        }

        let asset = AVURLAsset(url: url)

        do {
            // First check if the asset is readable (this is faster than checking DRM)
            let isReadable = try await asset.load(.isReadable)
            guard isReadable else {
                return false
            }
            
            // Then check for DRM protection
            let hasProtectedContent = try await asset.load(.hasProtectedContent)
            if hasProtectedContent {
                return false
            }

            // Item is readable and not DRM-protected
            return true
        } catch {
            // If loading properties fails, we cannot determine if it's analyzable
            // Log the error for debugging but return false to be safe
            logger.error("Error checking analyzability: \(error.localizedDescription)")
            return false
        }
    }

    /// Gets the asset URL for an item
    func getAssetURL(for item: MPMediaItem) -> URL? {
        item.assetURL
    }
}
