import Foundation
import Combine
import MediaPlayer
import os.log

/// Main orchestrator for audio analysis
final class AudioAnalyzer {
    private let fileReader = AudioFileReader()
    private let beatDetector: BeatDetector?
    private let tempoEstimator = TempoEstimator()
    private let logger = Logger(subsystem: "com.mindsync", category: "AudioAnalyzer")
    
    private let analysisTimeout: TimeInterval = 18.0
    private let targetSampleRate: Double = 44_100.0
    private let fallbackWindowDuration: Double = 0.35
    private let minimumDetectedBeats = 4

    private var cancellables = Set<AnyCancellable>()
    private var isCancelled = false

    /// Progress publisher for UI updates
    let progressPublisher = PassthroughSubject<AnalysisProgress, Never>()
    
    init() {
        self.beatDetector = BeatDetector()
        logger.info("AudioAnalyzer initialized")
    }

    /// Analyzes a local audio track
    func analyze(url: URL, mediaItem: MPMediaItem) async throws -> AudioTrack {
        isCancelled = false
        let analysisStart = Date()
        
        let title = mediaItem.title ?? "Unknown"
        logger.info("Starting analysis for track: \(title, privacy: .public)")

        // Extract metadata
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
        try validateSamples(samples)
        try checkForTimeout(startDate: analysisStart)

        guard !isCancelled else {
            throw AudioAnalysisError.cancelled
        }
        
        let resolvedDuration = resolveDuration(
            metadataDuration: duration,
            sampleCount: samples.count,
            sampleRate: targetSampleRate
        )

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

        var beatTimestamps: [TimeInterval]
        if let beatDetector = beatDetector {
            beatTimestamps = await beatDetector.detectBeats(in: samples)
        } else {
            // Fallback: If BeatDetector initialization failed, return empty beat timestamps
            // This allows analysis to continue without beat detection
            beatTimestamps = []
        }
        var bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        if beatTimestamps.count < minimumDetectedBeats {
            let fallbackBeats = generateEnergyDrivenBeats(
                from: samples,
                windowDuration: fallbackWindowDuration,
                sampleRate: targetSampleRate,
                trackDuration: resolvedDuration
            )
            
            if !fallbackBeats.isEmpty {
                beatTimestamps = fallbackBeats
                bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
                logger.info("Energy-based beat fallback used for track: \(title, privacy: .public)")
            }
        }
        
        if beatTimestamps.count < 2 {
            let uniformBeats = generateUniformBeats(
                duration: resolvedDuration,
                bpm: bpm
            )
            if !uniformBeats.isEmpty {
                beatTimestamps = uniformBeats
            }
        }
        
        try checkForTimeout(startDate: analysisStart)

        guard !isCancelled else {
            logger.warning("Analysis cancelled for track: \(title, privacy: .public)")
            throw AudioAnalysisError.cancelled
        }

        // Progress: Complete
        progressPublisher.send(AnalysisProgress(
            phase: .complete,
            progress: 1.0,
            message: "Complete!"
        ))

        logger.info("Analysis complete for track: \(title, privacy: .public), BPM: \(bpm, privacy: .public), Beats: \(beatTimestamps.count, privacy: .public)")

        // Create AudioTrack
        return AudioTrack(
            title: title,
            artist: artist,
            albumTitle: albumTitle,
            duration: resolvedDuration,
            assetURL: url,
            bpm: bpm,
            beatTimestamps: beatTimestamps
        )
    }
    
    /// Cancels the running analysis
    func cancel() {
        isCancelled = true
        logger.info("Analysis cancellation requested")
    }
    
    // MARK: - Helpers
    
    private func checkForTimeout(startDate: Date) throws {
        let elapsed = Date().timeIntervalSince(startDate)
        if elapsed > analysisTimeout {
            logger.error("Analysis timeout after \(elapsed, privacy: .public) seconds")
            throw AudioAnalysisError.analysisTimeout
        }
    }
    
    private func validateSamples(_ samples: [Float]) throws {
        guard !samples.isEmpty else {
            throw AudioAnalysisError.corruptedData
        }
        
        if samples.contains(where: { !$0.isFinite }) {
            throw AudioAnalysisError.corruptedData
        }
    }
    
    private func resolveDuration(
        metadataDuration: TimeInterval,
        sampleCount: Int,
        sampleRate: Double
    ) -> TimeInterval {
        let waveformDuration = Double(sampleCount) / sampleRate
        if metadataDuration <= 0 {
            return waveformDuration
        }
        // Use the greater duration to avoid truncated scripts
        return max(metadataDuration, waveformDuration)
    }
    
    private func generateEnergyDrivenBeats(
        from samples: [Float],
        windowDuration: Double,
        sampleRate: Double,
        trackDuration: TimeInterval
    ) -> [TimeInterval] {
        let windowSize = max(1, Int(sampleRate * windowDuration))
        guard windowSize > 0, samples.count >= windowSize else {
            return []
        }
        
        var rmsValues: [Float] = []
        rmsValues.reserveCapacity(samples.count / windowSize)
        var index = 0
        
        while index < samples.count {
            let end = min(index + windowSize, samples.count)
            if end <= index {
                break
            }
            var sum: Float = 0
            for sample in samples[index..<end] {
                sum += sample * sample
            }
            let frameCount = max(1, end - index)
            let rms = sqrt(sum / Float(frameCount))
            rmsValues.append(rms)
            index = end
        }
        
        guard let maxEnergy = rmsValues.max(), maxEnergy > 0 else {
            return []
        }
        
        let normalized = rmsValues.map { Double($0 / maxEnergy) }
        let meanEnergy = normalized.reduce(0, +) / Double(normalized.count)
        let dynamicThreshold = min(0.85, max(0.45, meanEnergy + 0.2))
        var timestamps: [TimeInterval] = []
        
        for idx in normalized.indices {
            let current = normalized[idx]
            guard current >= dynamicThreshold else { continue }
            let prev = idx > 0 ? normalized[idx - 1] : 0
            let next = idx + 1 < normalized.count ? normalized[idx + 1] : 0
            if current >= prev && current >= next {
                let timestamp = Double(idx) * windowDuration
                if timestamp <= trackDuration {
                    timestamps.append(timestamp)
                }
            }
        }
        
        // Prevent runaway arrays on extremely long tracks
        let maxBeats = 5000
        if timestamps.count > maxBeats {
            return Array(timestamps.prefix(maxBeats))
        }
        return timestamps
    }
    
    private func generateUniformBeats(duration: TimeInterval, bpm: Double) -> [TimeInterval] {
        guard duration > 0 else { return [] }
        
        let sanitizedBPM = max(30, min(200, bpm))
        let interval = 60.0 / sanitizedBPM
        guard interval > 0 else { return [] }
        let beatCount = min(5000, Int(duration / interval))
        guard beatCount > 0 else { return [] }
        
        return (0..<beatCount).map { Double($0) * interval }
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
