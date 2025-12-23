import Foundation

/// Service zur BPM-Schätzung aus Beat-Timestamps
final class TempoEstimator {
    /// Schätzt das Tempo (BPM) aus Beat-Timestamps
    /// - Parameter beatTimestamps: Array von Zeitstempeln in Sekunden
    /// - Returns: Geschätztes BPM (Beats Per Minute)
    func estimateBPM(from beatTimestamps: [TimeInterval]) -> Double {
        guard beatTimestamps.count >= 2 else {
            return 120.0 // Default
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
            let singleInterval = max(0.01, intervals.first ?? 0.5)
            let fallbackBpm = 60.0 / singleInterval
            return max(60.0, min(200.0, fallbackBpm))
        }

        let sortedIntervals = intervals.sorted()

        // IQR-basiertes Ausreißer-Filtering
        let count = sortedIntervals.count
        let q1Index = count / 4
        let q3Index = (3 * count) / 4
        let q1 = sortedIntervals[q1Index]
        let q3 = sortedIntervals[q3Index]
        let iqr = q3 - q1

        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr

        let filteredIntervals = sortedIntervals.filter { interval in
            interval > 0 && interval >= lowerBound && interval <= upperBound
        }

        // Falls Filtering alles entfernt hat, auf ursprüngliche Intervalle zurückfallen
        let intervalsForEstimation = filteredIntervals.isEmpty ? sortedIntervals : filteredIntervals

        // Wandle Intervalle in BPM-Kandidaten um und falte sie in den Bereich 60–200 BPM
        var bpmCandidates: [Double] = []
        for interval in intervalsForEstimation {
            guard interval > 0 else { continue }
            var bpm = 60.0 / interval

            // Faltung in den sinnvollen Tempobereich (z. B. halbes/doppeltes Tempo)
            while bpm < 60.0 {
                bpm *= 2.0
            }
            while bpm > 200.0 {
                bpm /= 2.0
            }
            bpmCandidates.append(bpm)
        }

        // Wenn keine gültigen Kandidaten vorhanden sind, Median-Fallback
        guard !bpmCandidates.isEmpty else {
            let medianInterval = intervalsForEstimation[intervalsForEstimation.count / 2]
            let fallbackBpm = 60.0 / max(0.01, medianInterval)
            return max(60.0, min(200.0, fallbackBpm))
        }

        // Erzeuge ein einfaches Histogramm (1-BPM-Bins) und wähle das häufigste BPM
        var histogram: [Int: Int] = [:]
        for bpm in bpmCandidates {
            let bin = Int(round(bpm))
            histogram[bin, default: 0] += 1
        }

        // Finde den dominanten BPM-Bin
        let dominantBin = histogram.max { a, b in a.value < b.value }?.key

        let estimatedBpm: Double
        if let dominantBin = dominantBin {
            estimatedBpm = Double(dominantBin)
        } else {
            // Letzter Fallback: Mittelwert der Kandidaten
            let sum = bpmCandidates.reduce(0.0, +)
            estimatedBpm = sum / Double(bpmCandidates.count)
        }

        // Begrenze auf sinnvollen Bereich (60-200 BPM)
        return max(60.0, min(200.0, estimatedBpm))
    }
}
