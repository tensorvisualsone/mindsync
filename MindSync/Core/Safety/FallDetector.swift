import Foundation
import CoreMotion
import Combine
import os.log

/// Service for detecting device falls using accelerometer data
final class FallDetector {
    private let motionManager = CMMotionManager()
    private let fallAccelerationThreshold: Double = SafetyLimits.fallAccelerationThreshold // 2.0g
    private let freefallThreshold: Double = SafetyLimits.freefallThreshold // 0.3g
    
    // Publisher for fall events
    let fallEventPublisher = PassthroughSubject<Void, Never>()
    
    private var isMonitoring = false
    private let logger = Logger(subsystem: "com.mindsync", category: "FallDetector")
    
    // Filtering to reduce false positives
    private var recentAccelerations: [Double] = []
    private let filterWindowSize = 5 // Number of samples to average
    
    init() {
        // Configure motion manager
        motionManager.accelerometerUpdateInterval = 1.0 / 20.0 // 20 Hz
    }
    
    /// Starts fall detection monitoring
    /// - Note: Only activates accelerometer when monitoring starts to save battery
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        guard motionManager.isAccelerometerAvailable else {
            logger.warning("Accelerometer not available on this device")
            return
        }
        
        isMonitoring = true
        recentAccelerations.removeAll()
        
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, error in
            guard let self = self, self.isMonitoring else { return }
            
            if let error = error {
                self.logger.error("Accelerometer error: \(error.localizedDescription, privacy: .public)")
                return
            }
            
            guard let acceleration = data?.acceleration else { return }
            
            // Calculate magnitude of acceleration vector
            let magnitude = sqrt(
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z
            )
            
            // Convert to g-force (1g = 9.81 m/s², but iOS already provides in g)
            let gForce = magnitude
            
            // Add to filter window
            self.recentAccelerations.append(gForce)
            if self.recentAccelerations.count > self.filterWindowSize {
                self.recentAccelerations.removeFirst()
            }
            
            // Calculate filtered (averaged) acceleration
            let filteredAcceleration = self.recentAccelerations.reduce(0, +) / Double(self.recentAccelerations.count)
            
            // Detect fall: sudden high acceleration (impact)
            if filteredAcceleration >= self.fallAccelerationThreshold {
                self.logger.warning("Fall detected: \(filteredAcceleration, privacy: .public) g")
                self.fallEventPublisher.send()
                // Stop monitoring after fall detection to prevent multiple events
                self.stopMonitoring()
            }
            
            // Optional: Detect freefall (very low acceleration)
            // This can indicate device is falling before impact
            if filteredAcceleration < self.freefallThreshold && self.recentAccelerations.count >= self.filterWindowSize {
                // Freefall detected - could be used for early warning
                // For now, we only detect impact (fallAccelerationThreshold)
            }
        }
        
        logger.info("Fall detection monitoring started")
    }
    
    /// Stops fall detection monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        motionManager.stopAccelerometerUpdates()
        isMonitoring = false
        recentAccelerations.removeAll()
        
        logger.info("Fall detection monitoring stopped")
    }
    
    /// Whether monitoring is currently active
    var isActive: Bool {
        isMonitoring
    }
    
    deinit {
        stopMonitoring()
    }
}
