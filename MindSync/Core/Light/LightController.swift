import Foundation

/// Protocol for light control
protocol LightControlling {
    /// Current light source
    var source: LightSource { get }

    /// Starts light output
    func start() throws

    /// Stops light output
    func stop()

    /// Sets intensity (0.0 - 1.0)
    func setIntensity(_ intensity: Float)

    /// Sets color (screen mode only)
    func setColor(_ color: LightEvent.LightColor)

    /// Executes a LightScript
    /// - Parameter script: The LightScript to execute
    /// - Parameter startTime: Reference time for synchronization
    func execute(script: LightScript, syncedTo startTime: Date)

    /// Cancels the current execution
    func cancelExecution()
    
    /// Pauses the current execution (light stays off but script position is preserved)
    func pauseExecution()
    
    /// Resumes the current execution from the paused position
    func resumeExecution()
}

enum LightControlError: Error {
    case torchUnavailable
    case configurationFailed
    case thermalShutdown
}
