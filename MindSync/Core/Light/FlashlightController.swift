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
final class FlashlightController: NSObject, LightControlling {
    var source: LightSource { .flashlight }

    private var device: AVCaptureDevice?
    private var isLocked = false
    private var currentScript: LightScript?
    private var scriptStartTime: Date?
    private var displayLink: CADisplayLink?
    private var displayLinkTarget: WeakDisplayLinkTarget?
    private var currentEventIndex: Int = 0
    private let thermalManager: ThermalManager

    init(thermalManager: ThermalManager) {
        self.thermalManager = thermalManager
        super.init()
        device = AVCaptureDevice.default(for: .video)
    }
    
    deinit {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
    }

    func start() throws {
        guard let device = device, device.hasTorch else {
            throw LightControlError.torchUnavailable
        }

        do {
            try device.lockForConfiguration()
            isLocked = true
        } catch {
            // Ensure device isn't left in an inconsistent state
            isLocked = false
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
        currentScript = script
        scriptStartTime = startTime
        currentEventIndex = 0

        // CADisplayLink for precise timing with weak reference wrapper to avoid retain cycle
        let target = WeakDisplayLinkTarget(target: self)
        displayLinkTarget = target
        displayLink = CADisplayLink(target: target, selector: #selector(WeakDisplayLinkTarget.updateLight))
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
        displayLinkTarget = nil
        currentScript = nil
        scriptStartTime = nil
        currentEventIndex = 0
        setIntensity(0.0)
    }

    fileprivate func updateLight() {
        guard let script = currentScript,
              let startTime = scriptStartTime else {
            return
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // Check if script is finished
        if elapsed >= script.duration {
            cancelExecution()
            return
        }

        // Skip past events to find current event using index tracking
        while currentEventIndex < script.events.count {
            let event = script.events[currentEventIndex]
            let eventEnd = event.timestamp + event.duration
            
            if elapsed < eventEnd {
                // Current event is active
                if elapsed >= event.timestamp {
                    setIntensity(event.intensity)
                } else {
                    // Between events, turn off
                    setIntensity(0.0)
                }
                break
            } else {
                // Move to next event
                currentEventIndex += 1
            }
        }
        
        // If we've passed all events, turn off
        if currentEventIndex >= script.events.count {
            setIntensity(0.0)
        }
    }
}
