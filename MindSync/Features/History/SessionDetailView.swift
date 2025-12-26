import SwiftUI

struct SessionDetailView: View {
    let session: Session
    
    var body: some View {
        List {
            Section(header: Text("Session Info")) {
                DetailRow(title: "Date", value: formatDate(session.startedAt))
                DetailRow(title: "Time", value: formatTime(session.startedAt))
                DetailRow(title: "Duration", value: session.formattedDuration)
                DetailRow(title: "Mode", value: session.mode.displayName)
                DetailRow(title: "Light Source", value: session.lightSource.displayName)
            }
            
            Section(header: Text("Audio Info")) {
                if let title = session.trackTitle {
                    DetailRow(title: "Title", value: title)
                }
                if let artist = session.trackArtist {
                    DetailRow(title: "Artist", value: artist)
                }
                if let bpm = session.trackBPM {
                    DetailRow(title: "BPM", value: "\(Int(bpm))")
                }
                DetailRow(title: "Source", value: session.audioSource == .microphone ? "Microphone" : "Local File")
            }
            
            Section(header: Text("Status")) {
                if let endReason = session.endReason {
                    DetailRow(title: "End Reason", value: endReason.localizedDescription)
                }
                if session.thermalWarningOccurred {
                    HStack {
                        Text("Thermal Warning")
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.mindSyncWarning)
                    }
                }
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

extension Session.EndReason {
    var localizedDescription: String {
        switch self {
        case .userStopped: return "User Stopped"
        case .trackEnded: return "Track Ended"
        case .thermalShutdown: return "Thermal Shutdown"
        case .fallDetected: return "Fall Detected"
        case .phoneCall: return "Phone Call"
        case .appBackgrounded: return "Backgrounded"
        }
    }
}

