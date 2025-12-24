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
        
        // Apply thermal limits
        let maxIntensity = thermalManager.maxFlashlightIntensity
        let clampedIntensity = max(0.0, min(maxIntensity, intensity))
        
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
        guard currentScript != nil, scriptStartTime != nil else { return }
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
            // Current event is active
            setIntensity(event.intensity)
        } else {
            // Between events or no active event, turn off
            setIntensity(0.0)
        }
    }
}
