import Foundation
import AVFoundation
import Accelerate

/// Service zum Lesen von PCM-Daten aus Audio-Dateien
final class AudioFileReader {
    /// Liest PCM-Daten aus einer Audio-Datei
    /// - Parameter url: URL der Audio-Datei
    /// - Returns: Array von Float-Samples (mono, 44.1kHz)
    /// - Throws: AudioAnalysisError
    func readPCM(from url: URL) async throws -> [Float] {
        let asset = AVAsset(url: url)

        guard asset.isReadable else {
            throw AudioAnalysisError.drmProtected
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

            let floatPointer = pointer.bindMemory(to: Float.self, capacity: length / MemoryLayout<Float>.size)
            let frameCount = length / MemoryLayout<Float>.size
            let frameArray = Array(UnsafeBufferPointer(start: floatPointer, count: frameCount))
            samples.append(contentsOf: frameArray)
        }

        if reader.status == .failed, let error = reader.error {
            throw AudioAnalysisError.analysisFailure(underlying: error)
        }

        return samples
    }
}

/// Fehler-Typen für Audio-Analyse
enum AudioAnalysisError: Error, LocalizedError {
    case fileNotFound
    case drmProtected
    case unsupportedFormat
    case analysisFailure(underlying: Error)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .fileNotFound:
            return "Audio-Datei nicht gefunden"
        case .drmProtected:
            return "DRM-geschützte Datei kann nicht analysiert werden"
        case .unsupportedFormat:
            return "Audio-Format wird nicht unterstützt"
        case .analysisFailure(let e):
            return "Analyse fehlgeschlagen: \(e.localizedDescription)"
        case .cancelled:
            return "Analyse abgebrochen"
        }
    }
}
