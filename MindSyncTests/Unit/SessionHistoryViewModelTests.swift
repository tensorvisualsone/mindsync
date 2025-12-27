import XCTest
import Combine
@testable import MindSync

@MainActor
final class SessionHistoryViewModelTests: XCTestCase {
    var viewModel: SessionHistoryViewModel!
    var mockService: MockSessionHistoryService!
    var cancellables: Set<AnyCancellable>!
    
    override func setUp() {
        super.setUp()
        mockService = MockSessionHistoryService()
        viewModel = SessionHistoryViewModel(historyService: mockService)
        cancellables = []
    }
    
    override func tearDown() {
        viewModel = nil
        mockService = nil
        cancellables = nil
        super.tearDown()
    }
    
    func testInitializationLoadsSessions() async throws {
        // Given
        let session = createTestSession()
        mockService.savedSessions = [session]
        
        // When
        // Create a fresh viewModel for this test to ensure clean state
        let testViewModel = SessionHistoryViewModel(historyService: mockService)
        
        // Give the Combine pipeline a moment to settle
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Then
        XCTAssertTrue(mockService.loadAllCalled)
        XCTAssertEqual(testViewModel.sessions.count, 1)
        XCTAssertEqual(testViewModel.sessions.first?.id, session.id)
    }
    
    func testClearHistory() {
        // Given
        let session = createTestSession()
        mockService.savedSessions = [session]
        viewModel.loadSessions()
        
        // When
        viewModel.clearHistory()
        
        // Then
        XCTAssertTrue(mockService.clearAllCalled)
        XCTAssertTrue(viewModel.sessions.isEmpty)
    }
    
    func testFilteringByMode() {
        // Given
        let thetaSession = createTestSession(mode: .theta)
        let gammaSession = createTestSession(mode: .gamma)
        mockService.savedSessions = [thetaSession, gammaSession]
        viewModel.loadSessions()
        
        // When
        viewModel.selectedModeFilter = .theta
        
        // Then (Async wait for publisher)
        let expectation = XCTestExpectation(description: "Filtering updates")
        
        viewModel.$filteredSessions
            .dropFirst() // Skip initial value
            .sink { sessions in
                if sessions.count == 1 && sessions.first?.mode == .theta {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        wait(for: [expectation], timeout: 1.0)
    }
    
    func testTotalDurationCalculation() {
        // Given
        let session1 = createTestSession(duration: 3600) // 1 hour
        let session2 = createTestSession(duration: 1800) // 30 min
        mockService.savedSessions = [session1, session2]
        viewModel.loadSessions()
        
        // Then
        XCTAssertEqual(viewModel.totalDuration, 5400)
        XCTAssertEqual(viewModel.formattedTotalDuration(), "1h 30m")
    }
    
    // Helper
    private func createTestSession(mode: EntrainmentMode = .theta, duration: TimeInterval = 600) -> Session {
        let startDate = Date()
        var session = Session(
            startedAt: startDate,
            mode: mode,
            lightSource: .screen,
            audioSource: .localFile,
            trackTitle: "Test Track",
            trackArtist: "Test Artist",
            trackBPM: 120.0
        )
        // Set end time and duration for deterministic testing
        session.endedAt = startDate.addingTimeInterval(duration)
        session.actualDuration = duration
        session.endReason = .userStopped
        return session
    }
}
