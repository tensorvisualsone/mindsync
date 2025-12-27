import Foundation
import SwiftUI
import AVFoundation
import Combine // Required for ObservableObject and @Published

/// ViewModel für die Audio-Latenz-Kalibrierung
/// Führt mehrere Messungen durch und berechnet den optimalen Latenz-Offset
/// 
/// WICHTIG: Timing-Präzision
/// Flash und Sound müssen exakt gleichzeitig starten für akkurate Messungen.
/// Wir verwenden AVAudioPlayer mit prepareToPlay() für präzises Timing statt
/// AudioServicesPlaySystemSound, da letzteres asynchron ist und eigene Latenz hat.
@MainActor
final class LatencyCalibrationViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published var state: CalibrationState = .ready
    @Published var currentMeasurement: Int = 0
    @Published var measurements: [TimeInterval] = []
    @Published var calibratedOffset: TimeInterval = 0.0
    @Published var showFlash: Bool = false
    
    // MARK: - Constants
    
    /// Anzahl der Messungen für die Kalibrierung
    /// Konstante, da sie nie mutiert wird
    let totalMeasurements: Int = 5
    
    // MARK: - Private Properties
    
    /// Durchschnittliche menschliche Reaktionszeit in Sekunden
    /// Wird von der gemessenen Zeit abgezogen, um die reine Bluetooth-Latenz zu isolieren
    /// Default: 0.2s (200ms) - typische Reaktionszeit für visuell-auditive Stimuli
    /// Kann für individuelle User angepasst werden (z.B. aus UserPreferences)
    /// Validierung: 0.0 - 1.0 Sekunden
    private let reactionTime: TimeInterval
    
    private var audioPlayer: AVAudioPlayer?
    private var clickSoundData: Data?
    private var flashStartTime: Date?
    private var tapTimeoutWorkItem: DispatchWorkItem?
    private var calibrationTask: Task<Void, Never>?
    
    // MARK: - Calibration State
    
    enum CalibrationState: Equatable {
        case ready              // Bereit zum Start
        case instructions       // Anleitung wird angezeigt
        case measuring          // Messung läuft
        case waitingForTap      // Wartet auf User-Tap
        case processing         // Berechnet Ergebnis
        case completed          // Kalibrierung abgeschlossen
        case error(String)      // Fehler aufgetreten
    }
    
    // MARK: - Initialization
    
    /// Initialisiert das ViewModel mit konfigurierbarer Reaktionszeit
    /// - Parameter reactionTime: Durchschnittliche menschliche Reaktionszeit in Sekunden.
    ///   Wird auf 0.0-1.0s validiert. Default: 0.2s (200ms).
    init(reactionTime: TimeInterval = 0.2) {
        // Validiere und clamp Reaktionszeit auf sinnvollen Bereich
        self.reactionTime = max(0.0, min(1.0, reactionTime))
        setupAudioSession()
        prepareClickSound()
    }
    
    /// Deinitializer: Deaktiviert die Audio-Session beim Deallokieren
    /// 
    /// WICHTIG: Actor Isolation
    /// Da die Klasse @MainActor ist, muss deinit nonisolated sein.
    /// Die setActive(false) Operation wird auf dem MainActor ausgeführt.
    /// 
    /// HINWEIS: calibrationTask und tapTimeoutWorkItem werden automatisch
    /// gecancelt wenn die Klasse deallokiert wird (Swift's Task/WorkItem cleanup).
    nonisolated deinit {
        // Deaktiviere Audio-Session auf MainActor
        // Nutze Task um auf MainActor zu wechseln, da deinit nonisolated ist
        Task { @MainActor in
            try? AVAudioSession.sharedInstance().setActive(false)
        }
    }
    
    // MARK: - Audio Setup
    
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            state = .error("Audio-Session konnte nicht initialisiert werden")
        }
    }
    
    /// Erstellt einen programmatisch generierten Click-Sound für präzises Timing
    /// Generiert einen kurzen 440Hz Beep (100ms) als WAV-Daten
    private func prepareClickSound() {
        let sampleRate: Double = 44100.0
        let duration: Double = 0.1 // 100ms
        let frequency: Double = 440.0 // A4 Note
        let amplitude: Float = 0.5
        
        let sampleCount = Int(sampleRate * duration)
        var samples = [Float](repeating: 0, count: sampleCount)
        
        // Generiere Sinus-Welle mit Fade-In/Out für sanfteren Sound
        for i in 0..<sampleCount {
            let t = Double(i) / sampleRate
            let fadeIn = min(1.0, t * 100) // 10ms Fade-In
            let fadeOut = min(1.0, (duration - t) * 100) // 10ms Fade-Out
            let fade = Float(min(fadeIn, fadeOut))
            
            // Aufteilen der komplexen Expression für besseres Type-Checking
            let phase = 2.0 * .pi * frequency * t
            let sineValue = sin(phase)
            let sample = Float(sineValue) * amplitude * fade
            samples[i] = sample
        }
        
        // Konvertiere zu WAV-Format
        let wavData = createWAVFile(samples: samples, sampleRate: Int(sampleRate))
        clickSoundData = wavData
        
        // Erstelle AVAudioPlayer und prepare für sofortiges Abspielen
        if let data = wavData {
            do {
                let player = try AVAudioPlayer(data: data)
                player.prepareToPlay() // WICHTIG: Lädt Audio in Buffer für sofortiges Abspielen
                self.audioPlayer = player
            } catch {
                print("Failed to create audio player: \(error)")
            }
        }
    }
    
    /// Konvertiert Float-Samples zu WAV-Datei-Format
    private func createWAVFile(samples: [Float], sampleRate: Int) -> Data? {
        let numChannels: UInt16 = 1 // Mono
        let bitsPerSample: UInt16 = 16
        let bytesPerSample = Int(bitsPerSample / 8)
        let dataSize = samples.count * bytesPerSample
        
        var wavData = Data()
        
        // Helper function to append little-endian bytes
        func appendLE<T: FixedWidthInteger>(_ value: T) {
            var leValue = value.littleEndian
            wavData.append(contentsOf: withUnsafeBytes(of: &leValue) { Data($0) })
        }
        
        // WAV Header
        wavData.append("RIFF".data(using: .ascii)!)
        appendLE(UInt32(36 + dataSize))
        wavData.append("WAVE".data(using: .ascii)!)
        
        // fmt chunk
        wavData.append("fmt ".data(using: .ascii)!)
        appendLE(UInt32(16)) // fmt chunk size
        appendLE(UInt16(1)) // PCM
        appendLE(numChannels)
        appendLE(UInt32(sampleRate))
        appendLE(UInt32(sampleRate * Int(numChannels) * bytesPerSample)) // Byte rate
        appendLE(UInt16(Int(numChannels) * bytesPerSample)) // Block align
        appendLE(bitsPerSample)
        
        // data chunk
        wavData.append("data".data(using: .ascii)!)
        appendLE(UInt32(dataSize))
        
        // Convert Float samples to Int16
        for sample in samples {
            let clampedSample = max(-1.0, min(1.0, sample))
            let int16Sample = Int16(clampedSample * Float(Int16.max))
            appendLE(int16Sample)
        }
        
        return wavData
    }
    
    // MARK: - Calibration Flow
    
    /// Startet die Kalibrierung
    /// 
    /// WICHTIG: Race Condition Prevention
    /// Cancelt alle laufenden Kalibrierungs-Tasks bevor eine neue gestartet wird,
    /// um zu verhindern, dass mehrere Kalibrierungen parallel laufen.
    func startCalibration() {
        // Cancle vorherige Kalibrierung falls vorhanden
        calibrationTask?.cancel()
        tapTimeoutWorkItem?.cancel()
        tapTimeoutWorkItem = nil
        
        state = .instructions
        currentMeasurement = 0
        measurements = []
        calibratedOffset = 0.0
        
        // Nach 3 Sekunden automatisch mit erster Messung beginnen
        // Nutze Task statt DispatchQueue für bessere Cancellation-Unterstützung
        calibrationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            
            // Prüfe ob Task gecancelt wurde
            guard !Task.isCancelled else { return }
            
            // performNextMeasurement() ist @MainActor, daher direkt aufrufbar
            await MainActor.run {
                self?.performNextMeasurement()
            }
        }
    }
    
    /// Führt die nächste Messung durch
    private func performNextMeasurement() {
        guard currentMeasurement < totalMeasurements else {
            calculateResult()
            return
        }
        
        currentMeasurement += 1
        state = .measuring
        
        // Zufälliger Delay zwischen 1.0 und 2.0 Sekunden
        // Verhindert, dass User den Rhythmus "lernt"
        let randomDelay = Double.random(in: 1.0...2.0)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + randomDelay) { [weak self] in
            self?.triggerFlashAndSound()
        }
    }
    
    /// Triggert Flash und Sound exakt gleichzeitig
    /// 
    /// WICHTIG: Timing-Präzision
    /// - Flash wird OHNE Animation sofort angezeigt (kein Animation-Delay)
    /// - Sound wird mit AVAudioPlayer.play() abgespielt (bereits prepared)
    /// - flashStartTime wird NACH beiden gestartet gesetzt für exakte Synchronisation
    private func triggerFlashAndSound() {
        // 1. Zeige weißen Flash SOFORT (ohne Animation für präzises Timing)
        // Animation würde Delay einführen, daher direkte Zuweisung
        showFlash = true
        
        // 2. Spiele Click-Sound SOFORT (bereits prepared, daher minimales Delay)
        // AVAudioPlayer.play() ist synchron und startet sofort nach prepareToPlay()
        audioPlayer?.play()
        
        // 3. Setze Start-Zeit NACH beiden gestartet sind für exakte Synchronisation
        // Dies stellt sicher, dass die gemessene Zeit von beiden Stimuli ausgeht
        flashStartTime = Date()
        
        // 4. Flash für 100ms anzeigen, dann ausblenden
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.showFlash = false
        }
        
        // 5. Warte auf User-Tap
        state = .waitingForTap
        
        // 6. Timeout für verpasste Taps: Wenn User nicht innerhalb von 4 Sekunden tippt,
        // überspringe diese Messung und gehe zur nächsten über
        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            // Prüfe ob wir noch im waitingForTap state sind (no-op wenn state sich geändert hat)
            guard let self = self, self.state == .waitingForTap else {
                return
            }
            
            // Verpasste Messung: Gehe zur nächsten über ohne Messung zu speichern
            self.state = .measuring
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.performNextMeasurement()
            }
        }
        
        tapTimeoutWorkItem = timeoutWorkItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0, execute: timeoutWorkItem)
    }
    
    /// Wird aufgerufen wenn User auf den Screen tippt
    func userTapped() {
        guard state == .waitingForTap,
              let startTime = flashStartTime else {
            return
        }
        
        // Cancle Timeout da User getippt hat
        tapTimeoutWorkItem?.cancel()
        tapTimeoutWorkItem = nil
        
        let tapTime = Date()
        let measuredLatency = tapTime.timeIntervalSince(startTime)
        
        // Speichere Messung (nur wenn plausibel: 0-1000ms)
        if measuredLatency >= 0 && measuredLatency <= 1.0 {
            measurements.append(measuredLatency)
        }
        
        // Kurze Pause vor nächster Messung
        state = .measuring
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performNextMeasurement()
        }
    }
    
    /// Berechnet das finale Ergebnis aus allen Messungen
    private func calculateResult() {
        state = .processing
        
        guard !measurements.isEmpty else {
            state = .error("Keine gültigen Messungen")
            return
        }
        
        // Verwende Median statt Durchschnitt (robuster gegen Ausreißer)
        let sortedMeasurements = measurements.sorted()
        let median: TimeInterval
        
        if sortedMeasurements.count % 2 == 0 {
            // Gerade Anzahl: Durchschnitt der beiden mittleren Werte
            let mid1 = sortedMeasurements[sortedMeasurements.count / 2 - 1]
            let mid2 = sortedMeasurements[sortedMeasurements.count / 2]
            median = (mid1 + mid2) / 2.0
        } else {
            // Ungerade Anzahl: Mittlerer Wert
            median = sortedMeasurements[sortedMeasurements.count / 2]
        }
        
        // Der gemessene Wert ist die Reaktionszeit des Users
        // Für die Latenz-Kompensation müssen wir die durchschnittliche
        // menschliche Reaktionszeit abziehen (konfigurierbar, default: 200ms)
        
        // Berechne Bluetooth-Latenz
        // Beispiel: Wenn User bei 400ms tappt und reactionTime 200ms ist:
        // 400ms - 200ms (Reaktion) = 200ms Bluetooth-Latenz
        calibratedOffset = max(0.0, median - reactionTime)
        
        // Runde auf 10ms für bessere Lesbarkeit
        calibratedOffset = round(calibratedOffset * 100) / 100
        
        state = .completed
    }
    
    /// Speichert den kalibrierten Wert in UserPreferences
    /// 
    /// WICHTIG: Validierung
    /// Speichert nur wenn:
    /// - Kalibrierung erfolgreich abgeschlossen (state == .completed)
    /// - calibratedOffset ist gültig (nicht 0 und innerhalb akzeptabler Grenzen)
    /// 
    /// - Returns: `true` wenn erfolgreich gespeichert, `false` wenn Validierung fehlgeschlagen ist
    @discardableResult
    func saveCalibration() -> Bool {
        // Guard: Prüfe ob Kalibrierung abgeschlossen ist
        guard state == .completed else {
            // Kalibrierung nicht abgeschlossen, nichts speichern
            return false
        }
        
        // Guard: Prüfe ob calibratedOffset gültig ist
        // - Muss > 0 sein (0 bedeutet keine Latenz, wäre ungewöhnlich nach Kalibrierung)
        // - Muss innerhalb der UserPreferences-Grenzen sein (0.0 - 0.5s)
        guard calibratedOffset > 0.0,
              calibratedOffset <= 0.5 else {
            // Ungültiger Offset-Wert, nichts speichern
            return false
        }
        
        // Alle Validierungen bestanden: Speichere in UserPreferences
        var prefs = UserPreferences.load()
        prefs.audioLatencyOffset = calibratedOffset
        prefs.save()
        
        return true
    }
    
    /// Bricht die laufende Kalibrierung ab und setzt sie zurück
    /// Wird verwendet wenn User die Kalibrierung während des Prozesses abbricht
    func cancelCalibration() {
        // Cancle alle laufenden Tasks und Timeouts
        calibrationTask?.cancel()
        calibrationTask = nil
        tapTimeoutWorkItem?.cancel()
        tapTimeoutWorkItem = nil
        
        // Stoppe Audio falls aktiv
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        
        // Setze State zurück
        state = .ready
        currentMeasurement = 0
        measurements = []
        calibratedOffset = 0.0
        showFlash = false
    }
    
    /// Setzt die Kalibrierung zurück (für "Erneut kalibrieren" nach Abschluss)
    func reset() {
        // Cancle alle laufenden Tasks und Timeouts
        calibrationTask?.cancel()
        calibrationTask = nil
        tapTimeoutWorkItem?.cancel()
        tapTimeoutWorkItem = nil
        
        state = .ready
        currentMeasurement = 0
        measurements = []
        calibratedOffset = 0.0
        showFlash = false
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
    }
}

// MARK: - Helper Extensions

extension LatencyCalibrationViewModel.CalibrationState {
    var isWaitingForTap: Bool {
        if case .waitingForTap = self {
            return true
        }
        return false
    }
    
    var isCompleted: Bool {
        if case .completed = self {
            return true
        }
        return false
    }
}

