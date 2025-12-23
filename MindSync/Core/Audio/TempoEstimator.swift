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

        // Finde dominantes Intervall (vereinfachter Ansatz: Median)
        let sortedIntervals = intervals.sorted()
        let medianInterval = sortedIntervals[sortedIntervals.count / 2]

        // BPM = 60 / Intervall in Sekunden
        let bpm = 60.0 / medianInterval

        // Begrenze auf sinnvollen Bereich (60-200 BPM)
        return max(60.0, min(200.0, bpm))
    }
}
