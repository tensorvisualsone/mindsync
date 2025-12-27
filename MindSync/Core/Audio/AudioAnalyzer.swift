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
    
    /// Base timeout per minute of track duration (in seconds per minute).
    /// Runtime grows approximately linearly with track duration.
    /// Typical analysis time: ~10-15 seconds per minute of audio.
    /// Set to 18 seconds per minute to provide buffer for slower devices.
    private let timeoutPerMinute: TimeInterval = 18.0
    
    /// Maximum timeout cap to prevent excessive wait times even for very long tracks.
    /// Long tracks (>10 min) use quick analysis mode for faster results.
    private let maxTimeout: TimeInterval = 60.0
    
    /// Minimum timeout to ensure short tracks have reasonable analysis time.
    private let minTimeout: TimeInterval = 10.0
    
    /// Track duration threshold (in minutes) for automatic quick analysis mode.
    /// Tracks longer than this will automatically use quick analysis for faster results.
    private let autoQuickAnalysisThresholdMinutes: Double = 10.0
    
    /// Warning thresholds as percentages of timeout (for user notifications).
    private let warningThreshold50: Double = 0.5
    private let warningThreshold75: Double = 0.75
    
    /// Context for a single analysis operation to ensure thread-safety.
    /// All mutable state is kept local to each analyze() call.
    private struct AnalysisContext {
        var warning50Shown: Bool = false
        var warning75Shown: Bool = false
        let quickAnalysisMode: Bool
        let isCancelled: Bool
        
        init(quickAnalysisMode: Bool, isCancelled: Bool = false) {
            self.quickAnalysisMode = quickAnalysisMode
            self.isCancelled = isCancelled
        }
    }
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

    /// Calculates dynamic timeout based on track duration.
    /// Formula: (duration in minutes) * timeoutPerMinute
    /// Uses linear scaling with min/max bounds for better UX.
    /// For very long tracks (>10 minutes), timeout is capped at maxTimeout.
    private func calculateTimeout(for duration: TimeInterval) -> TimeInterval {
        let durationMinutes = duration / 60.0
        let calculatedTimeout = durationMinutes * timeoutPerMinute
        return max(minTimeout, min(maxTimeout, calculatedTimeout))
    }
    
    /// Determines if quick analysis should be used automatically for long tracks.
    private func shouldUseAutoQuickAnalysis(for duration: TimeInterval) -> Bool {
        let durationMinutes = duration / 60.0
        return durationMinutes > autoQuickAnalysisThresholdMinutes
    }
    
    /// Analyzes a local audio track
    func analyze(url: URL, mediaItem: MPMediaItem, quickMode: Bool = false) async throws -> AudioTrack {
        // Reset cancellation flag for this analysis
        isCancelled = false
        
        // Create analysis context with local state to ensure thread-safety
        // Each analyze() call has its own context, preventing race conditions
        var context = AnalysisContext(quickAnalysisMode: quickMode)
        
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
        
        // Extract metadata
        let artist = mediaItem.artist
        let albumTitle = mediaItem.albumTitle
        let duration = mediaItem.playbackDuration
        
        // Auto-enable quick analysis for long tracks if not explicitly disabled
        let effectiveQuickMode = quickMode || shouldUseAutoQuickAnalysis(for: duration)
        context = AnalysisContext(quickAnalysisMode: effectiveQuickMode)
        
        if effectiveQuickMode && !quickMode {
            logger.info("Auto-enabling quick analysis for long track: \(title, privacy: .public) (duration: \(duration / 60.0, privacy: .public) minutes)")
        }
        logger.info("Starting analysis for track: \(title, privacy: .public) (quickMode: \(effectiveQuickMode, privacy: .public))")

        // Calculate dynamic timeout based on track duration
        let analysisTimeout = calculateTimeout(for: duration)
        logger.info("Analysis timeout set to \(analysisTimeout, privacy: .public) seconds for track duration \(duration, privacy: .public) seconds")

        // Progress: Load audio
        progressPublisher.send(AnalysisProgress(
            phase: .loading,
            progress: 0.1,
            message: "Loading audio..."
        ))

        // Read PCM data with progress updates
        progressPublisher.send(AnalysisProgress(
            phase: .extracting,
            progress: 0.3,
            message: "Extracting PCM data..."
        ))

        let samples = try await fileReader.readPCM(from: url)
        try validateSamples(samples)
        
        // Progress update after PCM extraction
        progressPublisher.send(AnalysisProgress(
            phase: .extracting,
            progress: 0.4,
            message: "Extracting PCM data..."
        ))
        
        try checkForTimeout(startDate: analysisStart, timeout: analysisTimeout, context: &context)

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
            // In quick mode, bypass the expensive full beat detector and use simpler energy-based detection
            // This trades granularity/accuracy for performance (main speed gain)
            if context.quickAnalysisMode {
                // Use energy-based detection to avoid the full BeatDetector pipeline
                // Larger window (1.5x) reduces granularity/stability but improves processing speed
                beatTimestamps = generateEnergyDrivenBeats(
                    from: samples,
                    windowDuration: fallbackWindowDuration * 1.5,
                    sampleRate: targetSampleRate,
                    trackDuration: resolvedDuration
                )
                logger.info("Quick analysis: Using energy-based beat detection")
            } else {
                beatTimestamps = await beatDetector.detectBeats(in: samples)
            }
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
            
            // Only use fallback if it provides a reasonable number of beats
            // and more than what we already found
            if !fallbackBeats.isEmpty && fallbackBeats.count > beatTimestamps.count {
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
        
        try checkForTimeout(startDate: analysisStart, timeout: analysisTimeout, context: &context)

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
    
    /// Analyzes a local audio file directly from URL (no caching)
    /// Used for files selected via Document Picker
    func analyze(url: URL, title: String? = nil, artist: String? = nil, quickMode: Bool = false) async throws -> AudioTrack {
        // Reset cancellation flag for this analysis
        isCancelled = false
        
        // Create analysis context with local state to ensure thread-safety
        var context = AnalysisContext(quickAnalysisMode: quickMode)
        
        let analysisStart = Date()
        
        let resolvedTitle = title ?? url.deletingPathExtension().lastPathComponent

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
        
        // Calculate duration from samples since we don't have metadata
        let duration = Double(samples.count) / targetSampleRate
        
        // Auto-enable quick analysis for long tracks if not explicitly disabled
        let effectiveQuickMode = quickMode || shouldUseAutoQuickAnalysis(for: duration)
        context = AnalysisContext(quickAnalysisMode: effectiveQuickMode)
        
        if effectiveQuickMode && !quickMode {
            logger.info("Auto-enabling quick analysis for long file: \(resolvedTitle, privacy: .public) (duration: \(duration / 60.0, privacy: .public) minutes)")
        }
        logger.info("Starting analysis for file: \(resolvedTitle, privacy: .public) (quickMode: \(effectiveQuickMode, privacy: .public))")
        
        // Calculate dynamic timeout based on track duration
        let analysisTimeout = calculateTimeout(for: duration)
        logger.info("Analysis timeout set to \(analysisTimeout, privacy: .public) seconds for track duration \(duration, privacy: .public) seconds")
        
        try checkForTimeout(startDate: analysisStart, timeout: analysisTimeout, context: &context)

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

        var beatTimestamps: [TimeInterval]
        if let beatDetector = beatDetector {
            // In quick mode, bypass the expensive full beat detector and use simpler energy-based detection
            // This trades granularity/accuracy for performance (main speed gain)
            if context.quickAnalysisMode {
                // Use energy-based detection to avoid the full BeatDetector pipeline
                // Larger window (1.5x) reduces granularity/stability but improves processing speed
                beatTimestamps = generateEnergyDrivenBeats(
                    from: samples,
                    windowDuration: fallbackWindowDuration * 1.5,
                    sampleRate: targetSampleRate,
                    trackDuration: duration
                )
                logger.info("Quick analysis: Using energy-based beat detection")
            } else {
                beatTimestamps = await beatDetector.detectBeats(in: samples)
            }
        } else {
            beatTimestamps = []
        }
        var bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
        
        if beatTimestamps.count < minimumDetectedBeats {
            let fallbackBeats = generateEnergyDrivenBeats(
                from: samples,
                windowDuration: fallbackWindowDuration,
                sampleRate: targetSampleRate,
                trackDuration: duration
            )
            
            if !fallbackBeats.isEmpty && fallbackBeats.count > beatTimestamps.count {
                beatTimestamps = fallbackBeats
                bpm = tempoEstimator.estimateBPM(from: beatTimestamps)
                logger.info("Energy-based beat fallback used for file: \(resolvedTitle, privacy: .public)")
            }
        }
        
        if beatTimestamps.count < 2 {
            let isValidBPM = bpm.isFinite && bpm > 0
            
            if isValidBPM {
                let uniformBeats = generateUniformBeats(
                    duration: duration,
                    bpm: bpm
                )
                if !uniformBeats.isEmpty {
                    beatTimestamps = uniformBeats
                    logger.info("Uniform beat fallback used for file: \(resolvedTitle, privacy: .public) with BPM: \(bpm, privacy: .public)")
                }
            }
        }
        
        try checkForTimeout(startDate: analysisStart, timeout: analysisTimeout, context: &context)

        guard !isCancelled else {
            logger.warning("Analysis cancelled for file: \(resolvedTitle, privacy: .public)")
            throw AudioAnalysisError.cancelled
        }

        // Progress: Complete
        progressPublisher.send(AnalysisProgress(
            phase: .complete,
            progress: 1.0,
            message: "Complete!"
        ))

        logger.info("Analysis complete for file: \(resolvedTitle, privacy: .public), BPM: \(bpm, privacy: .public), Beats: \(beatTimestamps.count, privacy: .public)")

        // Create AudioTrack (no caching for file-based analysis)
        return AudioTrack(
            title: resolvedTitle,
            artist: artist,
            albumTitle: nil,
            duration: duration,
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
    
    private func checkForTimeout(startDate: Date, timeout: TimeInterval, context: inout AnalysisContext) throws {
        let elapsed = Date().timeIntervalSince(startDate)
        let progress = elapsed / timeout
        
        // Check for timeout warnings (50% and 75%) independently
        // This ensures both warnings can be triggered even if progress jumps from <50% to ≥75%
        if progress >= warningThreshold50 && !context.warning50Shown {
            context.warning50Shown = true
            let remaining = max(1, Int(timeout - elapsed))
            progressPublisher.send(AnalysisProgress(
                phase: .analyzing,
                progress: 0.70,
                message: String(format: NSLocalizedString("analysis.warning.medium", comment: ""), remaining)
            ))
            logger.info("Analysis at 50% of timeout, remaining: \(remaining, privacy: .public) seconds")
        }
        
        if progress >= warningThreshold75 && !context.warning75Shown {
            context.warning75Shown = true
            let remaining = max(1, Int(timeout - elapsed))
            progressPublisher.send(AnalysisProgress(
                phase: .analyzing,
                progress: 0.85,
                message: String(format: NSLocalizedString("analysis.warning.long", comment: ""), remaining)
            ))
            logger.warning("Analysis at 75% of timeout, remaining: \(remaining, privacy: .public) seconds")
        }
        
        // Check for actual timeout
        if elapsed > timeout {
            logger.error("Analysis timeout after \(elapsed, privacy: .public) seconds (limit: \(timeout, privacy: .public) seconds)")
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
                let metadataDurationString = String(format: "%.3f", metadataDuration)
                let waveformDurationString = String(format: "%.3f", waveformDuration)
                let percentDifferenceString = String(format: "%.2f", percentDifference)
                logger.warning("Significant duration discrepancy: metadata=\(metadataDurationString, privacy: .public)s, waveform=\(waveformDurationString, privacy: .public)s, difference=\(percentDifferenceString, privacy: .public)%")
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
            logger.warning("Energy-driven beat detection produced \(timestamps.count, privacy: .public) beats, capping to \(maxBeats, privacy: .public) to avoid memory issues")
            return Array(timestamps.prefix(maxBeats))
        }
        return timestamps
    }
    
    private func generateUniformBeats(duration: TimeInterval, bpm: Double) -> [TimeInterval] {
        guard duration > 0 else { return [] }
        
        // Check for fundamentally invalid BPM (NaN, infinite, zero, or negative)
        guard bpm.isFinite && bpm > 0 else {
            logger.error("Cannot generate uniform beats: BPM is invalid (NaN, infinite, or non-positive): \(bpm, privacy: .public)")
            return []
        }
        
        let sanitizedBPM = max(30, min(200, bpm))
        
        // Log when BPM is clamped, as this indicates the tempo estimate may be unreliable
        if sanitizedBPM != bpm {
            logger.error("BPM \(bpm, privacy: .public) is outside valid range (30-200); clamping to \(sanitizedBPM, privacy: .public)")
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
