import Foundation
import Combine
import MediaPlayer

/// Main orchestrator for audio analysis
final class AudioAnalyzer {
    private let fileReader = AudioFileReader()
    private let beatDetector: BeatDetector?
    private let tempoEstimator = TempoEstimator()

    private var cancellables = Set<AnyCancellable>()
    private var isCancelled = false

    /// Progress publisher for UI updates
    let progressPublisher = PassthroughSubject<AnalysisProgress, Never>()
    
    init() {
        self.beatDetector = BeatDetector()
    }

    /// Analyzes a local audio track
    func analyze(url: URL, mediaItem: MPMediaItem) async throws -> AudioTrack {
        isCancelled = false

        // Extract metadata
        let title = mediaItem.title ?? "Unknown"
        let artist = mediaItem.artist
        let albumTitle = mediaItem.albumTitle
        let duration = mediaItem.playbackDuration

        // Progress: Load audio
        progressPublisher.send(AnalysisProgress(
            phase: .loading,
            progress: 0.1,
            message: "Loading audio..."
        ))

        // Read PCM data
        progressPublisher.send(AnalysisProgress(
            phase: .extracting,
            progress: 0.3,
            message: "Extracting PCM data..."
        ))

        let samples = try await fileReader.readPCM(from: url)

        guard !isCancelled else {
            throw AudioAnalysisError.cancelled
        }

        // Progress: Analyze frequencies
        progressPublisher.send(AnalysisProgress(
            phase: .analyzing,
            progress: 0.6,
            message: "Analyzing frequencies..."
        ))

        // Beat detection
        progressPublisher.send(AnalysisProgress(
            phase: .detecting,
            progress: 0.8,
            message: "Detecting beats..."
        ))

        let beatTimestamps: [TimeInterval]
        if let beatDetector = beatDetector {
            beatTimestamps = await beatDetector.detectBeats(in: samples)
        } else {
            // Fallback: If BeatDetector initialization failed, return empty beat timestamps
            // This allows analysis to continue without beat detection
            beatTimestamps = []
        }
        let bpm = tempoEstimator.estimateBPM(from: beatTimestamps)

        guard !isCancelled else {
            throw AudioAnalysisError.cancelled
        }

        // Progress: Complete
        progressPublisher.send(AnalysisProgress(
            phase: .complete,
            progress: 1.0,
            message: "Complete!"
        ))

        // Create AudioTrack
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

    /// Cancels the running analysis
    func cancel() {
        isCancelled = true
    }
}

/// Audio analysis progress
struct AnalysisProgress {
    let phase: Phase
    let progress: Double  // 0.0 - 1.0
    let message: String

    enum Phase: String {
        case loading = "Loading audio..."
        case extracting = "Extracting PCM data..."
        case analyzing = "Analyzing frequencies..."
        case detecting = "Detecting beats..."
        case mapping = "Creating LightScript..."
        case complete = "Complete!"
    }
}
