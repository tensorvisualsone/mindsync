import Foundation
import os.log

/// Service for session history management
/// - Note: Current implementation loads and saves all sessions to UserDefaults on every save operation,
///         which scales poorly with the number of sessions (up to 100). For better performance, consider
///         using a more efficient storage approach such as individual keys for recent sessions, a database,
///         or incremental updates rather than rewriting the entire array each time.
final class SessionHistoryService {
    private let userDefaults = UserDefaults.standard
    private let sessionsKey = "savedSessions"
    private let logger = Logger(subsystem: "com.mindsync", category: "SessionHistory")
    
    /// Saves a session
    /// - Note: This operation loads all existing sessions, appends the new one, and saves the entire array
    ///         back to UserDefaults. This creates unnecessary overhead as the session count approaches 100.
    ///         If encoding fails, the operation will be retried once. If it fails again, the session is lost.
    func save(session: Session) {
        var sessions = loadAll()
        sessions.append(session)
        
        // Limit to last 100 sessions
        if sessions.count > 100 {
            sessions = Array(sessions.suffix(100))
        }
        
        // Attempt to encode and save with retry logic
        var attempts = 0
        let maxAttempts = 2
        
        while attempts < maxAttempts {
            do {
                let data = try JSONEncoder().encode(sessions)
                userDefaults.set(data, forKey: sessionsKey)
                return // Success
            } catch {
                attempts += 1
                logger.error("Failed to encode sessions (attempt \(attempts)/\(maxAttempts)): \(error.localizedDescription, privacy: .private)")
                
                if attempts >= maxAttempts {
                    logger.error("Session could not be saved after \(maxAttempts) attempts. Session data may be lost.")
                }
            }
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
