import Foundation

/// Service für Session-Historie-Verwaltung
final class SessionHistoryService {
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "savedSessions"
    
    /// Speichert eine Session
    func save(session: Session) {
        var sessions = loadAll()
        sessions.append(session)
        
        // Begrenze auf letzte 100 Sessions
        if sessions.count > 100 {
            sessions = Array(sessions.suffix(100))
        }
        
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: sessionsKey)
        } catch {
            print("SessionHistoryService.save: Failed to encode sessions: \(error)")
        }
    }
    
    /// Lädt alle gespeicherten Sessions
    func loadAll() -> [Session] {
        guard let data = userDefaults.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([Session].self, from: data) else {
            return []
        }
        return sessions
    }
    
    /// Löscht alle gespeicherten Sessions
    func clearAll() {
        userDefaults.removeObject(forKey: sessionsKey)
    }
}
