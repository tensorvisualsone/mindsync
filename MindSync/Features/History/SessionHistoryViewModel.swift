import Foundation
import Combine

@MainActor
final class SessionHistoryViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var filteredSessions: [Session] = []
    @Published var selectedModeFilter: EntrainmentMode?
    
    private let historyService: SessionHistoryService
    private var cancellables = Set<AnyCancellable>()
    
    init(historyService: SessionHistoryService = ServiceContainer.shared.sessionHistoryService) {
        self.historyService = historyService
        loadSessions()
        
        $selectedModeFilter
            .combineLatest($sessions)
            .map { mode, allSessions in
                if let mode = mode {
                    return allSessions.filter { $0.mode == mode }
                } else {
                    return allSessions
                }
            }
            .assign(to: \.filteredSessions, on: self)
            .store(in: &cancellables)
    }
    
    func loadSessions() {
        let allSessions = historyService.loadAll()
        // Sort by date descending (newest first)
        sessions = allSessions.sorted { $0.startedAt > $1.startedAt }
    }
    
    func deleteSession(at offsets: IndexSet) {
        // Note: The current SessionHistoryService doesn't support deleting individual sessions by ID easily
        // without reloading and saving everything. This is a limitation of the array-based storage.
        // For now, we'll just implement clearing all history or we would need to extend the service.
        // Given the requirement to not edit the service deeply right now, we will skip individual deletion
        // or implement it if critical. The UI can offer "Clear All".
    }
    
    func clearHistory() {
        historyService.clearAll()
        loadSessions()
    }
    
    var totalDuration: TimeInterval {
        sessions.reduce(0) { $0 + $1.duration }
    }
    
    var totalSessions: Int {
        sessions.count
    }
    
    func formattedTotalDuration() -> String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
}

