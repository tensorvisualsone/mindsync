import Foundation
import os.log

/// Service for session history management
final class SessionHistoryService {
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "savedSessions"
    private let logger = Logger(subsystem: "com.mindsync", category: "SessionHistory")
    
    /// Saves a session
    func save(session: Session) {
        var sessions = loadAll()
        sessions.append(session)
        
        // Limit to last 100 sessions
        if sessions.count > 100 {
            sessions = Array(sessions.suffix(100))
        }
        
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: sessionsKey)
        } catch {
            logger.error("Failed to encode sessions: \(error.localizedDescription, privacy: .private)")
        }
    }
    
    /// Loads all saved sessions
    func loadAll() -> [Session] {
        guard let data = userDefaults.data(forKey: sessionsKey),
              let sessions = try? JSONDecoder().decode([Session].self, from: data) else {
            return []
        }
        return sessions
    }
    
    /// Deletes all saved sessions
    func clearAll() {
        userDefaults.removeObject(forKey: sessionsKey)
    }
}
