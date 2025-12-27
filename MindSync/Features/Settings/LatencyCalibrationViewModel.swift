import Foundation
import SwiftUI
import AVFoundation
import Combine

/// ViewModel für die Audio-Latenz-Kalibrierung
/// Führt mehrere Messungen durch und berechnet den optimalen Latenz-Offset
@MainActor
final class LatencyCalibrationViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published var state: CalibrationState = .ready
    @Published var currentMeasurement: Int = 0
    @Published var totalMeasurements: Int = 5
    @Published var measurements: [TimeInterval] = []
    @Published var calibratedOffset: TimeInterval = 0.0
    @Published var showFlash: Bool = false
    
    // MARK: - Private Properties
    
    private var audioPlayer: AVAudioPlayer?
    private var flashStartTime: Date?
    private var cancellables = Set<AnyCancellable>()
    
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
    
    init() {
        setupAudioSession()
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
    
    // MARK: - Calibration Flow
    
    /// Startet die Kalibrierung
    func startCalibration() {
        state = .instructions
        currentMeasurement = 0
        measurements = []
        calibratedOffset = 0.0
        
        // Nach 3 Sekunden automatisch mit erster Messung beginnen
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.performNextMeasurement()
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
    
    /// Triggert Flash und Sound gleichzeitig
    private func triggerFlashAndSound() {
        flashStartTime = Date()
        
        // 1. Zeige weißen Flash
        withAnimation(.easeInOut(duration: 0.05)) {
            showFlash = true
        }
        
        // Flash für 100ms anzeigen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            withAnimation(.easeInOut(duration: 0.05)) {
                self?.showFlash = false
            }
        }
        
        // 2. Spiele Click-Sound
        playClickSound()
        
        // 3. Warte auf User-Tap
        state = .waitingForTap
    }
    
    /// Spielt einen kurzen Click-Sound ab
    private func playClickSound() {
        // Generiere einen kurzen Beep-Sound programmtisch
        // Da wir keinen Sound-File haben, nutzen wir SystemSoundID
        AudioServicesPlaySystemSound(1306) // "Tock" Sound
    }
    
    /// Wird aufgerufen wenn User auf den Screen tippt
    func userTapped() {
        guard state == .waitingForTap,
              let startTime = flashStartTime else {
            return
        }
        
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
        // menschliche Reaktionszeit (~200ms) abziehen
        let averageReactionTime: TimeInterval = 0.2
        
        // Berechne Bluetooth-Latenz
        // Wenn User bei 400ms tappt: 400ms - 200ms (Reaktion) = 200ms Bluetooth-Latenz
        calibratedOffset = max(0.0, median - averageReactionTime)
        
        // Runde auf 10ms für bessere Lesbarkeit
        calibratedOffset = round(calibratedOffset * 100) / 100
        
        state = .completed
    }
    
    /// Speichert den kalibrierten Wert in UserPreferences
    func saveCalibration() {
        var prefs = UserPreferences.load()
        prefs.audioLatencyOffset = calibratedOffset
        prefs.save()
    }
    
    /// Setzt die Kalibrierung zurück
    func reset() {
        state = .ready
        currentMeasurement = 0
        measurements = []
        calibratedOffset = 0.0
        showFlash = false
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

