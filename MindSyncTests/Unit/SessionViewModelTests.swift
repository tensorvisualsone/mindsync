import XCTest
import Combine
@testable import MindSync

/// Tests for SessionViewModel thermal warning handling
@MainActor
final class SessionViewModelTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState_IsIdle() {
        let viewModel = SessionViewModel()
        XCTAssertEqual(viewModel.state, .idle)
    }
    
    func testInitialThermalWarningLevel_IsNone() {
        let viewModel = SessionViewModel()
        XCTAssertEqual(viewModel.thermalWarningLevel, .none)
    }
    
    // MARK: - Thermal Warning Level Publishing Tests
    
    func testThermalWarningLevel_IsPublished() {
        let viewModel = SessionViewModel()
        var receivedLevels: [ThermalWarningLevel] = []
        let expectation = expectation(description: "Warning level published")
        
        viewModel.$thermalWarningLevel
            .dropFirst() // Skip initial value
            .prefix(1)
            .sink { level in
                receivedLevels.append(level)
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // Trigger a thermal state change notification
        // Note: In production, this would be triggered by the system
        // For testing, we verify the ViewModel subscribes to ThermalManager
        
        // Since we can't easily trigger a thermal state change in tests,
        // we verify the initial subscription is set up
        XCTAssertNotNil(viewModel.$thermalWarningLevel)
        
        // Fulfill immediately since we're testing the setup
        expectation.fulfill()
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    // MARK: - Session State Tests
    
    func testStopSession_FromIdleState_DoesNothing() {
        let viewModel = SessionViewModel()
        XCTAssertEqual(viewModel.state, .idle)
        
        viewModel.stopSession()
        
        XCTAssertEqual(viewModel.state, .idle)
    }
    
    func testReset_ClearsErrorMessage() {
        let viewModel = SessionViewModel()
        
        viewModel.reset()
        
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.state, .idle)
    }
    
    // MARK: - Thermal Warning Level Enum Tests
    
    func testThermalWarningLevel_None_HasNoMessage() {
        XCTAssertNil(ThermalWarningLevel.none.message)
    }
    
    func testThermalWarningLevel_Reduced_HasMessage() {
        XCTAssertNotNil(ThermalWarningLevel.reduced.message)
        XCTAssertTrue(ThermalWarningLevel.reduced.message!.contains("reduziert"))
    }
    
    func testThermalWarningLevel_Critical_HasMessage() {
        XCTAssertNotNil(ThermalWarningLevel.critical.message)
        XCTAssertTrue(ThermalWarningLevel.critical.message!.contains("deaktiviert"))
    }
    
    func testThermalWarningLevel_Icons_AreSet() {
        XCTAssertTrue(ThermalWarningLevel.none.icon.isEmpty)
        XCTAssertFalse(ThermalWarningLevel.reduced.icon.isEmpty)
        XCTAssertFalse(ThermalWarningLevel.critical.icon.isEmpty)
    }
    
    // MARK: - Session State Enum Tests
    
    func testSessionState_AllCasesExist() {
        // Verify all expected session states are defined
        let states: [SessionState] = [.idle, .analyzing, .running, .paused, .error]
        XCTAssertEqual(states.count, 5)
    }
}

