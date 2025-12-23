import Foundation

/// Engine zur Erzeugung von LightScripts aus AudioTracks und EntrainmentMode
final class EntrainmentEngine {
    
    /// Erzeugt ein LightScript aus einem AudioTrack und einem EntrainmentMode
    /// - Parameters:
    ///   - track: Der analysierte AudioTrack mit Beat-Timestamps
    ///   - mode: Der gewählte EntrainmentMode (Alpha/Theta/Gamma)
    ///   - lightSource: Die gewählte Lichtquelle (für Frequenz-Limits)
    /// - Returns: Ein LightScript mit synchronisierten Licht-Ereignissen
    func generateLightScript(
        from track: AudioTrack,
        mode: EntrainmentMode,
        lightSource: LightSource
    ) -> LightScript {
        // Berechne Multiplikator N, sodass f_target im Zielband liegt
        let multiplier = calculateMultiplier(
            bpm: track.bpm,
            targetRange: mode.frequencyRange,
            maxFrequency: lightSource.maxFrequency
        )
        
        // Ziel-Frequenz berechnen: f_target = (BPM / 60) × N
        let targetFrequency = (track.bpm / 60.0) * Double(multiplier)
        
        // Generiere Licht-Ereignisse basierend auf Beat-Timestamps
        let events = generateLightEvents(
            beatTimestamps: track.beatTimestamps,
            targetFrequency: targetFrequency,
            mode: mode,
            trackDuration: track.duration
        )
        
        return LightScript(
            trackId: track.id,
            mode: mode,
            targetFrequency: targetFrequency,
            multiplier: multiplier,
            events: events
        )
    }
    
    /// Berechnet den Multiplikator N für BPM-zu-Hz-Mapping
    /// - Parameters:
    ///   - bpm: Beats Per Minute des Songs
    ///   - targetRange: Ziel-Frequenzband (z.B. 8-12 Hz für Alpha)
    ///   - maxFrequency: Maximale Frequenz der Lichtquelle
    /// - Returns: Ganzzahliger Multiplikator N
    private func calculateMultiplier(
        bpm: Double,
        targetRange: ClosedRange<Double>,
        maxFrequency: Double
    ) -> Int {
        // Grundfrequenz: BPM / 60 (Hz)
        let baseFrequency = bpm / 60.0
        
        // Finde kleinsten Multiplikator, der ins Zielband führt
        var multiplier = 1
        while true {
            let frequency = baseFrequency * Double(multiplier)
            
            // Wenn wir im Zielband sind, verwende diesen Multiplikator
            if targetRange.contains(frequency) {
                return multiplier
            }
            
            // Wenn wir über dem Zielband sind, verwende den vorherigen
            if frequency > targetRange.upperBound {
                return max(1, multiplier - 1)
            }
            
            // Wenn wir über der max. Frequenz sind, begrenze
            if frequency > maxFrequency {
                return max(1, multiplier - 1)
            }
            
            multiplier += 1
            
            // Sicherheits-Check: verhindere Endlosschleife
            if multiplier > 100 {
                // Fallback: verwende Multiplikator für mittlere Ziel-Frequenz
                let targetMid = (targetRange.lowerBound + targetRange.upperBound) / 2.0
                return max(1, Int(targetMid / baseFrequency))
            }
        }
    }
    
    /// Generiert Licht-Ereignisse aus Beat-Timestamps
    private func generateLightEvents(
        beatTimestamps: [TimeInterval],
        targetFrequency: Double,
        mode: EntrainmentMode,
        trackDuration: TimeInterval
    ) -> [LightEvent] {
        guard !beatTimestamps.isEmpty else {
            // Fallback: gleichmäßige Pulsation wenn keine Beats erkannt
            return generateFallbackEvents(
                frequency: targetFrequency,
                duration: trackDuration,
                mode: mode
            )
        }
        
        var events: [LightEvent] = []
        let period = 1.0 / targetFrequency  // Dauer eines Zyklus in Sekunden
        
        // Für jeden Beat ein Licht-Ereignis erzeugen
        for beatTimestamp in beatTimestamps {
            // Wähle Wellenform basierend auf Modus
            let waveform: LightEvent.Waveform = {
                switch mode {
                case .alpha: return .sine      // Sanft für Entspannung
                case .theta: return .sine     // Sanft für Trip
                case .gamma: return .square   // Hart für Fokus
                }
            }()
            
            // Intensität basierend auf Modus
            let intensity: Float = {
                switch mode {
                case .alpha: return 0.4  // Sanfter für Entspannung
                case .theta: return 0.3  // Sehr sanft für Trip
                case .gamma: return 0.7  // Intensiver für Fokus
                }
            }()
            
            // Dauer: halbe Periode für Rechteck, volle Periode für Sinus
            let duration: TimeInterval = {
                switch waveform {
                case .square: return period / 2.0  // Kurz für hartes Blinken
                case .sine: return period         // Länger für sanftes Pulsieren
                case .triangle: return period
                }
            }()
            
            let event = LightEvent(
                timestamp: beatTimestamp,
                intensity: intensity,
                duration: duration,
                waveform: waveform,
                color: nil  // Wird später für Screen-Modus gesetzt
            )
            
            events.append(event)
        }
        
        return events
    }
    
    /// Fallback: Generiert gleichmäßige Pulsation wenn keine Beats erkannt wurden
    private func generateFallbackEvents(
        frequency: Double,
        duration: TimeInterval,
        mode: EntrainmentMode
    ) -> [LightEvent] {
        var events: [LightEvent] = []
        let period = 1.0 / frequency
        var currentTime: TimeInterval = 0
        
        while currentTime < duration {
            let event = LightEvent(
                timestamp: currentTime,
                intensity: 0.4,
                duration: period / 2.0,
                waveform: .sine,
                color: nil
            )
            events.append(event)
            currentTime += period
        }
        
        return events
    }
}
