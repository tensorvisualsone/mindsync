import Foundation
import AVFoundation
import Accelerate

/// Service for reading PCM data from audio files
final class AudioFileReader {
    /// Reads PCM data from an audio file
    /// - Parameter url: URL of the audio file
    /// - Returns: Array of Float samples (mono, 44.1kHz)
    /// - Throws: AudioAnalysisError
    /// - Note: This method loads the entire audio file into memory as a single array of Float samples.
    ///         For very long audio files, this may cause memory pressure or crashes on devices with
    ///         limited RAM. Files longer than 30 minutes will throw an error to prevent memory issues.
    func readPCM(from url: URL) async throws -> [Float] {
        let asset = AVURLAsset(url: url)

        // Check if asset is readable (async load for iOS 16+)
        let isReadable = try await asset.load(.isReadable)
        guard isReadable else {
            throw AudioAnalysisError.drmProtected
        }
        
        // Check duration to prevent memory issues with very long files
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)
        let maxDurationInSeconds: Double = 30 * 60 // 30 minutes
        
        if durationInSeconds > maxDurationInSeconds {
            throw AudioAnalysisError.fileTooLong(duration: durationInSeconds)
        }

        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw AudioAnalysisError.unsupportedFormat
        }

        let formatDescriptions = try await audioTrack.load(.formatDescriptions)
        guard let formatDescription = formatDescriptions.first else {
            throw AudioAnalysisError.unsupportedFormat
        }

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: true,
                AVSampleRateKey: 44100.0,
                AVNumberOfChannelsKey: 1
            ]
        )

        reader.add(output)
        reader.startReading()

        var samples: [Float] = []

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer() else {
                break
            }

            guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else {
                continue
            }

            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            let status = CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: nil,
                totalLengthOut: &length,
                dataPointerOut: &dataPointer
            )

            guard status == noErr, let pointer = dataPointer else {
                continue
            }

            // Convert Int8 pointer to Float pointer using raw pointer rebinding
            let frameCount = length / MemoryLayout<Float>.size
            let rawPointer = UnsafeMutableRawPointer(pointer)
            let floatPointer = rawPointer.assumingMemoryBound(to: Float.self)
            let frameArray = Array(UnsafeBufferPointer<Float>(start: floatPointer, count: frameCount))
            samples.append(contentsOf: frameArray)
        }

        if reader.status == .failed, let error = reader.error {
            throw AudioAnalysisError.analysisFailure(underlying: error)
        }

        return samples
    }
}

/// Error types for audio analysis
enum AudioAnalysisError: Error, LocalizedError {
    case fileNotFound
    case drmProtected
    case unsupportedFormat
    case analysisFailure(underlying: Error)
    case cancelled
    case fileTooLong(duration: Double)

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audiodatei wurde nicht gefunden"
        case .drmProtected:
            return "DRM-geschützte Datei kann nicht analysiert werden"
        case .unsupportedFormat:
            return "Audioformat wird nicht unterstützt"
        case .analysisFailure(let e):
            return "Analyse fehlgeschlagen: \(e.localizedDescription)"
        case .cancelled:
            return "Analyse abgebrochen"
        case .fileTooLong(let duration):
            let minutes = Int(duration / 60)
            return "Audiodatei ist zu lang (\(minutes) Minuten). Die maximal unterstützte Länge beträgt 30 Minuten."
        }
    }
}
