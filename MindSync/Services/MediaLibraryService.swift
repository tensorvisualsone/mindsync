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

    /// Returns the asset URL if the item is analyzable, otherwise throws with a detailed reason.
    func assetURLForAnalysis(of item: MPMediaItem) async throws -> URL {
        // Accessing `MPMediaItem` properties must happen on the main actor
        let (assetURL, isCloudItem) = await MainActor.run { 
            (item.assetURL, item.isCloudItem) 
        }
        
        // Check if this is a cloud-only item (not downloaded)
        if isCloudItem && assetURL == nil {
            throw MediaLibraryValidationError.cloudItemNotDownloaded
        }
        
        guard let url = assetURL else {
            throw MediaLibraryValidationError.missingAsset
        }
        
        let asset = AVURLAsset(url: url)
        
        do {
            let isReadable = try await asset.load(.isReadable)
            guard isReadable else {
                throw MediaLibraryValidationError.unreadable
            }
            
            let hasProtectedContent = try await asset.load(.hasProtectedContent)
            if hasProtectedContent {
                throw MediaLibraryValidationError.drmProtected
            }
            
            return url
        } catch let validationError as MediaLibraryValidationError {
            throw validationError
        } catch let nsError as NSError {
            logger.error("Error checking analyzability: \(nsError.localizedDescription), domain: \(nsError.domain), code: \(nsError.code)")
            
            // Check for common AVFoundation errors
            if nsError.domain == AVFoundationErrorDomain {
                switch nsError.code {
                case AVError.contentIsProtected.rawValue:
                    throw MediaLibraryValidationError.drmProtected
                case AVError.fileFormatNotRecognized.rawValue:
                    throw MediaLibraryValidationError.unreadable
                default:
                    break
                }
            }
            
            // Check for file not found or permission issues
            if nsError.domain == NSCocoaErrorDomain {
                switch nsError.code {
                case NSFileReadNoSuchFileError, NSFileNoSuchFileError:
                    throw MediaLibraryValidationError.missingAsset
                case NSFileReadNoPermissionError:
                    throw MediaLibraryValidationError.unreadable
                default:
                    break
                }
            }
            
            throw MediaLibraryValidationError.unknown(nsError)
        }
    }
    
    /// Checks if an item can be analyzed (not DRM-protected)
    func canAnalyze(item: MPMediaItem) async -> Bool {
        do {
            _ = try await assetURLForAnalysis(of: item)
            return true
        } catch {
            return false
        }
    }
    
    /// Gets the asset URL for an item (without validation)
    /// Note: This method should be called from the main actor context
    func getAssetURL(for item: MPMediaItem) async -> URL? {
        await MainActor.run {
            item.assetURL
        }
    }
}

enum MediaLibraryValidationError: LocalizedError {
    case missingAsset
    case cloudItemNotDownloaded
    case drmProtected
    case unreadable
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .missingAsset:
            return NSLocalizedString("error.media.cloudItem", comment: "")
        case .cloudItemNotDownloaded:
            return NSLocalizedString("error.media.cloudItem", comment: "")
        case .drmProtected:
            return NSLocalizedString("error.drmProtected", comment: "")
        case .unreadable:
            return NSLocalizedString("error.media.unreadable", comment: "")
        case .unknown(let error):
            return String(format: NSLocalizedString("error.media.unknown", comment: ""), error.localizedDescription)
        }
    }
}
