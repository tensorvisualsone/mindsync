import Foundation
@testable import MindSync

class MockSessionHistoryService: SessionHistoryServiceProtocol {
    var savedSessions: [Session] = []
    var saveCalled = false
    var loadAllCalled = false
    var clearAllCalled = false
    
    func save(session: Session) {
        saveCalled = true
        savedSessions.append(session)
    }
    
    func loadAll() -> [Session] {
        loadAllCalled = true
        return savedSessions
    }
    
    func clearAll() {
        clearAllCalled = true
        savedSessions.removeAll()
    }
}
