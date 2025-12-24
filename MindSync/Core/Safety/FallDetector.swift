import Foundation
import CoreMotion
import Combine
import os.log

/// Service for detecting device falls using accelerometer data
final class FallDetector {
    private let motionManager = CMMotionManager()
    private let fallAccelerationThreshold: Double = SafetyLimits.fallAccelerationThreshold // 2.0g
    private let processingQueue = OperationQueue()
    
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
        
        // Configure processing queue for background accelerometer processing
        processingQueue.maxConcurrentOperationCount = 1
        processingQueue.qualityOfService = .userInitiated
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
        
        motionManager.startAccelerometerUpdates(to: processingQueue) { [weak self] data, error in
            guard let self = self, self.isMonitoring else { return }
            
            if let error = error {
                self.logger.error("Accelerometer error: \(error.localizedDescription, privacy: .public)")
                return
            }
            
            guard let acceleration = data?.acceleration else { return }
            
            // Calculate magnitude of acceleration vector
            // Note: CMAccelerometerData provides acceleration in g-forces (1g = 9.81 m/s²)
            // where 1g is Earth's gravitational acceleration
            let magnitude = sqrt(
                acceleration.x * acceleration.x +
                acceleration.y * acceleration.y +
                acceleration.z * acceleration.z
            )
            
            // The magnitude is already in g-forces as provided by iOS
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
                // Dispatch fall event to main queue since it will trigger UI updates
                DispatchQueue.main.async {
                    self.fallEventPublisher.send()
                }
                // Stop monitoring after fall detection to prevent multiple events
                self.stopMonitoring()
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
