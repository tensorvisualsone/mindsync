import SwiftUI

struct SessionHistoryView: View {
    @StateObject private var viewModel = SessionHistoryViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                if viewModel.sessions.isEmpty {
                    emptyStateView
                } else {
                    statsSection
                    filterSection
                    sessionsList
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !viewModel.sessions.isEmpty {
                        Button("Clear") {
                            viewModel.clearHistory()
                        }
                    }
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No sessions yet")
                    .font(.headline)
                Text("Your completed sessions will appear here.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        }
        .listRowBackground(Color.clear)
    }
    
    private var statsSection: some View {
        Section(header: Text("Overview")) {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(viewModel.totalSessions)")
                        .font(.title2)
                        .bold()
                    Text("Total Sessions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text(viewModel.formattedTotalDuration())
                        .font(.title2)
                        .bold()
                    Text("Total Time")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var filterSection: some View {
        Section(header: Text("Filter")) {
            Picker("Mode", selection: $viewModel.selectedModeFilter) {
                Text("All Modes").tag(EntrainmentMode?.none)
                ForEach(EntrainmentMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(EntrainmentMode?.some(mode))
                }
            }
        }
    }
    
    private var sessionsList: some View {
        Section(header: Text("Sessions")) {
            ForEach(viewModel.filteredSessions) { session in
                NavigationLink(destination: SessionDetailView(session: session)) {
                    SessionRow(session: session)
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: Session
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.mode.displayName)
                    .font(.headline)
                    .foregroundColor(session.mode.themeColor)
                Text(formatDate(session.startedAt))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(session.formattedDuration)
                    .font(.subheadline)
                    .monospacedDigit()
                if let title = session.trackTitle {
                    Text(title)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

