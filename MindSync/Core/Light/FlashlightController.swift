import Foundation
import AVFoundation
import os.log

extension Notification.Name {
    static let mindSyncTorchFailed = Notification.Name("com.mindsync.notifications.torchFailed")
}

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

    private lazy var device: AVCaptureDevice? = {
        // Lazy initialization to avoid crashes during app startup
        // AVCaptureDevice.default can fail if called too early
        return AVCaptureDevice.default(for: .video)
    }()
    private var isLocked = false
    private var displayLinkTarget: WeakDisplayLinkTarget?
    private let thermalManager: ThermalManager
    private let logger = Logger(subsystem: "com.mindsync", category: "FlashlightController")
    private var torchFailureNotified = false

    init(thermalManager: ThermalManager) {
        self.thermalManager = thermalManager
        super.init()
        // Device is now lazy-initialized when first accessed
    }

    func start() async throws {
        guard let device = device, device.hasTorch else {
            throw LightControlError.torchUnavailable
        }
        
        let attempts = 3
        var lastError: Error?
        
        for attempt in 1...attempts {
            do {
                try device.lockForConfiguration()
                isLocked = true
                torchFailureNotified = false
                return
            } catch {
                lastError = error
                logger.error("Torch lock failed (attempt \(attempt)/\(attempts)): \(error.localizedDescription, privacy: .public)")
                // Exponential backoff before retrying: 40ms, 80ms, 120ms for attempts 1-3
                if attempt < attempts {
                    try? await Task.sleep(nanoseconds: UInt64(0.04 * Double(attempt) * 1_000_000_000))
                }
            }
        }
        
        if let lastError {
            logger.error("All \(attempts) torch lock attempts failed. Last error: \(lastError.localizedDescription, privacy: .public)")
        }
        throw LightControlError.configurationFailed
    }

    func stop() {
        if let device = device, isLocked {
            device.torchMode = .off
            device.unlockForConfiguration()
            isLocked = false
        }
        torchFailureNotified = false
        cancelExecution()
    }

    func setIntensity(_ intensity: Float) {
        guard let device = device, isLocked else { return }
        
        if thermalManager.maxFlashlightIntensity <= 0 {
            handleTorchSystemShutdown(error: LightControlError.thermalShutdown)
            return
        }
        
        // Gamma 2.2 Korrektur für natürliche Wahrnehmung
        // Das menschliche Auge funktioniert logarithmisch, daher wirken 50% LED-Power
        // wie 70-80% Helligkeit. Die Gamma-Korrektur macht Fades weicher und organischer.
        let perceptionCorrected = pow(intensity, 2.2)
        
        // Apply thermal limits
        let maxIntensity = thermalManager.maxFlashlightIntensity
        let clampedIntensity = max(0.0, min(maxIntensity, perceptionCorrected))
        
        do {
            if clampedIntensity <= 0 {
                device.torchMode = .off
            } else {
                try device.setTorchModeOn(level: clampedIntensity)
            }
        } catch {
            handleTorchSystemShutdown(error: error)
        }
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
    
    // MARK: - Helpers
    
    /// Handles torch system shutdown and notifies observers.
    ///
    /// This method is called when the torch fails during operation. The `torchFailureNotified` flag
    /// prevents duplicate notifications for the same failure event.
    ///
    /// - Parameter error: The error that caused the shutdown, if available.
    ///
    /// - Note: The `torchFailureNotified` flag is reset in two scenarios:
    ///   1. When `stop()` is called (user manually stops the session)
    ///   2. When `start()` succeeds (new session begins successfully)
    ///   This ensures that each new session can properly report torch failures, while preventing
    ///   duplicate notifications within a single session.
    ///
    /// - Note: Thread Safety
    ///   This method accesses and modifies `torchFailureNotified` without explicit synchronization.
    ///   The expected threading model is that all torch operations (`setIntensity`, `start`, `stop`)
    ///   are called from the main thread via CADisplayLink. If this assumption changes and multiple
    ///   threads can call torch methods concurrently, consider adding synchronization (e.g., making
    ///   FlashlightController an actor or using a lock) to prevent race conditions on the flag.
    private func handleTorchSystemShutdown(error: Error?) {
        guard !torchFailureNotified else { return }
        torchFailureNotified = true
        
        if let error {
            logger.error("Torch shutdown detected: \(error.localizedDescription, privacy: .public)")
        } else {
            logger.error("Torch shutdown detected without explicit error")
        }
        
        if let device = device, isLocked {
            device.torchMode = .off
            device.unlockForConfiguration()
            isLocked = false
        }
        
        cancelExecution()
        NotificationCenter.default.post(name: .mindSyncTorchFailed, object: error)
    }
}
