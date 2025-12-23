import Foundation
import AVFoundation

/// Controller für Taschenlampen-Steuerung
final class FlashlightController: NSObject, LightControlling {
    var source: LightSource { .flashlight }

    private var device: AVCaptureDevice?
    private var isLocked = false
    private var currentScript: LightScript?
    private var scriptStartTime: Date?
    private var displayLink: CADisplayLink?
    private let thermalManager: ThermalManager

    init(thermalManager: ThermalManager) {
        self.thermalManager = thermalManager
        super.init()
        device = AVCaptureDevice.default(for: .video)
    }

    func start() throws {
        guard let device = device, device.hasTorch else {
            throw LightControlError.torchUnavailable
        }

        try device.lockForConfiguration()
        isLocked = true
    }

    func stop() {
        if let device = device, isLocked {
            device.torchMode = .off
            device.unlockForConfiguration()
            isLocked = false
        }
        cancelExecution()
    }

    func setIntensity(_ intensity: Float) {
        guard let device = device, isLocked else { return }
        
        // Apply thermal limits
        let maxIntensity = thermalManager.maxFlashlightIntensity
        let clampedIntensity = max(0.0, min(maxIntensity, intensity))
        
        try? device.setTorchModeOn(level: clampedIntensity)
    }

    func setColor(_ color: LightEvent.LightColor) {
        // Taschenlampe unterstützt keine Farben
    }

    func execute(script: LightScript, syncedTo startTime: Date) {
        currentScript = script
        scriptStartTime = startTime

        // CADisplayLink für präzises Timing
        displayLink = CADisplayLink(target: self, selector: #selector(updateLight))
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(
                minimum: 60,
                maximum: 120,
                preferred: 120
            )
        } else {
            // Fallback for iOS versions before 15.0
            displayLink?.preferredFramesPerSecond = 120
        }
        displayLink?.add(to: .main, forMode: .common)
    }

    func cancelExecution() {
        displayLink?.invalidate()
        displayLink = nil
        currentScript = nil
        scriptStartTime = nil
        setIntensity(0.0)
    }

    @objc private func updateLight() {
        guard let script = currentScript,
              let startTime = scriptStartTime else {
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Finde aktuelles Event
        if let currentEvent = script.events.first(where: { event in
            elapsed >= event.timestamp && elapsed < event.timestamp + event.duration
        }) {
            setIntensity(currentEvent.intensity)
        } else if elapsed >= script.duration {
            // Script zu Ende
            cancelExecution()
        }
    }
}
