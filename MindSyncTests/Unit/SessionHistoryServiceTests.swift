import XCTest
@testable import MindSync

final class SessionHistoryServiceTests: XCTestCase {
    var service: SessionHistoryService!
    
    override func setUp() {
        super.setUp()
        service = SessionHistoryService()
        // Clear any existing data before each test
        service.clearAll()
    }
    
    override func tearDown() {
        // Clean up after each test
        service.clearAll()
        service = nil
        super.tearDown()
    }
    
    // MARK: - Save Tests
    
    func testSaveSession_WithNewSession_SavesSuccessfully() {
        // Given: A new session
        let session = Session(
            mode: .alpha,
            lightSource: .flashlight,
            audioSource: .localFile,
            trackTitle: "Test Track",
            trackArtist: "Test Artist",
            trackBPM: 120.0
        )
        
        // When
        service.save(session: session)
        
        // Then: Session should be saved
        let loadedSessions = service.loadAll()
        XCTAssertEqual(loadedSessions.count, 1, "Expected one saved session")
        XCTAssertEqual(loadedSessions.first?.id, session.id, "Session ID should match")
    }
    
    func testSaveSession_WithMultipleSessions_SavesAll() {
        // Given: Multiple sessions
        let session1 = Session(mode: .alpha, lightSource: .flashlight, audioSource: .localFile)
        let session2 = Session(mode: .gamma, lightSource: .screen, audioSource: .microphone)
        let session3 = Session(mode: .theta, lightSource: .flashlight, audioSource: .localFile)
        
        // When
        service.save(session: session1)
        service.save(session: session2)
        service.save(session: session3)
        
        // Then: All sessions should be saved
        let loadedSessions = service.loadAll()
        XCTAssertEqual(loadedSessions.count, 3, "Expected three saved sessions")
    }
    
    func testSaveSession_WithMoreThan100Sessions_LimitsTo100() {
        // Given: 105 sessions
        for i in 0..<105 {
            let session = Session(
                mode: .alpha,
                lightSource: .flashlight,
                audioSource: .localFile,
                trackTitle: "Track \(i)"
            )
            service.save(session: session)
        }
        
        // Then: Should only keep last 100 sessions
        let loadedSessions = service.loadAll()
        XCTAssertEqual(loadedSessions.count, 100, "Expected exactly 100 sessions")
        
        // Verify it kept the most recent ones (oldest kept = Track 5, newest = Track 104)
        // loadedSessions is ordered from oldest to newest
        XCTAssertEqual(loadedSessions.first?.trackTitle, "Track 5", "Expected oldest kept session to be Track 5")
        XCTAssertEqual(loadedSessions.last?.trackTitle, "Track 104", "Expected newest session to be Track 104")
    }
    
    // MARK: - Load Tests
    
    func testLoadAll_WithNoSavedSessions_ReturnsEmptyArray() {
        // Given: No saved sessions
        
        // When
        let sessions = service.loadAll()
        
        // Then: Should return empty array
        XCTAssertEqual(sessions.count, 0, "Expected empty array")
    }
    
    func testLoadAll_AfterSaving_ReturnsCorrectSessions() {
        // Given: Saved sessions
        let session1 = Session(
            mode: .alpha,
            lightSource: .flashlight,
            audioSource: .localFile,
            trackTitle: "Track 1"
        )
        let session2 = Session(
            mode: .gamma,
            lightSource: .screen,
            audioSource: .microphone,
            trackTitle: "Track 2"
        )
        
        service.save(session: session1)
        service.save(session: session2)
        
        // When
        let loadedSessions = service.loadAll()
        
        // Then: Should load all sessions with correct data
        XCTAssertEqual(loadedSessions.count, 2)
        XCTAssertEqual(loadedSessions[0].trackTitle, "Track 1")
        XCTAssertEqual(loadedSessions[0].mode, .alpha)
        XCTAssertEqual(loadedSessions[1].trackTitle, "Track 2")
        XCTAssertEqual(loadedSessions[1].mode, .gamma)
    }
    
    // MARK: - Clear Tests
    
    func testClearAll_RemovesAllSessions() {
        // Given: Saved sessions
        service.save(session: Session(mode: .alpha, lightSource: .flashlight, audioSource: .localFile))
        service.save(session: Session(mode: .gamma, lightSource: .screen, audioSource: .microphone))
        
        // When
        service.clearAll()
        
        // Then: All sessions should be removed
        let sessions = service.loadAll()
        XCTAssertEqual(sessions.count, 0, "Expected no sessions after clear")
    }
    
    // MARK: - Data Persistence Tests
    
    func testDataPersistence_AcrossServiceInstances() {
        // Given: Session saved with first service instance
        let session = Session(
            mode: .alpha,
            lightSource: .flashlight,
            audioSource: .localFile,
            trackTitle: "Persistent Track"
        )
        service.save(session: session)
        
        // When: Create new service instance
        let newService = SessionHistoryService()
        let loadedSessions = newService.loadAll()
        
        // Then: Data should persist
        XCTAssertEqual(loadedSessions.count, 1, "Expected session to persist across instances")
        XCTAssertEqual(loadedSessions.first?.trackTitle, "Persistent Track")
    }
}
