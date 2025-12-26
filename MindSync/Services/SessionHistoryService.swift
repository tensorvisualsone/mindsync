import Foundation
import os.log

protocol SessionHistoryServiceProtocol {
    func save(session: Session)
    func loadAll() -> [Session]
    func clearAll()
    func delete(ids: Set<UUID>)
}

/// Service for session history management
/// - Note: Current implementation loads and saves all sessions to UserDefaults on every save operation,
///         which scales poorly with the number of sessions (up to 100). For better performance, consider
///         using a more efficient storage approach such as individual keys for recent sessions, a database,
///         or incremental updates rather than rewriting the entire array each time.
final class SessionHistoryService: SessionHistoryServiceProtocol {
    private let userDefaults: UserDefaults
    private let sessionsKey = "savedSessions"
    private let logger = Logger(subsystem: "com.mindsync", category: "SessionHistory")
    
    /// Creates a new `SessionHistoryService`.
    ///
    /// - Parameter userDefaults:
    ///   The `UserDefaults` store used for persistence. In production, the default `.standard`
    ///   instance is typically sufficient. In tests, **always** inject a dedicated instance
    ///   (for example created via `UserDefaults(suiteName:)` or `SessionHistoryService.makeTestInstance()`)
    ///   to avoid leaking state between tests.
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }
    
    /// Convenience factory for creating an instance backed by an isolated `UserDefaults` suite.
    ///
    /// This method is useful for testing scenarios where you need an isolated storage environment.
    ///
    /// - Parameter suiteName: The suite name to use for the test store. Defaults to
    ///   `"SessionHistoryServiceTests"`.
    /// - Returns: A `SessionHistoryService` configured with an isolated `UserDefaults` instance.
    ///
    /// - Note: Remember to call `removePersistentDomain(forName:)` or `removeSuite(named:)` 
    ///   in test teardown to clean up the isolated storage.
    static func makeTestInstance(suiteName: String = "SessionHistoryServiceTests") -> SessionHistoryService {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Failed to create isolated UserDefaults suite '\(suiteName)' for SessionHistoryService tests. Check the suite name configuration.")
        }
        return SessionHistoryService(userDefaults: defaults)
    }
    
    /// Saves a session
    /// - Note: This operation loads all existing sessions, appends the new one, and saves the entire array
    ///         back to UserDefaults. This creates unnecessary overhead as the session count approaches 100.
    func save(session: Session) {
        var sessions = loadAll()
        sessions.append(session)
        
        // Limit to last 100 sessions
        if sessions.count > 100 {
            sessions = Array(sessions.suffix(100))
            logger.info("Session history limit reached, keeping last 100 sessions")
        }
        
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: sessionsKey)
            logger.info("Session saved successfully: mode=\(session.mode.rawValue), duration=\(session.duration)s, source=\(session.audioSource.rawValue)")
        } catch {
            logger.error("Failed to encode sessions: \(error.localizedDescription, privacy: .private)")
            // Note: Encoding failures are typically deterministic (e.g., non-encodable data)
            // and retrying without changes won't help. The session data is lost in this case.
        }
    }
    
    /// Loads all saved sessions
    func loadAll() -> [Session] {
        // If there is no data stored yet, return an empty array.
        guard let data = userDefaults.data(forKey: sessionsKey) else {
            return []
        }
        
        do {
            let sessions = try JSONDecoder().decode([Session].self, from: data)
            return sessions
        } catch {
            logger.error("Failed to decode sessions from UserDefaults: \(error.localizedDescription, privacy: .private)")
            // We return an empty array to keep callers resilient, but the error is logged
            // so that data corruption or incompatible schema changes are not silent.
            return []
        }
    }
    
    /// Deletes all saved sessions
    func clearAll() {
        let count = loadAll().count
        userDefaults.removeObject(forKey: sessionsKey)
        logger.info("Cleared all \(count) sessions from history")
    }
    
    /// Deletes specific sessions
    func delete(ids: Set<UUID>) {
        var sessions = loadAll()
        sessions.removeAll { ids.contains($0.id) }
        
        do {
            let data = try JSONEncoder().encode(sessions)
            userDefaults.set(data, forKey: sessionsKey)
            logger.info("Deleted \(ids.count) sessions")
        } catch {
            logger.error("Failed to delete sessions: \(error.localizedDescription, privacy: .private)")
        }
    }
}
