import Foundation

extension String {
    /// Removes the ".mp3" extension from a filename if present.
    /// Used when loading audio files from the bundle, which requires the resource name without extension.
    ///
    /// Example:
    /// ```swift
    /// "alpha_audio.mp3".withoutMP3Extension // "alpha_audio"
    /// "alpha_audio".withoutMP3Extension     // "alpha_audio"
    /// ```
    var withoutMP3Extension: String {
        replacingOccurrences(of: ".mp3", with: "")
    }
}
