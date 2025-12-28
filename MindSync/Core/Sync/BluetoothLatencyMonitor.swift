import Foundation
import AVFoundation
import Combine
import os.log

/// Monitors and tracks dynamic Bluetooth audio latency
/// Continuously measures AVAudioSession latency to adjust synchronization
/// between audio playback and light/vibration output
@MainActor
final class BluetoothLatencyMonitor: ObservableObject {
    private let logger = Logger(subsystem: "com.mindsync", category: "BluetoothLatencyMonitor")
    
    /// Published current latency in seconds
    @Published private(set) var currentLatency: TimeInterval = 0.0
    
    /// Published smoothed latency (moving average) for stable synchronization
    @Published private(set) var smoothedLatency: TimeInterval = 0.0
    
    private var monitoringTimer: Timer?
    private var isMonitoring = false
    
    // Moving average for smoothing
    private var latencyHistory: [TimeInterval] = []
    private let historySize = 10 // Keep last 10 measurements
    private let smoothingFactor: Double = 0.8 // 80% old, 20% new
    
    /// Starts continuous latency monitoring
    /// - Parameter interval: Update interval in seconds (default: 1.0)
    func startMonitoring(interval: TimeInterval = 1.0) {
        guard !isMonitoring else {
            logger.warning("BluetoothLatencyMonitor is already monitoring")
            return
        }
        
        isMonitoring = true
        latencyHistory.removeAll()
        
        // Initial measurement
        updateLatency()
        
        // Schedule periodic updates
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateLatency()
            }
        }
        
        logger.info("BluetoothLatencyMonitor started monitoring (interval: \(interval)s)")
    }
    
    /// Stops latency monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        logger.info("BluetoothLatencyMonitor stopped monitoring")
    }
    
    /// Updates latency from AVAudioSession
    private func updateLatency() {
        let session = AVAudioSession.sharedInstance()
        
        // Total latency = output latency + input latency
        // For playback-only scenarios, input latency is typically 0
        let totalLatency = session.outputLatency + session.inputLatency
        
        // Update current latency
        currentLatency = totalLatency
        
        // Update smoothed latency using moving average
        latencyHistory.append(totalLatency)
        if latencyHistory.count > historySize {
            latencyHistory.removeFirst()
        }
        
        // Calculate smoothed value (exponential moving average)
        if self.smoothedLatency == 0.0 {
            self.smoothedLatency = totalLatency
        } else {
            self.smoothedLatency = (self.smoothedLatency * smoothingFactor) + (totalLatency * (1.0 - smoothingFactor))
        }
        
        // Log significant changes (>50ms difference)
        if abs(self.smoothedLatency - totalLatency) > 0.05 {
            logger.info("Latency changed: \(totalLatency * 1000)ms (smoothed: \(self.smoothedLatency * 1000)ms)")
        }
    }
    
    /// Whether monitoring is currently active
    var isActive: Bool {
        isMonitoring
    }
    
    deinit {
        // Cleanup: stop monitoring if still active
        // Note: Timer invalidation is safe to call from deinit
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
}
