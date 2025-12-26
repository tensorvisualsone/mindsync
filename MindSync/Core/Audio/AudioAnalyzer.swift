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
    
    /// Upper bound for a single analysis run.
    ///
    /// We intentionally use a fixed timeout instead of scaling directly with track length:
    /// - The analysis operates on downsampled PCM windows and is dominated by FFTs over
    ///   fixed-size buffers, so runtime grows sublinearly with the original track duration.
    /// - For the current pipeline and maximum supported track duration (~30 minutes),
    ///   18 seconds provides a conservative upper bound on iOS 17+ devices while keeping
    ///   the user-visible wait time acceptable.
    /// - If analysis complexity changes (e.g. more passes or higher-resolution windows),
    ///   revisit this constant and consider a timeout that scales with `MPMediaItem.playbackDuration`.
    private let analysisTimeout: TimeInterval = 18.0
    private let targetSampleRate: Double = 44_100.0
    private let fallbackWindowDuration: Double = 0.35
    private let minimumDetectedBeats = 4

    private var cancellables = Set<AnyCancellable>()
    private var isCancelled = false
    
    /// Cache directory for analyzed tracks
    private lazy var cacheDirectory: URL = {
        let paths = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        let baseCacheDir = paths[0]
        let cacheDir = baseCacheDir.appendingPathComponent("AudioAnalysisCache")
        do {
            try FileManager.default.createDirectory(at: cacheDir,
                                                    withIntermediateDirectories: true,
                                                    attributes: nil)
            return cacheDir
        } catch {
            logger.error("Failed to create cache directory at \(cacheDir.path, privacy: .public): \(String(describing: error), privacy: .public)")
            // Fallback: use the base caches directory to avoid silent cache failures
            return baseCacheDir
        }
    }()

    /// Progress publisher for UI updates
    let progressPublisher = PassthroughSubject<AnalysisProgress, Never>()
    
    init() {
        self.beatDetector = BeatDetector()
        logger.info("AudioAnalyzer initialized")
    }

    /// Analyzes a local audio track
    func analyze(url: URL, mediaItem: MPMediaItem) async throws -> AudioTrack {
        isCancelled = false
        
        // Check cache first
        if let cachedTrack = loadFromCache(for: mediaItem) {
            logger.info("Using cached analysis for track: \(mediaItem.title ?? "Unknown", privacy: .public)")
            // Return copy with current assetURL as the path might have changed
            return AudioTrack(
                id: cachedTrack.id,
                title: cachedTrack.title,
                artist: cachedTrack.artist,
                albumTitle: cachedTrack.albumTitle,
                duration: cachedTrack.duration,
                assetURL: url, // Use current URL
                bpm: cachedTrack.bpm,
                beatTimestamps: cachedTrack.beatTimestamps,
                rmsEnvelope: cachedTrack.rmsEnvelope,
                spectralCentroid: cachedTrack.spectralCentroid,
                analyzedAt: cachedTrack.analyzedAt,
                analysisVersion: cachedTrack.analysisVersion
            )
        }
        
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
            let isValidBPM = bpm.isFinite && bpm > 0
            
            if isValidBPM {
                let uniformBeats = generateUniformBeats(
                    duration: resolvedDuration,
                    bpm: bpm
                )
                if !uniformBeats.isEmpty {
                    beatTimestamps = uniformBeats
                    logger.info("Uniform beat fallback used for track: \(title, privacy: .public) with BPM: \(bpm, privacy: .public)")
                }
            } else {
                logger.info("Skipping uniform beat fallback for track: \(title, privacy: .public) due to invalid BPM estimate: \(bpm, privacy: .public)")
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
        let track = AudioTrack(
            title: title,
            artist: artist,
            albumTitle: albumTitle,
            duration: resolvedDuration,
            assetURL: url,
            bpm: bpm,
            beatTimestamps: beatTimestamps
        )
        
        // Save to cache
        saveToCache(track, for: mediaItem)
        
        return track
    }
    
    /// Cancels the running analysis
    func cancel() {
        isCancelled = true
        logger.info("Analysis cancellation requested")
    }
    
    // MARK: - Caching
    
    private func getCacheURL(for persistentID: MPMediaEntityPersistentID) -> URL {
        return cacheDirectory.appendingPathComponent("\(persistentID).json")
    }
    
    private func saveToCache(_ track: AudioTrack, for mediaItem: MPMediaItem) {
        let cacheURL = getCacheURL(for: mediaItem.persistentID)
        do {
            let data = try JSONEncoder().encode(track)
            try data.write(to: cacheURL)
        } catch {
            logger.error("Failed to cache audio track: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func loadFromCache(for mediaItem: MPMediaItem) -> AudioTrack? {
        let cacheURL = getCacheURL(for: mediaItem.persistentID)
        guard FileManager.default.fileExists(atPath: cacheURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: cacheURL)
            let track = try JSONDecoder().decode(AudioTrack.self, from: data)
            
            // Check version if AudioTrack changes in future
            guard track.analysisVersion == "1.0" else {
                return nil
            }
            
            return track
        } catch {
            logger.error("Failed to load cached track: \(error.localizedDescription, privacy: .public)")
            return nil
        }
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
        
        // Use the greater duration to avoid truncated scripts, but log if there's
        // a significant discrepancy between metadata and waveform durations.
        let maxDuration = max(metadataDuration, waveformDuration)
        let minDuration = min(metadataDuration, waveformDuration)
        
        if maxDuration > 0 {
            let relativeDifference = (maxDuration - minDuration) / maxDuration
            
            if relativeDifference > 0.05 {
                let percentDifference = relativeDifference * 100
                logger.warning("Significant duration discrepancy: metadata=\(metadataDuration, privacy: .public, format: .fixed(precision: 3))s, waveform=\(waveformDuration, privacy: .public, format: .fixed(precision: 3))s, difference=\(percentDifference, privacy: .public, format: .fixed(precision: 2))%")
            }
        }
        
        return maxDuration
    }
    
    /// Generates beats based on audio energy analysis.
    ///
    /// This method implements a dynamic thresholding algorithm to detect beats in the audio signal.
    /// It calculates the Root Mean Square (RMS) energy for sliding windows of the audio samples
    /// and identifies peaks that exceed a dynamic threshold based on the local mean energy.
    ///
    /// - Parameters:
    ///   - samples: The raw audio samples (mono).
    ///   - windowDuration: The duration of the analysis window in seconds (typically 0.35s).
    ///   - sampleRate: The sample rate of the audio data.
    ///   - trackDuration: The total duration of the track to ensure timestamps are within bounds.
    /// - Returns: An array of timestamps (in seconds) representing detected beats.
    ///            The array is capped at 5000 beats to prevent memory issues.
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
        
        // Log when BPM is clamped to inform debugging
        if sanitizedBPM != bpm {
            logger.warning("BPM \(bpm, privacy: .public) is outside valid range (30-200), clamping to \(sanitizedBPM, privacy: .public)")
        }
        
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
