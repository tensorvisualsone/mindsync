import XCTest
@testable import MindSync

@MainActor
final class BluetoothLatencyMonitorTests: XCTestCase {
    
    var monitor: BluetoothLatencyMonitor!
    
    override func setUp() async throws {
        try await super.setUp()
        monitor = BluetoothLatencyMonitor()
    }
    
    override func tearDown() async throws {
        monitor.stopMonitoring()
        monitor = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitializationWithDefaults() {
        let monitor = BluetoothLatencyMonitor()
        XCTAssertEqual(monitor.currentLatency, 0.0)
        XCTAssertEqual(monitor.smoothedLatency, 0.0)
        XCTAssertFalse(monitor.isActive)
    }
    
    func testInitializationWithCustomParameters() {
        let monitor = BluetoothLatencyMonitor(historySize: 5, smoothingFactor: 0.9)
        XCTAssertEqual(monitor.currentLatency, 0.0)
        XCTAssertEqual(monitor.smoothedLatency, 0.0)
        XCTAssertFalse(monitor.isActive)
    }
    
    func testInitializationPreconditions() {
        // Test invalid historySize (should crash in debug, but we can't test that)
        // Just document expected behavior
        
        // Test invalid smoothingFactor (should crash in debug)
        // Expected: precondition failure for historySize <= 0
        // Expected: precondition failure for smoothingFactor <= 0 or >= 1
    }
    
    // MARK: - Monitoring Start/Stop Tests
    
    func testStartMonitoring() async throws {
        monitor.startMonitoring(interval: 0.1)
        
        // Wait a moment for initial measurement
        try await Task.sleep(nanoseconds: 150_000_000) // 150ms
        
        XCTAssertTrue(monitor.isActive)
        // Current latency should be measured (likely small value from AVAudioSession)
        // We can't assert exact value as it depends on system state
        XCTAssertGreaterThanOrEqual(monitor.currentLatency, 0.0)
    }
    
    func testStopMonitoring() async throws {
        monitor.startMonitoring(interval: 0.1)
        try await Task.sleep(nanoseconds: 150_000_000)
        
        monitor.stopMonitoring()
        
        XCTAssertFalse(monitor.isActive)
    }
    
    func testStartMonitoringWhenAlreadyMonitoring() async throws {
        monitor.startMonitoring(interval: 0.1)
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Starting again should be safe (logs warning but doesn't crash)
        monitor.startMonitoring(interval: 0.1)
        
        XCTAssertTrue(monitor.isActive)
    }
    
    func testStopMonitoringWhenNotMonitoring() {
        // Should be safe to call stop when not monitoring
        monitor.stopMonitoring()
        XCTAssertFalse(monitor.isActive)
    }
    
    // MARK: - Latency Measurement Tests
    
    func testLatencyMeasurement() async throws {
        monitor.startMonitoring(interval: 0.1)
        
        // Wait for several measurements
        try await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        // Should have non-zero latency (from AVAudioSession)
        // Typical values are 0.001-0.1 seconds depending on audio route
        XCTAssertGreaterThanOrEqual(monitor.currentLatency, 0.0)
        XCTAssertLessThan(monitor.currentLatency, 1.0) // Sanity check
        
        // Smoothed latency should also be set
        XCTAssertGreaterThanOrEqual(monitor.smoothedLatency, 0.0)
    }
    
    func testSmoothedLatencyInitialization() async throws {
        monitor.startMonitoring(interval: 0.1)
        
        // Wait for first measurement
        try await Task.sleep(nanoseconds: 150_000_000)
        
        // First measurement should set smoothed latency to current value
        // (when smoothedLatency starts at 0)
        XCTAssertEqual(monitor.smoothedLatency, monitor.currentLatency, accuracy: 0.001)
    }
    
    func testSmoothedLatencyConvergence() async throws {
        monitor.startMonitoring(interval: 0.05)
        
        // Wait for multiple measurements to allow smoothing
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms = ~10 measurements
        
        // Smoothed value should be reasonably close to current value
        // With smoothing factor 0.8, it takes ~10 measurements to converge
        let difference = abs(monitor.smoothedLatency - monitor.currentLatency)
        XCTAssertLessThan(difference, 0.02) // Within 20ms
    }
    
    // MARK: - Published Property Tests
    
    func testPublishedProperties() async throws {
        let expectation = XCTestExpectation(description: "Latency updates")
        var updateCount = 0
        
        let cancellable = monitor.$currentLatency
            .dropFirst() // Skip initial value
            .sink { _ in
                updateCount += 1
                if updateCount >= 2 {
                    expectation.fulfill()
                }
            }
        
        monitor.startMonitoring(interval: 0.1)
        
        await fulfillment(of: [expectation], timeout: 1.0)
        cancellable.cancel()
        
        XCTAssertGreaterThanOrEqual(updateCount, 2)
    }
    
    // MARK: - Edge Cases
    
    func testVeryShortMonitoringInterval() async throws {
        // Test with very short interval (stress test)
        monitor.startMonitoring(interval: 0.01) // 10ms
        
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        XCTAssertTrue(monitor.isActive)
        // Should still function correctly
        XCTAssertGreaterThanOrEqual(monitor.currentLatency, 0.0)
        
        monitor.stopMonitoring()
    }
    
    func testVeryLongMonitoringInterval() async throws {
        // Test with very long interval
        monitor.startMonitoring(interval: 5.0) // 5 seconds
        
        try await Task.sleep(nanoseconds: 200_000_000) // 200ms
        
        // Should have initial measurement
        XCTAssertTrue(monitor.isActive)
        XCTAssertGreaterThanOrEqual(monitor.currentLatency, 0.0)
        
        monitor.stopMonitoring()
    }
    
    // MARK: - Cleanup Tests
    
    func testDeinitWhileMonitoring() async throws {
        var monitor: BluetoothLatencyMonitor? = BluetoothLatencyMonitor()
        monitor?.startMonitoring(interval: 0.1)
        
        try await Task.sleep(nanoseconds: 150_000_000)
        
        // Deinit should clean up timer safely
        monitor = nil
        
        // If we get here without crashing, cleanup worked
        XCTAssertNil(monitor)
    }
    
    func testDeinitWhileNotMonitoring() {
        var monitor: BluetoothLatencyMonitor? = BluetoothLatencyMonitor()
        
        // Deinit without ever starting monitoring
        monitor = nil
        
        XCTAssertNil(monitor)
    }
}
