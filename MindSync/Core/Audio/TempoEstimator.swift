import Foundation

/// Service for BPM estimation from beat timestamps
final class TempoEstimator {
    // Constants for BPM estimation
    private let minBPM: Double = 60.0
    private let maxBPM: Double = 200.0
    private let defaultBPM: Double = 120.0
    private let defaultInterval: TimeInterval = 0.5 // 120 BPM equivalent
    private let iqrOutlierMultiplier: Double = 1.5 // Standard IQR outlier detection threshold
    
    /// Estimates tempo (BPM) from beat timestamps
    /// - Parameter beatTimestamps: Array of timestamps in seconds
    /// - Returns: Estimated BPM (Beats Per Minute)
    func estimateBPM(from beatTimestamps: [TimeInterval]) -> Double {
        guard beatTimestamps.count >= 2 else {
            return defaultBPM
        }

        // Calculate inter-onset intervals
        var intervals: [TimeInterval] = []
        for i in 1..<beatTimestamps.count {
            let interval = beatTimestamps[i] - beatTimestamps[i - 1]
            intervals.append(interval)
        }

        // Robust estimation of dominant tempo:
        // 1. Sort intervals and remove outliers using IQR.
        // 2. Convert intervals to BPM candidates and fold them into target range.
        // 3. Select most common BPM (histogram / clustering).

        // Ensure we have enough intervals
        guard intervals.count >= 2 else {
            // Fallback: Median of few intervals
            let singleInterval = max(0.01, intervals.first ?? defaultInterval)
            let fallbackBpm = 60.0 / singleInterval
            return clampBPM(fallbackBpm)
        }

        let sortedIntervals = intervals.sorted()

        // IQR-based outlier filtering with proper quartile calculation
        let count = sortedIntervals.count
        
        // Helper to compute the median of a sorted slice
        func median(of slice: ArraySlice<TimeInterval>) -> TimeInterval {
            let sliceCount = slice.count
            guard sliceCount > 0 else {
                // Fallback to default interval to avoid crashing on empty slices
                return defaultInterval
            }

            let midOffset = sliceCount / 2
            let midIndex = slice.startIndex.advanced(by: midOffset)

            if sliceCount % 2 == 0 {
                let prevIndex = slice.index(before: midIndex)
                return (slice[prevIndex] + slice[midIndex]) / 2.0
            } else {
                return slice[midIndex]
            }
        }

        // Compute Q1 and Q3 as medians of the lower and upper halves
        let lowerHalf: ArraySlice<TimeInterval>
        let upperHalf: ArraySlice<TimeInterval>

        if count % 2 == 0 {
            // Even number of observations: split exactly in half
            lowerHalf = sortedIntervals[0..<(count / 2)]
            upperHalf = sortedIntervals[(count / 2)..<count]
        } else {
            // Odd number of observations: exclude the median element
            lowerHalf = sortedIntervals[0..<(count / 2)]
            upperHalf = sortedIntervals[(count / 2 + 1)..<count]
        }

        let q1 = median(of: lowerHalf)
        let q3 = median(of: upperHalf)
        let iqr = q3 - q1

        let lowerBound = q1 - iqrOutlierMultiplier * iqr
        let upperBound = q3 + iqrOutlierMultiplier * iqr

        let filteredIntervals = sortedIntervals.filter { interval in
            interval > 0 && interval >= lowerBound && interval <= upperBound
        }

        // If filtering removed everything, fall back to original intervals
        let intervalsForEstimation = filteredIntervals.isEmpty ? sortedIntervals : filteredIntervals

        // Convert intervals to BPM candidates and fold them into minBPM-maxBPM range
        var bpmCandidates: [Double] = []
        for interval in intervalsForEstimation {
            guard interval > 0 else { continue }
            var bpm = 60.0 / interval

            // Fold into sensible tempo range (e.g. half/double tempo)
            while bpm < minBPM {
                bpm *= 2.0
            }
            while bpm > maxBPM {
                bpm /= 2.0
            }
            bpmCandidates.append(bpm)
        }

        // If no valid candidates, median fallback
        guard !bpmCandidates.isEmpty else {
            let medianInterval = intervalsForEstimation[intervalsForEstimation.count / 2]
            let fallbackBpm = 60.0 / max(0.01, medianInterval)
            return clampBPM(fallbackBpm)
        }

        // Create a simple histogram (1-BPM bins) and select most common BPM
        var histogram: [Int: Int] = [:]
        for bpm in bpmCandidates {
            let bin = Int(round(bpm))
            histogram[bin, default: 0] += 1
        }

        // Find dominant BPM bin (highest count)
        let dominantBin = histogram.max { a, b in a.value < b.value }?.key

        let estimatedBpm: Double
        if let dominantBin = dominantBin {
            estimatedBpm = Double(dominantBin)
        } else {
            // Last fallback: Average of candidates
            let sum = bpmCandidates.reduce(0.0, +)
            estimatedBpm = sum / Double(bpmCandidates.count)
        }

        return clampBPM(estimatedBpm)
    }
    
    /// Clamps BPM value to valid range
    private func clampBPM(_ bpm: Double) -> Double {
        return max(minBPM, min(maxBPM, bpm))
    }
}
