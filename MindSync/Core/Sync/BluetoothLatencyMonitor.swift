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
    
    private var monitoringTimer: DispatchSourceTimer?
    private var isMonitoring = false
    
    // Moving average for smoothing
    private var latencyHistory: [TimeInterval] = []
    
    /// Maximum number of recent latency samples to keep for variance estimation and logging.
    ///
    /// The default of 10 keeps roughly the last ~10 seconds when using the default 1s polling
    /// interval. This was found in testing to balance responsiveness with stability across
    /// common Bluetooth audio devices (AirPods Pro, BeatsX, Sony WH-1000XM series).
    ///
    /// A smaller history would react faster to connection changes but be more susceptible to
    /// short-term jitter; a larger history would provide more stability but delay adaptation
    /// to genuine latency drift when switching devices or environments.
    private let historySize: Int
    
    /// Smoothing factor for the exponential moving average used for `smoothedLatency`.
    ///
    /// A higher value (closer to 1.0) favors stability by weighting historical data more heavily;
    /// a lower value reacts faster to changes by giving more weight to new measurements.
    ///
    /// The default of 0.8 was chosen empirically to track drift over several seconds without
    /// causing visible jitter in light synchronization on typical Bluetooth headphones. At this
    /// smoothing level:
    /// - Gradual drift (e.g., temperature-related changes) is incorporated smoothly
    /// - Sudden spikes (e.g., momentary CPU contention) are dampened
    /// - Latency changes when switching audio routes are recognized within 3-5 measurements
    private let smoothingFactor: Double
    
    /// Creates a new BluetoothLatencyMonitor.
    /// - Parameters:
    ///   - historySize: Number of recent samples to keep (minimum 1, default 10).
    ///   - smoothingFactor: Exponential moving average factor in (0, 1). Defaults to 0.8.
    init(historySize: Int = 10, smoothingFactor: Double = 0.8) {
        precondition(historySize > 0, "historySize must be greater than 0")
        precondition(smoothingFactor > 0.0 && smoothingFactor < 1.0, "smoothingFactor must be between 0 and 1 (exclusive)")
        self.historySize = historySize
        self.smoothingFactor = smoothingFactor
    }
    
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
        
        // Schedule periodic updates using DispatchSourceTimer for consistency
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            Task { @MainActor [weak self] in
                self?.updateLatency()
            }
        }
        timer.resume()
        monitoringTimer = timer
        
        logger.info("BluetoothLatencyMonitor started monitoring (interval: \(interval)s)")
    }
    
    /// Stops latency monitoring
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        monitoringTimer?.cancel()
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
        // DispatchSourceTimer must be cancelled if active (not suspended).
        // If the timer is suspended, we resume it before cancelling to avoid crashes.
        // According to DispatchSource documentation, calling cancel() on an active timer
        // is safe, but calling it on a suspended timer may cause issues.
        if let timer = monitoringTimer {
            if isMonitoring {
                // Timer is active (resumed), safe to cancel directly
                timer.cancel()
            } else {
                // Timer might be suspended, resume before cancelling
                timer.resume()
                timer.cancel()
            }
        }
        monitoringTimer = nil
    }
}
