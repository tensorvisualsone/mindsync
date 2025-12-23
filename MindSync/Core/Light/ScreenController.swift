import Foundation

/// Placeholder for screen strobe control
/// Will be implemented in Phase 7 (US5)
final class ScreenController: LightControlling {
    var source: LightSource { .screen }
    
    func start() throws {
        // TODO: Implement Phase 7
    }
    
    func stop() {
        // TODO: Implement Phase 7
    }
    
    func setIntensity(_ intensity: Float) {
        // TODO: Implement Phase 7
    }
    
    func setColor(_ color: LightEvent.LightColor) {
        // TODO: Implement Phase 7
    }
    
    func execute(script: LightScript, syncedTo startTime: Date) {
        // TODO: Implement Phase 7
    }
    
    func cancelExecution() {
        // TODO: Implement Phase 7
    }
}
