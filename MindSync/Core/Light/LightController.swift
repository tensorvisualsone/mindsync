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
    
    /// Pauses the currently executing light script.
    ///
    /// The light output is turned off while paused, but the current script
    /// position and its timing state are preserved so that execution can be
    /// resumed later via `resumeExecution()`.
    func pauseExecution()
    
    /// Resumes a previously paused light script from its preserved position.
    ///
    /// Light output continues from the point where `pauseExecution()` was
    /// called. If no script is currently paused, implementations may choose
    /// to ignore this call.
    func resumeExecution()
}

enum LightControlError: Error {
    case torchUnavailable
    case configurationFailed
    case thermalShutdown
}
