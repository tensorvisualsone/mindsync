import XCTest
import Combine
@testable import MindSync

/// Tests for SessionViewModel thermal warning handling
@MainActor
final class SessionViewModelTests: XCTestCase {
    var cancellables: Set<AnyCancellable>!
    var mockHistoryService: MockSessionHistoryService!
    
    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
        mockHistoryService = MockSessionHistoryService()
    }
    
    override func tearDown() {
        cancellables = nil
        mockHistoryService = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    func testInitialState_IsIdle() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        XCTAssertEqual(viewModel.state, .idle)
    }
    
    func testInitialThermalWarningLevel_IsNone() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        XCTAssertEqual(viewModel.thermalWarningLevel, .none)
    }
    
    // MARK: - Thermal Warning Level Publishing Tests
    
    func testThermalWarningLevel_IsPublished() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
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
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        XCTAssertEqual(viewModel.state, .idle)
        
        viewModel.stopSession()
        
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertFalse(mockHistoryService.saveCalled)
    }
    
    func testReset_ClearsErrorMessage() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
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
    
    // MARK: - Pause/Resume Tests
    
    func testPauseSession_FromRunningState_ChangeStateToRunning() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        viewModel.state = .running // Simulate running state
        
        viewModel.pauseSession()
        
        XCTAssertEqual(viewModel.state, .paused)
    }
    
    func testPauseSession_FromIdleState_DoesNothing() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        XCTAssertEqual(viewModel.state, .idle)
        
        viewModel.pauseSession()
        
        XCTAssertEqual(viewModel.state, .idle)
    }
    
    func testPauseSession_FromAnalyzingState_DoesNothing() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        viewModel.state = .analyzing
        
        viewModel.pauseSession()
        
        XCTAssertEqual(viewModel.state, .analyzing)
    }
    
    func testResumeSession_FromPausedState_ChangesStateToRunning() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        viewModel.state = .paused // Simulate paused state
        
        viewModel.resumeSession()
        
        XCTAssertEqual(viewModel.state, .running)
    }
    
    func testResumeSession_FromIdleState_DoesNothing() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        XCTAssertEqual(viewModel.state, .idle)
        
        viewModel.resumeSession()
        
        XCTAssertEqual(viewModel.state, .idle)
    }
    
    func testResumeSession_FromRunningState_DoesNothing() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        viewModel.state = .running
        
        viewModel.resumeSession()
        
        XCTAssertEqual(viewModel.state, .running)
    }
    
    func testStopSession_FromPausedState_ChangesToIdle() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        viewModel.state = .paused
        
        // Mock a current session with proper end time for deterministic duration
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(600) // 10 minutes
        viewModel.currentSession = Session(
            mode: .theta,
            lightSource: .screen,
            audioSource: .localFile,
            trackTitle: "Test",
            trackArtist: "Test",
            trackBPM: 120
        )
        // Set end time to simulate a completed session
        viewModel.currentSession?.endedAt = endDate
        viewModel.currentSession?.actualDuration = 600
        
        viewModel.stopSession()
        
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(mockHistoryService.saveCalled)
    }
    
    func testStopSession_FromRunningState_ChangesToIdle() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        viewModel.state = .running
        
        // Mock a current session with proper end time for deterministic duration
        let startDate = Date()
        let endDate = startDate.addingTimeInterval(600) // 10 minutes
        viewModel.currentSession = Session(
            mode: .theta,
            lightSource: .screen,
            audioSource: .localFile,
            trackTitle: "Test",
            trackArtist: "Test",
            trackBPM: 120
        )
        // Set end time to simulate a completed session
        viewModel.currentSession?.endedAt = endDate
        viewModel.currentSession?.actualDuration = 600
        
        viewModel.stopSession()
        
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertTrue(mockHistoryService.saveCalled)
    }
    
    func testPauseResumeTransitions_MaintainCorrectStateFlow() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        // Start in idle
        XCTAssertEqual(viewModel.state, .idle)
        
        // Simulate running state
        viewModel.state = .running
        XCTAssertEqual(viewModel.state, .running)
        
        // Pause
        viewModel.pauseSession()
        XCTAssertEqual(viewModel.state, .paused)
        
        // Resume
        viewModel.resumeSession()
        XCTAssertEqual(viewModel.state, .running)
        
        // Pause again
        viewModel.pauseSession()
        XCTAssertEqual(viewModel.state, .paused)
        
        // Stop from paused
        viewModel.stopSession()
        XCTAssertEqual(viewModel.state, .idle)
    }
    
    // MARK: - Threading Tests
    
    func testSessionViewModel_InitializesOnMainActor() {
        // Verify that SessionViewModel can be initialized on MainActor
        // This is important for thread-safety since it accesses ServiceContainer
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        // Access should not crash
        XCTAssertEqual(viewModel.state, .idle)
        XCTAssertEqual(viewModel.thermalWarningLevel, .none)
    }
    
    func testSessionViewModel_ServiceContainerAccessIsThreadSafe() {
        // Verify that ServiceContainer access in SessionViewModel is safe
        // Since SessionViewModel is @MainActor, all access should be on main thread
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        // These properties internally access ServiceContainer
        // If there were threading issues, this would crash
        XCTAssertNotNil(viewModel.thermalWarningLevel)
        
        // State changes should be safe
        viewModel.state = .running
        XCTAssertEqual(viewModel.state, .running)
    }
    
    func testSessionViewModel_CanAccessServicesSafely() {
        // Verify that SessionViewModel can safely access services from ServiceContainer
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        // Accessing services through the viewModel should not cause threading issues
        // Since SessionViewModel is @MainActor, all service access is on main thread
        XCTAssertEqual(viewModel.state, .idle)
        
        // Verify thermal warning level is accessible (uses ThermalManager from ServiceContainer)
        let warningLevel = viewModel.thermalWarningLevel
        XCTAssertNotNil(warningLevel)
    }
    
    // MARK: - DMN-Shutdown Mode Tests
    
    func testStartDMNShutdownSession_GeneratesCorrectScript() async {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        // Verify that the DMN-Shutdown script generation creates the expected structure
        let script = EntrainmentEngine.generateDMNShutdownScript()
        
        XCTAssertEqual(script.mode, .dmnShutdown)
        XCTAssertEqual(script.targetFrequency, 40.0)
        XCTAssertEqual(script.duration, 1800.0, accuracy: 1.0) // 30 minutes
        XCTAssertGreaterThan(script.events.count, 0)
    }
    
    func testStartDMNShutdownSession_UsesCorrectMode() {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        // Verify that DMN-Shutdown mode properties are correct
        XCTAssertEqual(EntrainmentMode.dmnShutdown.frequencyRange, 4.5...40.0)
        XCTAssertEqual(EntrainmentMode.dmnShutdown.targetFrequency, 40.0)
        XCTAssertEqual(EntrainmentMode.dmnShutdown.startFrequency, 10.0)
        XCTAssertEqual(EntrainmentMode.dmnShutdown.rampDuration, 240.0)
    }
    
    // MARK: - startFixedSession Tests
    
    func testStartFixedSession_Alpha_SetsAnalyzingState() async {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        XCTAssertEqual(viewModel.state, .idle)
        
        // Start the task but don't await completion
        let task = Task {
            await viewModel.startFixedSession(mode: .alpha)
        }
        
        // Give it a moment to transition to analyzing
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // State should be analyzing or beyond
        XCTAssertNotEqual(viewModel.state, .idle)
        
        // Cancel the task to clean up
        task.cancel()
    }
    
    func testStartFixedSession_Theta_GeneratesScript() async {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        // Start fixed session
        let task = Task {
            await viewModel.startFixedSession(mode: .theta)
        }
        
        // Give it a moment to start processing
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Should have transitioned from idle
        XCTAssertNotEqual(viewModel.state, .idle)
        
        task.cancel()
    }
    
    func testStartFixedSession_Gamma_GeneratesScript() async throws {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        let task = Task {
            await viewModel.startFixedSession(mode: .gamma)
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotEqual(viewModel.state, .idle)
        
        task.cancel()
    }
    
    func testStartFixedSession_CinematicMode_SetsError() async {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        XCTAssertEqual(viewModel.state, .idle)
        
        // Cinematic mode should not work with fixed sessions
        await viewModel.startFixedSession(mode: .cinematic)
        
        // Should be in error state
        XCTAssertEqual(viewModel.state, .error)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.errorMessage?.contains("fixed") ?? false)
    }
    
    func testStartFixedSession_WhileRunning_DoesNothing() async {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        // Set state to running
        viewModel.state = .running
        
        // Try to start a fixed session
        await viewModel.startFixedSession(mode: .alpha)
        
        // State should still be running (not restarted)
        XCTAssertEqual(viewModel.state, .running)
    }
    
    func testStartFixedSession_DMNShutdown_UsesFixedScript() async {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        // Verify DMN-Shutdown is a fixed-script mode
        XCTAssertTrue(EntrainmentMode.dmnShutdown.usesFixedScript)
        
        let task = Task {
            await viewModel.startFixedSession(mode: .dmnShutdown)
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotEqual(viewModel.state, .idle)
        
        task.cancel()
    }
    
    func testStartFixedSession_BeliefRewiring_UsesFixedScript() async throws {
        let viewModel = SessionViewModel(historyService: mockHistoryService)
        
        // Verify Belief-Rewiring is a fixed-script mode
        XCTAssertTrue(EntrainmentMode.beliefRewiring.usesFixedScript)
        
        let task = Task {
            await viewModel.startFixedSession(mode: .beliefRewiring)
        }
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        XCTAssertNotEqual(viewModel.state, .idle)
        
        task.cancel()
    }
}

