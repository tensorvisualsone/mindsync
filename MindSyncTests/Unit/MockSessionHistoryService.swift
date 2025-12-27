import Foundation
@testable import MindSync

class MockSessionHistoryService: SessionHistoryServiceProtocol {
    var savedSessions: [Session] = []
    var saveCalled = false
    var loadAllCalled = false
    var clearAllCalled = false
    var deleteIdsCalled = false
    var lastDeletedIds: Set<UUID> = []
    
    func save(session: Session) {
        saveCalled = true
        savedSessions.append(session)
    }
    
    func loadAll() -> [Session] {
        loadAllCalled = true
        return savedSessions
    }
    
    func delete(ids: Set<UUID>) {
        deleteIdsCalled = true
        lastDeletedIds = ids
        savedSessions.removeAll { ids.contains($0.id) }
    }
    
    func clearAll() {
        clearAllCalled = true
        savedSessions.removeAll()
    }
}
