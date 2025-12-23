import Foundation

/// Ein analysierter Audio-Track mit extrahierten Features
struct AudioTrack: Codable, Identifiable {
    let id: UUID

    // Metadaten (aus MPMediaItem)
    let title: String
    let artist: String?
    let albumTitle: String?
    let duration: TimeInterval  // Sekunden
    let assetURL: URL?          // Nur für lokale Dateien

    // Analyse-Ergebnisse
    let bpm: Double
    let beatTimestamps: [TimeInterval]  // Sekunden seit Start
    let rmsEnvelope: [Float]?           // Optional: Lautstärke-Kurve
    let spectralCentroid: [Float]?      // Optional: Helligkeit/Timbre

    // Analyse-Status
    let analyzedAt: Date
    let analysisVersion: String  // Für Cache-Invalidierung

    init(
        id: UUID = UUID(),
        title: String,
        artist: String? = nil,
        albumTitle: String? = nil,
        duration: TimeInterval,
        assetURL: URL? = nil,
        bpm: Double,
        beatTimestamps: [TimeInterval],
        rmsEnvelope: [Float]? = nil,
        spectralCentroid: [Float]? = nil,
        analyzedAt: Date = Date(),
        analysisVersion: String = "1.0"
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.albumTitle = albumTitle
        self.duration = duration
        self.assetURL = assetURL
        self.bpm = bpm
        self.beatTimestamps = beatTimestamps
        self.rmsEnvelope = rmsEnvelope
        self.spectralCentroid = spectralCentroid
        self.analyzedAt = analyzedAt
        self.analysisVersion = analysisVersion
    }

    /// Formatierte Dauer (z.B. "3:45")
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Anzahl der erkannten Beats
    var beatCount: Int { beatTimestamps.count }
}
