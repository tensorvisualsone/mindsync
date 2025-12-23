import Foundation

/// Service zur BPM-Schätzung aus Beat-Timestamps
final class TempoEstimator {
    // Constants for BPM estimation
    private let minBPM: Double = 60.0
    private let maxBPM: Double = 200.0
    private let defaultBPM: Double = 120.0
    private let defaultInterval: TimeInterval = 0.5 // 120 BPM equivalent
    private let iqrOutlierMultiplier: Double = 1.5 // Standard IQR outlier detection threshold
    
    /// Schätzt das Tempo (BPM) aus Beat-Timestamps
    /// - Parameter beatTimestamps: Array von Zeitstempeln in Sekunden
    /// - Returns: Geschätztes BPM (Beats Per Minute)
    func estimateBPM(from beatTimestamps: [TimeInterval]) -> Double {
        guard beatTimestamps.count >= 2 else {
            return defaultBPM
        }

        // Berechne Inter-Onset-Intervalle
        var intervals: [TimeInterval] = []
        for i in 1..<beatTimestamps.count {
            let interval = beatTimestamps[i] - beatTimestamps[i - 1]
            intervals.append(interval)
        }

        // Robustere Schätzung des dominanten Tempos:
        // 1. Sortiere Intervalle und entferne Ausreißer per IQR.
        // 2. Wandle Intervalle in BPM-Kandidaten um und falte sie in den Zielbereich.
        // 3. Wähle das am häufigsten vorkommende BPM (Histogramm / Clustering).

        // Sicherstellen, dass wir genug Intervalle haben
        guard intervals.count >= 2 else {
            // Fallback: Median der wenigen Intervalle
            let singleInterval = max(0.01, intervals.first ?? defaultInterval)
            let fallbackBpm = 60.0 / singleInterval
            return clampBPM(fallbackBpm)
        }

        let sortedIntervals = intervals.sorted()

        // IQR-basiertes Ausreißer-Filtering
        let count = sortedIntervals.count
        let q1Index = count / 4
        let q3Index = (3 * count) / 4
        let q1 = sortedIntervals[q1Index]
        let q3 = sortedIntervals[q3Index]
        let iqr = q3 - q1

        let lowerBound = q1 - iqrOutlierMultiplier * iqr
        let upperBound = q3 + iqrOutlierMultiplier * iqr

        let filteredIntervals = sortedIntervals.filter { interval in
            interval > 0 && interval >= lowerBound && interval <= upperBound
        }

        // Falls Filtering alles entfernt hat, auf ursprüngliche Intervalle zurückfallen
        let intervalsForEstimation = filteredIntervals.isEmpty ? sortedIntervals : filteredIntervals

        // Wandle Intervalle in BPM-Kandidaten um und falte sie in den Bereich minBPM–maxBPM
        var bpmCandidates: [Double] = []
        for interval in intervalsForEstimation {
            guard interval > 0 else { continue }
            var bpm = 60.0 / interval

            // Faltung in den sinnvollen Tempobereich (z. B. halbes/doppeltes Tempo)
            while bpm < minBPM {
                bpm *= 2.0
            }
            while bpm > maxBPM {
                bpm /= 2.0
            }
            bpmCandidates.append(bpm)
        }

        // Wenn keine gültigen Kandidaten vorhanden sind, Median-Fallback
        guard !bpmCandidates.isEmpty else {
            let medianInterval = intervalsForEstimation[intervalsForEstimation.count / 2]
            let fallbackBpm = 60.0 / max(0.01, medianInterval)
            return clampBPM(fallbackBpm)
        }

        // Erzeuge ein einfaches Histogramm (1-BPM-Bins) und wähle das häufigste BPM
        var histogram: [Int: Int] = [:]
        for bpm in bpmCandidates {
            let bin = Int(round(bpm))
            histogram[bin, default: 0] += 1
        }

        // Finde den dominanten BPM-Bin (highest count)
        let dominantBin = histogram.max { a, b in a.value < b.value }?.key

        let estimatedBpm: Double
        if let dominantBin = dominantBin {
            estimatedBpm = Double(dominantBin)
        } else {
            // Letzter Fallback: Mittelwert der Kandidaten
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
