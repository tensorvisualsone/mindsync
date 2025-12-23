import Foundation
import MediaPlayer
import AVFoundation

/// Service für Zugriff auf die Musikbibliothek
final class MediaLibraryService {
    var authorizationStatus: MPMediaLibraryAuthorizationStatus {
        MPMediaLibrary.authorizationStatus()
    }

    /// Fordert Berechtigung für Musikbibliothek an
    func requestAuthorization() async -> MPMediaLibraryAuthorizationStatus {
        await MPMediaLibrary.requestAuthorization()
    }

    /// Prüft ob ein Item analysierbar ist (nicht DRM-geschützt)
    func canAnalyze(item: MPMediaItem) -> Bool {
        guard let url = item.assetURL else { return false }
        let asset = AVAsset(url: url)
        
        // DRM-geschützte Inhalte können nicht analysiert werden
        if asset.hasProtectedContent {
            return false
        }
        
        // Für nicht geschützte Inhalte prüfen, ob das Asset lesbar ist
        return asset.isReadable
    }

    /// Holt die Asset-URL für ein Item
    func getAssetURL(for item: MPMediaItem) -> URL? {
        item.assetURL
    }
}
