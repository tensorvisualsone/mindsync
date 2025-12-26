import SwiftUI

struct SessionDetailView: View {
    let session: Session
    
    var body: some View {
        List {
            Section(header: Text(NSLocalizedString("history.detail.sessionInfo", comment: "Session Info"))) {
                DetailRow(title: NSLocalizedString("history.detail.date", comment: "Date"), value: formatDate(session.startedAt))
                DetailRow(title: NSLocalizedString("history.detail.time", comment: "Time"), value: formatTime(session.startedAt))
                DetailRow(title: NSLocalizedString("history.detail.duration", comment: "Duration"), value: session.formattedDuration)
                DetailRow(title: NSLocalizedString("history.detail.mode", comment: "Mode"), value: session.mode.displayName)
                DetailRow(title: NSLocalizedString("history.detail.lightSource", comment: "Light Source"), value: session.lightSource.displayName)
            }
            
            Section(header: Text(NSLocalizedString("history.detail.audioInfo", comment: "Audio Info"))) {
                if let title = session.trackTitle {
                    DetailRow(title: NSLocalizedString("history.detail.title", comment: "Title"), value: title)
                }
                if let artist = session.trackArtist {
                    DetailRow(title: NSLocalizedString("history.detail.artist", comment: "Artist"), value: artist)
                }
                if let bpm = session.trackBPM {
                    DetailRow(title: NSLocalizedString("history.detail.bpm", comment: "BPM"), value: "\(Int(bpm))")
                }
                DetailRow(title: NSLocalizedString("history.detail.source", comment: "Source"), value: session.audioSource == .microphone ? NSLocalizedString("session.microphone", comment: "") : NSLocalizedString("history.detail.localFile", comment: ""))
            }
            
            Section(header: Text(NSLocalizedString("history.detail.status", comment: "Status"))) {
                if let endReason = session.endReason {
                    DetailRow(title: NSLocalizedString("history.detail.endReason", comment: "End Reason"), value: endReason.localizedDescription)
                }
                if session.thermalWarningOccurred {
                    HStack {
                        Text(NSLocalizedString("history.detail.thermalWarning", comment: "Thermal Warning"))
                        Spacer()
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.mindSyncWarning)
                    }
                }
            }
        }
        .navigationTitle(NSLocalizedString("history.detail.title", comment: "Session Details"))
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

