import Foundation
import AVFoundation

/// Weak reference wrapper for CADisplayLink target to avoid retain cycles
private final class WeakDisplayLinkTarget {
    weak var target: FlashlightController?
    
    init(target: FlashlightController) {
        self.target = target
    }
    
    @objc func updateLight() {
        target?.updateLight()
    }
}

/// Controller for flashlight control
final class FlashlightController: BaseLightController, LightControlling {
    var source: LightSource { .flashlight }

    private var device: AVCaptureDevice?
    private var isLocked = false
    private var displayLinkTarget: WeakDisplayLinkTarget?
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

        var didLockConfiguration = false
        defer {
            isLocked = didLockConfiguration
        }

        do {
            try device.lockForConfiguration()
            didLockConfiguration = true
        } catch {
            throw LightControlError.configurationFailed
        }
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
        
        // Gamma 2.2 Korrektur für natürliche Wahrnehmung
        // Das menschliche Auge funktioniert logarithmisch, daher wirken 50% LED-Power
        // wie 70-80% Helligkeit. Die Gamma-Korrektur macht Fades weicher und organischer.
        let perceptionCorrected = pow(intensity, 2.2)
        
        // Apply thermal limits
        let maxIntensity = thermalManager.maxFlashlightIntensity
        let clampedIntensity = max(0.0, min(maxIntensity, perceptionCorrected))
        
        try? device.setTorchModeOn(level: clampedIntensity)
    }

    func setColor(_ color: LightEvent.LightColor) {
        // Flashlight does not support colors
    }

    func execute(script: LightScript, syncedTo startTime: Date) {
        initializeScriptExecution(script: script, startTime: startTime)

        // CADisplayLink for precise timing with weak reference wrapper to avoid retain cycle
        let target = WeakDisplayLinkTarget(target: self)
        displayLinkTarget = target
        setupDisplayLink(target: target, selector: #selector(WeakDisplayLinkTarget.updateLight))
    }

    func cancelExecution() {
        invalidateDisplayLink()
        displayLinkTarget = nil
        resetScriptExecution()
        setIntensity(0.0)
    }
    
    func pauseExecution() {
        pauseScriptExecution()
        displayLinkTarget = nil
        setIntensity(0.0)
    }
    
    func resumeExecution() {
        guard let _ = currentScript, let _ = scriptStartTime else { return }
        resumeScriptExecution()
        // Re-setup display link
        let target = WeakDisplayLinkTarget(target: self)
        displayLinkTarget = target
        setupDisplayLink(target: target, selector: #selector(WeakDisplayLinkTarget.updateLight))
    }

    fileprivate func updateLight() {
        let result = findCurrentEvent()
        
        if result.isComplete {
            cancelExecution()
            return
        }
        
        if let event = result.event {
            // Check if cinematic mode - apply dynamic intensity modulation
            let intensity: Float
            if let script = currentScript, script.mode == .cinematic {
                // Get audio energy and calculate dynamic intensity
                let audioEnergy = audioEnergyTracker?.currentEnergy ?? 0.0
                let baseFreq = script.targetFrequency
                let elapsed = result.elapsed
                
                // Calculate cinematic intensity
                let cinematicIntensity = EntrainmentEngine.calculateCinematicIntensity(
                    baseFrequency: baseFreq,
                    currentTime: elapsed,
                    audioEnergy: audioEnergy
                )
                
                // Multiply base event intensity with cinematic modulation
                intensity = event.intensity * cinematicIntensity
            } else {
                intensity = event.intensity
            }
            
            // Current event is active
            setIntensity(intensity)
        } else {
            // Between events or no active event, turn off
            setIntensity(0.0)
        }
    }
}
