import Foundation
import Combine

@MainActor
final class SessionHistoryViewModel: ObservableObject {
    @Published var sessions: [Session] = []
    @Published var filteredSessions: [Session] = []
    @Published var selectedModeFilter: EntrainmentMode?
    
    private let historyService: SessionHistoryServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
    
    init(historyService: SessionHistoryServiceProtocol = ServiceContainer.shared.sessionHistoryService) {
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
            .sink { [weak self] sessions in
                self?.filteredSessions = sessions
            }
            .store(in: &cancellables)
    }
    
    func loadSessions() {
        let allSessions = historyService.loadAll()
        // Sort by date descending (newest first)
        sessions = allSessions.sorted { $0.startedAt > $1.startedAt }
    }
    
    func deleteSession(at offsets: IndexSet) {
        let sessionsToDelete = offsets.map { filteredSessions[$0] }
        let idsToDelete = Set(sessionsToDelete.map { $0.id })
        
        // Update local state
        sessions.removeAll { idsToDelete.contains($0.id) }
        
        // Update persistent storage
        historyService.delete(ids: idsToDelete)
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
        if let formatted = Self.durationFormatter.string(from: totalDuration) {
            return formatted
        }

        // Fallback: localized format string for hours and minutes
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        let format = NSLocalizedString(
            "history.totalDuration.format",
            value: "%dh %02dm",
            comment: "Total duration in hours and minutes (e.g. 2h 05m)"
        )
        return String(format: format, hours, minutes)
    }
}

