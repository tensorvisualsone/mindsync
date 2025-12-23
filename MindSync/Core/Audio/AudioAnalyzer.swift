import Foundation
import Combine
import MediaPlayer

/// Haupt-Orchestrator für Audio-Analyse
final class AudioAnalyzer {
    private let fileReader = AudioFileReader()
    private let beatDetector = BeatDetector()
    private let tempoEstimator = TempoEstimator()

    private var cancellables = Set<AnyCancellable>()
    private var isCancelled = false

    /// Fortschritts-Publisher für UI-Updates
    let progressPublisher = PassthroughSubject<AnalysisProgress, Never>()

    /// Analysiert einen lokalen Audio-Track
    func analyze(url: URL, mediaItem: MPMediaItem) async throws -> AudioTrack {
        isCancelled = false

        // Metadaten extrahieren
        let title = mediaItem.title ?? "Unbekannt"
        let artist = mediaItem.artist
        let albumTitle = mediaItem.albumTitle
        let duration = mediaItem.playbackDuration

        // Fortschritt: Lade Audio
        progressPublisher.send(AnalysisProgress(
            phase: .loading,
            progress: 0.1,
            message: "Lade Audio..."
        ))

        // PCM-Daten lesen
        progressPublisher.send(AnalysisProgress(
            phase: .extracting,
            progress: 0.3,
            message: "Extrahiere PCM-Daten..."
        ))

        let samples = try await fileReader.readPCM(from: url)

        guard !isCancelled else {
            throw AudioAnalysisError.cancelled
        }

        // Fortschritt: Analysiere Frequenzen
        progressPublisher.send(AnalysisProgress(
            phase: .analyzing,
            progress: 0.6,
            message: "Analysiere Frequenzen..."
        ))

        // Beat-Detection
        progressPublisher.send(AnalysisProgress(
            phase: .detecting,
            progress: 0.8,
            message: "Erkenne Beats..."
        ))

        let beatTimestamps = await beatDetector.detectBeats(in: samples)
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)

        guard !isCancelled else {
            throw AudioAnalysisError.cancelled
        }

        // Fortschritt: Fertig
        progressPublisher.send(AnalysisProgress(
            phase: .complete,
            progress: 1.0,
            message: "Fertig!"
        ))

        // AudioTrack erstellen
        return AudioTrack(
            title: title,
            artist: artist,
            albumTitle: albumTitle,
            duration: duration,
            assetURL: url,
            bpm: bpm,
            beatTimestamps: beatTimestamps
        )
    }

    /// Bricht die laufende Analyse ab
    func cancel() {
        isCancelled = true
    }
}

/// Fortschritt der Audio-Analyse
struct AnalysisProgress {
    let phase: Phase
    let progress: Double  // 0.0 - 1.0
    let message: String

    enum Phase: String {
        case loading = "Lade Audio..."
        case extracting = "Extrahiere PCM-Daten..."
        case analyzing = "Analysiere Frequenzen..."
        case detecting = "Erkenne Beats..."
        case mapping = "Erstelle LightScript..."
        case complete = "Fertig!"
    }
}
